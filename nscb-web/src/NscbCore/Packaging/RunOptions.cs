using System.IO;

namespace NscbCore.Packaging;

/// <summary>
/// Pure resolution of job options / defaults — compress level, thread count (CPU-capped), target RSV —
/// and safe output-file naming. Extracted verbatim from the server job runner (Program.cs) so the
/// clamp / override / fallback rules are unit-testable without IO or a running server. Program.cs
/// delegates here, so the tested logic is exactly what runs.
/// </summary>
public static class RunOptions
{
    /// <summary>zstd level: per-job <c>level</c> option (clamped 1–22) if present, else the settings default (clamped).</summary>
    public static int ResolveLevel(IReadOnlyDictionary<string, string>? options, int settingsLevel)
        => options is not null && options.TryGetValue("level", out var v) && int.TryParse(v, out var l)
            ? Math.Clamp(l, 1, 22)
            : Math.Clamp(settingsLevel, 1, 22);

    /// <summary>
    /// Thread/parallelism: per-job <c>parallel</c> option (clamped 1–64) else the settings value (clamped 1–64),
    /// then capped to the CPU count so file-parallelism × per-file MT never oversubscribes, whatever the user set.
    /// </summary>
    public static int ResolveThreads(IReadOnlyDictionary<string, string>? options, int settingsThreads, int cpuCap)
    {
        int want = options is not null && options.TryGetValue("parallel", out var v) && int.TryParse(v, out var p)
            ? Math.Clamp(p, 1, 64)
            : Math.Clamp(settingsThreads, 1, 64);
        return Math.Min(want, Math.Max(1, cpuCap));
    }

    /// <summary>
    /// Auto CPU budget for a single job: the per‑job thread ceiling when N jobs share the machine, so the
    /// total across concurrent jobs stays ≈ cores (no oversubscription). cores / activeJobs, floored to 1.
    /// A lone job (activeJobs ≤ 1) gets the whole CPU; a batch of N gets ≈ cores/N each. Guards cores/active
    /// inputs ≥ 1 so it can never return 0.
    /// </summary>
    public static int ThreadBudget(int cores, int activeJobs)
        => Math.Max(1, Math.Max(1, cores) / Math.Max(1, activeJobs));

    /// <summary>Target RSV (u32) from the <c>rsv</c> option, or 0 when absent/invalid.</summary>
    public static uint ResolveRsv(IReadOnlyDictionary<string, string>? options)
        => options is not null && options.TryGetValue("rsv", out var v) && uint.TryParse(v, out var r) ? r : 0;

    /// <summary>
    /// Sanitize a string into a safe file name: invalid chars → spaces, collapse whitespace, trim, drop
    /// trailing dots, cap length; fall back when the result is blank.
    /// </summary>
    public static string SafeFileName(string s, string fallback = "XCI", int maxLen = 180)
    {
        foreach (var c in Path.GetInvalidFileNameChars()) s = s.Replace(c, ' ');
        s = System.Text.RegularExpressions.Regex.Replace(s, @"\s+", " ").Trim().TrimEnd('.');
        if (string.IsNullOrWhiteSpace(s)) return fallback;
        return s.Length > maxLen ? s[..maxLen] : s;
    }
}
