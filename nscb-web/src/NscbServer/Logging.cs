using System.Collections.Concurrent;

namespace NscbServer;

/// <summary>
/// Dependency-free leveled logger that mirrors every entry to the console and to a daily
/// rolling file under <c>{BaseDirectory}/logs/nscb-YYYY-MM-DD.log</c>. Used for job lifecycle,
/// failures and API errors so a shipped single-file build leaves an on-disk trail.
/// </summary>
public static class NSLog
{
    public enum Level { Info, Warn, Error }

    /// <summary>Controls whether logs are written to the on-disk file. When false, console + the in‑app
    /// “日志” view still work; only the file is skipped. Driven by the settings toggle.</summary>
    public static volatile bool Enabled = false;   // file logging is OFF by default; turned on via the settings toggle

    private static readonly object _gate = new();
    private static readonly ConcurrentQueue<string> _recent = new();
    private const int RecentCap = 500;
    private static string? _dir;
    private static bool _dirReady;

    public static void Init(string? baseDir)
    {
        // Only record the target path; the folder/file are created lazily once Enabled is true.
        // Logging is OFF by default, so a fresh install creates no "logs" folder.
        _dir = Path.Combine(baseDir ?? AppContext.BaseDirectory, "logs");
    }

    /// <summary>Turn file logging on/off from the settings toggle. Turning ON creates the logs folder
    /// immediately (and writes a banner line); while OFF nothing is written and no folder is created.</summary>
    public static void SetEnabled(bool on)
    {
        Enabled = on;
        if (!on || _dir is null) return;
        try
        {
            Directory.CreateDirectory(_dir); _dirReady = true;
            Info($"File logging enabled → {Path.Combine(_dir, "nscb-<date>.log")}");
        }
        catch { /* read-only location: console/in-app only */ }
    }

    public static void Info(string msg)  => Write(Level.Info, msg);
    public static void Warn(string msg)  => Write(Level.Warn, msg);
    public static void Error(string msg) => Write(Level.Error, msg);
    public static void Error(string msg, Exception ex)
        => Write(Level.Error, $"{msg}: {ex.GetType().Name}: {ex.Message}");

    /// <summary>Most recent log lines (newest last), for the /api/logs endpoint.</summary>
    public static IReadOnlyList<string> Recent(int max) => _recent.ToArray()[^Math.Min(max, _recent.Count)..];

    private static void Write(Level lvl, string msg)
    {
        var line = $"{DateTime.Now:yyyy-MM-dd HH:mm:ss} [{lvl.ToString().ToUpperInvariant()}] {msg}";
        lock (_gate)
        {
            _recent.Enqueue(line);
            while (_recent.Count > RecentCap) _recent.TryDequeue(out _);
        }
        var color = lvl switch { Level.Error => ConsoleColor.Red, Level.Warn => ConsoleColor.Yellow, _ => ConsoleColor.Gray };
        var saved = Console.ForegroundColor;
        try { Console.ForegroundColor = color; Console.WriteLine(line); }
        finally { Console.ForegroundColor = saved; }

        if (!Enabled || _dir is null) return;   // file logging off (default) → console + in-app view only, no folder
        try
        {
            if (!_dirReady) { Directory.CreateDirectory(_dir); _dirReady = true; }   // create lazily on first enabled write
            var path = Path.Combine(_dir, $"nscb-{DateTime.Now:yyyy-MM-dd}.log");
            lock (_gate) File.AppendAllText(path, line + Environment.NewLine);
        }
        catch { /* disk error: console already has it */ }
    }
}
