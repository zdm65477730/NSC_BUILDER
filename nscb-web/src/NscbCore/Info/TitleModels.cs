namespace NscbCore.Info;

/// <summary>One content file inside a container (NCA / NCZ / tik / cert / xml / ...).</summary>
public sealed class ContentEntryInfo
{
    public string Name { get; set; } = "";
    public long Size { get; set; }
    public bool Compressed { get; set; }
    public string? Kind { get; set; }              // "nca" | "ncz" | "ticket" | "cert" | "xml" | "html" | "other"
    public string? NcaType { get; set; }           // Program / Meta / Control / ...
    public string? Distribution { get; set; }      // Download / GameCard
    public string? NcaId { get; set; }             // hex (from cnmt when available)
    public ulong? TitleId { get; set; }
    public int? KeyGeneration { get; set; }
    public string? FirmwareRangeFromKg { get; set; }
    public bool? HasTitleKeyCrypto { get; set; }   // rights id present
    public string? Error { get; set; }
}

/// <summary>Card (XCI) header details.</summary>
public sealed class CardHeaderInfo
{
    public string? RomSize { get; set; }
    public byte? RomSizeFlag { get; set; }
    public ulong? PackageId { get; set; }
    public ulong? ValidDataEndAddress { get; set; }
    public string? FirmwareVersion { get; set; }    // decrypted RSV string when xci_header_key known
    public ulong? FirmwareVersionRaw { get; set; }
    public byte? KekIndex { get; set; }
    public byte? TitleKeyDecIndex { get; set; }
}

/// <summary>NSZ compression details.</summary>
public sealed class CompressionInfo
{
    public bool IsBlockCompressed { get; set; }
    public int BlockSizeExponent { get; set; }
    public long DecompressedSize { get; set; }
    public int SectionCount { get; set; }
}

/// <summary>Aggregate info for one container file (JSON keys are fixed English).</summary>
public sealed class ContainerFileInfo
{
    public string Path { get; set; } = "";
    public string Format { get; set; } = "";        // nsp / nsz / xci / xcz / nca / ncz
    public long FileSize { get; set; }

    public string? TitleName { get; set; }
    public string? Publisher { get; set; }
    public string? Developer { get; set; }     // from TitlesDb (eShop metadata) when available
    public string? Genre { get; set; }          // from TitlesDb
    public string? Region { get; set; }         // from TitlesDb
    public string? DisplayVersion { get; set; }
    public string? TitleId { get; set; }            // hex
    public string? BaseTitleId { get; set; }        // hex
    public string? TitleType { get; set; }          // Application / Patch / AddOnContent / ...
    public string? TitleVersion { get; set; }       // "1.0.3"
    public ulong? TitleVersionRaw { get; set; }     // raw cnmt TitleVersion (for NSCB [v{raw}] naming)
    public string? RequiredSystemVersion { get; set; } // RSV decoded, e.g. "(19.0.0)"
    public int? KeyGeneration { get; set; }
    public string? FirmwareRangeFromKg { get; set; }
    public string? FirmwareRequirement { get; set; }   // friendly summary
    public bool HasTitleKeyCrypto { get; set; }
    public bool HasTicket { get; set; }
    public bool TitleKeyAvailable { get; set; }     // title key could be derived (container ticket + prod.keys)

    public CardHeaderInfo? Card { get; set; }
    public CompressionInfo? Compression { get; set; }
    public List<ContentEntryInfo> Contents { get; set; } = [];
    public bool HasIcon { get; set; }

    public bool KeysAvailable { get; set; }
    public List<string> Warnings { get; set; } = [];
    public string? Error { get; set; }

    /// <summary>Shallow-ish copy: all scalar fields plus fresh copies of the small lists, so a caller can freely
    /// mutate the result (e.g. a version override for naming) without affecting a cached/shared instance.</summary>
    public ContainerFileInfo Clone() => new()
    {
        Path = Path, Format = Format, FileSize = FileSize,
        TitleName = TitleName, Publisher = Publisher, Developer = Developer, Genre = Genre, Region = Region,
        DisplayVersion = DisplayVersion, TitleId = TitleId, BaseTitleId = BaseTitleId, TitleType = TitleType,
        TitleVersion = TitleVersion, TitleVersionRaw = TitleVersionRaw, RequiredSystemVersion = RequiredSystemVersion,
        KeyGeneration = KeyGeneration, FirmwareRangeFromKg = FirmwareRangeFromKg, FirmwareRequirement = FirmwareRequirement,
        HasTitleKeyCrypto = HasTitleKeyCrypto, HasTicket = HasTicket, TitleKeyAvailable = TitleKeyAvailable,
        Card = Card, Compression = Compression, Contents = new List<ContentEntryInfo>(Contents), HasIcon = HasIcon,
        KeysAvailable = KeysAvailable, Warnings = new List<string>(Warnings), Error = Error,
    };
}

/// <summary>Content meta type strings (LibHac.Ncm.ContentMetaType).</summary>
public static class ContentMetaTypeStrings
{
    public static string From(byte value) => value switch
    {
        1 => "SystemProgram",
        2 => "SystemData",
        3 => "SystemUpdate",
        4 => "BootImagePackage",
        5 => "BootImagePackageSafe",
        128 => "Application",
        129 => "Patch",
        130 => "AddOnContent",
        131 => "Delta",
        _ => $"Unknown({value})",
    };
}

public static class ContentTypeStrings
{
    public static string From(byte value) => value switch
    {
        0 => "Meta",
        1 => "Program",
        2 => "Data",
        3 => "Control",
        4 => "HtmlDocument",
        5 => "LegalInformation",
        6 => "DeltaFragment",
        _ => $"Unknown({value})",
    };
}
