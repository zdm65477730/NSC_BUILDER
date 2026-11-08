namespace NscbCore.Progress;

/// <summary>
/// Pure progress-bar math shared by the server job runner (Program.cs delegates here, so the tested
/// arithmetic is exactly what runs): mapping streamed bytes into a [lo,hi] band, splitting a set of
/// per-item sizes into contiguous weighted sub-bands, and the adaptive (EMA) stage weighting for the
/// 3-phase merge. All functions are side-effect free and unit-testable.
/// </summary>
public static class ProgressBand
{
    /// <summary>Map accumulated bytes into [lo,hi] monotonically: <c>lo</c> at 0 bytes, <c>hi</c> once
    /// estBytes is reached, never overshooting hi. estBytes &lt;= 0 → lo.</summary>
    public static int Percent(long acc, long estBytes, int lo, int hi)
    {
        if (estBytes <= 0) return lo;
        int frac = (int)Math.Min((long)(hi - lo), (long)(hi - lo) * acc / estBytes);
        return lo + frac;
    }

    /// <summary>Contiguous sub-band of one item given a running prefix over size-weighted work:
    /// <c>[lo0 + span*before/total, lo0 + span*(before+itemSize)/total]</c> where span = hi1-lo0.
    /// total &lt;= 0 is treated as 1 (no divide-by-zero). Mirrors per-file / per-input band splitting.</summary>
    public static (int lo, int hi) SliceBand(long before, long itemSize, long total, int lo0, int hi1)
    {
        if (total <= 0) total = 1;
        long span = hi1 - lo0;
        int lo = lo0 + (int)(span * before / total);
        int hi = lo0 + (int)(span * (before + itemSize) / total);
        return (lo, hi);
    }

    /// <summary>Three-phase (decompress / merge / recompress) band edges from per-phase ms-per-byte weights.
    /// b1 = end of decompress, b2 = end of merge; each phase is clamped to keep at least 1% and to leave a
    /// recompress tail, so an extreme learned weight can never collapse a phase to zero width.</summary>
    public static (int b1, int b2) AdaptiveEdges(double wDecomp, double wMerge, double wRecomp)
    {
        double wsum = wDecomp + wMerge + wRecomp;
        if (wsum <= 0) wsum = 1;
        int b1 = Math.Clamp((int)(99 * wDecomp / wsum), 2, 90);
        int b2 = Math.Clamp(b1 + (int)(99 * wMerge / wsum), b1 + 1, 97);
        return (b1, b2);
    }

    /// <summary>Exponential moving average that favours history slightly (old 60% / sample 40%).</summary>
    public static double Ema(double old, double sample) => old * 0.6 + sample * 0.4;
}
