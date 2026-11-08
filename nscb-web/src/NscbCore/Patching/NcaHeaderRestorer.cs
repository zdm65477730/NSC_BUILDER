using System.Buffers.Binary;
using System.Security.Cryptography;
using LibHac.Common.Keys;
using NscbCore.Crypto;
using NscbCore.Keys;

namespace NscbCore.Patching;

/// <summary>
/// NSCB "restore modified file" (MODE 9) — reconstructs a NCA's ORIGINAL secure-block1 by brute-forcing
/// the known modification dimensions (distribution GameCard↔Download, and in future rights-id/keygen) and
/// accepting the candidate whose SHA-256 <b>validates against the intact RSA-PSS signature1</b>. Because a
/// successful restore is proven by the signature, no external backup of the original is needed.
/// This class implements the <b>distribution</b> restore (<c>restorehead_ntr</c>): the header's GameCard flag
/// (secure-block1 byte 0x204) is set back to whichever value the original signature covers.
/// </summary>
public static class NcaHeaderRestorer
{
    // RSA-PSS fixed header key public moduli (Nintendo production, per NSCB/hacbuild). Selected by sigKeyGen.
    private const string Modulus00 =
        "BFBE406CF4A780E9F07D0C99611D772F96BC4B9E58381B03ABB175499F2B4D5834B005A37522BE1A3F0373AC7068D116B904465EB707912F078B26DEF60007B2B451F80D0A5E58ADEBBC9AD649B964EFA782B5CF6D7013B00F85F6A908AA4D676687FA89FF7590181E6B3DE98A68C92604D980CE3F5E92CE01FF063BF2C1A90CCE026F16BC92420A4164CD52B6344DAEC02EDEA4DF27683CC1A060AD43F3FC86C13E6C46F77C299FFAFDF0E3CE64E735F2F656566F6DF1E242B08340A5C3202BCC9AAECAED4D7030A8701C70FD1363290279EAD2A7AF3528321C7BE62F1AAA407E328C2742FE8278EC0DEBE6834B6D8104401A9E9A67F67229FA04F09DE4F403";
    private const string Modulus01 =
        "ADE3E1FA0435E5B6DD49EA8929B1FFB643DFCA96A04A13DF43D9949796436548705833A27D357B96745E0B5C32181424C258B36C227AA1B7CB90A7A3F97D4516A5C8ED8FAD395E9E4B51687DF80C35C63F91AE44A592300D46F840FFD0FF06D21C7F9618DCB71D663ED173BC158A2F94F300C183F1CDD78188ABDF8CEF97DD1B175F58F69AE9E8C22F3815F52107F837905D2E024024150D25B7265D09CC4CF4F21B94705A9EEEED7777D45199F5DC761EE36C8CD112D457D1B683E4E4FEDAE9B43B33E5378ADFB57F89F19B9EB015B23AFEEA61845B7D4B23120B8312F2226BB922964B260B635E965752A3676422CAD0563E74B5981F0DF8B334E698685AAD";

    private const int Sb1Offset = 0x200;   // SecureBlock1 start (0x200..0x3FF), signed by Signature1
    private const int Sb1Length = 0x200;
    private const int Sig1Offset = 0x0;    // Signature1 (0x000..0x0FF)
    private const int Sig1Length = 0x100;

    /// <summary>Result of a header restore attempt: whether the header now verifies against its own signature.</summary>
    public readonly record struct RestoreResult(bool Changed, bool SignatureValid);

    /// <summary>Verify signature1 over a candidate SecureBlock1 with the fixed production RSA key.</summary>
    public static bool VerifySignature1(ReadOnlySpan<byte> header, ReadOnlySpan<byte> secureBlock1Candidate, int sigKeyGen)
    {
        if (header.Length < Sig1Offset + Sig1Length) return false;
        string modHex = sigKeyGen == 0 ? Modulus00 : Modulus01;
        using var rsa = RSA.Create();
        rsa.ImportParameters(new RSAParameters
        {
            Modulus = Convert.FromHexString(modHex),
            Exponent = [0x01, 0x00, 0x01],
        });
        byte[] sig = header.Slice(Sig1Offset, Sig1Length).ToArray();
        try { return rsa.VerifyData(secureBlock1Candidate, sig, HashAlgorithmName.SHA256, RSASignaturePadding.Pss); }
        catch { return false; }
    }

    /// <summary>
    /// Restore a decrypted 0xC00 NCA header in place by searching the modification space
    /// (distribution byte, key generation, rights-id, key-area) and accepting ONLY the candidate whose
    /// SHA-256 over secure-block1 validates against the intact RSA-PSS signature1 — so a success IS the
    /// original header (self-proving, no external backup); a miss is a safe no-op. Covers NSCB's
    /// restorehead_ntr (distribution) + restorehead_tr (rights-id / keygen).
    /// </summary>
    public static RestoreResult RestoreHeader(byte[] decryptedHeader, KeySet keys)
    {
        if (decryptedHeader.Length < Sb1Offset + Sb1Length) return new(false, false);
        byte[] cur = decryptedHeader.AsSpan(Sb1Offset, Sb1Length).ToArray();
        int sigKeyGen = decryptedHeader[0x221];
        if (VerifySignature1(decryptedHeader, cur, sigKeyGen))
            return new(false, true); // already the original

        byte keyIndex = decryptedHeader[0x207];
        byte curDist = cur[0x04];
        ulong titleId = BinaryPrimitives.ReadUInt64LittleEndian(decryptedHeader.AsSpan(0x210, 8));
        byte[] curKeyArea = decryptedHeader.AsSpan(0x300, 0x40).ToArray();
        byte[] curRightsId = decryptedHeader.AsSpan(0x230, 0x10).ToArray();

        foreach (byte dist in new byte[] { curDist, 0, 1 })
            for (int rev = 0; rev <= FirmwareTables.MaxKnownKeyGeneration; rev++)
            {
                int idx = rev > 0 ? rev - 1 : 0;                       // getMasterKeyIndex
                var (c1, c2) = CryptoFields(rev);
                byte[] tr = RightsIdFromTitleId(titleId, c2);
                byte[]? keyAreaEnc = DerivedKeyArea(curKeyArea, keys, idx, keyIndex);

                foreach (byte[] rightsId in new[] { curRightsId, tr })  // current (standard) or reconstructed (rights-id)
                foreach (byte[] keyArea in KeyAreaCandidates(curKeyArea, keyAreaEnc))
                {
                    byte[] cand = (byte[])cur.Clone();
                    cand[0x04] = dist;
                    cand[0x06] = c1; cand[0x20] = c2;                  // 0x206 / 0x220 within block
                    rightsId.CopyTo(cand, 0x30);                        // 0x230 rights-id
                    keyArea.CopyTo(cand, 0x100);                        // 0x300 key-area
                    if (VerifySignature1(decryptedHeader, cand, sigKeyGen))
                    {
                        cand.CopyTo(decryptedHeader, Sb1Offset);
                        return new(true, true);
                    }
                }
            }
        return new(false, false);
    }

    private static (byte Old, byte New) CryptoFields(int keyGen) => keyGen <= 2 ? ((byte)keyGen, (byte)0) : ((byte)2, (byte)keyGen);

    // rights-id = big-endian(titleId) + zeros, low byte = crypto2 (key generation), per NSCB restorehead_tr.
    private static byte[] RightsIdFromTitleId(ulong titleId, byte crypto2)
    {
        byte[] tr = new byte[0x10];
        BinaryPrimitives.WriteUInt64BigEndian(tr.AsSpan(0, 8), titleId);
        tr[0x0F] = crypto2;
        return tr;
    }

    // Original key-area from the current (RTRNCA) layout: titleKey = ECB^-1(keyAreaKey, cur[0:16]),
    // titleKeyEnc = ECB(titleKek[idx], titleKey); returns 0x40 of titleKeyEnc, or null if keys missing.
    private static byte[]? DerivedKeyArea(byte[] curKeyArea, KeySet keys, int idx, byte keyIndex)
    {
        try
        {
            if (idx >= keys.KeyAreaKeys.Length || idx >= keys.TitleKeks.Length) return null;
            byte[] kaek = keys.KeyAreaKeys[idx][keyIndex].DataRo[..0x10].ToArray();
            byte[] titleKey = AesEcb(kaek, curKeyArea[..0x10], decrypt: true);
            byte[] kek = keys.TitleKeks[idx].DataRo[..0x10].ToArray();
            byte[] tke = AesEcb(kek, titleKey, decrypt: false);
            var outBuf = new byte[0x40];
            for (int i = 0; i < 4; i++) tke.CopyTo(outBuf, i * 0x10);
            return outBuf;
        }
        catch { return null; }
    }

    // Candidate key-area values: current, derived(titleKeyEnc×4), titleKeyEnc+zeros, all-zeros.
    private static IEnumerable<byte[]> KeyAreaCandidates(byte[] cur, byte[]? derived)
    {
        yield return cur;
        if (derived is not null)
        {
            yield return derived;
            var padded = new byte[0x40];
            derived[..0x10].CopyTo(padded, 0);            // titleKeyEnc + zeros
            yield return padded;
        }
        yield return new byte[0x40];                      // zeros (matches NSCB restorehead_tr headdata)
    }

    private static byte[] AesEcb(byte[] key, byte[] data, bool decrypt)
    {
        using var aes = Aes.Create();
        aes.Key = key; aes.Mode = CipherMode.ECB; aes.Padding = PaddingMode.None;
        return decrypt ? aes.DecryptEcb(data, PaddingMode.None) : aes.EncryptEcb(data, PaddingMode.None);
    }

    /// <summary>
    /// Decrypt a 0xC00 raw NCA header, run the candidate restore, re-encrypt if it changed.
    /// </summary>
    public static RestoreResult RestoreHeaderInPlace(byte[] header, KeySet keys)
    {
        var headerKey = keys.HeaderKey.DataRo;
        bool wasEncrypted = !(header.Length > 0x202 && header[0x200] == (byte)'N' && header[0x201] == (byte)'C' && header[0x202] == (byte)'A');
        if (wasEncrypted) XtsHelper.TransformNcaHeader(header, headerKey, decrypt: true);
        var r = RestoreHeader(header, keys);
        if (wasEncrypted) XtsHelper.TransformNcaHeader(header, headerKey, decrypt: false);
        return r;
    }
}
