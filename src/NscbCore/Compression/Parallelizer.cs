namespace NscbCore.Compression;

/// <summary>
/// Small bounded-parallel helper used to compress several NCA→NCZ sections at once.
/// Falls back to a plain sequential loop when parallelism is 1 (or fewer), which keeps
/// single-threaded behaviour byte-identical to the serial path.
/// </summary>
public static class Parallelizer
{
    /// <summary>
    /// Run <paramref name="body"/> for every index of <paramref name="count"/> items using at
    /// most <paramref name="parallelism"/> concurrent workers. The body must be thread-safe.
    /// </summary>
    public static void ForIndex(int count, int parallelism, Action<int> body, CancellationToken ct = default)
    {
        if (parallelism <= 1)
        {
            for (int i = 0; i < count; i++)
            {
                ct.ThrowIfCancellationRequested();
                body(i);
            }
            return;
        }

        var opts = new ParallelOptions { MaxDegreeOfParallelism = parallelism, CancellationToken = ct };
        Parallel.For(0, count, opts, body);
    }

    /// <summary>Clamp a user-supplied parallelism hint to a sane 1..N range (capped by CPU count).</summary>
    public static int Clamp(int requested, int itemCount)
    {
        int max = Math.Max(1, Environment.ProcessorCount);
        return Math.Clamp(requested, 1, Math.Max(1, Math.Min(max, itemCount)));
    }
}
