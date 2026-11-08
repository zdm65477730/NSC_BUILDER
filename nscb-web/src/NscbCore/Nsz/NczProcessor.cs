using System.Buffers;
using System.Buffers.Binary;
using LibHac.Common.Keys;
using LibHac.Fs;
using LibHac.FsSystem;
using LibHac.Tools.FsSystem;
using LibHac.Tools.FsSystem.NcaUtils;
using ZstdSharp;
using ZstdSharp.Unsafe;

namespace NscbCore.Nsz;

/// <summary>
/// Solid-mode NCZ compression and decompression.
/// Mirrors NSCB's decompressor/compressor: NCZ = NCA header + section table + zstd stream.
/// Decompression is self-contained; compression requires a valid KeySet with the header key.
/// </summary>
public static class NczProcessor
{
    // ── Decompression ───────────────────────────────────────────────────────────

    /// <summary>
    /// Decompress a solid-mode NCZ stream to a complete NCA written to <paramref name="ncaOutput"/>.
    /// AES-CTR parameters come from the NCZ section table itself; no external keys are required.
    /// </summary>
    public static void Decompress(Stream nczInput, Stream ncaOutput,
        Action<long>? progress = null, CancellationToken ct = default)
        => Decompress(nczInput, ncaOutput, 0, progress, ct);

    /// <summary>Decompress a solid-mode NCZ. When <paramref name="maxNcaBytes"/> &gt; 0, only that many
    /// leading NCA bytes are produced (header + body prefix) and only fully-contained sections are
    /// re-encrypted — enough to read a small early section like ExeFS/main.npdm without expanding RomFS.</summary>
    public static void Decompress(Stream nczInput, Stream ncaOutput, long maxNcaBytes,
        Action<long>? progress = null, CancellationToken ct = default)
    {
        var ncz = NczHeader.Parse(nczInput);

        // Step 1: Write the plaintext NCA header (0x4000 bytes stored verbatim in NCZ).
        ncaOutput.Position = 0;
        ncaOutput.Write(ncz.NcaHeader, 0, ncz.NcaHeader.Length);
        progress?.Invoke(ncz.NcaHeader.Length);
        if (maxNcaBytes > 0 && maxNcaBytes <= NczHeader.NcaHeaderSize) return;

        // Step 2: Zstd-decompress the body → plaintext written sequentially from offset 0x4000.
        long bodyCap = maxNcaBytes > 0 ? maxNcaBytes - NczHeader.NcaHeaderSize : 0;
        nczInput.Position = ncz.DataOffset;
        ZstdDecompress(nczInput, ncaOutput, progress, ct, bodyCap);
        ncaOutput.Flush();

        // Step 3: AES-CTR re-encrypt each encrypted section in-place (only those fully within the cap).
        foreach (var s in ncz.Sections)
        {
            if (!s.UseCrypto || s.Size == 0) continue;
            if (maxNcaBytes > 0 && s.Offset + s.Size > maxNcaBytes) continue;
            ct.ThrowIfCancellationRequested();
            AesCtrEncryptInPlace(ncaOutput, s);
            progress?.Invoke(s.Size);
        }
    }

    // ── Compression ──────────────────────────────────────────────────────────────

    /// <summary>
    /// Compress a single NCA (accessible as <paramref name="ncaSource"/>) to solid-mode NCZ.
    /// Requires the header key to enumerate and read the decrypted section plaintext.
    /// </summary>
    public static void Compress(IStorage ncaSource, long ncaSize, Stream nczOutput,
        KeySet keySet, int zstdLevel, Action<long>? progress = null, CancellationToken ct = default, int threads = 1)
    {
        if (threads < 1) threads = 1;
        int cpu = Math.Max(1, Environment.ProcessorCount);
        if (threads > cpu) threads = cpu;   // never more zstd workers than cores

        var nca = new Nca(keySet, ncaSource);

        // Raw NCA header (0x4000) is stored verbatim (still XTS-encrypted, exactly as on disk).
        var ncaHeader = new byte[NczHeader.NcaHeaderSize];
        ncaSource.Read(0, ncaHeader).ThrowIfFailure();
        nczOutput.Write(ncaHeader);
        progress?.Invoke(ncaHeader.Length);

        // Faithful NCZ section table: per-region content counters + BKTR subsections, so the existing
        // Decompress re-encrypts every section and rebuilds the ORIGINAL NCA byte-for-byte.
        var sections = BuildSections(nca);
        byte[] table = BuildSectionTable(sections);
        nczOutput.Write(table);
        progress?.Invoke(table.Length);

        // Payload source = each region's DECRYPTED RAW content (OpenRawStorage), read section-by-section
        // in offset order. This (not the BKTR-merged OpenDecryptedNca) is exactly what Decompress
        // re-encrypts back to the ORIGINAL NCA bytes.
        var regStart = new long[4]; var regSize = new long[4]; var regStor = new IStorage[4]; int nreg = 0;
        for (int i = 0; i < 4; i++)
        {
            if (!nca.Header.IsSectionEnabled(i)) continue;
            long s = nca.Header.GetSectionStartOffset(i), z = nca.Header.GetSectionSize(i);
            if (z <= 0) continue;
            regStart[nreg] = s; regSize[nreg] = z; regStor[nreg] = nca.OpenRawStorage(i); nreg++;
        }
        // Open the whole-NCA decrypted view only for bytes that fall outside every raw region (gaps/rare).
        IStorage? lazyDec = null;
        // Read [absOffset, absOffset+size) from the RAW per-region storages, splitting at region boundaries so
        // every sub-read is 16-byte aligned. Aes128CtrEx/SectorStorage require aligned offset AND size; the
        // parallel path's chunk boundaries can otherwise straddle a region or land unaligned, throwing
        // "Offset must be a multiple of 16". Region bytes always come from OpenRawStorage (never the
        // BKTR-merged view) so the compressed payload decrypts back to the ORIGINAL NCA bytes.
        void ReadPayload(long absOffset, long size, Span<byte> dst)
        {
            long done = 0;
            while (done < size)
            {
                long cur = absOffset + done;
                int r = -1;
                for (int k = 0; k < nreg; k++)
                    if (cur >= regStart[k] && cur < regStart[k] + regSize[k]) { r = k; break; }
                long take;
                if (r >= 0)
                {
                    take = Math.Min(size - done, regStart[r] + regSize[r] - cur);          // stay inside this region
                    regStor[r].Read(cur - regStart[r], dst.Slice((int)done, (int)take)).ThrowIfFailure();
                }
                else
                {
                    long next = long.MaxValue;                                             // gap → up to next region
                    for (int k = 0; k < nreg; k++) if (regStart[k] > cur) next = Math.Min(next, regStart[k]);
                    take = next == long.MaxValue ? size - done : Math.Min(size - done, next - cur);
                    (lazyDec ??= nca.OpenDecryptedNca()).Read(cur, dst.Slice((int)done, (int)take)).ThrowIfFailure();
                }
                done += take;
            }
        }

        try
        {
            // SINGLE-FRAME output is MANDATORY for NSZ/XCZ compatibility: the format is one solid zstd frame and
            // conformant single-frame decoders (NSGManager, console installers) read only the FIRST frame — a past
            // "one frame per chunk" parallel pipeline emitted dozens of frames those tools truncated → partial
            // decompress / SHA256 verify FAIL (we measured 49 frames vs NSGManager's 1).
            // We compress through ZstdSharp's high-level CompressionStream, which drives zstd's INTERNAL
            // multithreading (nbWorkers) correctly and still emits exactly ONE frame → parallel speed AND
            // single-frame conformance (this is what NSCB does via libzstd threads=N). The low-level span
            // WrapStream loop is NOT used for MT: its (consumed==0 && written==0) early-break deadlocks workers.
            // ReadPayload keeps every region read 16-byte aligned (Aes128CtrEx) and region-boundary safe.
            using var compressor = new Compressor(zstdLevel);
            using var cs = new CompressionStream(nczOutput, compressor, 1 << 20, preserveCompressor: true, leaveOpen: true);
            if (threads > 1) cs.SetParameter(ZSTD_cParameter.ZSTD_c_nbWorkers, threads);   // set before first Write
            byte[] rbuf = new byte[0x100000];
            foreach (var s in sections)
            {
                long rem = s.Size; long o = s.Offset;
                while (rem > 0)
                {
                    ct.ThrowIfCancellationRequested();
                    int chunk = (int)Math.Min(rbuf.Length, rem);
                    ReadPayload(o, chunk, rbuf.AsSpan(0, chunk));
                    cs.Write(rbuf, 0, chunk);
                    progress?.Invoke(chunk);
                    o += chunk; rem -= chunk;
                }
            }
            cs.Flush();   // drain pending output; the using-Dispose then writes ZSTD_e_end → one complete frame
        }
        finally
        {
            lazyDec?.Dispose();
            foreach (var st in regStor) st?.Dispose();
        }
    }

    // ── Internal helpers ─────────────────────────────────────────────────────────

    private static List<NczSection> BuildSections(Nca nca)
    {
        var sections = new List<NczSection>();

        // Decrypted NCA header (fs entries live at 0x400 + i*0x200) + a decrypted-region reader for BKTR.
        byte[] hdr = new byte[NczHeader.NcaHeaderSize];
        using (var hs = nca.OpenHeaderStorage(false)) hs.Read(0, hdr).ThrowIfFailure();
        using var dec = nca.OpenDecryptedNca();

        // Content AES-CTR key: title key for rights-id NCAs, else the key-area key.
        byte[] aesKey = nca.Header.HasRightsId
            ? (nca.GetDecryptedTitleKey() ?? nca.GetDecryptedKey(0)!)
            : nca.GetDecryptedKey(0)!;

        for (int i = 0; i < 4; i++)
        {
            if (!nca.Header.IsSectionEnabled(i)) continue;
            long start = nca.Header.GetSectionStartOffset(i);
            long size = nca.Header.GetSectionSize(i);
            if (size <= 0) continue;

            var fsHdr = nca.GetFsHeader(i);
            bool none = fsHdr.EncryptionType == NcaEncryptionType.None;
            byte[] base16 = BaseContentCounter(fsHdr.Counter);   // [BE64(counter)][0*8]
            byte[] key = none ? new byte[0x10] : aesKey;
            long ct = none ? 1 : 3;

            // RomFS/BKTR2: the fs header carries {bktrOffset(0x120), bktrSize(0x128)}. When present,
            // emit one plain-CTR section per BKTR subsection with its own counter (mirrors NSCB).
            bool addedBktr = false;
            if (!none)
            {
                long bktrOff = ReadI64(hdr, 0x400 + i * 0x200 + 0x120);
                long bktrSize = ReadI64(hdr, 0x400 + i * 0x200 + 0x128);
                if (bktrSize > 0 && bktrOff >= 0)
                    addedBktr = TryAddBktrSections(dec, start, bktrOff, size, base16, key, sections);
            }
            if (!addedBktr)
                sections.Add(new NczSection { Offset = start, Size = size, CryptoType = ct, CryptoKey = key, CryptoCounter = (byte[])base16.Clone() });
        }

        // Fill inter-section gaps as plaintext so the body tiles contiguously from 0x4000.
        sections.Sort((a, b) => a.Offset.CompareTo(b.Offset));
        long cursor = NczHeader.NcaHeaderSize;
        for (int i = 0; i < sections.Count; i++)
        {
            var s = sections[i];
            if (s.Offset > cursor)
            {
                sections.Insert(i, new NczSection { Offset = cursor, Size = s.Offset - cursor, CryptoType = 1, CryptoKey = new byte[0x10], CryptoCounter = new byte[0x10] });
                i++;
            }
            cursor = s.Offset + s.Size;
        }

        dec.GetSize(out long decSize);
        long ncaEnd = decSize;   // payload is read from the decrypted storage; tile exactly to its size
        if (ncaEnd > cursor)
            sections.Add(new NczSection { Offset = cursor, Size = ncaEnd - cursor, CryptoType = 1, CryptoKey = new byte[0x10], CryptoCounter = new byte[0x10] });

        return sections;
    }

    // NSCB content counter for a region: bytes[0:8] = BE64(fsHdr.Counter), bytes[8:16] = 0.
    // (The decompressor recomputes bytes[8:16] = offset/16 from the absolute position.)
    private static byte[] BaseContentCounter(ulong counter)
    {
        byte[] c = new byte[0x10];
        BinaryPrimitives.WriteUInt64BigEndian(c.AsSpan(0, 8), counter);
        return c;
    }

    // NSCB setBktrCounter(ctr_val, 0): copy base, write BE32(ctr_val) into bytes[4:8], bytes[8:16] left 0.
    private static byte[] SetBktrCounter(byte[] base16, int ctrVal)
    {
        byte[] c = (byte[])base16.Clone();
        uint v = (uint)ctrVal;
        c[0x8 - 0 - 1] = (byte)(v & 0xFF); // c[7]
        c[0x8 - 1 - 1] = (byte)((v >> 8) & 0xFF);  // c[6]
        c[0x8 - 2 - 1] = (byte)((v >> 16) & 0xFF); // c[5]
        c[0x8 - 3 - 1] = (byte)((v >> 24) & 0xFF); // c[4]
        return c;
    }

    // Enumerate BKTR2 subsections from the decrypted region and add one plain-CTR section each.
    // Table layout at (regionStart+bktrOff): pad(4) bucketCount(4) totalPatchSize(8) baseOffsets[2046*8],
    // then buckets at +0x4000: each = pad(4) entryCount(4) endOffset(8) + entryCount*{virt(8) size(8) pad(4) ctr(4)}.
    private static bool TryAddBktrSections(IStorage dec, long regionStart, long bktrOff, long regionSize, byte[] base16, byte[] key, List<NczSection> outList)
    {
        long p = regionStart + bktrOff;
        long regionEnd = regionStart + regionSize;
        byte[] head = new byte[0x10];
        if (dec.Read(p, head).IsFailure()) return false;
        int bucketCount = (int)ReadI32(head, 4);
        if (bucketCount <= 0 || bucketCount > 0x4000) return false;

        long c = p + 0x4000;         // buckets begin after the 16 + 2046*8 header
        var offs = new List<long>();
        var cs = new List<int>();
        var bh = new byte[0x10];
        var eb = new byte[0x10];

        for (int b = 0; b < bucketCount; b++)
        {
            if (dec.Read(c, bh).IsFailure()) break;
            int entryCount = (int)ReadI32(bh, 4);
            c += 0x10;
            if (entryCount <= 0 || entryCount > 0x4000) break;
            for (int e = 0; e < entryCount; e++)
            {
                if (dec.Read(c, eb).IsFailure()) return offs.Count > 0;
                long absOff = regionStart + ReadI64(eb, 0);
                int ctr = (int)ReadI32(eb, 0xC);   // subsection entry = virt(8) padding(4) ctr(4)
                c += 0x10;
                if (absOff < regionStart || absOff >= regionEnd) continue;
                int idx = offs.BinarySearch(absOff);
                if (idx >= 0) { cs[idx] = ctr; continue; }
                idx = ~idx; offs.Insert(idx, absOff); cs.Insert(idx, ctr);
            }
        }

        if (offs.Count == 0) return false;
        // Tile exactly [regionStart, regionEnd): each subsection runs to the next boundary (last → end).
        if (offs[0] > regionStart) { offs.Insert(0, regionStart); cs.Insert(0, 0); }
        for (int i = 0; i < offs.Count; i++)
        {
            long o = offs[i];
            long sz = (i < offs.Count - 1 ? offs[i + 1] : regionEnd) - o;
            if (sz <= 0) continue;
            outList.Add(new NczSection { Offset = o, Size = sz, CryptoType = 3, CryptoKey = key, CryptoCounter = SetBktrCounter(base16, cs[i]) });
        }
        return true;
    }

    private static long ReadI64(byte[] b, int o) => BinaryPrimitives.ReadInt64LittleEndian(b.AsSpan(o, 8));
    private static uint ReadI32(byte[] b, int o) => BinaryPrimitives.ReadUInt32LittleEndian(b.AsSpan(o, 4));

    private static byte[] BuildSectionTable(List<NczSection> sections)
    {
        byte[] buf = new byte[16 + sections.Count * 0x40];
        NczHeader.MagicSolidNew.CopyTo(buf);
        BinaryPrimitives.WriteInt64LittleEndian(buf.AsSpan(8), sections.Count);
        for (int i = 0; i < sections.Count; i++)
        {
            var s = sections[i];
            int o = 16 + i * 0x40;
            BinaryPrimitives.WriteInt64LittleEndian(buf.AsSpan(o),        s.Offset);
            BinaryPrimitives.WriteInt64LittleEndian(buf.AsSpan(o + 8),    s.Size);
            BinaryPrimitives.WriteInt64LittleEndian(buf.AsSpan(o + 0x10), s.CryptoType);
            s.CryptoKey.AsSpan(0, 0x10).CopyTo(buf.AsSpan(o + 0x20));
            s.CryptoCounter.AsSpan(0, 0x10).CopyTo(buf.AsSpan(o + 0x30));
        }
        return buf;
    }

    private static void StreamSectionPlaintext(Nca nca, NczSection section,
        Compressor compressor, Stream output, byte[] outBuf, Action<long>? progress, CancellationToken ct)
    {
        const int Chunk = 0x40000;
        byte[] buf = new byte[Chunk];
        long remaining = section.Size;
        long absPos = section.Offset;
        bool decrypt = section.CryptoType is 3 or 4;

        while (remaining > 0)
        {
            ct.ThrowIfCancellationRequested();
            int chunk = (int)Math.Min(buf.Length, remaining);
            var rc = nca.BaseStorage.Read(absPos, buf.AsSpan(0, chunk));
            if (rc.IsFailure())
                throw new InvalidOperationException(
                    $"BaseStorage.Read failed at 0x{absPos:X} len={chunk}: {rc}");
            if (decrypt)
            {
                // XOR with AES-CTR keystream positioned at absolute NCA file offset.
                byte[] iv = AesCtrHelper.BuildCounter(section.CryptoCounter, absPos);
                AesCtrHelper.Transform(buf.AsSpan(0, chunk), section.CryptoKey, iv);
            }
            FeedCompressor(compressor, buf.AsSpan(0, chunk), output, outBuf);
            progress?.Invoke(chunk);
            absPos += chunk;
            remaining -= chunk;
        }
    }

    private static long GetLen(IStorage s)
    {
        s.GetSize(out long len).ThrowIfFailure();
        return len;
    }

    private static int FindFsIndex(Nca nca, long offset)
    {
        for (int i = 0; i < 4; i++)
        {
            if (!nca.Header.IsSectionEnabled(i)) continue;
            if (offset >= nca.Header.GetSectionStartOffset(i)
                && offset < nca.Header.GetSectionEndOffset(i))
                return i;
        }
        return -1;
    }

    // ── Zstd helpers ─────────────────────────────────────────────────────────────

    internal static void ZstdDecompress(Stream compressed, Stream output,
        Action<long>? progress, CancellationToken ct, long maxOutput = 0)
    {
        using var decomp = new Decompressor();
        byte[] inBuf  = new byte[0x40000];
        byte[] outBuf = new byte[0x40000];
        int inFilled = 0, inConsumed = 0;
        long produced = 0;

        while (true)
        {
            ct.ThrowIfCancellationRequested();
            if (inConsumed >= inFilled)
            {
                inFilled = compressed.Read(inBuf, 0, inBuf.Length);
                inConsumed = 0;
                if (inFilled == 0) break;
            }

            var status = decomp.UnwrapStream(
                inBuf.AsSpan(inConsumed, inFilled - inConsumed), outBuf,
                out int consumed, out int written);
            inConsumed += consumed;
            if (written > 0)
            {
                if (maxOutput > 0 && produced + written > maxOutput) written = (int)(maxOutput - produced);
                if (written > 0) { output.Write(outBuf, 0, written); produced += written; progress?.Invoke(written); }
                if (maxOutput > 0 && produced >= maxOutput) break;
            }
            // Do NOT stop on a single frame's Done — the NCZ body may be several concatenated frames
            // (parallel chunked compression). Keep feeding until the input stream hits EOF. When a frame
            // finishes with no buffered input left, the next iteration reads the following frame; a lone
            // trailing frame (old single-frame files) still ends cleanly on EOF.
        }
    }

    private static void FeedCompressor(Compressor compressor, ReadOnlySpan<byte> input,
        Stream output, byte[] outBuf)
    {
        int srcOff = 0;
        while (srcOff < input.Length)
        {
            compressor.WrapStream(
                input[srcOff..], outBuf,
                out int consumed, out int written, isFinalBlock: false);
            srcOff += consumed;
            if (written > 0) output.Write(outBuf, 0, written);
            if (consumed == 0 && written == 0) break;
        }
    }

    private static void FlushCompressor(Compressor compressor, Stream output, byte[] outBuf)
    {
        // Signal end of stream: wrap empty input with isFinalBlock=true until fully drained.
        OperationStatus status;
        int written;
        do
        {
            status = compressor.WrapStream(ReadOnlySpan<byte>.Empty, outBuf,
                out _, out written, isFinalBlock: true);
            if (written > 0) output.Write(outBuf, 0, written);
        } while (written > 0 && status != OperationStatus.Done);
    }

    // ── AES-CTR ──────────────────────────────────────────────────────────────────

    /// <summary>
    /// AES-CTR re-encrypt a section in-place in <paramref name="ncaStream"/>.
    /// Counter mirrors NSCB: <c>cryptoCounter[0:8] || (section_offset / 16 as BE u64)</c>.
    /// Processes in 0x10000 chunks to avoid large allocations.
    /// </summary>
    private static void AesCtrEncryptInPlace(Stream ncaStream, NczSection section)
    {
        byte[] ctr = AesCtrHelper.BuildCounter(section.CryptoCounter, section.Offset);
        const int Chunk = 0x10000; // must be multiple of 16
        byte[] buf = new byte[Chunk];
        long remaining = section.Size;
        long pos = section.Offset;
        long blockNum = section.Offset / 16;

        while (remaining > 0)
        {
            int chunk = (int)Math.Min(buf.Length, remaining);
            ncaStream.Position = pos;
            ncaStream.ReadExactly(buf, 0, chunk);

            // Build per-chunk counter: same prefix, lower 64-bit starts at (pos/16).
            byte[] chunkCtr = AesCtrHelper.BuildCounter(section.CryptoCounter, pos);
            AesCtrHelper.Transform(buf.AsSpan(0, chunk), section.CryptoKey, chunkCtr);

            ncaStream.Position = pos;
            ncaStream.Write(buf, 0, chunk);

            pos += chunk;
            remaining -= chunk;
            _ = blockNum; // silence unused warning
        }
    }
}
