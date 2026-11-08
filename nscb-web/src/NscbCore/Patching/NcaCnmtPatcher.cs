using System.Security.Cryptography;
using LibHac.Common.Keys;
using LibHac.Fs;
using LibHac.FsSystem;
using LibHac.Tools.FsSystem;
using LibHac.Tools.FsSystem.NcaUtils;
using NscbCore.Crypto;
using NscbCore.Nsz;
using NcaFsHeader = LibHac.Tools.FsSystem.NcaUtils.NcaFsHeader;

namespace NscbCore.Patching;

/// <summary>
/// Modifies fields inside a Meta NCA's cnmt (title id / version / RSV) and rebuilds the
/// NCA integrity so the result passes a strict verifier — not just Tinfoil.
/// <para>
/// Supports the PFS0 + <c>NcaHashType.Sha256</c> (flat "PartitionFs" hash) sections that
/// every Meta NCA uses. The chain rebuilt is exactly what LibHac's
/// <c>HierarchicalIntegrityVerificationStorage</c> (IntegrityStorageType.PartitionFs)
/// verifies: per-content-block SHA-256 into the hash table → SHA-256 of the whole table =
/// FsHeader <c>MasterHash</c> → SHA-256 of the FsHeader block = header <c>hblock</c> slot at
/// 0x280, then the 0xC00 header is AES-XTS re-encrypted. (Scheme validated by itest
/// <c>hashcheck</c> before wiring mutation.)</para>
/// </summary>
public static class NcaCnmtPatcher
{
    /// <summary>
    /// Decrypts the Meta NCA, runs <paramref name="mutateCnmt"/> over the cnmt bytes,
    /// rebuilds the section hash chain + header hashes, and writes everything back in place.
    /// Returns false if the NCA is not a PFS0/Sha256 Meta section we can rebuild.
    /// </summary>
    public static bool PatchCnmt(Stream ncaStream, long ncaOffset, long ncaSize, KeySet keySet,
        Action<Span<byte>> mutateCnmt, int fsIdx = 0)
    {
        const int HeaderSize = XtsHelper.HeaderSize; // 0xC00
        if (ncaSize < HeaderSize) return false;

        byte[] ncaBytes = new byte[ncaSize];
        ncaStream.Position = ncaOffset;
        ncaStream.ReadExactly(ncaBytes);

        Nca nca;
        NcaFsHeader fsHeader;
        try
        {
            nca = new Nca(keySet, new MemoryStorage(ncaBytes));
            fsHeader = nca.GetFsHeader(fsIdx); // also validates the current FsHeader hash
        }
        catch { return false; }

        if (fsHeader.FormatType != NcaFormatType.Pfs0 || fsHeader.HashType != NcaHashType.Sha256)
            return false;

        var info = fsHeader.GetIntegrityInfoSha256();
        int blockSize = info.BlockSize;
        long contentOff = info.GetLevelOffset(1), contentSize = info.GetLevelSize(1);
        long tableOff = info.GetLevelOffset(0), tableSize = info.GetLevelSize(0);

        long sectionStart = nca.Header.GetSectionStartOffset(fsIdx);
        long sectionSize = nca.Header.GetSectionSize(fsIdx);
        if (sectionStart + sectionSize > ncaBytes.Length) return false;

        // Decrypted raw section (content + hash table).
        byte[] section = new byte[sectionSize];
        nca.OpenRawStorage(fsIdx, openEncrypted: false).Read(0, section).ThrowIfFailure();

        // Locate the cnmt file inside the PFS0.
        long cnmtOff = FindCnmtData(section, contentOff);
        if (cnmtOff < 0) return false;
        mutateCnmt(section.AsSpan((int)cnmtOff, (int)Math.Min(section.Length - cnmtOff, contentSize + contentOff - cnmtOff)));

        // 1. Rebuild the flat hash table over the (modified) content.
        int numBlocks = (int)(tableSize / 32);
        for (int k = 0; k < numBlocks; k++)
        {
            long bOff = contentOff + (long)k * blockSize;
            int cnt = (int)Math.Min(blockSize, contentSize - (long)k * blockSize);
            if (cnt < 0) cnt = 0;
            byte[] h = cnt > 0
                ? SHA256.HashData(section.AsSpan((int)bOff, cnt))
                : new byte[32];
            h.CopyTo(section.AsSpan((int)(tableOff + k * 32), 32));
        }
        // 2. Master hash = SHA-256 of the whole table region.
        byte[] master = SHA256.HashData(section.AsSpan((int)tableOff, (int)tableSize));

        // 3. Update the header: decrypt, write master into FsHeader, recompute hblock, re-encrypt.
        var headerKey = keySet.HeaderKey.DataRo;
        byte[] hdr = ncaBytes[..HeaderSize].ToArray();
        bool wasEncrypted = !(hdr[0x200] == (byte)'N' && hdr[0x201] == (byte)'C' && hdr[0x202] == (byte)'A');
        if (wasEncrypted) XtsHelper.TransformNcaHeader(hdr, headerKey, decrypt: true);

        int fsBlock = 0x400 + fsIdx * 0x200;
        master.CopyTo(hdr.AsSpan(fsBlock + 8, 32)); // IntegrityInfo offset 8, MasterHash at +0.
        byte[] hblock = SHA256.HashData(hdr.AsSpan(fsBlock, 0x200));
        hblock.CopyTo(hdr.AsSpan(0x280 + fsIdx * 0x20, 32)); // GetFsHeaderHash slot.
        if (wasEncrypted) XtsHelper.TransformNcaHeader(hdr, headerKey, decrypt: false);

        hdr.CopyTo(ncaBytes, 0);

        // 4. Re-encrypt the modified section (AES-CTR) only if its FS encryption is enabled, then store.
        if (fsHeader.EncryptionType != NcaEncryptionType.None)
        {
            byte[] ctrKey = nca.Header.HasRightsId
                ? (nca.GetDecryptedTitleKey() ?? nca.GetDecryptedKey(fsIdx)!)
                : (nca.GetDecryptedKey(2) ?? nca.GetDecryptedKey(fsIdx) ?? nca.GetDecryptedKey(0))!;
            byte[] iv = AesCtrHelper.BuildCounter(new byte[16], sectionStart);
            AesCtrHelper.DecryptOrEncrypt(section, ctrKey, iv); // plaintext -> ciphertext
        }
        section.CopyTo(ncaBytes, (int)sectionStart);

        ncaStream.Position = ncaOffset;
        ncaStream.Write(ncaBytes, 0, ncaBytes.Length);
        ncaStream.Flush();
        return true;
    }

    /// <summary>Set the cnmt TitleID (u64 LE at cnmt offset 0).</summary>
    public static bool SetCnmtTitleId(Stream s, long off, long size, KeySet ks, ulong titleId, int fsIdx = 0) =>
        PatchCnmt(s, off, size, ks, cnmt =>
        {
            if (cnmt.Length >= 8) System.Buffers.Binary.BinaryPrimitives.WriteUInt64LittleEndian(cnmt[..8], titleId);
        }, fsIdx);

    /// <summary>Set the cnmt TitleVersion (u32 LE at cnmt offset 8).</summary>
    public static bool SetCnmtTitleVersion(Stream s, long off, long size, KeySet ks, uint version, int fsIdx = 0) =>
        PatchCnmt(s, off, size, ks, cnmt =>
        {
            if (cnmt.Length >= 12) System.Buffers.Binary.BinaryPrimitives.WriteUInt32LittleEndian(cnmt.Slice(8, 4), version);
        }, fsIdx);

    /// <summary>Set the cnmt RequiredSystemVersion (u32 LE at cnmt offset 0x28) + rebuild chain.</summary>
    public static bool SetCnmtRequiredSystemVersion(Stream s, long off, long size, KeySet ks, uint rsv, int fsIdx = 0) =>
        PatchCnmt(s, off, size, ks, cnmt =>
        {
            if (cnmt.Length >= 0x2C) System.Buffers.Binary.BinaryPrimitives.WriteUInt32LittleEndian(cnmt.Slice(0x28, 4), rsv);
        }, fsIdx);

    /// <summary>
    /// Rewrite the NcaId + size of existing cnmt content entries whose current id is a key in
    /// <paramref name="renames"/> (value = new id hex + new content size). Content-entry COUNT is
    /// unchanged, so the cnmt/section size is preserved and the hash chain rebuild still applies.
    /// Used by upd_base to point the merged Meta at the update's real NCA ids (no id mismatch).
    /// Entry layout (NSCB ContentMetaRecord): hash(0x20) + ncaId(0x10) + size(u48) + type(0x1) + idOff(0x1).
    /// </summary>
    public static bool RewriteContentEntryIds(Stream s, long off, long size, KeySet ks,
        IReadOnlyDictionary<string, (string NewId, long NewSize)> renames, int fsIdx = 0)
    {
        if (renames is null || renames.Count == 0) return true;
        const int EntrySize = 0x38;
        return PatchCnmt(s, off, size, ks, cnmt =>
        {
            if (cnmt.Length < 0x20) return;
            int tableOff = 0x20 + System.Buffers.Binary.BinaryPrimitives.ReadUInt16LittleEndian(cnmt.Slice(0xE, 2));
            int count = System.Buffers.Binary.BinaryPrimitives.ReadUInt16LittleEndian(cnmt.Slice(0x10, 2));
            for (int k = 0; k < count; k++)
            {
                int b = tableOff + k * EntrySize;
                if (b + EntrySize > cnmt.Length) break;
                string id = NscbCore.Info.NcaIdFormatter.ToHex(cnmt.Slice(b + 0x20, 0x10));
                if (!renames.TryGetValue(id, out var r)) continue;
                byte[] nb = Convert.FromHexString(r.NewId);
                if (nb.Length == 0x10) nb.CopyTo(cnmt.Slice(b + 0x20, 0x10));
                var sizeSpan = cnmt.Slice(b + 0x30, 6);
                long v = r.NewSize;
                for (int i = 0; i < 6; i++) sizeSpan[i] = (byte)(v >> (8 * i));
            }
        }, fsIdx);
    }

    /// <summary>
    /// Rewrite the SHA256 stored in cnmt content records whose ncaId is a key in
    /// <paramref name="hashesByNcaId"/> (value = the NCA's NEW whole-file SHA256). Only the 0x20-byte
    /// hash field of each matched record changes — ncaId/size/type stay intact, so file names and record
    /// count are unchanged (no rename; size-preserving chain rebuild). Makes a strict
    /// "SHA256(file) == cnmt record hash" verifier (e.g. NSGManager) pass again after keygen lowering
    /// re-wrapped those NCA headers. (The fixed-key Signature1 still cannot be re-created — that stays FAIL, as in NSCB.)
    /// </summary>
    public static bool RewriteContentHashes(Stream s, long off, long size, KeySet ks,
        IReadOnlyDictionary<string, byte[]> hashesByNcaId, int fsIdx = 0)
    {
        if (hashesByNcaId is null || hashesByNcaId.Count == 0) return true;
        const int EntrySize = 0x38;
        return PatchCnmt(s, off, size, ks, cnmt =>
        {
            if (cnmt.Length < 0x20) return;
            int tableOff = 0x20 + System.Buffers.Binary.BinaryPrimitives.ReadUInt16LittleEndian(cnmt.Slice(0xE, 2));
            int count = System.Buffers.Binary.BinaryPrimitives.ReadUInt16LittleEndian(cnmt.Slice(0x10, 2));
            for (int k = 0; k < count; k++)
            {
                int b = tableOff + k * EntrySize;
                if (b + EntrySize > cnmt.Length) break;
                string id = NscbCore.Info.NcaIdFormatter.ToHex(cnmt.Slice(b + 0x20, 0x10));   // record ncaId (= file name)
                if (hashesByNcaId.TryGetValue(id, out var h) && h.Length == 0x20)
                    h.CopyTo(cnmt.Slice(b, 0x20));                                            // record.hash = new file SHA256
            }
        }, fsIdx);
    }

    /// <summary>
    /// Read-only: return each cnmt content record's (ncaId hex, 32-byte stored hash) from a Meta NCA.
    /// Used to verify "SHA256(the .nca file) == record hash" the way NSGManager does. Empty on non-rebuildable Meta.
    /// </summary>
    public static List<(string NcaId, byte[] Hash)> ReadContentHashes(Stream s, long off, long size, KeySet keySet, int fsIdx = 0)
    {
        var result = new List<(string, byte[])>();
        const int HeaderSize = XtsHelper.HeaderSize;
        if (size < HeaderSize) return result;
        byte[] ncaBytes = new byte[size];
        s.Position = off; s.ReadExactly(ncaBytes);
        Nca nca; NcaFsHeader fsHeader;
        try { nca = new Nca(keySet, new MemoryStorage(ncaBytes)); fsHeader = nca.GetFsHeader(fsIdx); }
        catch { return result; }
        if (fsHeader.FormatType != NcaFormatType.Pfs0 || fsHeader.HashType != NcaHashType.Sha256) return result;
        long contentOff = fsHeader.GetIntegrityInfoSha256().GetLevelOffset(1);
        long sectionStart = nca.Header.GetSectionStartOffset(fsIdx);
        long sectionSize = nca.Header.GetSectionSize(fsIdx);
        if (sectionStart + sectionSize > ncaBytes.Length) return result;
        byte[] section = new byte[sectionSize];
        nca.OpenRawStorage(fsIdx, openEncrypted: false).Read(0, section).ThrowIfFailure();
        long cnmtOff = FindCnmtData(section, contentOff);
        if (cnmtOff < 0) return result;
        Span<byte> cnmt = section.AsSpan((int)cnmtOff, (int)(section.Length - cnmtOff));
        if (cnmt.Length < 0x20) return result;
        int tableOff = 0x20 + System.Buffers.Binary.BinaryPrimitives.ReadUInt16LittleEndian(cnmt.Slice(0xE, 2));
        int count = System.Buffers.Binary.BinaryPrimitives.ReadUInt16LittleEndian(cnmt.Slice(0x10, 2));
        const int EntrySize = 0x38;
        for (int k = 0; k < count; k++)
        {
            int b = tableOff + k * EntrySize;
            if (b + EntrySize > cnmt.Length) break;
            byte[] hash = cnmt.Slice(b, 0x20).ToArray();
            string id = NscbCore.Info.NcaIdFormatter.ToHex(cnmt.Slice(b + 0x20, 0x10));
            result.Add((id, hash));
        }
        return result;
    }

    /// <summary>Find the cnmt file's data offset within the decrypted section's PFS0.</summary>
    private static long FindCnmtData(byte[] section, long contentOff)
    {
        // Scan for "PFS0" near the content start.
        long pfs0 = -1;
        for (long i = contentOff; i + 4 <= section.Length; i++)
        {
            if (section[i] == 'P' && section[i + 1] == 'F' && section[i + 2] == 'S' && section[i + 3] == '0')
            { pfs0 = i; break; }
        }
        if (pfs0 < 0) return -1;

        int fileCount = System.Buffers.Binary.BinaryPrimitives.ReadInt32LittleEndian(section.AsSpan((int)(pfs0 + 4), 4));
        int strSize = System.Buffers.Binary.BinaryPrimitives.ReadInt32LittleEndian(section.AsSpan((int)(pfs0 + 8), 4));
        if (fileCount < 1) return -1;
        long dataStart = pfs0 + 0x10 + fileCount * 0x18 + strSize;
        // First entry's relative data offset.
        long entry0Off = System.Buffers.Binary.BinaryPrimitives.ReadInt64LittleEndian(section.AsSpan((int)(pfs0 + 0x10), 8));
        long cnmtAbs = dataStart + entry0Off;
        return (cnmtAbs >= 0 && cnmtAbs < section.Length) ? cnmtAbs : -1;
    }
}
