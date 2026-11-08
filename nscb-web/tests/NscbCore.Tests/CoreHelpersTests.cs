using System.IO;
using NscbCore.Info;
using Xunit;

namespace NscbCore.Tests;

/// <summary>
/// Unit tests for pure NscbCore helpers that don't need game files: the eShop TitlesDb loader/lookup
/// (+ rights-id → title-key extraction), the NCA-id hex formatter, and the content/meta type string maps.
/// These previously had no coverage.
/// </summary>
public class CoreHelpersTests : IDisposable
{
    private readonly List<string> _temp = new();
    public void Dispose() { foreach (var f in _temp) { try { File.Delete(f); } catch { } } }
    private string WriteJson(string content) { var p = Path.GetTempFileName(); File.WriteAllText(p, content); _temp.Add(p); return p; }

    // ── NcaIdFormatter ───────────────────────────────────────────────────────────────
    [Fact]
    public void NcaIdFormatter_ToHex_LowercaseFixedWidth()
    {
        byte[] id = { 0x01, 0x23, 0x45, 0x67, 0x89, 0xAB, 0xCD, 0xEF, 0, 0, 0, 0, 0, 0, 0, 0xF0 };
        Assert.Equal("0123456789abcdef00000000000000f0", NcaIdFormatter.ToHex(id));
        Assert.Equal("", NcaIdFormatter.ToHex(ReadOnlySpan<byte>.Empty));
    }

    // ── Content*Strings maps ─────────────────────────────────────────────────────────
    [Theory]
    [InlineData((byte)128, "Application")] [InlineData((byte)129, "Patch")]
    [InlineData((byte)130, "AddOnContent")] [InlineData((byte)131, "Delta")]
    [InlineData((byte)3, "SystemUpdate")]  [InlineData((byte)200, "Unknown(200)")]
    public void ContentMetaTypeStrings_KnownAndUnknown(byte v, string expected)
        => Assert.Equal(expected, ContentMetaTypeStrings.From(v));

    [Theory]
    [InlineData((byte)0, "Meta")] [InlineData((byte)1, "Program")] [InlineData((byte)3, "Control")]
    [InlineData((byte)6, "DeltaFragment")] [InlineData((byte)9, "Unknown(9)")]
    public void ContentTypeStrings_KnownAndUnknown(byte v, string expected)
        => Assert.Equal(expected, ContentTypeStrings.From(v));

    // ── TitlesDb ─────────────────────────────────────────────────────────────────────
    [Fact]
    public void TitlesDb_LoadAndLookup_metadataAndCaseAndPrefixTolerance()
    {
        var json = """
        {
          "0100abcd00000000": { "name":"Game A", "developer":"DevA", "publisher":"PubA", "region":"JP",
                                "category":["Action","RPG"], "iconUrl":"http://i/a.png" },
          "0100ffff00000000": { "name":"Game B", "category":[] }
        }
        """;
        var db = TitlesDb.Load(WriteJson(json));
        Assert.Equal(2, db.Count);

        var a = db.Lookup("0100abcd00000000");
        Assert.NotNull(a);
        Assert.Equal("Game A", a!.Name);
        Assert.Equal("DevA", a.Developer);
        Assert.Equal("PubA", a.Publisher);
        Assert.Equal("JP", a.Region);
        Assert.Equal("Action, RPG", a.Genre);          // array joined with ", "

        Assert.NotNull(db.Lookup("0100ABCD00000000")); // case-insensitive (full id is upper)
        Assert.NotNull(db.Lookup("0100abcd00000000E000")); // 16-hex prefix fallback (base+ext id form)
        Assert.Null(db.Lookup("0100deadbeef0000"));    // miss
        Assert.Null(db.Lookup(null));                  // null / blank guard
        Assert.Null(db.Lookup("   "));

        var b = db.Lookup("0100ffff00000000");         // empty category → Genre null, name kept
        Assert.Equal("Game B", b!.Name);
        Assert.Null(b.Genre);
    }

    [Fact]
    public void TitlesDb_ExtractsTitleKeysOnlyWhenBothHex32()
    {
        var json = """
        {
          "0100a10000000000": { "name":"WithKey", "key":"00112233445566778899aabbccddeeff",
                                "rightsId":"0123456789abcdef0123456789abcdef" },
          "0100a20000000000": { "name":"KeyOnly", "key":"00112233445566778899aabbccddeeff" },
          "0100a30000000000": { "name":"ShortKey", "key":"00aa", "rightsId":"0123456789abcdef0123456789abcdef" }
        }
        """;
        var db = TitlesDb.Load(WriteJson(json));
        Assert.Equal(3, db.Count);
        // Only the entry with BOTH a 32-hex key AND a 32-hex rights-id contributes a title key.
        Assert.Equal(1, db.TitleKeyCount);
        Assert.True(db.TitleKeys.ContainsKey("0123456789ABCDEF0123456789ABCDEF"));   // upper-cased rid
        var key = db.TitleKeys["0123456789ABCDEF0123456789ABCDEF"];
        Assert.Equal(16, key.Length);
        Assert.Equal(0x00, key[0]);
        Assert.Equal(0xff, key[15]);
    }

    [Fact]
    public void TitlesDb_NonObjectRootAndBlankValues_DontThrow()
    {
        var arr = TitlesDb.Load(WriteJson("[1,2,3]"));          // root not an object → empty
        Assert.Equal(0, arr.Count);
        var mixed = TitlesDb.Load(WriteJson("""{ "0100000000000001": 5, "0100000000000002": {"name":""} }"""));
        Assert.Equal(1, mixed.Count);                            // scalar value "5" is skipped (not an object)
        Assert.Null(mixed.Lookup("0100000000000001"));           // non-object entry not stored
        Assert.Null(mixed.Lookup("0100000000000002")!.Name);     // present but empty name → null (NullIfEmpty)
    }

    [Fact]
    public void TitlesDb_MissingFile_ThrowsLoadFailure_SurfaceIsTryGet()
    {
        // Load() itself surfaces IO/parse errors (the server's TryGetTitlesDb swallows them). Assert it throws
        // rather than silently returning empty, so a bad configured path is diagnosable upstream.
        Assert.ThrowsAny<Exception>(() => TitlesDb.Load(Path.Combine(Path.GetTempPath(), "nscb-no-such-db-" + Guid.NewGuid().ToString("N") + ".json")));
    }
}
