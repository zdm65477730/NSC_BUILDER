using System.Buffers.Binary;
using System.Security.Cryptography;
using LibHac.Common.Keys;
using LibHac.Fs;
using LibHac.FsSystem;
using LibHac.Tools.FsSystem;
using LibHac.Tools.FsSystem.NcaUtils;
using NscbCore.Formats;
using NscbCore.Info;
using NscbCore.Keys;
using NscbCore.Nsz;
using NscbCore.Crypto;

namespace NscbCore.Patching;

/// <summary>NCA header distribution type (byte at header offset 0x204). Values match LibHac/hactool: 0 = Download, 1 = GameCard.</summary>
public enum NcaDistribution : byte
{
    Download = 0,
    GameCard = 1,
}

/// <summary>
/// In-place NCA patching utilities:
/// - cnmt RequiredSystemVersion downgrade (RSV patch)
/// - NCA key-generation byte changes
/// - XCI card header Game_info firmware version update
/// All operations work on a <see cref="Stream"/> opened in read/write mode;
/// Meta NCAs are small (< 100 KB) so an in-memory copy is safe.
/// </summary>
public static class NcaPatcher
{
    // ── cnmt RequiredSystemVersion patch ────────────────────────────────────────

    /// <summary>
    /// Patch the RequiredSystemVersion field in the cnmt file inside a Meta NCA.
    /// LibHac is used to locate the section; the PFS0 data is modified in-place.
    /// For NCA2 download NCAs with no integrity hash, no hash chain update is needed.
    /// For sections with integrity (IVFC/SHA-256), the caller should also call
    /// <see cref="RebuildHashChain"/> after patching.
    /// </summary>
    /// <returns>true if a cnmt file was found and patched.</returns>
    public static bool PatchCnmtRequiredSystemVersion(
        Stream ncaStream, long ncaOffset, long ncaSize, KeySet keySet, uint newRsv, int metaFsIdx = 0)
    {
        byte[] ncaBytes = ReadNcaBytes(ncaStream, ncaOffset, ncaSize);
        // Meta NCAs can be very small (a few KB); don't over-restrict here.
        if (ncaBytes.Length < 0xC00) return false;

        // Header is AES-XTS encrypted; use LibHac to peek at ContentType.
        NcaContentType contentType;
        try
        {
            var ms = new MemoryStorage(ncaBytes);
            var probeNca = new Nca(keySet, ms);
            contentType = probeNca.Header.ContentType;
        }
        catch { return false; }
        if (contentType != NcaContentType.Meta) return false;

        if (!TryPatchCnmtInPlace(ncaBytes, keySet, newRsv, metaFsIdx))
            return false;

        WriteNcaBytes(ncaStream, ncaOffset, ncaBytes);
        return true;
    }

    /// <summary>
    /// Patch a cnmt RequiredSystemVersion inside the in-memory NCA byte array.
    /// Reads the fully-decrypted raw FS section, patches the RSV in the PFS0's cnmt,
    /// then AES-CTR re-encrypts the whole section in-place. The NCA header's hblock/htable
    /// chain (in the XTS-encrypted region) is not rewritten here.
    /// </summary>
    private static bool TryPatchCnmtInPlace(byte[] ncaBytes, KeySet keySet, uint newRsv, int metaFsIdx)
    {
        using var memStorage = new MemoryStorage(ncaBytes);
        var nca = new Nca(keySet, memStorage);
        if (!nca.Header.IsSectionEnabled(metaFsIdx)) return false;

        long sectionStart = nca.Header.GetSectionStartOffset(metaFsIdx);
        long sectionSize  = nca.Header.GetSectionSize(metaFsIdx);
        if (sectionStart + sectionSize > ncaBytes.Length) return false;

        var fsHeader = nca.GetFsHeader(metaFsIdx);
        if (fsHeader.FormatType != NcaFormatType.Pfs0) return false;
        bool encrypted = fsHeader.EncryptionType != NcaEncryptionType.None;

        // Read the decrypted view of the whole raw section (hash tables + PFS0).
        var rawDec = nca.OpenRawStorage(metaFsIdx, openEncrypted: false);
        byte[] section = new byte[sectionSize];
        rawDec.Read(0, section).ThrowIfFailure();

        // Locate the PFS0 magic inside the section (may be preceded by hash tables).
        int pfs0Rel = -1;
        for (int i = 0; i + 4 <= section.Length; i += 0x10)
        {
            if (section[i] == (byte)'P' && section[i + 1] == (byte)'F' &&
                section[i + 2] == (byte)'S' && section[i + 3] == (byte)'0')
            { pfs0Rel = i; break; }
        }
        if (pfs0Rel < 0) return false;

        int fileCount = BinaryPrimitives.ReadInt32LittleEndian(section.AsSpan(pfs0Rel + 4));
        int strTableSize = BinaryPrimitives.ReadInt32LittleEndian(section.AsSpan(pfs0Rel + 8));
        if (fileCount < 1) return false;
        int pfs0HdrEnd = pfs0Rel + 0x10 + fileCount * 0x18 + strTableSize;
        if (pfs0HdrEnd + 0x2C > section.Length) return false;

        // First entry — the cnmt file.
        int ent0 = pfs0Rel + 0x10;
        long entryDataOff = BinaryPrimitives.ReadInt64LittleEndian(section.AsSpan(ent0));
        long cnmtAbs = pfs0HdrEnd + entryDataOff;
        if (cnmtAbs + 0x2C > section.Length) return false;

        // RequiredSystemVersion at cnmt + 0x28 (NSCB convention).
        BinaryPrimitives.WriteUInt32LittleEndian(section.AsSpan((int)cnmtAbs + 0x28), newRsv);

        if (encrypted)
        {
            // Re-encrypt with the same AES-CTR key LibHac uses internally for the FS section.
            // For rights-ID NCAs: title key. Otherwise: keys[2] of the key block (matches NSCB's
            // `unwrapAesWrappedTitlekey(...)[32:48]` convention).
            byte[] key;
            if (nca.Header.HasRightsId)
            {
                key = nca.GetDecryptedTitleKey() ?? nca.GetDecryptedKey(metaFsIdx)!;
            }
            else
            {
                // NSCB uses keys[2] ("KB1L" slot 2) as the AES-CTR key for non-rights NCAs.
                key = nca.GetDecryptedKey(2)
                      ?? nca.GetDecryptedKey(metaFsIdx)
                      ?? nca.GetDecryptedKey(0)!;
            }
            byte[] iv = AesCtrHelper.BuildCounter(new byte[16], sectionStart);

            // Self-check: decrypting a fresh copy must yield the same plaintext we started from.
            byte[] verify = new byte[section.Length];
            ncaBytes.AsSpan((int)sectionStart, (int)sectionSize).CopyTo(verify);
            // Wait: verify is now encrypted bytes; decrypting it should give us back `section` (pre-modify)
            // which we no longer have. Just verify the ORIGINAL bytes round-trip through
            // our encrypt/decrypt pair. We do this by decrypting `verify` and checking
            // that the FIRST bytes match the pre-modified section (before we patched the RSV).
            AesCtrHelper.DecryptOrEncrypt(verify, key, iv);
            // verify now contains what the ORIGINAL ciphertext decrypts to via our formula.
            // It must start with the same bytes as `section` up to the RSV position.
            int prefixLen = System.Math.Min((int)cnmtAbs + 0x28, verify.Length);
            for (int i = 0; i < prefixLen; i++)
            {
                if (verify[i] != section[i])
                    throw new InvalidOperationException($"Crypto round-trip mismatch at section+0x{i:X}: got {verify[i]:X2}, expected {section[i]:X2}");
            }
            // Same formula confirmed. Now re-encrypt `section` (which HAS the new RSV) to ciphertext.
            // Note: `section` was decrypted content from OpenRawStorage; our encrypt produces ciphertext.
            AesCtrHelper.DecryptOrEncrypt(section, key, iv);
        }

        section.CopyTo(ncaBytes, (int)sectionStart);
        return true;
    }

    // ── Keygen bytes patch ───────────────────────────────────────────────────────

    /// <summary>Header keygen fields for a target keygen: NSCB stores keygen in cryptoType(0x206)
    /// for ≤ 2 else splits (2 in 0x206, keygen in cryptoType2 0x220).</summary>
    private static (byte Old, byte New) CryptoFields(int keyGen) => keyGen <= 2 ? ((byte)keyGen, (byte)0) : ((byte)2, (byte)keyGen);

    /// <summary>
    /// Lower the NCA's key generation to <paramref name="newKeyGen"/> (NSCB "lower master key / keygen").
    /// Re-wraps the key area block (0x300, 0x40) from the old key_area_key to the target generation's and
    /// updates the crypto-type header fields (0x206/0x220). Handles both plaintext and AES-XTS-encrypted
    /// headers (mirrors <see cref="RemoveTitleKey"/>). <b>Standard crypto only:</b> rights-ID (title-key) NCAs
    /// are left untouched (re-keying them would require changing ticket crypto). No-op if already ≤ target.
    /// The header's RSA signature becomes stale (inherent to editing the header) — installers ignore it.
    /// </summary>
    public static bool PatchKeyGeneration(
        Stream ncaStream, long ncaOffset, long ncaSize,
        KeySet keySet, int newKeyGen)
    {
        const int HS = XtsHelper.HeaderSize; // 0xC00
        if (ncaSize < HS || newKeyGen < 1) return false;

        byte[] hdr = ReadNcaBytes(ncaStream, ncaOffset, HS);
        // Work directly on the raw header bytes (auto-detecting XTS below) instead of building an
        // Nca — an NCZ's embedded NCA header may already be decrypted, so `new Nca` would throw.
        var headerKey = keySet.HeaderKey.DataRo;
        bool wasEncrypted = !(hdr[0x200] == (byte)'N' && hdr[0x201] == (byte)'C' && hdr[0x202] == (byte)'A');
        if (wasEncrypted) XtsHelper.TransformNcaHeader(hdr, headerKey, decrypt: true);

        int keyGen = Math.Max(hdr[0x206], hdr[0x220]);            // effective current keygen
        if (newKeyGen >= keyGen) { if (wasEncrypted) XtsHelper.TransformNcaHeader(hdr, headerKey, decrypt: false); return false; } // already at/below target → nothing lowered
        int oldRev = Math.Max(0, keyGen - 1), newRev = Math.Max(0, newKeyGen - 1);
        int kaekIndex = hdr[0x207];
        if (kaekIndex < 0 || kaekIndex > 2) return false;
        // Only NCAs with a real (non-empty) key area can be safely re-keyed: NSCB's change_mkrev only
        // re-wraps the key block, and rights-ID NCAs whose title key lives in the ticket (empty key area,
        // e.g. an AesCtrEx program) cannot be lowered without corrupting content key derivation → leave intact.
        byte[] area = new byte[0x40];
        hdr.AsSpan(0x300, 0x40).CopyTo(area);
        bool keyAreaUsed = false;
        foreach (var b in area) if (b != 0) { keyAreaUsed = true; break; }
        if (!keyAreaUsed
            || oldRev >= keySet.KeyAreaKeys.Length || newRev >= keySet.KeyAreaKeys.Length)
        {
            if (wasEncrypted) XtsHelper.TransformNcaHeader(hdr, headerKey, decrypt: false);
            return false;   // no key area to re-wrap → don't touch this NCA
        }
        byte[] oldKak = keySet.KeyAreaKeys[oldRev][kaekIndex].DataRo[..0x10].ToArray();
        byte[] newKak = keySet.KeyAreaKeys[newRev][kaekIndex].DataRo[..0x10].ToArray();
        area = AesEcbEncrypt(newKak, AesEcbDecrypt(oldKak, area));
        area.CopyTo(hdr, 0x300);

        var (o, n) = CryptoFields(newKeyGen);
        hdr[0x206] = o; hdr[0x220] = n;

        if (wasEncrypted) XtsHelper.TransformNcaHeader(hdr, headerKey, decrypt: false);
        WriteNcaBytes(ncaStream, ncaOffset, hdr);
        return true;
    }

    private static byte[] AesEcbDecrypt(byte[] key, byte[] data)
    {
        using var aes = System.Security.Cryptography.Aes.Create();
        aes.Key = key;
        aes.Mode = CipherMode.ECB;
        return aes.DecryptEcb(data, System.Security.Cryptography.PaddingMode.None);
    }

    // ── XCI card header Game_info firmware version ───────────────────────────────

    /// <summary>
    /// RTRNCA / removeTitleRights: convert a RightsID (title-key) NCA into a null-crypto NCA
    /// so it installs without a ticket. Port of NSCB's <c>removeTitleRightsnca</c>:
    /// rewrite the key block (0x300) as <c>AES-ECB(keyAreaKey[mkey][kaekIndex], titleKey*4)</c>
    /// and clear RightsID (0x230). The section content is NOT re-encrypted (it already is
    /// AES-CTR under the title key, which every key-area slot now reproduces), so no hash
    /// chain changes. Only the 0xC00 header region is edited and re-encrypted (AES-XTS when
    /// the header is encrypted). Requires the title key to be present in <paramref name="keySet"/>.
    /// </summary>
    public static bool RemoveTitleKey(Stream ncaStream, long ncaOffset, long ncaSize, KeySet keySet)
    {
        const int HeaderSize = XtsHelper.HeaderSize; // 0xC00
        if (ncaSize < HeaderSize) return false;

        // Only the header region matters: read/patch/re-encrypt just the 0xC00 header so this
        // works even for multi-GB program NCAs without loading the whole NCA into memory.
        byte[] hdr = ReadNcaBytes(ncaStream, ncaOffset, HeaderSize);

        Nca nca;
        try { nca = new Nca(keySet, new MemoryStorage(hdr)); }
        catch { return false; }
        if (!nca.Header.HasRightsId) return true; // already null-crypto

        byte[]? titleKey = nca.GetDecryptedTitleKey();
        if (titleKey is null || titleKey.Length != 0x10) return false; // title key not loaded

        // Decrypt the header to read keyGen / kaekIndex and to edit RightsID + key block.
        var headerKey = keySet.HeaderKey.DataRo;
        bool wasEncrypted = !(hdr[0x200] == (byte)'N' && hdr[0x201] == (byte)'C' && hdr[0x202] == (byte)'A');
        if (wasEncrypted) XtsHelper.TransformNcaHeader(hdr, headerKey, decrypt: true);

        int keyGen = Math.Max(hdr[0x206], hdr[0x220]);  // Header.KeyGeneration = max(cryptoType1, cryptoType2)
        int masterRev = keyGen == 0 ? 0 : keyGen - 1;   // LibHac Utilities.GetMasterKeyRevision
        if (masterRev < 0 || masterRev >= keySet.KeyAreaKeys.Length) return false;
        int kaekIndex = hdr[0x207];                     // Header.KeyAreaKeyIndex (app=0/ocean=1/system=2)
        if (kaekIndex < 0 || kaekIndex > 2) return false;
        byte[] areaKey = keySet.KeyAreaKeys[masterRev][kaekIndex].DataRo[..0x10].ToArray();

        // encKeyBlock = AES-ECB(areaKey, titleKey repeated 4×) (mirrors NSCB titleKeyDec * 4).
        byte[] plainBlock = new byte[0x40];
        for (int i = 0; i < 4; i++) titleKey.CopyTo(plainBlock, i * 0x10);
        byte[] encKeyBlock = AesEcbEncrypt(areaKey, plainBlock);

        Array.Clear(hdr, 0x230, 0x10);              // RightsID -> 0 (null crypto)
        encKeyBlock.CopyTo(hdr, 0x300);             // new key block

        if (wasEncrypted) XtsHelper.TransformNcaHeader(hdr, headerKey, decrypt: false);

        WriteNcaBytes(ncaStream, ncaOffset, hdr);
        return true;
    }

    private static byte[] AesEcbEncrypt(byte[] key, byte[] data)
    {
        using var aes = System.Security.Cryptography.Aes.Create();
        aes.Key = key;
        aes.Mode = CipherMode.ECB;
        aes.Padding = PaddingMode.None;
        return aes.EncryptEcb(data, PaddingMode.None);
    }

    /// <summary>
    /// Update the Game_info firmware version field in an XCI card header (the u64 at the
    /// start of the encrypted Game_info area at offset 0x190).
    /// </summary>
    public static bool PatchXciGameInfoFwVersion(
        Stream xciStream, ReadOnlySpan<byte> xciHeaderKey, ulong newFwVersion)
    {
        if (xciHeaderKey.Length < 0x10) return false;

        // Read card header (0x200 bytes).
        byte[] header = new byte[0x200];
        xciStream.Position = 0;
        if (xciStream.Read(header) != 0x200) return false;

        // Extract IV and decrypt Game_info.
        byte[] iv = header[XciLayout.HdrIv..(XciLayout.HdrIv + 0x10)];
        Array.Reverse(iv);
        byte[] enc = header[XciLayout.HdrEncryptedData..(XciLayout.HdrEncryptedData + XciLayout.HdrEncryptedDataSize)];

        byte[] plain = new byte[enc.Length];
        var cbc = new LibHac.Crypto.AesCbcDecryptor(xciHeaderKey[..0x10], iv);
        cbc.Transform(enc, plain);

        // Update firmware version (first u64 of Game_info).
        BinaryPrimitives.WriteUInt64LittleEndian(plain.AsSpan(0, 8), newFwVersion);

        // Re-encrypt.
        byte[] reEnc = new byte[plain.Length];
        var enc2 = new LibHac.Crypto.AesCbcEncryptor(xciHeaderKey[..0x10], iv);
        enc2.Transform(plain, reEnc);
        reEnc.CopyTo(header.AsSpan(XciLayout.HdrEncryptedData));

        // Write back.
        xciStream.Position = 0;
        xciStream.Write(header, 0, header.Length);
        return true;
    }

    // ── setcgame / seteshop (header distribution type) ───────────────────────────

    /// <summary>
    /// Flip the NCA header distribution-type byte (0x204) in place: GameCard(0) ⇄ Download(1).
    /// The 0xC00 header is decrypted with LibHac's exact per-sector scheme, the byte is
    /// rewritten, then the header is re-encrypted. The FsHeader SHA-256 chain lives at 0x400+
    /// and is left untouched, so installers still validate the NCA; only the RSA header
    /// signature (over 0x200..0x3FF) becomes stale — it is never checked locally and cannot
    /// be regenerated without Nintendo's private key. Returns false if the header key is wrong
    /// or the region is too small.
    /// </summary>
    public static bool SetDistribution(Stream ncaStream, long ncaOffset, long ncaSize,
        KeySet keySet, NcaDistribution dist)
    {
        const int hs = XtsHelper.HeaderSize; // 0xC00
        if (ncaSize < hs) return false;

        byte[] hdr = new byte[hs];
        ncaStream.Position = ncaOffset;
        ncaStream.ReadExactly(hdr);

        bool alreadyDecrypted = hdr[0x200] == (byte)'N' && hdr[0x201] == (byte)'C' && hdr[0x202] == (byte)'A';
        if (alreadyDecrypted)
        {
            hdr[0x204] = (byte)dist;
        }
        else
        {
            var hk = keySet.HeaderKey.DataRo;
            XtsHelper.TransformNcaHeader(hdr, hk, decrypt: true);
            if (!(hdr[0x200] == (byte)'N' && hdr[0x201] == (byte)'C' && hdr[0x202] == (byte)'A'))
                return false; // header key incorrect → decryption produced garbage
            hdr[0x204] = (byte)dist;
            XtsHelper.TransformNcaHeader(hdr, hk, decrypt: false);
        }

        ncaStream.Position = ncaOffset;
        ncaStream.Write(hdr, 0, hs);
        ncaStream.Flush();
        return true;
    }

    // ── Hash chain ───────────────────────────────────────────────────────────────

    /// <summary>
    /// Rebuild the NCA hash chain for a modified section (pfs0_hash → htable_hash → hblock_hash).
    /// Mirrors NSCB's post-patch hash update logic.
    /// </summary>
    private static void RebuildHashChainInMemory(byte[] ncaBytes, Nca nca, int fsIdx,
        byte[] sectionData, long sectionStart, long sectionSize)
    {
        // 1. SHA-256 of the new section data → pfs0_hash
        byte[] pfs0Hash = SHA256.HashData(sectionData);

        // 2. pfs0_hash is stored at NCA offset 0xC00 + htable_offset (within the extended header).
        //    htable_offset comes from FsHeader at offset 0x30 within FsHeader[fsIdx].
        long fsHdrBase = 0x400 + 0x200L * fsIdx;
        long htableOffset = BinaryPrimitives.ReadInt64LittleEndian(ncaBytes.AsSpan((int)(fsHdrBase + 0x30), 8));
        long pfs0HashPos = 0xC00 + htableOffset;
        if (pfs0HashPos + 0x20 <= ncaBytes.Length)
            pfs0Hash.CopyTo(ncaBytes, (int)pfs0HashPos);

        // 3. SHA-256 of pfs0Hash (0x20 bytes) → htable_hash → write to FsHeader at +0x8.
        byte[] htableHash = SHA256.HashData(pfs0Hash);
        if (fsHdrBase + 0x8 + 0x20 <= ncaBytes.Length)
            htableHash.CopyTo(ncaBytes, (int)(fsHdrBase + 0x8));

        // 4. SHA-256 of FsHeader block (0x200 bytes at 0x400 + 0x200*fsIdx) → hblock_hash → write to 0x280 + 0x20*fsIdx.
        byte[] fsHdrBlock = ncaBytes[(int)fsHdrBase..((int)(fsHdrBase + 0x200))];
        byte[] hblockHash = SHA256.HashData(fsHdrBlock);
        long hblockPos = 0x280 + 0x20L * fsIdx;
        if (hblockPos + 0x20 <= ncaBytes.Length)
            hblockHash.CopyTo(ncaBytes, (int)hblockPos);
    }

    // ── AES-CTR helpers ──────────────────────────────────────────────────────────

    private static byte[] BuildSectionCounter(ulong headerCounter, long sectionFileOffset)
    {
        byte[] ctr = new byte[0x10];
        BinaryPrimitives.WriteUInt64BigEndian(ctr.AsSpan(0, 8), headerCounter);
        BinaryPrimitives.WriteUInt64BigEndian(ctr.AsSpan(8, 8), (ulong)(sectionFileOffset / 16));
        return ctr;
    }

    private static void DecryptKeyArea(byte[] keyArea, byte[] kaek)
    {
        // NCA key area: each 0x10-byte block is AES-ECB encrypted with key_area_key.
        using var aes = System.Security.Cryptography.Aes.Create();
        aes.Key = kaek;
        aes.Mode = System.Security.Cryptography.CipherMode.ECB;
        aes.Padding = System.Security.Cryptography.PaddingMode.None;
        using var dec = aes.CreateDecryptor();
        for (int off = 0; off + 0x10 <= keyArea.Length; off += 0x10)
        {
            byte[] block = keyArea[off..(off + 0x10)];
            byte[] plain = dec.TransformFinalBlock(block, 0, 0x10);
            plain.CopyTo(keyArea, off);
        }
    }

    private static void EncryptKeyArea(byte[] keyArea, byte[] kaek)
    {
        using var aes = System.Security.Cryptography.Aes.Create();
        aes.Key = kaek;
        aes.Mode = System.Security.Cryptography.CipherMode.ECB;
        aes.Padding = System.Security.Cryptography.PaddingMode.None;
        using var enc = aes.CreateEncryptor();
        for (int off = 0; off + 0x10 <= keyArea.Length; off += 0x10)
        {
            byte[] block = keyArea[off..(off + 0x10)];
            byte[] cipher = enc.TransformFinalBlock(block, 0, 0x10);
            cipher.CopyTo(keyArea, off);
        }
    }

    // ── I/O helpers ──────────────────────────────────────────────────────────────

    private static byte[] ReadNcaBytes(Stream stream, long offset, long size)
    {
        byte[] buf = new byte[size];
        stream.Position = offset;
        stream.ReadExactly(buf);
        return buf;
    }

    private static void WriteNcaBytes(Stream stream, long offset, byte[] data)
    {
        stream.Position = offset;
        stream.Write(data, 0, data.Length);
        stream.Flush();
    }
}
