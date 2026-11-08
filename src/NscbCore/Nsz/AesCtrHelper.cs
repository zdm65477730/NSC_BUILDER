using System.Security.Cryptography;

namespace NscbCore.Nsz;

/// <summary>
/// AES-CTR transform built on top of BCL AES-ECB.
/// The 128-bit counter is treated as a big-endian unsigned integer incremented by 1 per 16-byte block,
/// matching NSCB's <c>AESCTR.seek</c> (which uses a 64-bit counter with a 64-bit fixed prefix).
/// </summary>
internal static class AesCtrHelper
{
    /// <summary>
    /// In-place AES-CTR XOR transform (encrypt = decrypt in CTR mode).
    /// </summary>
    public static void DecryptOrEncrypt(Span<byte> data, ReadOnlySpan<byte> key, ReadOnlySpan<byte> initialCounter)
        => Transform(data, key, initialCounter);

    /// <summary>
    /// In-place AES-CTR XOR transform (encrypt = decrypt in CTR mode).
    /// </summary>
    public static void Transform(Span<byte> data, ReadOnlySpan<byte> key, ReadOnlySpan<byte> initialCounter)
    {
        if (data.IsEmpty) return;
        if (key.Length != 16)
            throw new ArgumentException("AES-128 key must be 16 bytes.", nameof(key));
        if (initialCounter.Length != 16)
            throw new ArgumentException("CTR counter must be 16 bytes.", nameof(initialCounter));

        // ECB encryptor: encrypt individual 16-byte counter blocks to produce keystream.
        using var aes = Aes.Create();
        aes.Key = key.ToArray();
        aes.Mode = CipherMode.ECB;
        aes.Padding = PaddingMode.None;
        using var enc = aes.CreateEncryptor();

        byte[] counter = initialCounter.ToArray();
        byte[] keystream = new byte[16];

        int pos = 0;
        while (pos < data.Length)
        {
            // Encrypt counter block → keystream.
            enc.TransformBlock(counter, 0, 16, keystream, 0);

            int chunk = Math.Min(16, data.Length - pos);
            for (int j = 0; j < chunk; j++)
                data[pos + j] ^= keystream[j];

            pos += chunk;
            if (pos < data.Length)
                IncrementCounter(counter);
        }
    }

    /// <summary>Build a 16-byte counter for an NCA section: prefix(8) || (offset/16 as BE u64).</summary>
    public static byte[] BuildCounter(ReadOnlySpan<byte> nonce8, long byteOffset)
    {
        byte[] ctr = new byte[16];
        nonce8[..8].CopyTo(ctr);
        // Lower 8 bytes = big-endian block number.
        ulong block = (ulong)(byteOffset / 16);
        for (int i = 0; i < 8; i++)
            ctr[8 + 7 - i] = (byte)((block >> (i * 8)) & 0xFF);
        return ctr;
    }

    private static void IncrementCounter(byte[] ctr)
    {
        for (int i = 15; i >= 0; i--)
            if (++ctr[i] != 0) break;
    }
}
