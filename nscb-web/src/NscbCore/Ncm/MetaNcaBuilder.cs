using System.Buffers.Binary;
using System.Security.Cryptography;
using LibHac.Common.Keys;
using LibHac.Fs;
using LibHac.FsSystem;
using LibHac.Tools.FsSystem;
using LibHac.Tools.FsSystem.NcaUtils;
using NscbCore.Crypto;
using NscbCore.Formats;
using NscbCore.Nsz;

namespace NscbCore.Ncm;

/// <summary>
/// Rebuilds a Meta NCA whose embedded cnmt has a <b>different byte size</b> (e.g. the
/// content-entry count changed). This resizes section 0 (PFS0 + flat SHA-256 hash table),
/// regenerates the hash chain (per-block digests → master → FsHeader hblock), updates the
/// section-info end block, and re-encrypts both the 0xC00 header (AES-XTS) and the section
/// (AES-CTR). Section 0 layout constants come from LibHac's NcaHeader/NcaFsHeader writers.
/// </summary>
/// <remarks>
/// Only single-PFS0-section Meta NCAs are supported (the normal shape for a cnmt Meta NCA).
/// The section is placed contiguously at <c>startBlock*0x200</c> (=0xC00) and the NCA ends
/// right after it, matching how Meta NCAs are laid out.
/// </remarks>
public static class MetaNcaBuilder
{
    private const int SectionInfoOffset = 0x240;
    private const int FsHeaderHashOffset = 0x280;
    private const int FsHeadersOffset = 0x400;
    private const int BlockSize = 0x200;

    // Offsets inside a section's SHA-256 (flat hash table) integrity info.
    private const int IntegrityInfoRel = 8;                 // integrity info base within FsHeader
    private const int MasterHashRel = 0x00;                 // +integrity base
    private const int BlockSizeRel = 0x20;
    private const int Level0OffRel = 0x28;                  // level[0] = hash table { off i64, size i64 }
    private const int Level1OffRel = 0x38;                  // level[1] = content (PFS0)

    /// <summary>
    /// Produce a new Meta NCA whose section-0 PFS0 has the file <paramref name="cnmtFileName"/>
    /// replaced by <paramref name="newCnmt"/>; all other PFS0 files are carried over unchanged.
    /// </summary>
    public static byte[] RebuildWithCnmt(byte[] ncaBytes, KeySet keySet, string cnmtFileName, byte[] newCnmt)
    {
        if (ncaBytes.Length < 0xC00) throw new InvalidDataException("NCA too small.");

        var nca = new Nca(keySet, new MemoryStorage((byte[])ncaBytes.Clone()));
        var fsHeader = nca.GetFsHeader(0);
        if (fsHeader.FormatType != NcaFormatType.Pfs0 || fsHeader.HashType != NcaHashType.Sha256)
            throw new NotSupportedException("MetaNcaBuilder supports only PFS0/Sha256 section 0 (Meta NCA).");

        long secStart = nca.Header.GetSectionStartOffset(0);
        long secSize = nca.Header.GetSectionSize(0);
        byte[] oldSection = new byte[secSize];
        nca.OpenRawStorage(0, openEncrypted: false).Read(0, oldSection).ThrowIfFailure();

        // Decrypt the header to read/patch FsHeader + section-info.
        var headerKey = keySet.HeaderKey.DataRo;
        byte[] hdr = ncaBytes[..0xC00].ToArray();
        bool wasEncrypted = !(hdr[0x200] == (byte)'N' && hdr[0x201] == (byte)'C' && hdr[0x202] == (byte)'A');
        if (wasEncrypted) XtsHelper.TransformNcaHeader(hdr, headerKey, decrypt: true);

        int fsBase = FsHeadersOffset; // section 0
        int integ = fsBase + IntegrityInfoRel;
        int blockSize = BinaryPrimitives.ReadInt32LittleEndian(hdr.AsSpan(integ + BlockSizeRel, 4));

        // Extract the existing PFS0 (level[1] content region) and its files.
        long contentOff = BinaryPrimitives.ReadInt64LittleEndian(hdr.AsSpan(integ + Level1OffRel, 8));
        long contentSize = BinaryPrimitives.ReadInt64LittleEndian(hdr.AsSpan(integ + Level1OffRel + 8, 8));
        var pfs0 = oldSection.AsSpan((int)contentOff, (int)contentSize).ToArray();
        var files = ReadPfs0Files(pfs0);
        bool replaced = false;
        for (int i = 0; i < files.Count; i++)
            if (files[i].Name.Equals(cnmtFileName, StringComparison.OrdinalIgnoreCase))
            { files[i] = (cnmtFileName, newCnmt); replaced = true; }
        if (!replaced) { files.Add((cnmtFileName, newCnmt)); } // add if the meta had none

        // New content PFS0 (header + files).
        byte[] newPfs0 = BuildPfs0(files);
        int newContentLen = newPfs0.Length;

        // Regenerate the flat hash table over the new content (PartitionFs: last block = real bytes only).
        int numBlocks = (newContentLen + blockSize - 1) / blockSize;
        int newTableSize = numBlocks * 0x20;
        long newContentOff = AlignUp(newTableSize, 0x10);          // table first, content after
        long newSectionLen = newContentOff + newContentLen;
        byte[] newSection = new byte[AlignUp((int)newSectionLen, BlockSize)];
        for (int k = 0; k < numBlocks; k++)
        {
            long bo = (long)k * blockSize;
            int cnt = (int)Math.Min(blockSize, newContentLen - bo);
            byte[] h = cnt > 0 ? SHA256.HashData(newPfs0.AsSpan((int)bo, cnt)) : new byte[0x20];
            h.CopyTo(newSection.AsSpan(k * 0x20, 0x20));
        }
        newPfs0.AsSpan().CopyTo(newSection.AsSpan((int)newContentOff));

        byte[] master = SHA256.HashData(newSection.AsSpan(0, newTableSize));
        master.CopyTo(hdr.AsSpan(integ + MasterHashRel, 0x20));
        BinaryPrimitives.WriteInt64LittleEndian(hdr.AsSpan(integ + Level0OffRel, 8), 0);                 // table offset
        BinaryPrimitives.WriteInt64LittleEndian(hdr.AsSpan(integ + Level0OffRel + 8, 8), newTableSize);  // table size
        BinaryPrimitives.WriteInt64LittleEndian(hdr.AsSpan(integ + Level1OffRel, 8), newContentOff);     // content offset
        BinaryPrimitives.WriteInt64LittleEndian(hdr.AsSpan(integ + Level1OffRel + 8, 8), newContentLen); // content size

        // Section-info end block for section 0 (start unchanged); NCA is 0xC00 + newSection.
        int startBlock = (int)secStart / BlockSize;
        int endBlock = startBlock + newSection.Length / BlockSize;
        BinaryPrimitives.WriteInt32LittleEndian(hdr.AsSpan(SectionInfoOffset + 0 * 16 + 0, 4), startBlock);
        BinaryPrimitives.WriteInt32LittleEndian(hdr.AsSpan(SectionInfoOffset + 0 * 16 + 4, 4), endBlock);

        // Recompute hblock[0] = SHA256(FsHeader block).
        byte[] hblock = SHA256.HashData(hdr.AsSpan(fsBase, 0x200));
        hblock.CopyTo(hdr.AsSpan(FsHeaderHashOffset, 0x20));

        BinaryPrimitives.WriteInt64LittleEndian(hdr.AsSpan(0x208, 8), 0xC00 + newSection.Length); // entire-archive-size (strict readers)
        if (wasEncrypted) XtsHelper.TransformNcaHeader(hdr, headerKey, decrypt: false);

        // Encrypt the new section with the same section AES-CTR key + counter the reader uses.
        if (fsHeader.EncryptionType != NcaEncryptionType.None)
        {
            byte[] ctrKey = nca.Header.HasRightsId
                ? (nca.GetDecryptedTitleKey() ?? nca.GetDecryptedKey(0)!)
                : (nca.GetDecryptedKey(2) ?? nca.GetDecryptedKey(0))!;
            byte[] iv = AesCtrHelper.BuildCounter(new byte[16], secStart);
            AesCtrHelper.DecryptOrEncrypt(newSection, ctrKey, iv);
        }

        byte[] result = new byte[0xC00 + newSection.Length];
        hdr.CopyTo(result, 0);
        newSection.CopyTo(result, 0xC00);
        return result;
    }

    private static List<(string Name, byte[] Data)> ReadPfs0Files(byte[] pfs0)
    {
        var list = new List<(string, byte[])>();
        using var ms = new MemoryStream(pfs0);
        foreach (var e in Pfs0.ReadEntries(ms))
        {
            byte[] data = new byte[e.Size];
            Array.Copy(pfs0, (int)e.DataOffset, data, 0, (int)e.Size);
            list.Add((e.Name, data));
        }
        return list;
    }

    private static byte[] BuildPfs0(List<(string Name, byte[] Data)> files)
    {
        byte[] header = Pfs0Builder.BuildHeader(files.ConvertAll(f => (f.Name, (long)f.Data.Length)));
        byte[] outBuf = new byte[header.Length + files.Sum(f => f.Data.Length)];
        header.CopyTo(outBuf, 0);
        int pos = header.Length;
        foreach (var (_, data) in files) { data.CopyTo(outBuf, pos); pos += data.Length; }
        return outBuf;
    }

    private static int AlignUp(int v, int a) => (v + a - 1) / a * a;
}
