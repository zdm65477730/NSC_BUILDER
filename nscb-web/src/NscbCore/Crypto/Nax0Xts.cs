using System.Buffers.Binary;
using System.Security.Cryptography;

namespace NscbCore.Crypto;

/// <summary>
/// AES-128-XTS transform for <b>NAX0</b> (Nintendo Archive, SD-card storage), faithful to
/// the Atmosphere / hactool sector model:
/// <list type="bullet">
///   <item><description>sector size = 0x4000 (16384 bytes); tweak = AES-ECB(K2, sector index as 16-byte little-endian)</description></item>
///   <item><description>per 16-byte block the sector tweak is multiplied by α⁻¹ in GF(2¹²⁸) using the
///     <b>right-shift + 0xE1</b> reduction — the inverse of the IEEE-1619 left-shift + 0x87 convention used
///     by <see cref="XtsHelper"/> for NCA headers. The two are NOT interchangeable.</description></item>
///   <item><description>ciphertext stealing is applied to a trailing partial block, mirroring the reference byte-for-byte.</description></item>
/// </list>
/// Only the XTS body is provided: NAX0 header unwrap and HMAC verification are out of scope.
/// </summary>
public static class Nax0Xts
{
    public const int SectorSize = 0x4000;
    public const int BlockSize = 0x10;

    /// <summary>
    /// Transform a whole buffer split into <see cref="SectorSize"/>-byte sectors, with the
    /// sector index incrementing per sector starting at <paramref name="firstSectorNum"/>.
    /// </summary>
    public static void Transform(Span<byte> data, ReadOnlySpan<byte> key1, ReadOnlySpan<byte> key2,
        ulong firstSectorNum, bool encrypt)
    {
        int pos = 0;
        ulong sector = firstSectorNum;
        while (pos < data.Length)
        {
            int len = Math.Min(SectorSize, data.Length - pos);
            TransformSector(data.Slice(pos, len), key1, key2, sector, encrypt);
            pos += len;
            sector++;
        }
    }

    /// <summary>
    /// Transform a single NAX0 sector (length ≤ <see cref="SectorSize"/>) in place.
    /// Encryption and decryption are the same routine apart from the inner AES direction.
    /// </summary>
    public static void TransformSector(Span<byte> data, ReadOnlySpan<byte> key1, ReadOnlySpan<byte> key2,
        ulong sectorNum, bool encrypt)
    {
        if (key1.Length != BlockSize || key2.Length != BlockSize)
            throw new ArgumentException("NAX0 XTS keys must be 16 bytes each (AES-128).");
        if (data.Length > SectorSize)
            throw new ArgumentException($"NAX0 sector cannot exceed {SectorSize} bytes.");

        using var aesData = CreateEcb(key1);
        using var aesTweak = CreateEcb(key2);

        // T0 = AES-ECB(key2, sectorNum as 16-byte little-endian).
        Span<byte> sectorBytes = stackalloc byte[BlockSize];
        BinaryPrimitives.WriteUInt64LittleEndian(sectorBytes, sectorNum); // high 8 bytes stay zero
        byte[] tweak = aesTweak.EncryptEcb(ToArr(sectorBytes), PaddingMode.None);

        int total = data.Length;
        int fullBlocks = total / BlockSize;
        int trailing = total % BlockSize;
        int nBlocks = (total + BlockSize - 1) / BlockSize;

        var outBuf = new byte[total];
        int outLen = 0; // logical length appended (supports the pop/replace on CTS)

        for (int i = 0; i < nBlocks; i++)
        {
            int offset = i * BlockSize;
            Span<byte> block = data.Slice(offset, Math.Min(BlockSize, total - offset));

            if (i < fullBlocks)
            {
                byte[] cipher = TransformBlock(aesData, ToArr(block), tweak, encrypt);
                CopyLen(cipher, outBuf, ref outLen, BlockSize);
                tweak = GfMul(tweak);
            }
            else
            {
                // Trailing partial block → ciphertext stealing.
                // Re-encrypt the previous full block with the *current* tweak, then the
                // partial block with the next tweak, and interleave the tails exactly as
                // the reference does (including popping the previously appended block).
                Span<byte> prev = data.Slice(offset - BlockSize, BlockSize);
                byte[] cPrev = TransformBlock(aesData, ToArr(prev), tweak, encrypt);
                tweak = GfMul(tweak);

                // Partial block padded to 16 with zero high bytes.
                byte[] padded = new byte[BlockSize];
                block.CopyTo(padded);
                byte[] cPart = TransformBlock(aesData, padded, tweak, encrypt);

                // Pop the last full block already appended, replace with new_prev + new_part.
                outLen -= BlockSize;
                // new_prev = cPrev[0 .. 16-trailing] ++ cPart[0 .. trailing]
                for (int k = 0; k < BlockSize - trailing; k++)
                    outBuf[outLen++] = cPrev[k];
                for (int k = 0; k < trailing; k++)
                    outBuf[outLen++] = cPart[k];
                // new_part = cPrev[16-trailing .. 16]
                for (int k = BlockSize - trailing; k < BlockSize; k++)
                    outBuf[outLen++] = cPrev[k];
            }
        }

        outBuf.AsSpan(0, total).CopyTo(data);
    }

    private static byte[] TransformBlock(Aes aes, byte[] block, byte[] tweak, bool encrypt)
    {
        Span<byte> x = stackalloc byte[BlockSize];
        for (int i = 0; i < BlockSize; i++) x[i] = (byte)(block[i] ^ tweak[i]);
        byte[] inner = encrypt
            ? aes.EncryptEcb(ToArr(x), PaddingMode.None)
            : aes.DecryptEcb(ToArr(x), PaddingMode.None);
        for (int i = 0; i < BlockSize; i++) inner[i] ^= tweak[i];
        return inner;
    }

    /// <summary>GF(2^128) multiply by α⁻¹: little-endian right shift with reduction 0xE1 at the top byte.</summary>
    private static byte[] GfMul(byte[] tweak)
    {
        int t = tweak[0] & 1; // carry = LSB
        // Right shift the whole 16-byte little-endian value by one bit.
        for (int i = 0; i < BlockSize; i++)
        {
            int nextCarry = (i + 1 < BlockSize) ? (tweak[i + 1] & 1) : 0;
            tweak[i] = (byte)((tweak[i] >> 1) | (nextCarry << 7));
        }
        if (t != 0) tweak[15] ^= 0xE1;
        return tweak;
    }

    private static Aes CreateEcb(ReadOnlySpan<byte> key)
    {
        var a = Aes.Create();
        a.Key = key.ToArray();
        a.Mode = CipherMode.ECB;
        a.Padding = PaddingMode.None;
        return a;
    }

    private static byte[] ToArr(Span<byte> s) => s.ToArray();

    private static void CopyLen(byte[] src, byte[] dst, ref int dstPos, int len)
    {
        Array.Copy(src, 0, dst, dstPos, len);
        dstPos += len;
    }
}
