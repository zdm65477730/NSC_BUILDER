using NscbCore.Info;
using NscbCore.Renaming;
using Xunit;

namespace NscbCore.Tests;

public class FileNamerTests
{
    private static ContainerFileInfo Info(string name, string id, ulong ver, string type) => new()
    {
        TitleName = name, TitleId = id, TitleVersionRaw = ver, TitleType = type, Format = "nsp",
    };

    [Fact]
    public void BuildFileName_NsxSample_MatchesNscbFormat()
    {
        var i = Info("OBAKEIDORO 2 Chase & Seek", "010044d027c72800", 262144, "Patch");
        string n = FileNamer.BuildFileName(i, "whatever.nsp", new RenameOptions(true, true, true));
        Assert.Equal("OBAKEIDORO 2 Chase & Seek [010044D027C72800][v262144][UPD].nsp", n);
    }

    [Fact]
    public void BuildFileName_BaseApplication_ZeroVersion_IncludesV0()
    {
        var i = Info("My Game", "010044d027c72000", 0, "Application");
        string n = FileNamer.BuildFileName(i, "x.nsp", new RenameOptions(true, true, true));
        Assert.Equal("My Game [010044D027C72000][v0][Base].nsp", n);
    }

    [Fact]
    public void BuildFileName_SanitizesIllegalChars()
    {
        var i = Info("A: B/C*D?", "0100000000000000", 5, "AddOnContent");
        string n = FileNamer.BuildFileName(i, "x.nsz", new RenameOptions(true, true, true));
        Assert.Equal("A BCD [0100000000000000][v5][DLC].nsz", n);
    }

    [Fact]
    public void BuildFileName_OptionToggles_DropParts()
    {
        var i = Info("Game", "0100abcd00000000", 12, "Patch");
        Assert.Equal("Game [0100ABCD00000000][UPD].nsp",
            FileNamer.BuildFileName(i, "x.nsp", new RenameOptions(false, true, true)));
        Assert.Equal("Game [0100ABCD00000000][v12].nsp",
            FileNamer.BuildFileName(i, "x.nsp", new RenameOptions(true, false, true)));
    }

    [Fact]
    public void BuildFileName_FallsBackToStrippedStem_WhenNoContentName()
    {
        var i = Info("", "0100abcd00000000", 3, "Application");
        string n = FileNamer.BuildFileName(i, "Old Name [0100ABCD00000000][v1][Base].nsp", new RenameOptions(true, true, true));
        Assert.Equal("Old Name [0100ABCD00000000][v3][Base].nsp", n);
    }

    [Fact]
    public void Sanitize_StripsControlAndTrailingDots()
    {
        Assert.Equal("clean name", FileNamer.Sanitize("clean  name..."));
        Assert.Equal("ab", FileNamer.Sanitize("a\u0000b"));
    }

    [Fact]
    public void TypeTag_MapsContentMetaTypes()
    {
        Assert.Equal("Base", FileNamer.TypeTag("Application"));
        Assert.Equal("UPD", FileNamer.TypeTag("Patch"));
        Assert.Equal("UPD", FileNamer.TypeTag("Delta"));
        Assert.Equal("DLC", FileNamer.TypeTag("AddOnContent"));
        Assert.Equal("", FileNamer.TypeTag("SystemProgram"));
    }

    [Fact]
    public void StripTags_RemovesTrailingGroups()
    {
        Assert.Equal("Old Name", FileNamer.StripTags("Old Name [0100ABCD00000000][v1][Base]"));
    }

    // Regression guard for the C# trap that caused a real bug: RenameOptions is a readonly record struct, so
    // `new RenameOptions()` calls the parameterless ctor that ZEROES the bools (it does NOT apply the `= true`
    // parameter defaults). The naming code must therefore pass explicit trues, else name/version/type vanish.
    [Fact]
    public void RenameOptions_DefaultStruct_ZeroesBools_NotTheParameterDefaults()
    {
        var d = new RenameOptions();
        Assert.False(d.IncludeVersion);
        Assert.False(d.IncludeTypeTag);
        Assert.False(d.UseContentName);
        // …whereas the explicit form carries the intended flags:
        var on = new RenameOptions(true, true, true);
        Assert.True(on.IncludeVersion && on.IncludeTypeTag && on.UseContentName);
    }

    [Fact]
    public void BuildFileName_AllFalseOptions_StripsContentNameVersionType()
    {
        var i = Info("My Game", "0100abcd00000000", 12, "Patch");
        // With the (buggy) all-false default, only the filename stem + title id survive.
        Assert.Equal("old [0100ABCD00000000].nsp", FileNamer.BuildFileName(i, "old.nsp", new RenameOptions()));
        // With the correct explicit flags, the full content-derived name is produced.
        Assert.Equal("My Game [0100ABCD00000000][v12][UPD].nsp", FileNamer.BuildFileName(i, "old.nsp", new RenameOptions(true, true, true)));
    }
}
