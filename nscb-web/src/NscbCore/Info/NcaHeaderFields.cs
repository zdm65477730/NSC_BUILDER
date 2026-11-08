using System.Buffers.Binary;
using System.Text;

namespace NscbCore.Info;

/// <summary>
/// Hand-parsed NCA header fields from a decrypted 0x4000 header block.
/// Used for NCZ entries (whose 0x4000 header is plaintext) and as a
/// dependency-free fallback when LibHac cannot construct an Nca.
/// Offsets follow the switchbrew NCA format / NSC_BUILDER pyNCA3 layout.
/// </summary>
public sealed class NcaHeaderFields
{
    public const int HeaderSize = 0x4000;

    public uint Magic { get; private init; }
    public byte DistributionType { get; private init; }
    public byte ContentTypeByte { get; private init; }
    public byte KeyGenerationOld { get; private init; }
    public byte KeyAreaKeyIndex { get; private init; }
    public long NcaSize { get; private init; }
    public ulong TitleId { get; private init; }
    public uint SdkVersion { get; private init; }
    public byte CryptoType2 { get; private init; }
    public byte KeyGenerationNew { get; private init; }
    public byte[] RightsId { get; private init; } = new byte[0x10];

    public bool HasRightsId => !RightsId.All(b => b == 0);
    public bool IsNca3 => Magic == 0x3341434E; // "NCA3" little-endian
    public bool IsNca2 => Magic == 0x3241434E; // "NCA2"

    /// <summary>The effective key generation (larger of the old and new fields).</summary>
    public byte KeyGeneration => Math.Max(KeyGenerationOld, KeyGenerationNew);

    public static bool IsNcaHeader(ReadOnlySpan<byte> header)
        => header.Length >= 0x204
            && header[0x200] == (byte)'N' && header[0x201] == (byte)'C' && header[0x202] == (byte)'A';

    public static NcaHeaderFields Parse(ReadOnlySpan<byte> header)
    {
        if (!IsNcaHeader(header))
            throw new InvalidDataException("Not an NCA header (missing NCA magic at 0x200)");

        return new NcaHeaderFields
        {
            Magic = BinaryPrimitives.ReadUInt32LittleEndian(header[0x200..]),
            DistributionType = header[0x204],
            ContentTypeByte = header[0x205],
            KeyGenerationOld = header[0x206],
            KeyAreaKeyIndex = header[0x207],
            NcaSize = BinaryPrimitives.ReadInt64LittleEndian(header[0x208..]),
            TitleId = BinaryPrimitives.ReadUInt64LittleEndian(header[0x210..]),
            SdkVersion = BinaryPrimitives.ReadUInt32LittleEndian(header[0x21C..]),
            CryptoType2 = header[0x220],
            KeyGenerationNew = header[0x221],
            RightsId = header[0x230..0x240].ToArray(),
        };
    }

    public static string ContentTypeString(byte contentType) => contentType switch
    {
        0 => "Program",
        1 => "Meta",
        2 => "Control",
        3 => "Manual",
        4 => "Data",
        5 => "PublicData",
        _ => $"Unknown({contentType})",
    };

    public static string DistributionTypeString(byte distributionType) => distributionType switch
    {
        0 => "Download",
        1 => "GameCard",
        _ => $"Unknown({distributionType})",
    };
}

/// <summary>Helper to format 16-byte NcaId / RightsId style identifiers.</summary>
public static class NcaIdFormatter
{
    public static string ToHex(ReadOnlySpan<byte> id)
    {
        var sb = new StringBuilder(id.Length * 2);
        foreach (byte b in id)
            sb.Append(b.ToString("x2"));
        return sb.ToString();
    }
}
