using System.Security.Cryptography;

namespace NscbCore.Crypto;

/// <summary>
/// AES-128-XTS implementation (IEEE 1619) using BCL AES-ECB, matching LibHac's
/// <c>LibHac.Tools.FsSystem.Aes128XtsTransform</c> byte-for-byte.
/// <para><b>Status: verified.</b> Confirmed equal to LibHac over the full NCA header on real
/// GameCard NCAs (see itest <c>xtsverify</c> / <c>setdistribution</c>). Two rules were needed
/// to match: the sector number is encoded <b>big-endian</b> into the 16-byte tweak input
/// (<c>FillArrayFromSector</c>), and GF(2^128) uses the IEEE left-shift + 0x87 rule.
/// <see cref="TransformNcaHeader"/> additionally reproduces LibHac's version-dependent
/// per-sector data-unit scheme over the 0xC00 header region.</para>
/// <para>NAX0 (sector 0x4000, right-shift + 0xE1) is a different convention — see <see cref="Nax0Xts"/>.</para>
/// </summary>
public static class XtsHelper
{
    public const int BlockSize = 0x10;
    public const int DefaultSectorSize = 0x200;

    /// <summary>Full XTS-encrypted NCA header region (LibHac <c>NcaHeader.HeaderSize</c>).</summary>
    public const int HeaderSize = 0xC00;
    /// <summary>XTS sector size used across the NCA header (LibHac <c>HeaderSectorSize</c>).</summary>
    public const int HeaderSectorSize = 0x200;

    /// <summary>
    /// In-place XTS transform of a buffer split into fixed-size sectors, with the sector
    /// (data-unit) index incrementing per sector starting at <paramref name="sectorOffset"/>.
    /// </summary>
    public static void Transform(Span<byte> data, ReadOnlySpan<byte> key1, ReadOnlySpan<byte> key2,
        long sectorOffset = 0, int sectorSize = DefaultSectorSize, bool encrypt = true)
    {
        if (key1.Length != 0x10 || key2.Length != 0x10)
            throw new ArgumentException("XTS keys must be 16 bytes each (AES-128).");
        if (sectorSize <= 0 || sectorSize % BlockSize != 0)
            throw new ArgumentException("sectorSize must be a positive multiple of 16.");

        using var aesData = CreateEcb(key1);
        using var aesTweak = CreateEcb(key2);

        int pos = 0;
        long sector = sectorOffset;
        while (pos < data.Length)
        {
            int len = Math.Min(sectorSize, data.Length - pos);
            XtsSector(data.Slice(pos, len), (ulong)sector, aesData, aesTweak, encrypt);
            pos += len;
            sector++;
        }
    }

    /// <summary>Transform a single sector (any length) whose data-unit index is <paramref name="sectorNum"/>.</summary>
    public static void TransformSector(Span<byte> data, ReadOnlySpan<byte> key1, ReadOnlySpan<byte> key2,
        ulong sectorNum, bool encrypt)
    {
        using var aesData = CreateEcb(key1);
        using var aesTweak = CreateEcb(key2);
        XtsSector(data, sectorNum, aesData, aesTweak, encrypt);
    }

    /// <summary>
    /// Decrypt (<paramref name="decrypt"/>=true) or re-encrypt an NCA header region in place,
    /// reproducing LibHac's exact per-sector data-unit scheme over the 0xC00 region:
    /// <list type="bullet">
    ///   <item><description>sectors 0 &amp; 1 (bytes 0x000..0x3FF) always, with data-unit 0 and 1.</description></item>
    ///   <item><description>Nca3 (version digit '3' at 0x203): sectors at 0x400.. use data-unit = block index (2..5).</description></item>
    ///   <item><description>Nca2 (digit '2'): blocks at 0x400..0xBFF all use data-unit <b>0</b>.</description></item>
    ///   <item><description>Nca0 (digit '0'): only the first two sectors are XTS-transformed.</description></item>
    /// </list>
    /// </summary>
    /// <param name="header">The header region; must be at least <see cref="HeaderSize"/> (0xC00) bytes.</param>
    /// <param name="headerKey">The 32-byte header key (data key = [0..16), tweak key = [16..32)).</param>
    public static void TransformNcaHeader(Span<byte> header, ReadOnlySpan<byte> headerKey, bool decrypt)
    {
        if (headerKey.Length != 0x20)
            throw new ArgumentException("NCA header key must be 32 bytes.", nameof(headerKey));
        if (header.Length < HeaderSize)
            throw new ArgumentException($"NCA header region must be at least {HeaderSize} bytes.", nameof(header));

        ReadOnlySpan<byte> key1 = headerKey[..0x10];
        ReadOnlySpan<byte> key2 = headerKey[0x10..0x20];
        using var aesData = CreateEcb(key1);
        using var aesTweak = CreateEcb(key2);

        if (decrypt)
        {
            // Ciphertext at entry: the version digit (0x203) is only readable after sectors 0/1
            // are decrypted, so decrypt those first, then the version-dependent remainder.
            XtsSector(header.Slice(0, HeaderSectorSize), 0, aesData, aesTweak, encrypt: false);
            XtsSector(header.Slice(HeaderSectorSize, HeaderSectorSize), 1, aesData, aesTweak, encrypt: false);
            ProcessHeaderRest(header, header[0x203] - '0', aesData, aesTweak, encrypt: false);
        }
        else
        {
            // Plaintext at entry: read the version digit BEFORE anything is encrypted.
            int version = header[0x203] - '0';
            XtsSector(header.Slice(0, HeaderSectorSize), 0, aesData, aesTweak, encrypt: true);
            XtsSector(header.Slice(HeaderSectorSize, HeaderSectorSize), 1, aesData, aesTweak, encrypt: true);
            ProcessHeaderRest(header, version, aesData, aesTweak, encrypt: true);
        }
    }

    /// <summary>
    /// Applies LibHac's version-dependent data-unit scheme to the 0x400..0xBFF header blocks:
    /// Nca3 → blocks 2..5 with data-unit = index; Nca2 → blocks 2..5 all with data-unit 0;
    /// Nca0 → nothing. Order is irrelevant (each sector is independent).
    /// </summary>
    private static void ProcessHeaderRest(Span<byte> header, int version, Aes aesData, Aes aesTweak, bool encrypt)
    {
        if (version == 3)
        {
            for (int j = 2; j < 6; j++)
                XtsSector(header.Slice(j * HeaderSectorSize, HeaderSectorSize), (ulong)j, aesData, aesTweak, encrypt);
        }
        else if (version == 2)
        {
            for (int i = 2; i < 6; i++)
                XtsSector(header.Slice(i * HeaderSectorSize, HeaderSectorSize), 0, aesData, aesTweak, encrypt);
        }
        // version 0 (NCA0): only the first two sectors are XTS-transformed.
    }

    /// <summary>Process one sector region: reset the tweak from the sector number, XOR-AES-XOR per 16-byte block.</summary>
    private static void XtsSector(Span<byte> data, ulong sector, Aes aesData, Aes aesTweak, bool encrypt)
    {
        var dataOp = encrypt ? aesData.CreateEncryptor() : aesData.CreateDecryptor();
        var tweakOp = aesTweak.CreateEncryptor(); // tweak is always AES-encrypt

        // T_sector = AES-ECB(tweakKey, sectorNumber as 16-byte BIG-endian).
        var sectorNumBytes = new byte[BlockSize];
        ulong sn = sector;
        for (int b = BlockSize - 1; b >= 0; b--) { sectorNumBytes[b] = (byte)sn; sn >>= 8; }
        byte[] tweak = tweakOp.TransformFinalBlock(sectorNumBytes, 0, BlockSize);

        var tmp = new byte[BlockSize];
        for (int off = 0; off + BlockSize <= data.Length; off += BlockSize)
        {
            var blk = data.Slice(off, BlockSize);
            for (int i = 0; i < BlockSize; i++) tmp[i] = (byte)(blk[i] ^ tweak[i]);
            byte[] inner = dataOp.TransformFinalBlock(tmp, 0, BlockSize);
            for (int i = 0; i < BlockSize; i++) blk[i] = (byte)(inner[i] ^ tweak[i]);
            GfMul(tweak);
        }
    }

    private static Aes CreateEcb(ReadOnlySpan<byte> key)
    {
        var a = Aes.Create();
        a.Key = key.ToArray();
        a.Mode = CipherMode.ECB;
        a.Padding = PaddingMode.None;
        return a;
    }

    /// <summary>Multiply by α (x) in GF(2^128) with the XTS primitive polynomial.</summary>
    private static void GfMul(Span<byte> v)
    {
        // v is a 16-byte little-endian element of GF(2^128).
        byte carry = 0;
        for (int i = 0; i < 16; i++)
        {
            byte newCarry = (byte)((v[i] & 0x80) >> 7);
            v[i] = (byte)((v[i] << 1) | carry);
            carry = newCarry;
        }
        if (carry != 0) v[0] ^= 0x87; // reduction polynomial x^128 + x^7 + x^2 + x + 1
    }
}
