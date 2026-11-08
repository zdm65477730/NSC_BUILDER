using NscbCore.Packaging;
using Xunit;

namespace NscbCore.Tests;

/// <summary>
/// Coverage for the pure option/default resolution + safe file naming extracted from the server job
/// runner (Program.cs delegates here). Tests the clamp / override / fallback / CPU-cap rules that were
/// previously only exercised by manual server smoke tests.
/// </summary>
public class RunOptionsTests
{
    private static Dictionary<string, string> Opt(string k, string v) => new() { [k] = v };

    // ── ResolveLevel ───────────────────────────────────────────────────────────────
    [Fact]
    public void ResolveLevel_optionOverridesSettings()
        => Assert.Equal(7, RunOptions.ResolveLevel(Opt("level", "7"), 17));

    [Theory]
    [InlineData("30", 22)]   // above max → clamp 22
    [InlineData("-5", 1)]    // below min → clamp 1
    [InlineData("0", 1)]
    [InlineData("22", 22)]
    [InlineData("abc", 17)]  // non-numeric option → fall back to settings
    public void ResolveLevel_optionClampedOrFallback(string optVal, int expected)
        => Assert.Equal(expected, RunOptions.ResolveLevel(Opt("level", optVal), 17));

    [Theory]
    [InlineData(17, 17)] [InlineData(99, 22)] [InlineData(0, 1)] [InlineData(-3, 1)]
    public void ResolveLevel_settingsClamped_whenNoOption(int settings, int expected)
        => Assert.Equal(expected, RunOptions.ResolveLevel(new Dictionary<string, string>(), settings));

    [Fact]
    public void ResolveLevel_nullOptions_usesSettings()
        => Assert.Equal(12, RunOptions.ResolveLevel(null!, 12));

    // ── ResolveThreads ─────────────────────────────────────────────────────────────
    [Fact]
    public void ResolveThreads_optionUnderCap()
        => Assert.Equal(4, RunOptions.ResolveThreads(Opt("parallel", "4"), 24, cpuCap: 8));

    [Fact]
    public void ResolveThreads_cappedToCpu()
        => Assert.Equal(2, RunOptions.ResolveThreads(Opt("parallel", "4"), 24, cpuCap: 2));

    [Fact]
    public void ResolveThreads_noOption_usesSettingsCappedToCpu()
        => Assert.Equal(8, RunOptions.ResolveThreads(new Dictionary<string, string>(), 24, cpuCap: 8));

    [Fact]
    public void ResolveThreads_hugeOption_clampedTo64ThenCpu()
        => Assert.Equal(16, RunOptions.ResolveThreads(Opt("parallel", "1000"), 1, cpuCap: 16));

    [Theory]
    [InlineData(0, 8, 1)]   // settings 0 → clamp 1
    [InlineData(-4, 8, 1)]
    public void ResolveThreads_settingsFloor(int settings, int cap, int expected)
        => Assert.Equal(expected, RunOptions.ResolveThreads(new Dictionary<string, string>(), settings, cap));

    [Fact]
    public void ResolveThreads_cpuCapBelowOne_isFlooredToOne()
        => Assert.Equal(1, RunOptions.ResolveThreads(Opt("parallel", "8"), 8, cpuCap: 0));

    // ── ResolveRsv ─────────────────────────────────────────────────────────────────
    [Fact]
    public void ResolveRsv_parsesOrZero()
    {
        Assert.Equal(131072u, RunOptions.ResolveRsv(Opt("rsv", "131072")));
        Assert.Equal(0u, RunOptions.ResolveRsv(new Dictionary<string, string>()));
        Assert.Equal(0u, RunOptions.ResolveRsv(Opt("rsv", "not-a-number")));
        Assert.Equal(0u, RunOptions.ResolveRsv(null!));
    }

    // ── SafeFileName ───────────────────────────────────────────────────────────────
    [Fact]
    public void SafeFileName_replacesInvalidCharsAndCollapsesSpaces()
        // '/' is invalid on BOTH Windows and Linux, so this assertion is platform-independent
        // (':'/'\'/'*' are invalid only on Windows, so we avoid them here).
        => Assert.Equal("a b c", RunOptions.SafeFileName("a//b   /c"));

    [Fact]
    public void SafeFileName_trimsAndDropsTrailingDots()
    {
        Assert.Equal("Game", RunOptions.SafeFileName("  Game  "));
        Assert.Equal("Game", RunOptions.SafeFileName("Game..."));
    }

    [Theory]
    [InlineData("")]
    [InlineData("   ")]
    public void SafeFileName_blankFallsBack(string input)
        => Assert.Equal("XCI", RunOptions.SafeFileName(input));

    [Fact]
    public void SafeFileName_capsLength()
        => Assert.Equal(180, RunOptions.SafeFileName(new string('x', 500)).Length);

    [Fact]
    public void SafeFileName_customFallbackAndMaxLen()
    {
        Assert.Equal("NA", RunOptions.SafeFileName("  ", "NA"));
        Assert.Equal(5, RunOptions.SafeFileName("abcdefghij", "NA", maxLen: 5).Length);
    }

    [Fact]
    public void SafeFileName_keepsUnicode()
        => Assert.Equal("あ漢 字", RunOptions.SafeFileName("あ漢 字"));

    // ── ThreadBudget (auto CPU sharing across concurrent jobs) ─────────────────────
    [Theory]
    [InlineData(8, 1, 8)]    // lone job → whole CPU (no regression for single-file compress)
    [InlineData(8, 2, 4)]    // batch of 2 → half each
    [InlineData(8, 3, 2)]    // 8/3 integer-divides to 2
    [InlineData(8, 8, 1)]
    [InlineData(8, 16, 1)]   // never below 1
    [InlineData(24, 8, 3)]
    [InlineData(1, 4, 1)]    // 1 core → always 1
    [InlineData(4, 0, 4)]    // activeJobs 0 (startup guard) → full CPU
    public void ThreadBudget_splitsCpuAcrossJobs(int cores, int active, int expected)
        => Assert.Equal(expected, RunOptions.ThreadBudget(cores, active));

    [Theory]
    [InlineData(0, 1)] [InlineData(-4, 1)] [InlineData(0, 8)] [InlineData(16, -2)]
    public void ThreadBudget_neverBelowOne(int cores, int active)
        => Assert.True(RunOptions.ThreadBudget(cores, active) >= 1);

    [Fact]
    public void ThreadBudget_loneJobEqualsCores()
        => Assert.Equal(32, RunOptions.ThreadBudget(32, 1));
}
