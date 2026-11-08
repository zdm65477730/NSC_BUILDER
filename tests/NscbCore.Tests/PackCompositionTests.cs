using NscbCore.Packaging;
using Xunit;

namespace NscbCore.Tests;

/// <summary>
/// Regression coverage for the single source of truth that classifies title content-meta types into the
/// pack/split composition (G/U/D) and renders "(1G+1U+1D)". This is what JobRunner.BuildPackName and
/// TitleSplitter.Composition now delegate to — so a DLC is always counted as D (the bug where pack names
/// stopped at "(1G+1U)" is locked here).
/// </summary>
public class PackCompositionTests
{
    [Fact]
    public void Classify_BaseUpdateDlc_IsOneEach()
        => Assert.Equal((1, 1, 1), PackComposition.Classify(new string?[] { "Application", "Patch", "AddOnContent" }));

    [Theory]
    [InlineData("Application", 1, 0, 0)]
    [InlineData("Patch", 0, 1, 0)]
    [InlineData("Delta", 0, 1, 0)]
    [InlineData("SystemUpdate", 0, 1, 0)]
    [InlineData("AddOnContent", 0, 0, 1)]
    [InlineData(null, 1, 0, 0)]          // unknown → treated as base game
    [InlineData("SystemProgram", 1, 0, 0)]
    public void Classify_SingleType(string? t, int g, int u, int d)
        => Assert.Equal((g, u, d), PackComposition.Classify(new[] { t }));

    [Fact]
    public void Classify_MultipleGamesUpdatesDlcs()
        => Assert.Equal((2, 3, 4), PackComposition.Classify(new string?[]
        {
            "Application", "Application",
            "Patch", "Delta", "SystemUpdate",
            "AddOnContent", "AddOnContent", "AddOnContent", "AddOnContent",
        }));

    [Fact]
    public void Tag_BaseUpdateDlc()
        => Assert.Equal("(1G+1U+1D)", PackComposition.Tag(new string?[] { "Application", "Patch", "AddOnContent" }));

    [Fact]
    public void Tag_BaseOnly_Is1G()
        => Assert.Equal("(1G)", PackComposition.Tag(new string?[] { "Application" }));

    [Fact]
    public void Tag_Empty_FallsBackTo1G()
        => Assert.Equal("(1G)", PackComposition.Tag(Array.Empty<string?>()));

    [Fact]
    public void Tag_MultiDlc()
        => Assert.Equal("(1G+1U+2D)", PackComposition.Tag(new string?[] { "Application", "Patch", "AddOnContent", "AddOnContent" }));

    // OutputFormat.CompositionTag (leading-space variant used for output file names) must also render D,
    // and stay blank for a single title.
    [Fact]
    public void OutputFormatTag_BaseUpdateDlc_HasD()
        => Assert.Equal(" (1G+1U+1D)", OutputFormat.CompositionTag(1, 1, 1));

    [Fact]
    public void OutputFormatTag_SingleTitle_Blank()
        => Assert.Equal("", OutputFormat.CompositionTag(1, 0, 0));

    // ── edge cases: collections with NO base game present ─────────────────────────
    [Fact]
    public void Classify_UpdatePlusDlc_NoBase()
        => Assert.Equal((0, 1, 1), PackComposition.Classify(new string?[] { "Patch", "AddOnContent" }));

    [Fact]
    public void Classify_AllDlc_NoBaseNoUpdate()
        => Assert.Equal((0, 0, 3), PackComposition.Classify(new string?[] { "AddOnContent", "AddOnContent", "AddOnContent" }));

    [Fact]
    public void Classify_OnlyDeltaUpdate()
        => Assert.Equal((0, 1, 0), PackComposition.Classify(new string?[] { "Delta" }));

    [Fact]
    public void Classify_Empty_IsAllZero()
        => Assert.Equal((0, 0, 0), PackComposition.Classify(Array.Empty<string?>()));

    [Fact]
    public void Tag_DlcOnly_Is1D()
        => Assert.Equal("(1D)", PackComposition.Tag(new string?[] { "AddOnContent" }));

    [Fact]
    public void Tag_UpdateOnly_Is1U()
        => Assert.Equal("(1U)", PackComposition.Tag(new string?[] { "Patch" }));

    [Fact]
    public void Tag_UpdateAndDlc_NoBase_OmitsGameSegment()
        => Assert.Equal("(1U+1D)", PackComposition.Tag(new string?[] { "Patch", "AddOnContent" }));

    [Fact]
    public void Tag_MultipleDlcOnly()
        => Assert.Equal("(3D)", PackComposition.Tag(new string?[] { "AddOnContent", "AddOnContent", "AddOnContent" }));

    [Fact]
    public void Tag_UnclassifiedCountAsGames_TwoNulls_Is2G()
        => Assert.Equal("(2G)", PackComposition.Tag(new string?[] { null, null }));   // null/unrecognized → base games
}
