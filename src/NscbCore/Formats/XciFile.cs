using System.Buffers.Binary;
using LibHac.Crypto;

namespace NscbCore.Formats;

/// <summary>
/// File-layout offsets and card header parsing for XCI/XCZ images.
/// The physical layout hides the 0x1000 byte CardKeyArea, so on file:
/// CardHeader at 0x0, CardHeaderT2 at 0x200, CertArea at 0x7000, root HFS0 at 0xF000.
/// </summary>
public static class XciLayout
{
    public const int CardHeaderSize = 0x200;
    public const int CardHeaderT2Offset = 0x200;
    public const int CertAreaOffset = 0x7000;
    public const int CertAreaSize = 0x8000;
    public const long RootHfs0Offset = 0xF000;
    public const uint PageSize = 0x200;

    // CardHeader body offsets (relative to 0x100, i.e. after the RSA signature)
    public const int HdrMagic = 0x100;
    public const int HdrRomAreaStartPage = 0x104;
    public const int HdrBackupAreaStartPage = 0x108;
    public const int HdrKekTitleKeyIndex = 0x10C;
    public const int HdrRomSize = 0x10D;
    public const int HdrVersion = 0x10E;
    public const int HdrFlags = 0x10F;
    public const int HdrPackageId = 0x110;
    public const int HdrValidDataEndAddress = 0x118;
    public const int HdrIv = 0x120;
    public const int HdrPartitionFsHeaderAddress = 0x130;
    public const int HdrPartitionFsHeaderSize = 0x138;
    public const int HdrPartitionFsHeaderHash = 0x140;
    public const int HdrInitialDataHash = 0x160;
    public const int HdrSelSec = 0x180;
    public const int HdrSelT1Key = 0x184;
    public const int HdrSelKey = 0x188;
    public const int HdrLimArea = 0x18C;
    public const int HdrEncryptedData = 0x190;
    public const int HdrEncryptedDataSize = 0x70;
}

/// <summary>Parsed XCI/XCZ card header.</summary>
public sealed class XciCardHeader
{
    public byte[] Signature { get; init; } = new byte[0x100];
    public uint RomAreaStartPage { get; init; }
    public uint BackupAreaStartPage { get; init; }
    public byte KekIndex { get; init; }
    public byte TitleKeyDecIndex { get; init; }
    public byte RomSizeFlag { get; init; }
    public byte HeaderVersion { get; init; }
    public byte Flags { get; init; }
    public ulong PackageId { get; init; }
    public ulong ValidDataEndAddress { get; init; }
    public ulong PartitionFsHeaderAddress { get; init; }
    public ulong PartitionFsHeaderSize { get; init; }
    public byte[] PartitionFsHeaderHash { get; init; } = new byte[0x20];

    /// <summary>Firmware version (RSV) from the encrypted header area; null when the key is unavailable.</summary>
    public ulong? FwVersion { get; init; }

    public bool IsHeaderEncryptedAreaDecrypted { get; init; }

    /// <summary>Total file size implied by the header (valid data end page * 0x200).</summary>
    public ulong HeaderFileSize => (ulong)ValidDataEndAddress * XciLayout.PageSize;
}

/// <summary>Parses XCI/XCZ card headers (decrypting the trailing encrypted area when the key is known).</summary>
public static class XciReader
{
    public static bool IsXci(Stream stream)
    {
        Span<byte> buf = stackalloc byte[0x104];
        stream.Position = 0;
        int read = stream.Read(buf);
        stream.Position = 0;
        return read >= 0x104 && buf[0x100] == (byte)'H' && buf[0x101] == (byte)'E'
            && buf[0x102] == (byte)'A' && buf[0x103] == (byte)'D';
    }

    /// <summary>Reads and parses the card header at offset 0.</summary>
    public static XciCardHeader ReadCardHeader(Stream stream, ReadOnlySpan<byte> xciHeaderKey)
    {
        byte[] header = new byte[XciLayout.CardHeaderSize];
        stream.Position = 0;
        if (stream.Read(header) != header.Length)
            throw new InvalidDataException("Truncated XCI card header");

        if (header[XciLayout.HdrMagic + 0] != (byte)'H' || header[XciLayout.HdrMagic + 1] != (byte)'E'
            || header[XciLayout.HdrMagic + 2] != (byte)'A' || header[XciLayout.HdrMagic + 3] != (byte)'D')
            throw new InvalidDataException("Not an XCI image (missing HEAD magic)");

        ulong fwVersion = 0;
        bool decrypted = false;

        if (xciHeaderKey.Length >= 0x10)
        {
            // The 0x70 byte trailing area is AES-128-CBC encrypted with the XCI header key.
            byte[] iv = header[XciLayout.HdrIv..(XciLayout.HdrIv + 0x10)];
            Array.Reverse(iv);
            byte[] enc = header[XciLayout.HdrEncryptedData..(XciLayout.HdrEncryptedData + XciLayout.HdrEncryptedDataSize)];

            try
            {
                var cbc = new AesCbcDecryptor(xciHeaderKey[..0x10], iv);
                cbc.Transform(enc, enc);
                fwVersion = BinaryPrimitives.ReadUInt64LittleEndian(enc);
                decrypted = true;
            }
            catch
            {
                decrypted = false;
            }
        }

        return new XciCardHeader
        {
            Signature = header[..0x100],
            RomAreaStartPage = BinaryPrimitives.ReadUInt32LittleEndian(header.AsSpan(XciLayout.HdrRomAreaStartPage, 4)),
            BackupAreaStartPage = BinaryPrimitives.ReadUInt32LittleEndian(header.AsSpan(XciLayout.HdrBackupAreaStartPage, 4)),
            KekIndex = (byte)(header[XciLayout.HdrKekTitleKeyIndex] & 0xF),
            TitleKeyDecIndex = (byte)(header[XciLayout.HdrKekTitleKeyIndex] >> 4),
            RomSizeFlag = header[XciLayout.HdrRomSize],
            HeaderVersion = header[XciLayout.HdrVersion],
            Flags = header[XciLayout.HdrFlags],
            PackageId = BinaryPrimitives.ReadUInt64LittleEndian(header.AsSpan(XciLayout.HdrPackageId, 8)),
            ValidDataEndAddress = BinaryPrimitives.ReadUInt64LittleEndian(header.AsSpan(XciLayout.HdrValidDataEndAddress, 8)),
            PartitionFsHeaderAddress = BinaryPrimitives.ReadUInt64LittleEndian(header.AsSpan(XciLayout.HdrPartitionFsHeaderAddress, 8)),
            PartitionFsHeaderSize = BinaryPrimitives.ReadUInt64LittleEndian(header.AsSpan(XciLayout.HdrPartitionFsHeaderSize, 8)),
            PartitionFsHeaderHash = header[XciLayout.HdrPartitionFsHeaderHash..(XciLayout.HdrPartitionFsHeaderHash + 0x20)],
            FwVersion = decrypted ? fwVersion : null,
            IsHeaderEncryptedAreaDecrypted = decrypted,
        };
    }
}
