using System.Buffers.Binary;
using System.Text;

namespace NscbCore.Info;

/// <summary>
/// Hand-parsed NACP (ApplicationControlProperty) fields, mirroring the
/// NSC_BUILDER Nacp offsets (which follow switchbrew). Layout highlights:
/// 16 language entries of 0x300 bytes (Name 0x200 + Author 0x100),
/// DisplayVersion at 0x3060, age ratings at 0x3040.
/// </summary>
public sealed class NacpInfo
{
    public const int Size = 0x4000;

    private static readonly string[] LanguageNames =
    {
        "AmericanEnglish", "BritishEnglish", "Japanese", "French", "German",
        "LatinAmericanSpanish", "Spanish", "Italian", "Dutch", "CanadianFrench",
        "Portuguese", "Russian", "Korean", "TraditionalChinese", "SimplifiedChinese",
    };

    private static readonly string[] OrganizationNames =
    {
        "CERO", "GRACGCRB", "GSRMR", "ESRB", "ClassInd", "USK",
        "PEGI", "PEGIPortugal", "PEGIBBFC", "Russian", "ACB", "OFLC",
    };

    public sealed record LanguageEntry(string Language, string Name, string Publisher);

    public List<LanguageEntry> Languages { get; private init; } = [];
    public string DisplayName { get; private init; } = "";
    public string Publisher { get; private init; } = "";
    public string DisplayVersion { get; private init; } = "";
    public string Isbn { get; private init; } = "";
    public Dictionary<string, string> AgeRatings { get; private init; } = new();
    public byte ProgramIndex { get; private init; }
    public ulong AddOnContentBaseId { get; private init; }
    public ulong SaveDataOwnerId { get; private init; }

    public static NacpInfo Parse(ReadOnlySpan<byte> data)
    {
        if (data.Length < Size)
            throw new InvalidDataException($"NACP too small: {data.Length} bytes");

        var languages = new List<LanguageEntry>();
        for (int i = 0; i < 15; i++)
        {
            int baseOffset = i * 0x300;
            string name = ReadUtf8Z(data[baseOffset..(baseOffset + 0x200)]);
            if (name.Length == 0)
                continue;
            string publisherEntry = ReadUtf8Z(data[(baseOffset + 0x200)..(baseOffset + 0x300)]);
            languages.Add(new LanguageEntry(LanguageNames[i], name, publisherEntry));
        }

        var ages = new Dictionary<string, string>();
        for (int i = 0; i < 12; i++)
        {
            byte age = data[0x3040 + i];
            if (age <= 18 && age is 0 or 3 or 4 or 6 or 7 or 8 or 10 or 12 or 13 or 14 or 15 or 16 or 17 or 18)
                ages[OrganizationNames[i]] = age.ToString();
        }

        // Pick a display name: prefer the system UI language family, fall back
        // in a stable order (zh-Hans -> zh-Hant -> AmericanEnglish -> first entry).
        var byLang = languages.ToDictionary(l => l.Language, l => l);
        string displayName =
            byLang.GetValueOrDefault("SimplifiedChinese")?.Name
            ?? byLang.GetValueOrDefault("TraditionalChinese")?.Name
            ?? byLang.GetValueOrDefault("AmericanEnglish")?.Name
            ?? languages.FirstOrDefault()?.Name
            ?? "";

        string publisher =
            byLang.GetValueOrDefault("SimplifiedChinese")?.Publisher
            ?? byLang.GetValueOrDefault("TraditionalChinese")?.Publisher
            ?? byLang.GetValueOrDefault("AmericanEnglish")?.Publisher
            ?? languages.FirstOrDefault()?.Publisher
            ?? "";
        if (string.IsNullOrEmpty(publisher))
            publisher = languages.Select(l => l.Publisher).FirstOrDefault(p => !string.IsNullOrEmpty(p)) ?? "";

        return new NacpInfo
        {
            Languages = languages,
            DisplayName = displayName,
            Publisher = publisher,
            DisplayVersion = ReadUtf8Z(data[0x3060..0x3070]),
            Isbn = ReadUtf8Z(data[0x3000..0x3024]),
            AgeRatings = ages,
            ProgramIndex = data[0x3212],
            AddOnContentBaseId = BinaryPrimitives.ReadUInt64LittleEndian(data[0x3070..]),
            SaveDataOwnerId = BinaryPrimitives.ReadUInt64LittleEndian(data[0x3078..]),
        };
    }

    private static string ReadUtf8Z(ReadOnlySpan<byte> bytes)
    {
        int end = bytes.IndexOf((byte)0);
        if (end >= 0)
            bytes = bytes[..end];
        return Encoding.UTF8.GetString(bytes).Trim();
    }
}
