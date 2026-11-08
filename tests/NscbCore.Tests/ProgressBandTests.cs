using NscbCore.Progress;
using Xunit;

namespace NscbCore.Tests;

/// <summary>
/// Coverage for the pure progress-band math extracted from the server job runner (Program.cs delegates
/// here): byte→[lo,hi] percentage mapping, size-weighted contiguous sub-band slicing, adaptive 3-phase
/// band edges, and the EMA smoothing. Previously only exercised indirectly via manual runs.
/// </summary>
public class ProgressBandTests
{
    // ── Percent ──────────────────────────────────────────────────────────────────────
    [Theory]
    [InlineData(0L, 100L, 0, 99, 0)]        // start → lo
    [InlineData(50L, 100L, 0, 99, 49)]      // half → 49 (99*50/100)
    [InlineData(100L, 100L, 0, 99, 99)]     // done → hi
    [InlineData(250L, 100L, 0, 99, 99)]     // overshoot clamps to hi
    [InlineData(10L, 10L, 3, 78, 78)]       // offset band, fully consumed
    [InlineData(0L, 0L, 3, 78, 3)]          // estBytes 0 → lo (no divide-by-zero)
    [InlineData(5L, -1L, 5, 90, 5)]         // negative est → lo
    public void Percent_MapsAccumulatedBytesMonotonically(long acc, long est, int lo, int hi, int expected)
        => Assert.Equal(expected, ProgressBand.Percent(acc, est, lo, hi));

    [Fact]
    public void Percent_NeverOvershootsHi()
    {
        for (long acc = 0; acc <= 1000; acc += 7)
            Assert.InRange(ProgressBand.Percent(acc, 100, 10, 60), 10, 60);
    }

    // ── SliceBand ─────────────────────────────────────────────────────────────────────
    [Fact]
    public void SliceBand_EqualSizes_AreContiguousAndCoverRange()
    {
        // two 100-byte items over [0,99]
        var (a0, a1) = ProgressBand.SliceBand(0, 100, 200, 0, 99);      // item 0
        var (b0, b1) = ProgressBand.SliceBand(100, 100, 200, 0, 99);    // item 1 (prefix = 100)
        Assert.Equal(0, a0);
        Assert.Equal(a1, b0);            // contiguous: item0's hi == item1's lo
        Assert.Equal(99, b1);            // last reaches hi1
    }

    [Fact]
    public void SliceBand_MatchesRunConvertFormula()
    {
        // old inline: lo = before*99/totSz ; hi = (before+sz)*99/totSz
        long before = 300, sz = 150, tot = 600;
        var (lo, hi) = ProgressBand.SliceBand(before, sz, tot, 0, 99);
        Assert.Equal((int)(before * 99 / tot), lo);
        Assert.Equal((int)((before + sz) * 99 / tot), hi);
    }

    [Fact]
    public void SliceBand_PackPreprocess_UsesOffset3To78()
    {
        // old inline: lo = 3 + 75*before/cwtot
        long before = 0, cw = 50, cwtot = 100;
        var (lo, hi) = ProgressBand.SliceBand(before, cw, cwtot, 3, 78);
        Assert.Equal(3 + (int)(75 * before / cwtot), lo);
        Assert.Equal(3 + (int)(75 * (before + cw) / cwtot), hi);
    }

    [Fact]
    public void SliceBand_TotalZero_DoesNotThrow()
    {
        var (lo, hi) = ProgressBand.SliceBand(0, 0, 0, 10, 50);
        Assert.Equal(10, lo);
        Assert.Equal(10, hi);   // item size 0 → collapses to lo
    }

    // ── AdaptiveEdges ───────────────────────────────────────────────────────────────────
    [Fact]
    public void AdaptiveEdges_DefaultWeights_MatchInlineComputation()
    {
        // reproduce the pre-extraction inline math with the typical defaults
        double wd = 3.0e-5, wm = 2.0e-5, wr = 5.0e-5, wsum = wd + wm + wr;
        int expB1 = Math.Clamp((int)(99 * wd / wsum), 2, 90);
        int expB2 = Math.Clamp(expB1 + (int)(99 * wm / wsum), expB1 + 1, 97);
        var (b1, b2) = ProgressBand.AdaptiveEdges(wd, wm, wr);
        Assert.Equal(expB1, b1);
        Assert.Equal(expB2, b2);
        Assert.Equal((29, 48), (b1, b2));   // 0.3 / 0.2 / 0.5 split of 99
    }

    [Theory]
    [InlineData(1e9, 1, 1)]        // decomp dominates
    [InlineData(1, 1, 1e9)]        // recomp dominates
    [InlineData(0, 0, 0)]          // all zero → guarded
    [InlineData(1, 1, 1)]
    public void AdaptiveEdges_Invariants_Hold(double wd, double wm, double wr)
    {
        var (b1, b2) = ProgressBand.AdaptiveEdges(wd, wm, wr);
        Assert.InRange(b1, 2, 90);
        Assert.True(b2 > b1, "merge end must exceed decomp end");
        Assert.InRange(b2, 3, 97);
    }

    // ── Ema ────────────────────────────────────────────────────────────────────────────
    [Fact]
    public void Ema_WeightsHistorySixtySampleForty()
    {
        Assert.Equal(14.0, ProgressBand.Ema(10, 20), 10);          // 10*0.6 + 20*0.4
        Assert.Equal(20.0, ProgressBand.Ema(20, 20), 10);          // stable when sample == current
    }
}
