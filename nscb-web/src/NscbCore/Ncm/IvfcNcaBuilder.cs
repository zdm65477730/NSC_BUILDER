using System.Buffers.Binary;
using System.Security.Cryptography;
using LibHac.Common.Keys;
using LibHac.Fs;
using LibHac.FsSystem;
using LibHac.Tools.FsSystem;
using LibHac.Tools.FsSystem.NcaUtils;
using NscbCore.Crypto;
using NscbCore.Nsz;

namespace NscbCore.Ncm;

/// <summary>
/// Rebuilds a NCA whose IVFC-hashed section (e.g. a Data/Program RomFS section) carries
/// <b>different content</b>, resizing the section and regenerating the full multi-level
/// plain-SHA-256 hash tree + header master hash + hblock, then re-encrypting the header
/// (AES-XTS) and the section (AES-CTR). This is the IVFC counterpart of
/// <see cref="MetaNcaBuilder"/> (which handles the flat 2-level PFS0/Sha256 case).
/// </summary>
/// <remarks>
/// Operates on a section that ends at the file tail (the normal shape for a single-RomFS
/// Data NCA, and for a Program NCA's RomFS section which is last). Other enabled sections
/// before it are left in place; the rebuilt section starts at its original start offset.
/// </remarks>
public static class IvfcNcaBuilder
{
    private const int SectionInfoOffset = 0x240;
    private const int FsHeaderHashOffset = 0x280;
    private const int FsHeadersOffset = 0x400;
    private const int BlockSize = 0x200;

    private const int IvfcMasterRel = 8 + 192; // masterHash within the section FsHeader
    private const int IvfcLevelsRel = 8 + 16;  // level[0] within the section FsHeader; each 24 bytes
    private const int CompressionInfoRel = 376; // NcaCompressionInfo within the FsHeader (TableOffset i64 @ +0)

    /// <summary>Rebuild <paramref name="ncaBytes"/>'s section <paramref name="idx"/> with new content.</summary>
    public static byte[] RebuildWithContent(byte[] ncaBytes, KeySet keySet, int idx, byte[] newContent)
    {
        var nca = new Nca(keySet, new MemoryStorage((byte[])ncaBytes.Clone()));
        var fsHeader = nca.GetFsHeader(idx);
        if (fsHeader.HashType != NcaHashType.Ivfc)
            throw new NotSupportedException("IvfcNcaBuilder requires an IVFC-hashed section.");

        long secStart = nca.Header.GetSectionStartOffset(idx);

        var headerKey = keySet.HeaderKey.DataRo;
        byte[] hdr = ncaBytes[..0xC00].ToArray();
        bool wasEncrypted = !(hdr[0x200] == (byte)'N' && hdr[0x201] == (byte)'C' && hdr[0x202] == (byte)'A');
        if (wasEncrypted) XtsHelper.TransformNcaHeader(hdr, headerKey, decrypt: true);

        // This builder assumes the NCA3 header layout (FsHeaders @0x400, IVFC fields, etc.).
        // Older NCA2 / NCA0 have different header geometry, and ACFC-compressed Program sections
        // interleave a bucket-tree in the raw region — neither is handled here. Fail loudly rather
        // than emit an NCA that silently fails integrity verification.
        if (hdr[0x200] != (byte)'N' || hdr[0x201] != (byte)'C' || hdr[0x202] != (byte)'A' || hdr[0x203] != (byte)'3')
            throw new NotSupportedException(
                $"IvfcNcaBuilder supports NCA3 sections only (found magic '{(char)hdr[0x200]}{(char)hdr[0x201]}{(char)hdr[0x202]}{(char)hdr[0x203]}'). " +
                "NCA2/NCA0 and ACFC-compressed Program sections are not yet supported.");
        if (fsHeader.ExistsCompressionLayer())
            throw new NotSupportedException(
                "IvfcNcaBuilder does not yet rebuild ACFC/LZ4-compressed sections (real Program RomFS deltas); uncompressed IVFC sections are supported.");

        int fsBase = FsHeadersOffset + idx * 0x200;
        int levelsAbs = fsBase + IvfcLevelsRel;
        int nl = BinaryPrimitives.ReadInt32LittleEndian(hdr.AsSpan(fsBase + 8 + 12, 4)); // LevelCount (integrity base +12)
        var step = new int[nl];
        var oldSize = new long[nl];
        for (int i = 0; i < nl; i++)
        {
            step[i] = BinaryPrimitives.ReadInt32LittleEndian(hdr.AsSpan(levelsAbs + i * 24 + 16, 4));
            oldSize[i] = BinaryPrimitives.ReadInt64LittleEndian(hdr.AsSpan(levelsAbs + i * 24 + 8, 8));
        }
        // Active regions = contiguous from 0 up to the last non-empty; the last is the content.
        int active = 0;
        for (int i = 0; i < nl; i++) if (oldSize[i] > 0) active = i + 1;
        if (active < 2) throw new InvalidDataException("IVFC section has no content level.");

        var (regions, master) = IvfcTree.Build(newContent, step, active);

        // Lay out section: region 0 (top) first … content last. Track cumulative offsets/sizes.
        long total = 0;
        foreach (var r in regions) total += r.Length;
        byte[] section = new byte[AlignUp(total, BlockSize)];
        long cur = 0;
        for (int i = 0; i < active; i++)
        {
            regions[i].CopyTo(section.AsSpan((int)cur));
            BinaryPrimitives.WriteInt64LittleEndian(hdr.AsSpan(levelsAbs + i * 24, 8), cur);            // offset
            BinaryPrimitives.WriteInt64LittleEndian(hdr.AsSpan(levelsAbs + i * 24 + 8, 8), regions[i].Length); // size
            cur += regions[i].Length;
        }
        for (int i = active; i < nl; i++) // deactivate unused levels
        {
            BinaryPrimitives.WriteInt64LittleEndian(hdr.AsSpan(levelsAbs + i * 24, 8), 0);
            BinaryPrimitives.WriteInt64LittleEndian(hdr.AsSpan(levelsAbs + i * 24 + 8, 8), 0);
        }

        // Master hash (write up to the stored region width; top region must collapse to ≤ that).
        long mhs = BinaryPrimitives.ReadInt32LittleEndian(hdr.AsSpan(fsBase + 8 + 8, 4)); // MasterHashSize (integrity base +8)
        if (master.Length > mhs) throw new NotSupportedException("Content too large for the fixed IVFC level layout.");
        // Zero the whole master-hash field then write ours, so any unused (larger) slot is clean
        // rather than stale from the original header.
        hdr.AsSpan(fsBase + IvfcMasterRel, (int)mhs).Clear();
        master.CopyTo(hdr.AsSpan(fsBase + IvfcMasterRel, (int)mhs)[..master.Length]);

        // Section-info end block (resize); start unchanged.
        int startBlock = (int)(secStart / BlockSize);
        int endBlock = startBlock + section.Length / BlockSize;
        BinaryPrimitives.WriteInt32LittleEndian(hdr.AsSpan(SectionInfoOffset + idx * 16, 4), startBlock);
        BinaryPrimitives.WriteInt32LittleEndian(hdr.AsSpan(SectionInfoOffset + idx * 16 + 4, 4), endBlock);

        // The rebuilt section is a plain (uncompressed) IVFC RomFS over <paramref name="newContent">;
        // callers feed it the DECOMPRESSED content for ACFC/LZ4 sources. Drop any compression layer
        // (LibHac ExistsCompressionLayer() == CompressionInfo.TableOffset != 0) so the section mounts
        // as plain RomFS. The old bucket-tree tables are gone since we rewrite the whole section.
        BinaryPrimitives.WriteInt64LittleEndian(hdr.AsSpan(fsBase + CompressionInfoRel, 8), 0);      // TableOffset
        BinaryPrimitives.WriteInt64LittleEndian(hdr.AsSpan(fsBase + CompressionInfoRel + 8, 8), 0);  // TableSize

        // Recompute hblock[idx] = SHA256(FsHeader block).
        byte[] hblock = SHA256.HashData(hdr.AsSpan(fsBase, 0x200));
        hblock.CopyTo(hdr.AsSpan(FsHeaderHashOffset + idx * 0x20, 0x20));

        // Refresh the "entire archive size" header field (0x208) for strict readers (DBI/hactool).
        BinaryPrimitives.WriteInt64LittleEndian(hdr.AsSpan(0x208, 8), secStart + section.Length);
        if (wasEncrypted) XtsHelper.TransformNcaHeader(hdr, headerKey, decrypt: false);

        if (fsHeader.EncryptionType != NcaEncryptionType.None)
        {
            byte[] ctrKey = nca.Header.HasRightsId
                ? (nca.GetDecryptedTitleKey() ?? nca.GetDecryptedKey(idx)!)
                : (nca.GetDecryptedKey(2) ?? nca.GetDecryptedKey(idx))!;
            byte[] iv = AesCtrHelper.BuildCounter(new byte[16], secStart);
            AesCtrHelper.DecryptOrEncrypt(section, ctrKey, iv);
        }

        byte[] result = new byte[secStart + section.Length];
        hdr.CopyTo(result, 0);
        // Preserve any lower sections that live between the header and this section (e.g. a
        // Program NCA's ExeFS before its RomFS); the rebuilt IVFC section starts at secStart.
        if (secStart > 0xC00)
            ncaBytes.AsSpan(0xC00, (int)(secStart - 0xC00)).CopyTo(result.AsSpan(0xC00));
        section.CopyTo(result, (int)secStart);
        return result;
    }

    private static int AlignUp(long v, int a) => (int)((v + a - 1) / a * a);

    /// <summary>
    /// Rebuild an ENTIRE multi-section NCA to <paramref name="dst"/>, applying per-section
    /// replacement content (<param name="patched"/>, keyed by section index; sections not listed are
    /// carried over unchanged). Because a patched section can change size, EVERY later section is
    /// re-laid-out and re-encrypted at its new absolute offset (AES-CTR is offset-keyed), and each
    /// enabled section's header start/end block + (for rebuilt IVFC sections) its hash tree / fs-header
    /// hash are regenerated. Only uncompressed IVFC sections can be rebuilt; any other patched section
    /// throws (fail-loud). Unchanged sections are relocated verbatim (works for any type, incl. compressed).
    /// </summary>
    public static void RebuildMultiStreaming(IStorage src, KeySet keySet, Stream dst,
        IReadOnlyDictionary<int, (IStorage Content, long Len)> patched, Action<string>? log = null)
    {
        var nca = new Nca(keySet, src);
        var headerKey = keySet.HeaderKey.DataRo;
        byte[] hdr = new byte[0xC00];
        src.Read(0, hdr).ThrowIfFailure();
        bool wasEncrypted = !(hdr[0x200] == (byte)'N' && hdr[0x201] == (byte)'C' && hdr[0x202] == (byte)'A');
        if (wasEncrypted) XtsHelper.TransformNcaHeader(hdr, headerKey, decrypt: true);
        if (hdr[0x200] != (byte)'N' || hdr[0x201] != (byte)'C' || hdr[0x202] != (byte)'A' || hdr[0x203] != (byte)'3')
            throw new NotSupportedException("IvfcNcaBuilder supports NCA3 only.");

        // Enabled sections (start/end block differ), ascending by original start.
        var idxs = new List<int>();
        for (int i = 0; i < 4; i++)
        {
            int sb = BinaryPrimitives.ReadInt32LittleEndian(hdr.AsSpan(SectionInfoOffset + i * 16, 4));
            int eb = BinaryPrimitives.ReadInt32LittleEndian(hdr.AsSpan(SectionInfoOffset + i * 16 + 4, 4));
            if (eb > sb) idxs.Add(i);
        }
        idxs.Sort((a, b) => BinaryPrimitives.ReadInt32LittleEndian(hdr.AsSpan(SectionInfoOffset + a * 16, 4))
                             .CompareTo(BinaryPrimitives.ReadInt32LittleEndian(hdr.AsSpan(SectionInfoOffset + b * 16, 4))));

        // Per-section image (pre-encryption) descriptor: IVFC-rebuilt or verbatim copy.
        // Keep each section at origStart + cumulative size delta so an identity rebuild is byte-for-byte
        // and only sections AFTER a resized (patched) one shift.
        dst.Write(hdr, 0, 0); // establish writable stream
        dst.Seek(0, SeekOrigin.Begin);
        long delta = 0;
        var secPlan = new List<(int idx, long newStart, long imgLen, bool rebuild, IStorage? content, long len)>();
        var newHdr = (byte[])hdr.Clone();
        foreach (int idx in idxs)
        {
            int sb0 = BinaryPrimitives.ReadInt32LittleEndian(hdr.AsSpan(SectionInfoOffset + idx * 16, 4));
            int eb0 = BinaryPrimitives.ReadInt32LittleEndian(hdr.AsSpan(SectionInfoOffset + idx * 16 + 4, 4));
            long origStart = (long)sb0 * BlockSize, origLen = (long)(eb0 - sb0) * BlockSize;
            long writePos = origStart + delta;
            log?.Invoke($"idx{idx} origStart=0x{origStart:X} origLen=0x{origLen:X} writePos=0x{writePos:X} delta=0x{delta:X} patched={patched.ContainsKey(idx)}");
            int fsBase = FsHeadersOffset + idx * 0x200;
            int levelsAbs = fsBase + IvfcLevelsRel;
            if (patched.TryGetValue(idx, out var pr) && pr.Content is not null)
            {
                var fh = nca.GetFsHeader(idx);
                if (fh.HashType == NcaHashType.Sha256)
                {
                    // Flat PartitionFs (PFS0/SHA-256) section (e.g. a Program's ExeFS). Rebuild the
                    // hash table over the supplied DECOMPRESSED logical content, regenerate master +
                    // level offsets/sizes, then (re)encrypt at writePos with the section's fs.Counter.
                    if (pr.Len > int.MaxValue - 0x100) throw new NotSupportedException("flat patched section too large");
                    int integ = fsBase + 8;
                    int flBlock = BinaryPrimitives.ReadInt32LittleEndian(newHdr.AsSpan(integ + 0x20, 4));
                    if (flBlock <= 0) throw new NotSupportedException("flat section has invalid block size");
                    byte[] content = new byte[pr.Len];
                    pr.Content.Read(0, content).ThrowIfFailure();
                    int numBlocks = (int)((pr.Len + flBlock - 1) / flBlock);
                    long tableSize = (long)numBlocks * 0x20;
                    long contentOff = (tableSize + 0xF) / 0x10 * 0x10;
                    long secTotal = contentOff + pr.Len;
                    long fsecLen = (secTotal + BlockSize - 1) / BlockSize * BlockSize;
                    byte[] img = new byte[fsecLen];
                    for (int k = 0; k < numBlocks; k++)
                    {
                        long bo = (long)k * flBlock; int cnt = (int)Math.Min(flBlock, pr.Len - bo);
                        SHA256.HashData(cnt > 0 ? content.AsSpan((int)bo, cnt) : ReadOnlySpan<byte>.Empty).CopyTo(img.AsSpan(k * 0x20, 0x20));
                    }
                    content.CopyTo(img.AsSpan((int)contentOff));
                    SHA256.HashData(img.AsSpan(0, (int)tableSize)).CopyTo(newHdr.AsSpan(integ, 0x20));
                    BinaryPrimitives.WriteInt64LittleEndian(newHdr.AsSpan(integ + 0x28, 8), 0);
                    BinaryPrimitives.WriteInt64LittleEndian(newHdr.AsSpan(integ + 0x30, 8), tableSize);
                    BinaryPrimitives.WriteInt64LittleEndian(newHdr.AsSpan(integ + 0x38, 8), contentOff);
                    BinaryPrimitives.WriteInt64LittleEndian(newHdr.AsSpan(integ + 0x40, 8), pr.Len);
                    byte[] hbf = SHA256.HashData(newHdr.AsSpan(fsBase, 0x200)); hbf.CopyTo(newHdr.AsSpan(FsHeaderHashOffset + idx * 0x20, 0x20));
                    Aes128CtrTransform? trF = fh.EncryptionType != NcaEncryptionType.None
                        ? new Aes128CtrTransform(CtrKey(nca, keySet, idx), Aes128CtrStorage.CreateCounter(fh.Counter, writePos)) : null;
                    dst.Seek(writePos, SeekOrigin.Begin);
                    trF?.TransformBlock(img.AsSpan(0, (int)fsecLen));
                    dst.Write(img, 0, (int)fsecLen);
                    secPlan.Add((idx, writePos, fsecLen, true, null, 0));
                    delta += fsecLen - origLen;
                    if (log is not null) log($"  idx{idx} flat patched fsecLen=0x{fsecLen:X} content=0x{pr.Len:X} table=0x{tableSize:X} bs=0x{flBlock:X}");
                    continue;
                }
                if (fh.HashType != NcaHashType.Ivfc) throw new NotSupportedException("patched section must be IVFC or Sha256");
                // A compressed (ACFC) section is rebuilt as a plain, UNCOMPRESSED IVFC RomFS over the
                // supplied DECOMPRESSED logical content (valid alternative to compressed; no compressor
                // needed). Correctness is ensured by LevelCount=active, the 64-bit section length, the
                // moved-sibling crypto guard below, and upd_base's reopen-verify (rejects a bad result).
                int nl = BinaryPrimitives.ReadInt32LittleEndian(newHdr.AsSpan(fsBase + 8 + 12, 4)); // header level capacity
                if (log is not null)
                {
                    var sb2 = new System.Text.StringBuilder($"  idx{idx} SOURCE nl={nl} levels=[");
                    for (int i = 0; i < nl; i++) { long o = BinaryPrimitives.ReadInt64LittleEndian(newHdr.AsSpan(levelsAbs + i * 24, 8)); long s2 = BinaryPrimitives.ReadInt64LittleEndian(newHdr.AsSpan(levelsAbs + i * 24 + 8, 8)); int bs2 = BinaryPrimitives.ReadInt32LittleEndian(newHdr.AsSpan(levelsAbs + i * 24 + 16, 4)); sb2.Append($"(0x{o:X},0x{s2:X},bs{bs2}) "); }
                    sb2.Append($"] mhsSrc={BinaryPrimitives.ReadInt32LittleEndian(newHdr.AsSpan(fsBase + 8 + 8, 4))} compOff={BinaryPrimitives.ReadInt64LittleEndian(newHdr.AsSpan(fsBase + CompressionInfoRel, 8))}");
                    log(sb2.ToString());
                }
                var sstep = new int[nl]; var oldsz = new long[nl]; int ActiveOut;
                for (int i = 0; i < nl; i++) { sstep[i] = BinaryPrimitives.ReadInt32LittleEndian(newHdr.AsSpan(levelsAbs + i * 24 + 16, 4)); oldsz[i] = BinaryPrimitives.ReadInt64LittleEndian(newHdr.AsSpan(levelsAbs + i * 24 + 8, 8)); }
                { int a = 0; for (int i = 0; i < nl; i++) if (oldsz[i] > 0) a = i + 1; if (a < 2) throw new InvalidDataException("IVFC has no content level."); ActiveOut = a; }
                int active = ActiveOut;
                var step = new int[active]; Array.Copy(sstep, step, active);
                // Rebuild as uncompressed IVFC with the block-aligned layout real RomFS uses (this is
                // the variant that reopen-verifies): sz[i]=alignUp(numBlocks*32, block), regions
                // zero-padded to sz, and LevelCount=active+1 / blockStep written (LibHac InitIvfcForRomFs:
                // array[i]=level[i-1], content=level[LevelCount-2]).
                var sz = new long[active]; sz[active - 1] = pr.Len;
                for (int i = active - 2; i >= 0; i--) { int bs = 1 << step[i]; sz[i] = AlignUpL(RegionBlocks(sz[i + 1], bs) * 0x20, bs); }
                var region = new byte[active - 1][];
                region[active - 2] = Pad(StreamHashRegion(pr.Content, pr.Len, 1 << step[active - 2]), sz[active - 2]);
                for (int i = active - 3; i >= 0; i--) region[i] = Pad(IvfcTree.HashRegion(region[i + 1], 1 << step[i]), sz[i]);
                byte[] master = IvfcTree.HashRegion(region[0], 1 << step[0]);
                long cur = 0; var off = new long[active]; for (int i = 0; i < active; i++) { off[i] = cur; cur += sz[i]; }
                if (active + 1 > nl) throw new NotSupportedException("IVFC level capacity too small");
                BinaryPrimitives.WriteInt32LittleEndian(newHdr.AsSpan(fsBase + 8 + 12, 4), active + 1);
                for (int i = 0; i < nl; i++)
                {
                    long o = i < active ? off[i] : 0, s = i < active ? sz[i] : 0; int bsv = i < active ? step[i] : 0;
                    BinaryPrimitives.WriteInt64LittleEndian(newHdr.AsSpan(levelsAbs + i * 24, 8), o);
                    BinaryPrimitives.WriteInt64LittleEndian(newHdr.AsSpan(levelsAbs + i * 24 + 8, 8), s);
                    BinaryPrimitives.WriteInt32LittleEndian(newHdr.AsSpan(levelsAbs + i * 24 + 16, 4), bsv);
                }
                long mhs = BinaryPrimitives.ReadInt32LittleEndian(newHdr.AsSpan(fsBase + 8 + 8, 4));
                if (log is not null) log($"  idx{idx} IVFC step=[{string.Join(",", step)}] sz=[{string.Join(",", sz.Select(x => "0x" + x.ToString("X")))}] regs=[{string.Join(",", region.Select(r => "0x" + r.Length.ToString("X")))}] off=[{string.Join(",", off.Select(x => "0x" + x.ToString("X")))}] master={master.Length} mhs={mhs} nl={nl}");
                if (master.Length > mhs) throw new NotSupportedException("content too large for IVFC layout");
                newHdr.AsSpan(fsBase + IvfcMasterRel, (int)mhs).Clear(); master.CopyTo(newHdr.AsSpan(fsBase + IvfcMasterRel, (int)mhs)[..master.Length]);
                BinaryPrimitives.WriteInt64LittleEndian(newHdr.AsSpan(fsBase + CompressionInfoRel, 8), 0);
                BinaryPrimitives.WriteInt64LittleEndian(newHdr.AsSpan(fsBase + CompressionInfoRel + 8, 8), 0);
                byte[] hb = SHA256.HashData(newHdr.AsSpan(fsBase, 0x200)); hb.CopyTo(newHdr.AsSpan(FsHeaderHashOffset + idx * 0x20, 0x20));
                long total = off[active - 1] + pr.Len; long secLen = (total + BlockSize - 1) / BlockSize * BlockSize; // 64-bit: sections can exceed 2 GiB
                if (log is not null) log($"  idx{idx} patched rebuilt secLen=0x{secLen:X} levelsLen=0x{off[active - 1]:X} active={active}");
                // Stream the section (levels buffer + content + block pad) in 1 MiB chunks. Aes128CtrTransform
                // does NOT carry its counter across TransformBlock calls, so seed each chunk's transform at the
                // chunk's absolute offset (clamped to 16) — this keeps memory bounded and the CTR correct.
                long encStart = writePos;
                byte[] levelsBuf = new byte[off[active - 1]]; for (int i = 0; i < active - 1; i++) region[i].CopyTo(levelsBuf.AsSpan((int)off[i]));
                long levelsLen = off[active - 1];
                bool enc = nca.GetFsHeader(idx).EncryptionType != NcaEncryptionType.None;
                ulong fsCtr = nca.GetFsHeader(idx).Counter;
                byte[] ctrK = enc ? CtrKey(nca, keySet, idx) : Array.Empty<byte>();
                const int CH = 0x100000; byte[] chunk = new byte[CH];
                for (long rp = 0; rp < secLen; rp += CH)
                {
                    int cl = (int)Math.Min(CH, secLen - rp); // CH and secLen are multiples of 16, rp too
                    Array.Clear(chunk, 0, cl);
                    if (rp < levelsLen) { int nl2 = (int)Math.Min(cl, levelsLen - rp); levelsBuf.AsSpan((int)rp, nl2).CopyTo(chunk); }
                    long cs = Math.Max(rp, levelsLen), ce = Math.Min(rp + cl, levelsLen + pr.Len);
                    if (ce > cs) pr.Content.Read(cs - levelsLen, chunk.AsSpan((int)(cs - rp), (int)(ce - cs))).ThrowIfFailure();
                    if (enc) new Aes128CtrTransform(ctrK, Aes128CtrStorage.CreateCounter(fsCtr, encStart + rp)).TransformBlock(chunk.AsSpan(0, cl));
                    dst.Seek(encStart + rp, SeekOrigin.Begin);
                    dst.Write(chunk, 0, cl);
                }
                secPlan.Add((idx, encStart, secLen, true, pr.Content, pr.Len));
                delta += secLen - origLen;
            }
            else
            {
                int sb = BinaryPrimitives.ReadInt32LittleEndian(newHdr.AsSpan(SectionInfoOffset + idx * 16, 4));
                int eb = BinaryPrimitives.ReadInt32LittleEndian(newHdr.AsSpan(SectionInfoOffset + idx * 16 + 4, 4));
                long imgLen = (long)(eb - sb) * BlockSize;
                if (writePos == origStart)
                {
                    // Unmoved → copy the section's ENCRYPTED bytes verbatim (no crypto round-trip).
                    dst.Seek(origStart, SeekOrigin.Begin);
                    long d0 = 0; byte[] buf0 = new byte[0x100000];
                    while (d0 < imgLen) { int n = (int)Math.Min(buf0.Length, imgLen - d0); src.Read(origStart + d0, buf0.AsSpan(0, n)).ThrowIfFailure(); dst.Write(buf0, 0, n); d0 += n; }
                }
                else
                {
                    // Moved → re-encrypt at the new absolute offset using the section's own CTR base
                    // (high 8 bytes = fsHeader.Counter, which LibHac folds into the counter seed).
                    var et = nca.GetFsHeader(idx).EncryptionType;
                    if (et is NcaEncryptionType.AesXts or NcaEncryptionType.AesCtrEx)
                        throw new NotSupportedException("cannot safely relocate an AesXts/AesCtrEx section; unsupported section ordering (fail-loud).");
                    var raw = nca.OpenRawStorage(idx, openEncrypted: false);
                    bool enc = et != NcaEncryptionType.None;
                    ulong fsCtr = nca.GetFsHeader(idx).Counter;
                    byte[] ctrK = enc ? CtrKey(nca, keySet, idx) : Array.Empty<byte>();
                    const int CH = 0x100000; byte[] buf = new byte[CH];
                    for (long rp = 0; rp < imgLen; rp += CH)
                    {
                        int n = (int)Math.Min(CH, imgLen - rp);
                        raw.Read(rp, buf.AsSpan(0, n)).ThrowIfFailure();
                        if (enc) new Aes128CtrTransform(ctrK, Aes128CtrStorage.CreateCounter(fsCtr, writePos + rp)).TransformBlock(buf.AsSpan(0, n));
                        dst.Seek(writePos + rp, SeekOrigin.Begin);
                        dst.Write(buf, 0, n);
                    }
                }
                secPlan.Add((idx, writePos, imgLen, false, null, 0));
            }
        }
        // finalize section start/end blocks for every section (in the new layout)
        foreach (var (idx, newStart, imgLen, _, _, _) in secPlan)
        {
            BinaryPrimitives.WriteInt32LittleEndian(newHdr.AsSpan(SectionInfoOffset + idx * 16, 4), (int)(newStart / BlockSize));
            BinaryPrimitives.WriteInt32LittleEndian(newHdr.AsSpan(SectionInfoOffset + idx * 16 + 4, 4), (int)((newStart + imgLen) / BlockSize));
            // note: patched sections already hashed their hblock against newHdr above BEFORE these
            // section-info edits; recompute all hblocks last so they cover the final header.
        }
        for (int i = 0; i < 4; i++)
        {
            if (!idxs.Contains(i)) continue;
            byte[] hb = SHA256.HashData(newHdr.AsSpan(FsHeadersOffset + i * 0x200, 0x200));
            hb.CopyTo(newHdr.AsSpan(FsHeaderHashOffset + i * 0x20, 0x20));
        }
        // Update the NCA's "entire archive size" field (0x208) to the new length BEFORE re-signing-free
        // re-encrypt: strict readers (DBI/hactool) compare it against the file size.
        long end = 0xC00; foreach (var s in secPlan) end = Math.Max(end, s.newStart + s.imgLen);
        BinaryPrimitives.WriteInt64LittleEndian(newHdr.AsSpan(0x208, 8), end);
        if (wasEncrypted) XtsHelper.TransformNcaHeader(newHdr, headerKey, decrypt: false);
        dst.Seek(0, SeekOrigin.Begin);
        dst.Write(newHdr, 0, 0xC00);
        dst.SetLength(end);
        dst.Flush();
    }

    private static byte[] CtrKey(Nca nca, KeySet keySet, int idx) =>
        nca.Header.HasRightsId ? (nca.GetDecryptedTitleKey() ?? nca.GetDecryptedKey(idx)!)
                               : (nca.GetDecryptedKey(2) ?? nca.GetDecryptedKey(idx))!;

    private static long RegionBlocks(long len, int bs) => Math.Max(1, (len + bs - 1) / bs);
    private static long RegionLen(long len, int bs) => RegionBlocks(len, bs) * 0x20;
    private static long AlignUpL(long v, long a) => (v + a - 1) / a * a;
    private static byte[] Pad(byte[] b, long n)
    {
        if (b.Length >= n) return b;
        byte[] r = new byte[n]; b.CopyTo(r, 0); return r;
    }

    /// <summary>
    /// Streaming variant of <see cref="RebuildWithContent"/>: reads the source NCA and the new section
    /// content via <see cref="IStorage"/> and writes the rebuilt NCA to <paramref name="dst"/>, holding
    /// only the (small) hash levels + the source header in memory. Verified byte-identical to
    /// <see cref="RebuildWithContent"/> for the same inputs, so it is safe for multi-GB sections.
    /// </summary>
    public static void RebuildStreaming(IStorage src, int idx, IStorage content, long contentLen,
        KeySet keySet, Stream dst)
    {
        var nca = new Nca(keySet, src);
        var fsHeader = nca.GetFsHeader(idx);
        if (fsHeader.HashType != NcaHashType.Ivfc)
            throw new NotSupportedException("IvfcNcaBuilder requires an IVFC-hashed section.");
        long secStart = nca.Header.GetSectionStartOffset(idx);
        var headerKey = keySet.HeaderKey.DataRo;

        byte[] hdr = new byte[0xC00];
        src.Read(0, hdr).ThrowIfFailure();
        bool wasEncrypted = !(hdr[0x200] == (byte)'N' && hdr[0x201] == (byte)'C' && hdr[0x202] == (byte)'A');
        if (wasEncrypted) XtsHelper.TransformNcaHeader(hdr, headerKey, decrypt: true);
        if (hdr[0x200] != (byte)'N' || hdr[0x201] != (byte)'C' || hdr[0x202] != (byte)'A' || hdr[0x203] != (byte)'3')
            throw new NotSupportedException("IvfcNcaBuilder supports NCA3 sections only.");

        int fsBase = FsHeadersOffset + idx * 0x200;
        int levelsAbs = fsBase + IvfcLevelsRel;
        int nl = BinaryPrimitives.ReadInt32LittleEndian(hdr.AsSpan(fsBase + 8 + 12, 4));
        var step = new int[nl];
        var oldSize = new long[nl];
        for (int i = 0; i < nl; i++)
        {
            step[i] = BinaryPrimitives.ReadInt32LittleEndian(hdr.AsSpan(levelsAbs + i * 24 + 16, 4));
            oldSize[i] = BinaryPrimitives.ReadInt64LittleEndian(hdr.AsSpan(levelsAbs + i * 24 + 8, 8));
        }
        int active = 0;
        for (int i = 0; i < nl; i++) if (oldSize[i] > 0) active = i + 1;
        if (active < 2) throw new InvalidDataException("IVFC section has no content level.");

        // Region sizes bottom-up from the new content length (mirrors IvfcTree.Build lengths).
        var sz = new long[active];
        sz[active - 1] = contentLen;
        for (int i = active - 2; i >= 0; i--) sz[i] = RegionLen(sz[i + 1], 1 << step[i]);
        if (sz[0] <= 0) throw new NotSupportedException("Content too large for the fixed IVFC level layout.");

        // Hash levels active-2 .. 0. Bottom level is streamed over the content; the rest are small (in RAM).
        var region = new byte[active - 1][];
        region[active - 2] = StreamHashRegion(content, contentLen, 1 << step[active - 2]);
        for (int i = active - 3; i >= 0; i--) region[i] = IvfcTree.HashRegion(region[i + 1], 1 << step[i]);
        byte[] master = IvfcTree.HashRegion(region[0], 1 << step[0]);

        // Header edits.
        long cur = 0;
        var levelOff = new long[active];
        for (int i = 0; i < active; i++) { levelOff[i] = cur; cur += sz[i]; }
        for (int i = 0; i < nl; i++)
        {
            long off = i < active ? levelOff[i] : 0, size = i < active ? sz[i] : 0;
            BinaryPrimitives.WriteInt64LittleEndian(hdr.AsSpan(levelsAbs + i * 24, 8), off);
            BinaryPrimitives.WriteInt64LittleEndian(hdr.AsSpan(levelsAbs + i * 24 + 8, 8), size);
        }
        long mhs = BinaryPrimitives.ReadInt32LittleEndian(hdr.AsSpan(fsBase + 8 + 8, 4));
        if (master.Length > mhs) throw new NotSupportedException("Content too large for the fixed IVFC level layout.");
        hdr.AsSpan(fsBase + IvfcMasterRel, (int)mhs).Clear();
        master.CopyTo(hdr.AsSpan(fsBase + IvfcMasterRel, (int)mhs)[..master.Length]);

        long total = levelOff[active - 1] + contentLen;
        long secLen = AlignUp(total, BlockSize);
        int startBlock = (int)(secStart / BlockSize);
        int endBlock = startBlock + (int)(secLen / BlockSize);
        BinaryPrimitives.WriteInt32LittleEndian(hdr.AsSpan(SectionInfoOffset + idx * 16, 4), startBlock);
        BinaryPrimitives.WriteInt32LittleEndian(hdr.AsSpan(SectionInfoOffset + idx * 16 + 4, 4), endBlock);
        BinaryPrimitives.WriteInt64LittleEndian(hdr.AsSpan(fsBase + CompressionInfoRel, 8), 0);
        BinaryPrimitives.WriteInt64LittleEndian(hdr.AsSpan(fsBase + CompressionInfoRel + 8, 8), 0);
        byte[] hblock = SHA256.HashData(hdr.AsSpan(fsBase, 0x200));
        hblock.CopyTo(hdr.AsSpan(FsHeaderHashOffset + idx * 0x20, 0x20));
        BinaryPrimitives.WriteInt64LittleEndian(hdr.AsSpan(0x208, 8), secStart + secLen); // entire-archive-size (strict readers)
        if (wasEncrypted) XtsHelper.TransformNcaHeader(hdr, headerKey, decrypt: false);

        bool enc = fsHeader.EncryptionType != NcaEncryptionType.None;
        byte[] ctrKey = enc
            ? (nca.Header.HasRightsId ? (nca.GetDecryptedTitleKey() ?? nca.GetDecryptedKey(idx)!)
                                      : (nca.GetDecryptedKey(2) ?? nca.GetDecryptedKey(idx))!)
            : Array.Empty<byte>();

        dst.Write(hdr, 0, 0xC00);
        CopyStream(src, dst, 0xC00, secStart); // preserve lower sections verbatim

        // Levels (active-1 regions) are contiguous from section start.
        byte[] levelsBuf = new byte[levelOff[active - 1]];
        for (int i = 0; i < active - 1; i++) region[i].CopyTo(levelsBuf.AsSpan((int)levelOff[i]));
        WriteEncrypted(dst, levelsBuf, secStart, enc, ctrKey);
        // Content streamed in place.
        long co = 0;
        byte[] cb = new byte[0x100000];
        while (co < contentLen)
        {
            int n = (int)Math.Min(cb.Length, contentLen - co);
            content.Read(co, cb.AsSpan(0, n)).ThrowIfFailure();
            WriteEncrypted(dst, cb[..n], secStart + levelOff[active - 1] + co, enc, ctrKey);
            co += n;
        }
        // Zero padding to the block-aligned section length.
        for (long p = total; p < secLen; p += 0x10000)
        {
            int n = (int)Math.Min(0x10000, secLen - p);
            WriteEncrypted(dst, new byte[n], secStart + p, enc, ctrKey);
        }
        dst.Flush();
    }

    private static void WriteEncrypted(Stream dst, byte[] buf, long absOffset, bool enc, byte[] ctrKey)
    {
        if (enc) AesCtrHelper.DecryptOrEncrypt(buf, ctrKey, AesCtrHelper.BuildCounter(new byte[16], absOffset));
        dst.Write(buf, 0, buf.Length);
    }

    private static byte[] StreamHashRegion(IStorage content, long len, int bs)
    {
        byte[] region = new byte[RegionBlocks(len, bs) * 0x20];
        byte[] block = new byte[bs];
        long j = 0;
        for (long off = 0; off < len || off == 0; off += bs, j++)
        {
            Array.Clear(block, 0, block.Length);
            int n = (int)Math.Min(bs, len - off);
            if (n > 0) content.Read(off, block.AsSpan(0, n)).ThrowIfFailure();
            SHA256.HashData(block).CopyTo(region.AsSpan((int)(j * 0x20), 0x20));
            if (off + n >= len) break;
        }
        return region;
    }

    private static void CopyStream(IStorage src, Stream dst, long from, long to)
    {
        byte[] buf = new byte[0x100000];
        for (long p = from; p < to;)
        {
            int n = (int)Math.Min(buf.Length, to - p);
            src.Read(p, buf.AsSpan(0, n)).ThrowIfFailure();
            dst.Write(buf, 0, n);
            p += n;
        }
    }
}
