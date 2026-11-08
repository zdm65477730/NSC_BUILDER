#!/usr/bin/env python3
"""Reference NCZ decompressor matching NSCB's decompressor.py logic exactly.
Usage: python ncz_ref.py <input.nsz> <output_dir>
Extracts every .ncz entry to <output_dir>/<basename>.nca and copies other entries verbatim.
"""
import sys, os, struct, io
from Crypto.Cipher import AES
from Crypto.Util import Counter
import zstandard

def read_int64le(f):
    return struct.unpack('<q', f.read(8))[0]

def read_int32le(f):
    return struct.unpack('<I', f.read(4))[0]

def parse_pfs0(data, base=0):
    """Returns list of (name, offset, size) absolute offsets."""
    assert data[base:base+4] == b'PFS0', "not PFS0"
    n = read_int32le(io.BytesIO(data[base+4:base+8]))
    stbl_size = read_int32le(io.BytesIO(data[base+8:base+12]))
    entries = []
    tbl_off = base + 0x10
    str_off = tbl_off + n * 0x18
    for i in range(n):
        e = tbl_off + i * 0x18
        off = struct.unpack('<q', data[e:e+8])[0]
        size = struct.unpack('<q', data[e+8:e+16])[0]
        name_off = struct.unpack('<I', data[e+16:e+20])[0]
        end = data.index(b'\x00', str_off + name_off)
        name = data[str_off + name_off:end].decode()
        entries.append((name, base + 0x10 + n * 0x18 + stbl_size + off, size))
    return entries

def decompress_ncz_bytes(ncz):
    f = io.BytesIO(ncz)
    header = f.read(0x4000)
    magic = f.read(8)
    assert magic in (b'NCZSECTN', b'NCZSECTOK'), f"unexpected magic {magic}"
    sc = read_int64le(f)
    sections = []
    for _ in range(sc):
        off = read_int64le(f); size = read_int64le(f)
        ct = read_int64le(f); f.read(8)  # padding
        key = f.read(0x10); counter = f.read(0x10)
        sections.append((off, size, ct, key, counter))
    # leading gap
    if sections and sections[0][0] - 0x4000 > 0:
        sections.insert(0, (0x4000, sections[0][0] - 0x4000, 1, sections[0][3], sections[0][4]))
    dctx = zstandard.ZstdDecompressor()
    reader = dctx.stream_reader(f)
    out = bytearray(header)
    while True:
        chunk = reader.read(65536)
        if not chunk: break
        out.extend(chunk)
    # AES-CTR re-encrypt each encrypted section
    for (off, size, ct, key, counter) in sections:
        if ct != 3: continue
        needed = off + size
        if needed > len(out): out.extend(b'\x00' * (needed - len(out)))
        ctr = Counter.new(64, prefix=counter[0:8], initial_value=(off >> 4))
        aes = AES.new(key, AES.MODE_CTR, counter=ctr)
        enc = aes.encrypt(bytes(out[off:off+size]))
        out[off:off+size] = enc
    return bytes(out)

def main():
    nsz_path, out_dir = sys.argv[1], sys.argv[2]
    os.makedirs(out_dir, exist_ok=True)
    with open(nsz_path, 'rb') as f:
        data = f.read()
    entries = parse_pfs0(data, 0)
    print(f"PFS0 has {len(entries)} entries")
    for name, off, size in entries:
        blob = data[off:off+size]
        if name.endswith('.ncz'):
            print(f"decompressing {name} ({size} bytes)...")
            nca = decompress_ncz_bytes(blob)
            out_name = name[:-3] + 'nca'
        else:
            nca = blob
            out_name = name
        with open(os.path.join(out_dir, out_name), 'wb') as o:
            o.write(nca)
        print(f"  -> {out_name}: {len(nca)} bytes")
    print("done")

if __name__ == '__main__':
    main()
