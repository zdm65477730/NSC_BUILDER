using System.Text.Json;

namespace NscbCore.Info;

/// <summary>One eShop title record (metadata only — no keys).</summary>
public sealed class TitlesDbEntry
{
    public string? Name { get; set; }
    public string? Developer { get; set; }
    public string? Publisher { get; set; }
    public string? Region { get; set; }
    public string? Genre { get; set; }
    public string? IconUrl { get; set; }
    public string? BannerUrl { get; set; }
}

/// <summary>
/// Loads a Nintendo title metadata DB (the eShop "titles.json" — id → name/dev/publisher/genre/…).
/// Enriches Info/Database/Rename with nicer names and metadata. Contains NO title keys.
/// </summary>
public sealed class TitlesDb
{
    private readonly Dictionary<string, TitlesDbEntry> _m = new(StringComparer.OrdinalIgnoreCase);
    // rights-id (32-hex, upper-cased) → 16-byte title key, from entries that carry both.
    private readonly Dictionary<string, byte[]> _titleKeys = new(StringComparer.OrdinalIgnoreCase);
    public int Count => _m.Count;
    public int TitleKeyCount => _titleKeys.Count;
    public IReadOnlyDictionary<string, byte[]> TitleKeys => _titleKeys;

    public static TitlesDb Load(string path)
    {
        var db = new TitlesDb();
        using var doc = JsonDocument.Parse(File.ReadAllBytes(path));
        if (doc.RootElement.ValueKind != JsonValueKind.Object) return db;
        foreach (var prop in doc.RootElement.EnumerateObject())
        {
            var v = prop.Value;
            if (v.ValueKind != JsonValueKind.Object) continue;
            db._m[prop.Name] = new TitlesDbEntry
            {
                Name = Str(v, "name"),
                Developer = Str(v, "developer"),
                Publisher = Str(v, "publisher"),
                Region = Str(v, "region"),
                Genre = Arr(v, "category"),
                IconUrl = Str(v, "iconUrl"),
                BannerUrl = Str(v, "bannerUrl"),
            };
            // Some entries also carry the real title key ("key") + its rights-id — usable for decryption.
            string? keyHex = Str(v, "key"), rid = Str(v, "rightsId");
            if (IsHex(keyHex, 32) && IsHex(rid, 32))
                db._titleKeys[rid!.ToUpperInvariant()] = Convert.FromHexString(keyHex!);
        }
        return db;
    }

    private static bool IsHex(string? s, int len) =>
        s != null && s.Length == len && Uri.IsHexDigit(s[0]) && s.All(Uri.IsHexDigit);

    /// <summary>Look up by title id (case/space tolerant; accepts the 16-hex id).</summary>
    public TitlesDbEntry? Lookup(string? titleId)
    {
        if (string.IsNullOrWhiteSpace(titleId)) return null;
        titleId = titleId.Trim();
        if (_m.TryGetValue(titleId, out var e)) return e;
        if (titleId.Length >= 16 && _m.TryGetValue(titleId[..16], out var e2)) return e2;
        return null;
    }

    private static string? Str(JsonElement o, string p) =>
        o.TryGetProperty(p, out var v) && v.ValueKind == JsonValueKind.String ? NullIfEmpty(v.GetString()) : null;

    private static string? Arr(JsonElement o, string p)
    {
        if (!o.TryGetProperty(p, out var v) || v.ValueKind != JsonValueKind.Array || v.GetArrayLength() == 0) return null;
        var parts = v.EnumerateArray().Where(x => x.ValueKind == JsonValueKind.String).Select(x => x.GetString()).Where(s => !string.IsNullOrEmpty(s));
        var joined = string.Join(", ", parts);
        return string.IsNullOrEmpty(joined) ? null : joined;
    }

    private static string? NullIfEmpty(string? s) => string.IsNullOrEmpty(s) ? null : s;
}
