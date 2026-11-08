using System.Text.Json;
using System.Text.Json.Serialization;
using NscbCore.Formats;
using NscbCore.Info;
using NscbCore.Keys;
using NscbCore.Nsz;
using NscbCore.Packaging;
using NscbCore.Patching;
using NscbCore.Splitting;
using NscbJobs;
using NscbServer;
using System.Net.Http;
using Microsoft.AspNetCore.StaticFiles;
#if WINDOWS
using Microsoft.Web.WebView2.Core;
using Microsoft.Web.WebView2.WinForms;
using System.Drawing;
using System.Windows.Forms;
#endif

var builder = WebApplication.CreateBuilder(new WebApplicationOptions
{
    Args = args,
    // Serve wwwroot from the executable's directory (single-file publish layout).
    ContentRootPath = AppContext.BaseDirectory,
});

// Listen only on localhost. Pick a free port so a second/leftover instance never fails to bind.
int port = FirstFreePort(54321, 16);
builder.WebHost.UseUrls($"http://127.0.0.1:{port}");

builder.Services.AddSingleton<AppSettings>();
builder.Services.AddSingleton<SseHub>();
// Serialize enums as names (JobType/JobStatus) so the UI can read status/type.
builder.Services.ConfigureHttpJsonOptions(o => o.SerializerOptions.Converters.Add(new JsonStringEnumConverter()));
builder.Services.AddSingleton(sp =>
{
    var hub = sp.GetRequiredService<SseHub>();
    var settings = sp.GetRequiredService<AppSettings>();
    // Let the runner broadcast live progress (bars move; long jobs like Database no longer look frozen).
    JobRunner.PublishProgress = job => hub.Publish(new JobEvent(job.Id, "progress", job.ProgressPct, null, job.Status));
    return new JobEngine(hub.Publish, async (job, ct) =>
    {
        // Track how many jobs are running right now so GetParallel can split the CPU budget across them.
        System.Threading.Interlocked.Increment(ref settings.ActiveJobs);
        try { await JobRunner.Run(job, ct, settings); }
        finally { System.Threading.Interlocked.Decrement(ref settings.ActiveJobs); }
    }, Math.Clamp(settings.Workers, 1, 64));
});

builder.WebHost.ConfigureKestrel(k => k.ListenLocalhost(port));

var app = builder.Build();

// Load settings from disk if available.
var settings = app.Services.GetRequiredService<AppSettings>();
settings.Load();
NSLog.Init(AppContext.BaseDirectory);
NSLog.SetEnabled(settings.LogsEnabled);   // logs folder/file are created only when the option is ON (default off)
NSLog.Info("NSC_BUILDER web server initializing.");

// Serve the SPA from embedded wwwroot resources (single-file friendly).
var webRoot = new NscbServer.WebRootFileProvider(typeof(Program).Assembly);
// Map the site root to index.html (the embedded provider reports the root as a non-directory, so
// UseDefaultFiles alone won't rewrite '/'; this guarantees the app loads at http://127.0.0.1:54321/).
app.Use(async (ctx, next) => { if (ctx.Request.Path == "/") ctx.Request.Path = "/index.html"; await next(); });
app.UseStaticFiles(new StaticFileOptions
{
    FileProvider = webRoot,
    ContentTypeProvider = MetroContentTypes(),
    // A local tool shipping an embedded SPA: never let the webview/browser cache stale UI.
    OnPrepareResponse = c => c.Context.Response.Headers["Cache-Control"] = "no-store, no-cache, must-revalidate",
});

// ── Browse ────────────────────────────────────────────────────────────────────────

app.MapGet("/api/browse", (string? path, string? all, string? recurse) =>
{
    bool listAll = !string.IsNullOrEmpty(all);
    try
    {
        // No path → list drive roots (Windows) / "/" so the picker is usable immediately.
        if (string.IsNullOrWhiteSpace(path))
            return Results.Ok(new BrowseResult("", null, BrowseRoots()));

        var dir = new DirectoryInfo(path);
        if (!dir.Exists) return Results.Ok(new BrowseResult(path, null, Array.Empty<BrowseEntry>()));
        settings.LastBrowseDir = path;

        // Recursive mode (used by "add folder"): return every supported game file under the tree so files
        // in SUBFOLDERS are included too. Loop-guarded + access-tolerant; returns files only (no folders).
        if (!string.IsNullOrEmpty(recurse))
            return Results.Ok(new BrowseResult(path, dir.Parent?.FullName, RecurseGameFiles(dir)));

        var folders = SafeEnumerate(() => dir.EnumerateDirectories())
            .Where(d => !d.Attributes.HasFlag(FileAttributes.Hidden))
            .Select(d => new BrowseEntry(d.Name, d.FullName, true, 0));

        var files = SafeEnumerate(() => dir.EnumerateFiles())
            .Where(f => listAll || IsSupportedFile(f.Name))
            .Select(f => new BrowseEntry(f.Name, f.FullName, false, SafeLength(f)));

        string? parent = dir.Parent?.FullName;   // null at a drive/filesystem root
        return Results.Ok(new BrowseResult(path, parent, folders.Concat(files)));
    }
    catch (Exception ex) { return ApiError(ex); }
});

// Enumerate tolerating per-directory access errors (Windows ACLs / reparse points).
static IEnumerable<T> SafeEnumerate<T>(Func<IEnumerable<T>> f)
{
    var list = new List<T>();
    try { foreach (var x in f()) list.Add(x); } catch { /* Access denied / etc → stop, return what we got */ }
    return list;
}
static long SafeLength(FileInfo f) { try { return f.Length; } catch { return 0; } }
static IEnumerable<BrowseEntry> BrowseRoots()
{
    var roots = new List<BrowseEntry>();
    foreach (var d in DriveInfo.GetDrives())
    {
        try { if (d.IsReady) roots.Add(new BrowseEntry(string.IsNullOrEmpty(d.VolumeLabel) ? d.Name : $"{d.Name[..2]} ({d.VolumeLabel})", d.RootDirectory.FullName, true, 0)); }
        catch { /* not ready (empty optical/removable) → skip */ }
    }
    if (roots.Count == 0) roots.Add(new BrowseEntry("/", "/", true, 0));   // Unix fallback
    return roots;
}
// Depth-first walk of subfolders collecting supported game files (loop-guarded via visited dirs,
// access-tolerant per directory, skips hidden dirs). Used by recursive browse for "add folder".
static IEnumerable<BrowseEntry> RecurseGameFiles(DirectoryInfo root)
{
    var outList = new List<BrowseEntry>();
    var seen = new HashSet<string>(StringComparer.Ordinal);
    var stack = new Stack<DirectoryInfo>(); stack.Push(root);
    while (stack.Count > 0)
    {
        var d = stack.Pop();
        try { if (!seen.Add(d.FullName)) continue; } catch { continue; }
        foreach (var f in SafeEnumerate(() => d.EnumerateFiles()))
            if (IsSupportedFile(f.Name)) outList.Add(new BrowseEntry(f.Name, f.FullName, false, SafeLength(f)));
        foreach (var sub in SafeEnumerate(() => d.EnumerateDirectories()))
        { try { if (!sub.Attributes.HasFlag(FileAttributes.Hidden)) stack.Push(sub); } catch { } }
    }
    return outList;
}

// ── Info ──────────────────────────────────────────────────────────────────────────

app.MapGet("/api/info", (string path, AppSettings cfg) =>
{
    try
    {
        var keys = cfg.TryLoadKeys();
        var svc = keys is not null ? new TitleInfoService(keys) : null;
        if (svc is null) return Results.BadRequest(new { error = "Keys not available for full info." });
        var file = JobRunner.InfoWithDb(path, cfg);
        return Results.Ok(file);
    }
    catch (Exception ex) { return ApiError(ex); }
});

app.MapGet("/api/info/icon", (string path, AppSettings cfg) =>
{
    try
    {
        var keys = cfg.TryLoadKeys();
        if (keys is null) return Results.NotFound();
        var svc = new TitleInfoService(keys);
        var icon = svc.GetIcon(path);
        if (icon is null) return Results.NotFound();
        return Results.File(icon.Value.Data, icon.Value.ContentType);
    }
    catch { return Results.NotFound(); }
});

// Synchronous NPDM facet (Metro info panel's “Npdm” tab).
app.MapGet("/api/npdm", (string path, AppSettings cfg) =>
{
    try
    {
        var keys = cfg.TryLoadKeys();
        if (keys is null) return Results.BadRequest(new { error = "Keys not available." });
        var (npdm, reason) = NpdmInfoReader.Inspect(path, keys);
        if (npdm is not null) return Results.Ok(npdm);
        string msg;
        if (reason == "cannot-open")
        {
            // The Program NCA exists but can't be decrypted → this game's title key is not in the loaded key set.
            // Be precise about the titles.json state so a user who ALREADY configured one isn't just told to “update it”.
            var tdb = cfg.TryGetTitlesDb();
            msg = "读取 main.npdm 需要该游戏的 title key，但未能从其自带 ticket + prod.keys 推导出来。"
                + "请确认 prod.keys 覆盖该游戏固件（对应 master_key），且容器带有可解的零售 ticket。"
                + "（个人/设备绑定票券不支持；titles.json 仅提供元数据，不再用于取密钥。）";
        }
        else msg = "该包内未找到 Program NCA 的 main.npdm（可能是纯 update / DLC 包，不含程序 NCA）。";
        return Results.NotFound(new { error = msg });
    }
    catch (Exception ex) { return ApiError(ex); }
});

// Synchronous NCA-hash verification (校验 facet). Returns { ok, total, checked, failures }.
app.MapGet("/api/verify", (string path, AppSettings cfg) =>
{
    try
    {
        var keys = cfg.TryLoadKeys();
        if (keys is null) return Results.BadRequest(new { error = "Keys not available for verify." });
        var vr = NscbCore.Verify.Verifier.VerifyContainer(path, keys);
        return Results.Ok(new { ok = vr.Ok, total = vr.TotalFiles, @checked = vr.CheckedFiles, failures = vr.Failures, files = vr.Files });
    }
    catch (Exception ex) { return ApiError(ex); }
});

// Preview the NSCB-style pack name for the current selection so the UI can auto-fill the output field.
// Body: { "inputs": [file|folder, ...] }. Returns { name } (without the .xci extension).
app.MapPost("/api/packname", async (HttpContext ctx, AppSettings cfg) =>
{
    List<string> inputs = new();
    try
    {
        using var rd = new StreamReader(ctx.Request.Body);
        using var jd = JsonDocument.Parse(await rd.ReadToEndAsync());
        if (jd.RootElement.TryGetProperty("inputs", out var ar) && ar.ValueKind == JsonValueKind.Array)
            foreach (var p in ar.EnumerateArray()) if (p.ValueKind == JsonValueKind.String) inputs.Add(p.GetString()!);
    }
    catch { }
    var files = JobRunner.ExpandPackInputs(inputs);
    string? name = files.Count > 0 ? JobRunner.BuildPackName(files, cfg.TryLoadKeys(), cfg) : null;
    return Results.Ok(new { name = name ?? "", ext = files.Count > 0 ? JobRunner.PackExtension(files) : ".xci" });
});

// Download/refresh the eShop titles.json metadata DB. Body: { "url": optional, "path": optional save }.
app.MapPost("/api/titlesdb/fetch", async (HttpContext ctx, AppSettings cfg) =>
{
    string url = "https://tinfoil.media/repo/db/titles.json";
    string? savePath = null; bool explicitPath = false;
    try
    {
        using var rd = new StreamReader(ctx.Request.Body);
        var body = await rd.ReadToEndAsync();
        if (!string.IsNullOrWhiteSpace(body))
        {
            using var jd = JsonDocument.Parse(body);
            if (jd.RootElement.TryGetProperty("url", out var u) && u.ValueKind == JsonValueKind.String) url = u.GetString()!;
            if (jd.RootElement.TryGetProperty("path", out var pp) && pp.ValueKind == JsonValueKind.String) { savePath = pp.GetString(); explicitPath = true; }
        }
    }
    catch { /* body optional */ }
    savePath ??= cfg.TitlesDbPath ?? Path.Combine(AppContext.BaseDirectory, "titles.json");
    savePath = NscbCore.Keys.NscbKeys.ExpandPath(savePath!);
    HttpResponseMessage? resp = null;
    try
    {
        using var http = new HttpClient { Timeout = TimeSpan.FromSeconds(180) };   // bounded: a stalled server yields a clear timeout, not an endless hang
        try { resp = await http.GetAsync(url); }
        catch (TaskCanceledException) { return Results.Json(new { code = "timeout", error = "download timed out" }, statusCode: StatusCodes.Status504GatewayTimeout); }
        catch (HttpRequestException hex) { return Results.Json(new { code = "net", error = hex.Message }, statusCode: StatusCodes.Status502BadGateway); }
        if (!resp.IsSuccessStatusCode)
            return Results.Json(new { code = "http", status = (int)resp.StatusCode, error = "HTTP " + (int)resp.StatusCode }, statusCode: StatusCodes.Status502BadGateway);
        byte[] bytes;
        try { bytes = await resp.Content.ReadAsByteArrayAsync(); }
        catch (Exception iex) { return Results.Json(new { code = "net", error = iex.Message }, statusCode: StatusCodes.Status502BadGateway); }
        // Sanity: titles.json must be JSON, not an empty body or an HTML error page served with 200.
        var head = System.Text.Encoding.UTF8.GetString(bytes, 0, Math.Min(bytes.Length, 512)).TrimStart();
        if (bytes.Length == 0 || !(head.StartsWith('{') || head.StartsWith('[')))
            return Results.Json(new { code = "badcontent", error = "invalid titles.json" }, statusCode: StatusCodes.Status502BadGateway);
        var di = Path.GetDirectoryName(savePath); if (di is not null) Directory.CreateDirectory(di);
        File.WriteAllBytes(savePath, bytes);
        // Honour the “留空=按场景默认” rule: only record TitlesDbPath when the user picked a custom location.
        // A default save lands beside the exe, which ResolveTitlesDbPath auto-discovers, so leave the field empty.
        if (explicitPath) cfg.TitlesDbPath = savePath;
        cfg.InvalidateTitlesDb(); cfg.InvalidateKeys(); cfg.TitlesUpdatedAt = DateTime.UtcNow.ToString("o"); cfg.Save();
        var db = cfg.TryGetTitlesDb();
        NSLog.Info($"titles.json fetched: {bytes.LongLength} bytes → {savePath} ({db?.Count ?? 0} titles)");
        return Results.Ok(new { savedPath = savePath, bytes = (long)bytes.LongLength, count = db?.Count ?? 0 });
    }
    catch (Exception ex) { return ApiError(ex); }
    finally { resp?.Dispose(); }
});

// title.keys was removed as a key source: rights-id title keys now come from titles.json (merged into the
// key set) and from each container's own ticket (TicketTitleKeys, using prod.keys master keys), matching
// NSCB/NUT/NSGManager. Personal/device-bound tickets are out of scope. See /api/titlesdb/fetch above.

// ── Jobs ──────────────────────────────────────────────────────────────────────────

app.MapPost("/api/jobs", (CreateJobRequest req, JobEngine engine) =>
{
    if (req.Inputs is null || req.Inputs.Length == 0)
        return Results.BadRequest(new { error = "No inputs." });

    // Reject unknown job types instead of silently coercing to Info.
    if (!Enum.TryParse<JobType>(req.Type, ignoreCase: true, out var type) || !Enum.IsDefined(type))
        return Results.BadRequest(new { error = $"Unknown job type: {req.Type}" });

    // Fail fast with a clear message if an input path does not exist (job inputs are existing sources).
    foreach (var input in req.Inputs)
        if (string.IsNullOrWhiteSpace(input) || (!File.Exists(input) && !Directory.Exists(input)))
            return Results.BadRequest(new { error = $"Input not found: {input}" });

    var job = engine.Submit(type, req.Inputs, req.Options);
    NSLog.Info($"[job {job.Id}] submitted {type} ({req.Inputs.Length} input(s))");
    return Results.Ok(new { id = job.Id });
});

app.MapGet("/api/jobs", (JobEngine engine) =>
    Results.Ok(engine.Jobs.OrderByDescending(j => j.CreatedAt)));

app.MapGet("/api/jobs/{id}", (string id, JobEngine engine) =>
    engine.GetJob(id) is { } j ? Results.Ok(j) : Results.NotFound());

app.MapDelete("/api/jobs/{id}", (string id, JobEngine engine) =>
    engine.Cancel(id) ? Results.Ok() : Results.NotFound());

// ── SSE ───────────────────────────────────────────────────────────────────────────

app.MapGet("/api/events", async (HttpContext ctx, SseHub hub, CancellationToken ct) =>
{
    ctx.Response.Headers["Content-Type"] = "text/event-stream";
    ctx.Response.Headers["Cache-Control"] = "no-cache";
    ctx.Response.Headers["Connection"] = "keep-alive";

    var tcs = new TaskCompletionSource();
    using var reg = ct.Register(() => tcs.TrySetResult());
    using var sub = hub.Subscribe(async line =>
    {
        try { await ctx.Response.WriteAsync(line, ct); await ctx.Response.Body.FlushAsync(ct); }
        catch { tcs.TrySetResult(); }
    });

    await tcs.Task;
});

// ── Settings ──────────────────────────────────────────────────────────────────────

app.MapGet("/api/settings", () => Results.Ok(settings.PublicView()));

// ── Logs (recent, in-memory; also written to {base}/logs) ─────────────────────────
app.MapGet("/api/logs", (int? limit) =>
    Results.Ok(NSLog.Recent(Math.Clamp(limit ?? 200, 1, 500))));

app.MapPut("/api/settings", async (HttpContext ctx) =>
{
    using var reader = new StreamReader(ctx.Request.Body);
    var json = await reader.ReadToEndAsync();
    // Web JSON options (camelCase + case-insensitive) so the UI's { prodKeysPath, … } actually bind.
    var patch = JsonSerializer.Deserialize<SettingsPatch>(json, new JsonSerializerOptions(JsonSerializerDefaults.Web));
    if (patch is not null) settings.Apply(patch);
    settings.Save();
    // Apply a changed "workers" immediately (grow consumers) so queue concurrency takes effect without restarting.
    try { app.Services.GetRequiredService<JobEngine>().SetConcurrency(Math.Clamp(settings.Workers, 1, 64)); } catch { }
    return Results.Ok(settings.PublicView());
});

// ── Start ─────────────────────────────────────────────────────────────────────────

app.Start();
// Prewarm keys + the (large) titles.json parse off the request path, so the first /api/settings is fast.
_ = System.Threading.Tasks.Task.Run(() => { try { if (app.Services.GetService(typeof(AppSettings)) is AppSettings warm) { warm.TryLoadKeys(); warm.TryGetTitlesDb(); } } catch { } });
string appUrl = $"http://127.0.0.1:{port}";
NSLog.Info($"NSC_BUILDER Web UI → {appUrl}");
bool headless = args.Contains("--no-open") || args.Contains("--headless") || args.Contains("--serve");
if (headless)
{
    // Server only — no window, no browser (for automation / self-testing).
    await app.WaitForShutdownAsync();
}
else if (args.Contains("--browser"))
{
    TryOpenBrowser(appUrl);
    await app.WaitForShutdownAsync();
}
else
{
#if WINDOWS
    // Embed the UI in a native desktop window (WinForms + WebView2 on Windows). Blocks until the user
    // closes it; falls back to the system browser if the webview cannot start (e.g. runtime missing).
    try
    {
        OpenDesktopWindow(appUrl);
    }
    catch (Exception ex)
    {
        NSLog.Info($"Desktop window unavailable ({ex.GetType().Name}); opening browser.");
        TryOpenBrowser(appUrl);
        await app.WaitForShutdownAsync();
    }
    await app.StopAsync();
#else
    // No native window on macOS/Linux (WinForms/WebView2 are Windows-only): run the server and open the
    // UI in the system browser.
    NSLog.Info("Native window is Windows-only; opening the UI in the system browser.");
    TryOpenBrowser(appUrl);
    await app.WaitForShutdownAsync();
#endif
}
NSLog.Info("NSC_BUILDER web server stopped.");

// ── Helpers ───────────────────────────────────────────────────────────────────────

// Unified API error: logs the exception and returns the same { error } envelope every
// endpoint uses, so the client has one shape to render.
// Returns the first bindable localhost TCP port at/after `from` (so a leftover/second instance
// starting the window on a busy 54321 no longer crashes with “connection refused”).
static int FirstFreePort(int from, int tries)
{
    for (int p = from; p < from + tries; p++)
    {
        try { var l = new System.Net.Sockets.TcpListener(System.Net.IPAddress.Loopback, p); l.Start(); l.Stop(); return p; }
        catch { }
    }
    return from;
}

static IResult ApiError(Exception ex)
{
    NSLog.Error("API request failed", ex);
    return Results.Json(new { error = ex.Message }, statusCode: StatusCodes.Status500InternalServerError);
}

static bool IsSupportedFile(string name)
{
    string ext = Path.GetExtension(name).ToLowerInvariant();
    if (ext is ".nsp" or ".nsz" or ".xci" or ".xcz" or ".nca" or ".ncz" or ".zip") return true;
    return NscbCore.Splitting.Fat32Splitter.IsSplitPart(name); // .00 / .01 / …
}

#if WINDOWS
static void OpenDesktopWindow(string url)
{
    // WinForms + WebView2 host: unlike Photino, this exposes the CoreWebView2 so we can receive
    // real OS drag-drop file/folder paths (WebMessageReceived + ICoreWebView2File.Path).
    // Runs on an STA thread with its own message loop (WebView2 requirement).
    string nonceUrl = url.TrimEnd('/') + "/?n=" + Guid.NewGuid().ToString("N")[..8];   // per-launch URL defeats stale cache
    Exception? error = null;
    var thread = new Thread(() =>
    {
        try
        {
            Application.SetHighDpiMode(HighDpiMode.PerMonitorV2);
            Application.EnableVisualStyles();
            Application.SetCompatibleTextRenderingDefault(false);
            using var form = new NscbWindow(nonceUrl);
            Application.Run(form);
        }
        catch (Exception ex) { error = ex; }
    });
    thread.SetApartmentState(ApartmentState.STA);
    thread.IsBackground = true;
    thread.Start();
    thread.Join();                 // block until the window closes
    if (error is not null) throw error;
}
#endif

// File→content-type map covering the metroui icon font + vector assets we embed under wwwroot.
static FileExtensionContentTypeProvider MetroContentTypes()
{
    var p = new FileExtensionContentTypeProvider();
    p.Mappings[".woff"] = "font/woff";
    p.Mappings[".woff2"] = "font/woff2";
    p.Mappings[".ttf"] = "font/ttf";
    p.Mappings[".otf"] = "font/otf";
    p.Mappings[".eot"] = "application/vnd.ms-fontobject";
    p.Mappings[".svg"] = "image/svg+xml";
    p.Mappings[".map"] = "application/json";
    p.Mappings[".json"] = "application/json";
    return p;
}

static void TryOpenBrowser(string url)
{
    try
    {
        if (OperatingSystem.IsWindows())
            System.Diagnostics.Process.Start(new System.Diagnostics.ProcessStartInfo(url) { UseShellExecute = true });
        else if (OperatingSystem.IsLinux())
            System.Diagnostics.Process.Start("xdg-open", url);
        else if (OperatingSystem.IsMacOS())
            System.Diagnostics.Process.Start("open", url);
    }
    catch { /* headless environment */ }
}

// ── DTOs ──────────────────────────────────────────────────────────────────────────

record BrowseEntry(string Name, string Path, bool IsDir, long Size);
record BrowseResult(string Path, string? Parent, IEnumerable<BrowseEntry> Entries);
record CreateJobRequest(string Type, string[]? Inputs, Dictionary<string, string>? Options);

// ── SSE hub ───────────────────────────────────────────────────────────────────────

sealed class SseHub
{
    private readonly List<Func<string, Task>> _subscribers = [];
    private readonly object _lock = new();

    public IDisposable Subscribe(Func<string, Task> handler)
    {
        lock (_lock) _subscribers.Add(handler);
        return new Subscription(this, handler);
    }

    public void Publish(JobEvent evt)
    {
        string json = JsonSerializer.Serialize(evt, new JsonSerializerOptions
        {
            PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
            DefaultIgnoreCondition = JsonIgnoreCondition.WhenWritingNull,
            Converters = { new JsonStringEnumConverter() },
        });
        string line = $"data: {json}\n\n";
        Func<string, Task>[] subs;
        lock (_lock) subs = _subscribers.ToArray();
        foreach (var s in subs) _ = s(line);
    }

    private void Unsubscribe(Func<string, Task> h) { lock (_lock) _subscribers.Remove(h); }
    private sealed class Subscription(SseHub hub, Func<string, Task> h) : IDisposable
    { public void Dispose() => hub.Unsubscribe(h); }
}

// ── App settings ──────────────────────────────────────────────────────────────────

sealed class AppSettings
{
    public string? ProdKeysPath { get; set; }
    public string? OutputDir { get; set; }
    public string? LastBrowseDir { get; set; }
    public string Language { get; set; } = "zh-CN";
    public string Theme { get; set; } = "dark";
    // MODE0 global defaults (per-job options still override these).
    // Workers = how many files/jobs run at once (batch parallelism). CPU-aware default; when >1 the per-file
    // internal threads are auto-shared (cores / runningJobs), so total threads ≈ cores (no oversubscription).
    public int Workers { get; set; } = Math.Max(2, Math.Min(8, Environment.ProcessorCount / 2));
    // Live count of jobs executing right now (JobEngine inc/dec); GetParallel divides the core budget by this so a
    // lone heavy file still uses all cores while a batch shares them. Runtime-only, never persisted.
    [System.Text.Json.Serialization.JsonIgnore] public int ActiveJobs;
    // Thread budget for a compress/decompress job: split across files (file-parallel) AND fed to zstd as internal
    // MT workers per NCA (single-frame). MT is safe + format-compatible, so default to all cores (≈4-5× faster than 1).
    public int CompressThreads { get; set; } = Math.Max(1, Environment.ProcessorCount);
    public int CompressLevel { get; set; } = 17;
    // Which page to show on launch: "info" | "jobs" | any operation id (e.g. "CompressNsz").
    public string DefaultView { get; set; } = "info";
    // Path to the eShop titles.json metadata DB (name/dev/publisher/genre; NOT keys).
    public string? TitlesDbPath { get; set; }
    // Auto-download titles.json on launch when it is missing/stale; + when it was last updated (ISO UTC).
    public bool TitlesAutoUpdate { get; set; } = false;
    public string? TitlesUpdatedAt { get; set; }
    // Master switch for file logging (console/in-app view always work). Default OFF so a fresh install creates no "logs" folder.
    public bool LogsEnabled { get; set; } = false;

    private string SettingsPath =>
        Path.Combine(AppContext.BaseDirectory, "settings.json");

    private NscbKeys? _cachedKeys;
    private string? _cachedKeysPath;

    // On Windows unify to '\'; after ~ / %VAR% / $VAR expansion, so the settings never mix
    // "D:/Tools/x" and "D:\Tools\x". On macOS/Linux '/' is already native and '\' is a LEGAL filename
    // character, so we must NOT convert it (that would corrupt real Unix paths). Relative paths are not
    // resolved against CWD. Applied on both Load and Apply so a mixed Windows settings.json self-heals.
    private static string? NormPath(string? p)
    {
        if (string.IsNullOrWhiteSpace(p)) return p;
        p = NscbCore.Keys.NscbKeys.ExpandPath(p);
        return Path.DirectorySeparatorChar == '\\' ? p.Replace('/', '\\') : p;
    }

    public void Load()
    {
        // First run (no settings.json): persist the defaults so a fresh install gets CompressThreads = all cores
        // (MT single-frame is safe + format-compatible) written to disk, not just held in memory.
        if (!File.Exists(SettingsPath)) { Save(); return; }
        try
        {
            var s = JsonSerializer.Deserialize<AppSettings>(File.ReadAllText(SettingsPath));
            if (s is null) return;
            ProdKeysPath = NormPath(s.ProdKeysPath);
            OutputDir = NormPath(s.OutputDir);
            Language = s.Language;
            Theme = s.Theme;
            Workers = s.Workers > 0 ? Math.Clamp(s.Workers, 1, 64) : Math.Max(2, Math.Min(8, Environment.ProcessorCount / 2));
            CompressThreads = s.CompressThreads > 0 ? Math.Clamp(s.CompressThreads, 1, 64) : Math.Max(1, Environment.ProcessorCount);
            CompressLevel = s.CompressLevel > 0 ? Math.Clamp(s.CompressLevel, 1, 22) : 17;
            DefaultView = string.IsNullOrWhiteSpace(s.DefaultView) ? "info" : s.DefaultView;
            TitlesDbPath = NormPath(s.TitlesDbPath);
            TitlesAutoUpdate = s.TitlesAutoUpdate;
            TitlesUpdatedAt = s.TitlesUpdatedAt;
            LogsEnabled = s.LogsEnabled;
        }
        catch { }
    }

    public void Save()
    {
        try { File.WriteAllText(SettingsPath,
            JsonSerializer.Serialize(this, new JsonSerializerOptions { WriteIndented = true })); }
        catch { }
    }

    public void Apply(SettingsPatch p)
    {
        if (p.ProdKeysPath is not null) ProdKeysPath = NormPath(p.ProdKeysPath);
        if (p.OutputDir is not null) OutputDir = NormPath(p.OutputDir);
        if (p.Language is not null) Language = p.Language;
        if (p.Theme is not null) Theme = p.Theme;
        if (p.Workers is not null) Workers = Math.Clamp(p.Workers.Value, 1, 64);
        if (p.CompressThreads is not null) CompressThreads = Math.Clamp(p.CompressThreads.Value, 1, 64);
        if (p.CompressLevel is not null) CompressLevel = Math.Clamp(p.CompressLevel.Value, 1, 22);
        if (!string.IsNullOrWhiteSpace(p.DefaultView)) DefaultView = p.DefaultView;
        if (p.TitlesDbPath is not null) { TitlesDbPath = NormPath(p.TitlesDbPath); _titlesDb = null; }
        if (p.TitlesAutoUpdate is not null) TitlesAutoUpdate = p.TitlesAutoUpdate.Value;
        if (p.LogsEnabled is not null) { LogsEnabled = p.LogsEnabled.Value; NSLog.SetEnabled(LogsEnabled); }
        _cachedKeys = null; // invalidate
    }

    public object PublicView()
    {
        var k = TryLoadKeys();
        return new
        {
            prodKeysPath = ProdKeysPath,
            resolvedProdKeys = k?.ProdKeysPath,
            outputDir = OutputDir,
            language = Language,
            theme = Theme,
            workers = Workers,
            recommendedWorkers = Math.Max(2, Math.Min(8, Environment.ProcessorCount / 2)),   // "推荐" one-click for concurrent files
            compressThreads = CompressThreads,
            recommendedThreads = Math.Max(1, Environment.ProcessorCount),   // Settings “推荐=核心数” one-click button
            compressLevel = CompressLevel,
            defaultView = DefaultView,
            titlesDbPath = TitlesDbPath,
            titlesDbLoaded = TryGetTitlesDb() is not null,
            titlesDbCount = _titlesDb?.Count ?? 0,
            titlesAutoUpdate = TitlesAutoUpdate,
            logsEnabled = LogsEnabled,
            titlesUpdatedAt = TitlesUpdatedAt,
            keysLoaded = k is not null,
            keysError = _lastKeyError,
            detectedHint = "把 prod.keys 放在程序同目录，或在此填写绝对路径（支持 ~ 与 %VAR%）",
        };
    }

    private string? _lastKeyError;
    private TitlesDb? _titlesDb;
    private string? _titlesDbKey;
    public string? LastTitlesDbError { get; private set; }
    public void InvalidateTitlesDb() { _titlesDb = null; _titlesDbKey = null; JobRunner.InvalidateInfoCache(); }
    public void InvalidateKeys() { _cachedKeys = null; _cachedKeysPath = null; JobRunner.InvalidateInfoCache(); }

    /// <summary>Load & cache the eShop titles.json metadata DB (configured path, else titles.json beside the exe).</summary>
    public TitlesDb? TryGetTitlesDb()
    {
        string? p = ResolveTitlesDbPath();
        if (p is null) { _titlesDb = null; _titlesDbKey = null; return null; }
        if (_titlesDb is not null && _titlesDbKey == p) return _titlesDb;
        try { _titlesDb = TitlesDb.Load(p); _titlesDbKey = p; LastTitlesDbError = null; NSLog.Info($"TitlesDb loaded {_titlesDb.Count} titles from {p}"); return _titlesDb; }
        catch (Exception ex) { LastTitlesDbError = ex.Message; NSLog.Info("titles db load failed: " + ex.Message); return null; }
    }
    private string? ResolveTitlesDbPath()
    {
        if (!string.IsNullOrWhiteSpace(TitlesDbPath)) { var e = NscbCore.Keys.NscbKeys.ExpandPath(TitlesDbPath); if (File.Exists(e)) return e; }
        foreach (var cand in new[] { Path.Combine(AppContext.BaseDirectory, "titles.json"), Path.Combine(AppContext.BaseDirectory, "Titles", "titles.json") })
            if (File.Exists(cand)) return cand;
        return null;
    }

    public NscbKeys? TryLoadKeys()
    {
        // Always attempt load: NscbKeys expands ~/%VAR%, accepts a folder, and auto-detects prod.keys
        // next to the exe / in .switch — so it works even with no configured path. Null if nothing found.
        string key = ProdKeysPath ?? "";
        if (_cachedKeys is not null && _cachedKeysPath == key)
            return _cachedKeys;
        try
        {
            _cachedKeys = NscbKeys.Load(ProdKeysPath);
            _cachedKeysPath = key; _lastKeyError = null;
            return _cachedKeys;
        }
        catch (Exception ex) { _lastKeyError = ex.Message; NSLog.Info("key load failed: " + ex.Message); return null; }
    }
}

sealed class SettingsPatch
{
    public string? ProdKeysPath { get; set; }
    public string? OutputDir { get; set; }
    public string? Language { get; set; }
    public string? Theme { get; set; }
    public int? Workers { get; set; }
    public int? CompressThreads { get; set; }
    public int? CompressLevel { get; set; }
    public string? DefaultView { get; set; }
    public string? TitlesDbPath { get; set; }
    public bool? TitlesAutoUpdate { get; set; }
    public bool? LogsEnabled { get; set; }
    public string? TitlesUpdatedAt { get; set; }
}

// ── Job runner ────────────────────────────────────────────────────────────────────

static class JobRunner
{
    /// <summary>Set at startup to broadcast a job's progress to the UI (SSE).</summary>
    public static Action<NscbJob>? PublishProgress;

    public static async Task Run(NscbJob job, CancellationToken ct, AppSettings settings)
    {
        var keys = settings.TryLoadKeys();
        // Recover rights-id title keys from each input container's own tickets into the shared KeySet, so
        // packing/convert/etc. can decrypt Program NCAs with prod.keys alone (NSGManager-style; no per-title dump).
        if (keys is not null) foreach (var inp in job.Inputs) { try { NscbCore.Keys.TicketTitleKeys.RegisterFromContainer(keys, inp); } catch { } }
        long total = 0;
        foreach (var f in job.Inputs)
            try { total += new FileInfo(f).Length; } catch { }
        job.BytesTotal = total;
        job.BytesDone = 0; job.ProgressPct = 0;
        job.Sw = System.Diagnostics.Stopwatch.StartNew();   // times each stage
        // Balance the thread budget so batch (files) × per-file zstd MT ≈ the configured thread count, never more:
        // 1 file → all threads on it (MT); K files → split across files, each getting threads/K MT workers.
        int totalThreads = GetParallel(job, settings);
        int filePar = Math.Min(job.Inputs.Count, totalThreads);
        int innerPar = Math.Max(1, totalThreads / Math.Max(1, filePar));

        NSLog.Info($"[job {job.Id}] START {job.Type}");
        try
        {
        await Task.Run(() =>
        {
            // Seed a step label for every job so the text under the progress bar always shows the current
            // action (ops that iterate overwrite it per file/phase). Guarantees all operations report steps.
            if (job.Inputs.Count > 0) Detail(job, 0, job.Inputs.Count, job.Inputs[0]);
            switch (job.Type)
            {
                case JobType.ConvertNspToXci:
                    RunConvert(job, (src, dst, rep, step) => ContainerConverter.NspToXci(src, dst, keys, rep, ct, innerPar), ".xci", ct, filePar, settings);
                    break;
                case JobType.ConvertXciToNsp:
                    RunConvert(job, (src, dst, rep, step) => ContainerConverter.XciToNsp(src, dst, rep, ct, innerPar), ".nsp", ct, filePar, settings);
                    break;
                case JobType.CompressNsz:
                    RunConvert(job, (src, dst, rep, step) => NszConverter.NspToNsz(src, dst, keys!, GetLevel(job, settings), rep, ct, innerPar, step), ".nsz", ct, filePar, settings);
                    break;
                case JobType.CompressXcz:
                    RunConvert(job, (src, dst, rep, step) => NszConverter.XciToXcz(src, dst, keys!, GetLevel(job, settings), rep, ct, innerPar, step), ".xcz", ct, filePar, settings);
                    break;
                case JobType.DecompressNsz:
                    RunConvert(job, (src, dst, rep, step) => NszConverter.NszToNsp(src, dst, rep, ct, innerPar), ".nsp", ct, filePar, settings);
                    break;
                case JobType.DecompressXcz:
                    RunConvert(job, (src, dst, rep, step) => NszConverter.XczToXci(src, dst, rep, ct, innerPar), ".xci", ct, filePar, settings);
                    break;
                case JobType.PatchRsv:
                    RunDowngrade(job, keys, settings, ct);   // combined: lower RSV + keygen to the same target firmware
                    break;
                case JobType.PackXci:
                    RunPack(job, keys, settings, p => Report(job, p), ct);
                    break;
                case JobType.SplitFat32:
                    for (int _mi = 0; _mi < job.Inputs.Count; _mi++)
                    {
                        string src = job.Inputs[_mi];
                        Detail(job, _mi, job.Inputs.Count, src);
                        long parts = Fat32Splitter.Split(src, p => Report(job, p), ct);
                        job.OutputPath = src + ".00";
                        _ = parts;
                    }
                    break;
                case JobType.MergeFat32:
                    for (int _mi = 0; _mi < job.Inputs.Count; _mi++)
                    {
                        string src = job.Inputs[_mi];
                        Detail(job, _mi, job.Inputs.Count, src);
                        // Reconstruct the original name by dropping the trailing ".NN" part suffix.
                        string mergedName = System.Text.RegularExpressions.Regex.Replace(Path.GetFileName(src), @"\.\d{2}$", "");
                        string mOut = OutDir(settings, src);
                        string outp = Path.Combine(mOut, mergedName);
                        Fat32Splitter.Merge(src, outp, p => Report(job, p), ct);
                        job.OutputPath = outp;
                    }
                    break;
                case JobType.SplitTitles:
                    {
                        if (keys is null) throw new InvalidOperationException("Keys required for splitter.");
                        string optOut = job.Options.GetValueOrDefault("outDir") ?? "";
                        string? outDir = string.IsNullOrWhiteSpace(optOut) ? null : optOut;   // null → 整合包dir/[游戏名].原始名
                        Detail(job, 0, job.Inputs.Count, job.Inputs[0]);
                        bool baseAsCard = job.Options.GetValueOrDefault("basecard") == "1";
                        var outputs = NscbCore.Splitting.TitleSplitter.Split(job.Inputs[0], outDir, keys,
                            p => Report(job, p), ct, baseAsCard);
                        job.OutputPath = string.Join(", ", outputs);
                        break;
                    }
                case JobType.Extract:
                    {
                        if (keys is null) throw new InvalidOperationException("Keys required for extract.");
                        string optOut = job.Options.GetValueOrDefault("outDir") ?? "";
                        string outDir = string.IsNullOrWhiteSpace(optOut)
                            ? NscbCore.Splitting.TitleSplitter.DefaultPackageFolder(job.Inputs[0], keys)   // 默认：包所在目录下新建 [游戏名].原始名
                            : optOut;
                        string filterStr = job.Options.GetValueOrDefault("filter") ?? "All";
                        var filter = Enum.TryParse<NscbCore.Extraction.ExtractFilter>(filterStr, true, out var ff) ? ff : NscbCore.Extraction.ExtractFilter.All;
                        Detail(job, 0, job.Inputs.Count, job.Inputs[0]);
                        var outs = NscbCore.Extraction.ContentExtractor.Extract(job.Inputs[0], outDir, keys, filter,
                            p => Report(job, p), ct);
                        job.OutputPath = $"{outs.Count} files -> {outDir}";
                        break;
                    }
                case JobType.GenXml:
                    {
                        if (keys is null) throw new InvalidOperationException("Keys required for xml.");
                        string xml = NscbCore.Xml.CnmtXml.GenerateFromContainer(job.Inputs[0], keys);
                        string dst = Path.ChangeExtension(job.Inputs[0], ".cnmt.xml");
                        File.WriteAllText(dst, xml);
                        job.OutputPath = dst;
                        Report(job, new FileInfo(dst).Length);
                        break;
                    }
                case JobType.Verify:
                    {
                        if (keys is null) throw new InvalidOperationException("Keys required for verify.");
                        var vr = NscbCore.Verify.Verifier.VerifyContainer(job.Inputs[0], keys, ct);
                        job.OutputPath = vr.Ok ? "OK" : $"{vr.Failures.Count} failures";
                        if (!vr.Ok) throw new InvalidOperationException(string.Join("; ", vr.Failures.Take(5)));
                        break;
                    }
                case JobType.TrimXci:
                    {
                        for (int _mi = 0; _mi < job.Inputs.Count; _mi++)
                        {
                            string src = job.Inputs[_mi];
                            Detail(job, _mi, job.Inputs.Count, src);
                            string outp = ContentTaggedPath(job, src, settings.OutputDir, "TRIM", settings);
                            Guarded(outp, () => NscbCore.Xci.XciTrimmer.Trim(src, outp, keys, p => Report(job, p), ct));
                            job.OutputPath = outp;
                        }
                        break;
                    }
                case JobType.SuperTrimXci:
                    {
                        if (keys is null) throw new InvalidOperationException("Keys required for super-trim.");
                        for (int _mi = 0; _mi < job.Inputs.Count; _mi++)
                        {
                            string src = job.Inputs[_mi];
                            Detail(job, _mi, job.Inputs.Count, src);
                            string outp = ContentTaggedPath(job, src, settings.OutputDir, "SUPERT", settings);
                            Guarded(outp, () => NscbCore.Xci.XciTrimmer.SuperTrim(src, outp, keys, p => Report(job, p), ct));
                            job.OutputPath = outp;
                        }
                        break;
                    }
                case JobType.EraseDeltas:
                    {
                        if (keys is null) throw new InvalidOperationException("Keys required for erase-deltas.");
                        for (int _mi = 0; _mi < job.Inputs.Count; _mi++)
                        {
                            string src = job.Inputs[_mi];
                            Detail(job, _mi, job.Inputs.Count, src);
                            string outp = ContentTaggedPath(job, src, settings.OutputDir, "NODELTA", settings);
                            Guarded(outp, () => NscbCore.Xci.XciTrimmer.EraseDeltaFragments(src, outp, keys, p => Report(job, p), ct));
                            job.OutputPath = outp;
                        }
                        break;
                    }
                case JobType.UpdBase:
                    {
                        if (keys is null) throw new InvalidOperationException("Keys required for update merge.");
                        if (job.Inputs.Count < 2) throw new InvalidOperationException("Provide a base plus at least one update.");

                        // upd_base accepts NSP/NSZ/XCI/XCZ for both base and updates. Output format follows the
                        // content precedence (card family if any XCI/XCZ; compressed if any NSZ/XCZ):
                        //   all-NSP→NSP · NSZ(+NSP)→NSZ · XCI(+NSP)→XCI · any XCZ or XCI+NSZ → XCZ.
                        // Merging ALWAYS happens on plaintext NSP (a compressed container can't be merged directly —
                        // the cnmt/Meta hash chain must be rebuilt against the decompressed Program), then re-packaged.
                        foreach (var f0 in job.Inputs)
                        {
                            var k0 = ContainerReader.DetectKind(f0);
                            if (k0 is not (ContainerKind.Nsp or ContainerKind.Nsz or ContainerKind.Xci or ContainerKind.Xcz))
                                throw new InvalidOperationException($"UpdBase inputs must be NSP/NSZ/XCI/XCZ (got {k0}).");
                        }
                        bool allNsp = job.Inputs.All(f => ContainerReader.DetectKind(f) == ContainerKind.Nsp);
                        string ext = MergeTargetExt(job.Inputs);
                        // The merged pack carries the (highest) update's title version, not the base's v0.
                        ulong mergedVer = 0;
                        foreach (var u in job.Inputs.Skip(1)) { try { if (new TitleInfoService(keys).GetFileInfo(u).TitleVersionRaw is ulong uv && uv > mergedVer) mergedVer = uv; } catch { } }
                        string outDir = OutDir(settings, job.Inputs[0]);
                        string contentName = ConvertOutputName(job.Inputs[0], ext, settings, mergedVer == 0 ? null : mergedVer);
                        string stemCn = contentName.EndsWith(ext, StringComparison.OrdinalIgnoreCase) ? contentName[..^ext.Length] : contentName;
                        string outp = Path.Combine(outDir, MakeSafe(stemCn + "[UPDATED]" + ext));
                        bool applyDeltas = job.Options.GetValueOrDefault("applyDeltas") == "1";
                        int n = job.Inputs.Count;

                        try
                        {
                        if (allNsp)  // pure NSP merge — no compression/decompression at all
                        {
                            NscbCore.Packaging.UpdBaseMerger.Merge(job.Inputs[0], job.Inputs.Skip(1).ToList(), outp, keys,
                                Band(job, total, 3, 96, "[1/1] 合并 update → NSP（重建 cnmt/Meta 哈希链）…"), ct, applyDeltas);
                        }
                        else
                        {
                            string tempDir = Path.Combine(Path.GetTempPath(), "nscb_updbase_" + job.Id);
                            Directory.CreateDirectory(tempDir);
                            var temps = new List<string>();
                            try
                            {
                                // Adaptive time-weighted stages: band widths follow each stage's LEARNED ms-per-byte
                                // (EMA across runs); the first run uses typical defaults (~30/20/49). The proxy byte
                                // base = sum of input sizes (known upfront), so predicted stage times are proportional
                                // to their learned rates. Each stage shows "[k/3] 动作"; Phase stays monotonic regardless.
                                long[] insz = new long[n]; long insTot = 0;
                                for (int i = 0; i < n; i++) { try { insz[i] = Math.Max(1, new FileInfo(job.Inputs[i]).Length); } catch { insz[i] = 1; } insTot += insz[i]; }
                                if (insTot <= 0) insTot = 1;
                                long proxy = insTot;
                                double wd = StageRate("upd.decomp", 3.0e-5), wm = StageRate("upd.merge", 2.0e-5), wr = StageRate("upd.recomp", 5.0e-5);
                                var (b1, b2) = NscbCore.Progress.ProgressBand.AdaptiveEdges(wd, wm, wr);   // end of [1/3] decomp, end of [2/3] merge
                                string NspOf(string path, int idx)
                                {
                                    var k = ContainerReader.DetectKind(path);
                                    if (k == ContainerKind.Nsp) return path;
                                    string name = Path.GetFileName(path);
                                    string t = Path.Combine(tempDir, MakeSafe(Path.GetFileNameWithoutExtension(path)) + ".nsp");
                                    temps.Add(t);
                                    long flen = Math.Max(1, new FileInfo(path).Length);
                                    long before = 0; for (int q = 0; q < idx; q++) before += insz[q];
                                    var (lo, hi) = NscbCore.Progress.ProgressBand.SliceBand(before, flen, insTot, 0, b1); int mid = (lo + hi) / 2;
                                    if (k == ContainerKind.Nsz)
                                        NszConverter.NszToNsp(path, t, Band(job, flen, lo, hi, $"[1/3] 解压输入 {idx + 1}/{n}：{name}"), ct);
                                    else if (k == ContainerKind.Xci)
                                        ContainerConverter.XciToNsp(path, t, Band(job, flen, lo, hi, $"[1/3] 转换输入 {idx + 1}/{n}：{name}"), ct);
                                    else // Xcz → XCI → NSP
                                    {
                                        string xci = Path.Combine(tempDir, MakeSafe(Path.GetFileNameWithoutExtension(path)) + ".xci");
                                        temps.Add(xci);
                                        NszConverter.XczToXci(path, xci, Band(job, flen, lo, mid, $"[1/3] 解压 XCZ {idx + 1}/{n}：{name}"), ct);
                                        ContainerConverter.XciToNsp(xci, t, Band(job, flen, mid, hi, $"[1/3] 转 XCI→NSP {idx + 1}/{n}：{name}"), ct);
                                    }
                                    return t;
                                }
                                var swd = System.Diagnostics.Stopwatch.StartNew();
                                string baseNsp = NspOf(job.Inputs[0], 0);
                                var updNsp = new List<string>();
                                for (int i = 1; i < n; i++) updNsp.Add(NspOf(job.Inputs[i], i));
                                swd.Stop(); LearnStageRate("upd.decomp", proxy, swd.Elapsed.TotalMilliseconds);
                                long msize = Math.Max(1, new FileInfo(baseNsp).Length);
                                string merged = Path.Combine(tempDir, "merged.nsp");
                                var swm = System.Diagnostics.Stopwatch.StartNew();
                                NscbCore.Packaging.UpdBaseMerger.Merge(baseNsp, updNsp, merged, keys,
                                    Band(job, msize, b1, b2, "[2/3] 合并 update → NSP（重建 cnmt/Meta 哈希链）…"), ct, applyDeltas);
                                swm.Stop(); LearnStageRate("upd.merge", proxy, swm.Elapsed.TotalMilliseconds);
                                int threads = GetParallel(job, settings), level = GetLevel(job, settings);
                                long mout = Math.Max(1, new FileInfo(merged).Length);
                                var swr = System.Diagnostics.Stopwatch.StartNew();
                                if (ext == ".nsz")
                                    NszConverter.NspToNsz(merged, outp, keys!, level, Band(job, mout, b2, 99, $"[3/3] 重新压缩为 NSZ（等级 {level}／线程 {threads}，大文件可能较久）…"), ct, threads);
                                else if (ext == ".xci")
                                    ContainerConverter.NspToXci(merged, outp, keys, Band(job, mout, b2, 99, "[3/3] 封装为 XCI…"), ct, threads);
                                else // .xcz
                                {
                                    int bmid = b2 + (99 - b2) / 2;
                                    string xci = Path.Combine(tempDir, "merged.xci"); temps.Add(xci);
                                    ContainerConverter.NspToXci(merged, xci, keys, Band(job, mout, b2, bmid, "[3/3] 先封装为 XCI…"), ct, threads);
                                    long xlen = Math.Max(1, new FileInfo(xci).Length);
                                    NszConverter.XciToXcz(xci, outp, keys!, level, Band(job, xlen, bmid, 99, $"[3/3] 再压缩为 XCZ（等级 {level}／线程 {threads}，可能较久）…"), ct, threads);
                                }
                                swr.Stop(); LearnStageRate("upd.recomp", proxy, swr.Elapsed.TotalMilliseconds);
                            }
                            finally { foreach (var t in temps) { try { File.Delete(t); } catch { } } try { Directory.Delete(tempDir, true); } catch { } }
                        }
                        }
                        catch { try { if (File.Exists(outp)) File.Delete(outp); } catch { } throw; }   // never leave a partial merged output on failure/cancel
                        // Merging rewrites the Meta NCA header (0x208/0x240/0x280 fall inside the 0x200–0x400 range
                        // covered by the fixed-key RSA Signature1) → that signature is necessarily invalidated and
                        // stricter tools (NSGManager) will flag "not original ROM". Content SHA256 still passes and
                        // standard installers (Tinfoil/DBI/Awoo) do not check the header signature.
                        try { NSLog.Warn($"[job {job.Id}] 合并已重建 Meta：头部固定密钥签名(Signature1)必然失效（内容 SHA256 校验仍通过；Tinfoil/DBI/Awoo 安装不受影响）。") ; } catch { }
                        job.OutputPath = outp;
                        break;
                    }
                case JobType.Database:
                    {
                        if (keys is null) throw new InvalidOperationException("Keys required for database export.");
                        if (job.Inputs.Count == 0) throw new InvalidOperationException("Provide files or folders to scan.");
                        string fmt = job.Options.GetValueOrDefault("format") ?? "csv";
                        string ext = fmt.ToLowerInvariant() switch { "json" => ".json", "html" => ".html", "tsv" => ".tsv", _ => ".csv" };
                        string src0 = job.Inputs[0];
                        string baseName = Path.GetFileName(src0.TrimEnd(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar, '/', '\\'));
                        if (string.IsNullOrWhiteSpace(baseName)) baseName = "database";
                        string? dbOut = job.Options.GetValueOrDefault("outDir");
                        string outDir = !string.IsNullOrWhiteSpace(dbOut) ? NscbCore.Keys.NscbKeys.ExpandPath(dbOut!)
                            : (!string.IsNullOrWhiteSpace(settings.OutputDir) ? OutDir(settings, src0)
                               : (Directory.Exists(src0) ? src0 : Path.GetDirectoryName(src0) ?? "."));
                        string outp = Path.Combine(outDir, baseName + ".db" + ext);
                        Directory.CreateDirectory(outDir);
                        File.WriteAllText(outp, NscbCore.Info.DatabaseExporter.Export(job.Inputs, fmt, keys,
                            (done, total) => { job.BytesTotal = total; job.BytesDone = done; job.ProgressPct = total > 0 ? (int)Math.Min(100, done * 100 / total) : 0; job.Detail = $"扫描 {done}/{total}"; JobRunner.PublishProgress?.Invoke(job); }, ct));
                        job.OutputPath = outp;
                        break;
                    }
                case JobType.Rename:
                    {
                        if (keys is null) throw new InvalidOperationException("Keys required for rename.");
                        if (job.Inputs.Count == 0) throw new InvalidOperationException("Provide files or folders to rename.");
                        bool apply = job.Options.GetValueOrDefault("apply", "1") == "1";
                        var opt = new NscbCore.Renaming.RenameOptions(
                            IncludeVersion: job.Options.GetValueOrDefault("version", "1") == "1",
                            IncludeTypeTag: job.Options.GetValueOrDefault("typetag", "1") == "1",
                            UseContentName: job.Options.GetValueOrDefault("contentname", "1") == "1");
                        string? outDir = job.Options.GetValueOrDefault("outDir");
                        var res = NscbCore.Renaming.FileRenamer.Rename(job.Inputs, keys, outDir, opt, apply, ct);
                        foreach (var r in res) if (r.Error is not null) throw new InvalidOperationException($"Failed to rename '{r.OldPath}': {r.Error}");
                        int done = res.Count(r => r.Applied);
                        job.OutputPath = apply
                            ? $"{done}/{res.Count} renamed"
                            : $"dry-run: {res.Count} files (e.g. {System.IO.Path.GetFileName(res.Count > 0 ? res[0].NewPath : "")})";
                        break;
                    }
                case JobType.RelinkAccount:
                    {
                        for (int _mi = 0; _mi < job.Inputs.Count; _mi++)
                        {
                            string src = job.Inputs[_mi];
                            Detail(job, _mi, job.Inputs.Count, src);
                            string outp = ContentTaggedPath(job, src, settings.OutputDir, "REMLINK", settings);
                            int tcount = 0;
                            Guarded(outp, () => tcount = NscbCore.Patching.TicketAccountPatcher.PatchContainer(src, outp, ct).Count);
                            job.OutputPath = $"{tcount} ticket(s) -> {outp}";
                            Report(job, new FileInfo(outp).Length);
                        }
                        break;
                    }
                case JobType.ReadNpdm:
                    {
                        if (keys is null) throw new InvalidOperationException("Keys required for NPDM read.");
                        var npdm = NscbCore.Info.NpdmInfoReader.ReadFromContainer(job.Inputs[0], keys)
                                   ?? throw new InvalidOperationException("No Program NCA / main.npdm found.");
                        string dst = Path.ChangeExtension(job.Inputs[0], ".npdm.json");
                        File.WriteAllText(dst, System.Text.Json.JsonSerializer.Serialize(npdm,
                            new System.Text.Json.JsonSerializerOptions { WriteIndented = true }));
                        job.OutputPath = dst;
                        break;
                    }
                case JobType.JoinFile:
                    {
                        string outp = NscbCore.Joiner.FileJoiner.Join(job.Inputs[0],
                            job.Options.GetValueOrDefault("outputPath"), ct);
                        job.OutputPath = outp;
                        break;
                    }
                case JobType.SetCgame:
                case JobType.SetEshop:
                    {
                        if (keys is null) throw new InvalidOperationException("Keys required for header rewrite.");
                        var dist = job.Type == JobType.SetCgame
                            ? NscbCore.Patching.NcaDistribution.GameCard
                            : NscbCore.Patching.NcaDistribution.Download;
                        for (int _mi = 0; _mi < job.Inputs.Count; _mi++)
                        {
                            string src = job.Inputs[_mi];
                            Detail(job, _mi, job.Inputs.Count, src);
                            string outp = ContentTaggedPath(job, src, settings.OutputDir,
                                job.Type == JobType.SetCgame ? "CGAME" : "ESHOP", settings);
                            int n = 0;
                            Guarded(outp, () => n = NscbCore.Patching.ContainerPatcher.SetDistribution(src, outp, keys, dist, b => Report(job, b), ct));
                            job.OutputPath = $"{outp} ({n} NCA headers → {dist})";
                        }
                        break;
                    }
                case JobType.Restore:
                    {
                        if (keys is null) throw new InvalidOperationException("Keys required for restore.");
                        for (int _mi = 0; _mi < job.Inputs.Count; _mi++)
                        {
                            string src = job.Inputs[_mi];
                            Detail(job, _mi, job.Inputs.Count, src);
                            string outp = ContentTaggedPath(job, src, settings.OutputDir, "RESTORE", settings);
                            (int changed, int valid) rv = (0, 0);
                            Guarded(outp, () => rv = NscbCore.Patching.ContainerPatcher.Restore(src, outp, keys, b => Report(job, b), ct));
                            job.OutputPath = $"{outp} ({rv.changed} header(s) restored, {rv.valid} sig-valid)";
                        }
                        break;
                    }
                case JobType.SetCnmtTitleId:
                case JobType.SetCnmtVersion:
                    {
                        if (keys is null) throw new InvalidOperationException("Keys required for cnmt rewrite.");
                        string val = job.Options.GetValueOrDefault("value")
                                     ?? throw new InvalidOperationException("Missing 'value' option.");
                        for (int _mi = 0; _mi < job.Inputs.Count; _mi++)
                        {
                            string src = job.Inputs[_mi];
                            Detail(job, _mi, job.Inputs.Count, src);
                            string outp = ContentTaggedPath(job, src, settings.OutputDir,
                                job.Type == JobType.SetCnmtTitleId ? "CNMTID" : "CNMTVER", settings);
                            Guarded(outp, () =>
                            {
                                if (job.Type == JobType.SetCnmtTitleId)
                                {
                                    ulong tid = Convert.ToUInt64(val.StartsWith("0x", StringComparison.OrdinalIgnoreCase) ? val[2..] : val, 16);
                                    NscbCore.Patching.ContainerPatcher.SetCnmtTitleId(src, outp, keys, tid, b => Report(job, b), ct);
                                }
                                else
                                {
                                    uint ver = val.StartsWith("0x", StringComparison.OrdinalIgnoreCase)
                                        ? Convert.ToUInt32(val[2..], 16)
                                        : uint.Parse(val);
                                    NscbCore.Patching.ContainerPatcher.SetCnmtTitleVersion(src, outp, keys, ver, b => Report(job, b), ct);
                                }
                            });
                            job.OutputPath = outp;
                        }
                        break;
                    }
                case JobType.RemoveTitleKey:
                    {
                        if (keys is null) throw new InvalidOperationException("Keys required to remove title-key crypto.");
                        for (int _mi = 0; _mi < job.Inputs.Count; _mi++)
                        {
                            string src = job.Inputs[_mi];
                            Detail(job, _mi, job.Inputs.Count, src);
                            string outp = ContentTaggedPath(job, src, settings.OutputDir, "NOKEY", settings);
                            Guarded(outp, () => NscbCore.Patching.ContainerPatcher.RemoveTitleKeyCrypto(src, outp, keys, b => Report(job, b), ct));
                            job.OutputPath = outp;
                        }
                        break;
                    }
                default:
                    // For Verify / other read-only jobs: just read file size to complete progress.
                    Report(job, total);
                    break;
            }
        }, ct);
        NSLog.Info($"[job {job.Id}] DONE {job.Type}");
        }
        catch (OperationCanceledException) { NSLog.Warn($"[job {job.Id}] CANCELLED {job.Type}"); throw; }
        catch (Exception ex) { NSLog.Error($"[job {job.Id}] FAILED {job.Type} :: {ex}", ex); throw; }
        finally { CloseStages(job); }
    }

    // Run `write`; if it throws (or is cancelled), delete the partial `outp` so a failed job never leaves a
    // half-written container with a final-looking name. The lambda runs synchronously (no deferred-capture issue).
    private static void Guarded(string outp, Action write)
    {
        try { write(); }
        catch { try { if (File.Exists(outp)) File.Delete(outp); } catch { } throw; }
    }

    private static void RunConvert(NscbJob job, Action<string, string, Action<long>, Action<string>?> action, string newExt, CancellationToken ct, int fileParallelism = 1, AppSettings? cfg = null)
    {
        // Same "stage + action" style as merge/pack: each file gets an adjacent byte band and a precise from→to
        // label; the bar tracks the action and never reaches 100 until the job is Done (Phase is monotonic).
        int total = job.Inputs.Count;
        string desc = job.Type switch
        {
            JobType.CompressNsz => "压缩 NSP→NSZ",
            JobType.CompressXcz => "压缩 XCI→XCZ",
            JobType.DecompressNsz => "解压 NSZ→NSP",
            JobType.DecompressXcz => "解压 XCZ→XCI",
            JobType.ConvertNspToXci => "转换 NSP→XCI",
            JobType.ConvertXciToNsp => "转换 XCI→NSP",
            _ => "转换",
        };
        // Weight each file's band by its size (zstd cost ∝ bytes ≈ wall time) so the bar tracks real time share,
        // not just file count. Each file shows "[i/N] 动作：文件" and fills its own proportional slice.
        long[] sz = new long[total]; long totSz = 0;
        for (int i = 0; i < total; i++) { try { sz[i] = Math.Max(1, new FileInfo(job.Inputs[i]).Length); } catch { sz[i] = 1; } totSz += sz[i]; }
        if (totSz <= 0) totSz = 1;
        NscbCore.Compression.Parallelizer.ForIndex(total, fileParallelism, i =>
        {
            string src = job.Inputs[i];
            ct.ThrowIfCancellationRequested();
            string name = Path.GetFileName(src);
            long before = 0; for (int k = 0; k < i; k++) before += sz[k];
            var (lo, hi) = NscbCore.Progress.ProgressBand.SliceBand(before, sz[i], totSz, 0, 99);   // size/time-weighted band
            string fileLbl = $"[{i + 1}/{total}] {desc}：{name}";
            string sub = "";                                     // current per-NCA sub-step, updated via onStep
            var rep = Band(job, sz[i], lo, hi, () => sub.Length > 0 ? $"{fileLbl} · {sub}" : fileLbl);
            Phase(job, lo, fileLbl);
            string dir = OutDir(cfg, src);   // honour the configured 默认输出目录 (was: always next to source)
            string dst = Path.Combine(dir, ConvertOutputName(src, newExt, cfg));   // name from SOURCE content, not the input filename
            try { action(src, dst, rep, s => sub = s); }
            catch { try { if (File.Exists(dst)) File.Delete(dst); } catch { } throw; }   // never leave a partial output on failure/cancel
            job.OutputPath = dst;
        }, ct);
    }

    // Shared Info builder used by BOTH /api/info and output naming, so a generated filename always matches
    // what the Info page shows (TitleInfoService + titles.json name enrichment).
    // Path-keyed cache of the (expensive) container parse + titles.json enrichment, invalidated by size+mtime and
    // whenever keys/DB change. Batch Rename/Database and repeated Info/naming calls on the same file then reuse a
    // single parse. Always returns a CLONE so callers may mutate freely (e.g. a version override) without
    // corrupting the cached instance.
    private static readonly System.Collections.Concurrent.ConcurrentDictionary<string, (long len, DateTime mt, NscbCore.Info.ContainerFileInfo info)> _infoCache = new();
    public static void InvalidateInfoCache() => _infoCache.Clear();

    public static NscbCore.Info.ContainerFileInfo InfoWithDb(string path, AppSettings cfg)
    {
        long len = -1; DateTime mt = default;
        try { var fi = new FileInfo(path); len = fi.Length; mt = fi.LastWriteTimeUtc; } catch { }
        if (len >= 0 && _infoCache.TryGetValue(path, out var hit) && hit.len == len && hit.mt == mt)
            return hit.info.Clone();

        var keys = cfg.TryLoadKeys()!;
        var file = new TitleInfoService(keys).GetFileInfo(path);
        var db = cfg.TryGetTitlesDb();
        if (db is not null)
        {
            var m = db.Lookup(file.TitleId ?? file.BaseTitleId);
            if (m is not null)
            {
                file.Developer ??= m.Developer; file.Genre ??= m.Genre; file.Region ??= m.Region;
                if (string.IsNullOrWhiteSpace(file.Publisher)) file.Publisher = m.Publisher;
                if (string.IsNullOrWhiteSpace(file.TitleName)) file.TitleName = m.Name;
            }
        }
        if (len >= 0)
        {
            if (_infoCache.Count > 512) _infoCache.Clear();   // bounded: a batch can touch many distinct files
            _infoCache[path] = (len, mt, file);
        }
        return file.Clone();
    }

    // Build a convert/compress/decompress output file name from the source's parsed content, matching the
    // Info page exactly (InfoWithDb + FileNamer). Falls back to `<inputStem><newExt>` when unusable.
    private static string ConvertOutputName(string src, string newExt, AppSettings? cfg, ulong? verOverride = null)
    {
        string fallback = Path.GetFileNameWithoutExtension(src) + newExt;
        if (cfg is null || cfg.TryLoadKeys() is null) return fallback;
        try
        {
            var info = InfoWithDb(src, cfg);
            if (verOverride is ulong vv) info.TitleVersionRaw = vv;   // e.g. upd_base: name shows the merged (update) version
            if (!string.IsNullOrWhiteSpace(info.TitleId))
            {
                // NOTE: RenameOptions is a record struct → `new RenameOptions()` would ZERO the bools (no
                // default-value application). Pass explicit trues so it uses content name + version + type.
                string named = NscbCore.Renaming.FileNamer.BuildFileName(info, Path.ChangeExtension(src, newExt), new NscbCore.Renaming.RenameOptions(true, true, true));
                if (!string.IsNullOrWhiteSpace(named) && named != Path.GetFileName(src)) fallback = named;
            }
        }
        catch { }
        // Multi-content combined packs carry a "(1G+1U)" composition tag before the extension.
        string comp = CompositionTag(src, cfg);
        if (comp.Length > 0 && fallback.EndsWith(newExt, StringComparison.OrdinalIgnoreCase))
            fallback = fallback[..^newExt.Length] + comp + newExt;
        return fallback;
    }

    // " (1G+1U)" composition tag for a container that holds more than one title; empty otherwise.
    private static string CompositionTag(string src, AppSettings? cfg)
    {
        var keys = cfg?.TryLoadKeys();
        if (keys is null) return "";
        try
        {
            var (g, u, d) = NscbCore.Splitting.TitleSplitter.Composition(src, keys);
            return NscbCore.Packaging.OutputFormat.CompositionTag(g, u, d);
        }
        catch { return ""; }
    }

    // Output path for the patch/transform ops: name from the SOURCE content (Name [id][v][Type]) with the
    // operation tag as a trailing bracket → `Name [id][v][Type][TAG].ext`. Falls back to the input stem when
    // content info is unavailable. dir is used only if it exists, else write next to the source.
    private static string ContentTaggedPath(NscbJob job, string src, string? dir, string tag, AppSettings cfg, ulong? verOverride = null)
    {
        string ext = Path.GetExtension(src);
        string content = ConvertOutputName(src, ext, cfg, verOverride); // "Name [id][v][Type].ext" or "stem.ext"
        string stem = content.EndsWith(ext, StringComparison.OrdinalIgnoreCase) ? content[..^ext.Length] : content;
        if (!string.IsNullOrEmpty(tag)) stem += "[" + tag + "]";
        string outDir = OutDir(cfg, src, dir);
        return Path.Combine(outDir, MakeSafe(stem + ext));
    }

    private static void RunPatch(NscbJob job, Action<string, string> action, CancellationToken ct, string suffix = "_patched")
    {
        int n = job.Inputs.Count;
        for (int i = 0; i < n; i++)
        {
            string src = job.Inputs[i];
            ct.ThrowIfCancellationRequested();
            Detail(job, i, n, src);
            string dst = GetOutputPath(job, src, null, suffix);
            action(src, dst);
            job.OutputPath = dst;
        }
    }

    // Keep only filename-safe chars from a version label (e.g. "11.0.0").
    private static string SanitizeVer(string? s)
        => System.Text.RegularExpressions.Regex.Replace((s ?? "").Trim(), @"[^0-9A-Za-z._\-]", "");

    // Combined "compat old firmware": set cnmt RequiredSystemVersion AND NCA keygeneration to the same
    // target firmware. For NSZ/XCZ we decompress, patch both, then recompress (keygen edits need plaintext).
    private static void RunDowngrade(NscbJob job, NscbKeys? keys, AppSettings settings, CancellationToken ct)
    {
        if (keys is null) throw new InvalidOperationException("Keys required for firmware/keygen downgrade.");
        // Derive RSV authoritatively from the typed firmware (e.g. "11.0.0"); fall back to the numeric
        // rsv option. Then the matching key generation comes from the same firmware table.
        string lblRaw = job.Options.GetValueOrDefault("rsvLabel") ?? "";
        uint rsv;
        if (lblRaw.Contains('.') && lblRaw.Split('.').All(p => p.Length > 0 && p.All(char.IsDigit)))
        { try { rsv = FirmwareTables.RsvFromFwString(lblRaw); } catch { rsv = GetRsv(job); } }
        else rsv = GetRsv(job);
        int? kg = FirmwareTables.KeyGenerationFromRsv(rsv);
        try { NSLog.Info($"[job {job.Id}] downgrade: target={FirmwareTables.FwStringFromRsv(rsv)} rsv=0x{rsv:X} keygen={(kg?.ToString() ?? "(none → RSV only)")}"); } catch { }
        string lbl = SanitizeVer(lblRaw.Length > 0 ? lblRaw : job.Options.GetValueOrDefault("rsv"));
        int count = job.Inputs.Count;
        for (int idx = 0; idx < count; idx++)
        {
            string src = job.Inputs[idx];
            ct.ThrowIfCancellationRequested();
            double lo = idx * 100.0 / count, hi = (idx + 1) * 100.0 / count;
            void SetPct(double p) { int pi = (int)Math.Min(hi, Math.Max(job.ProgressPct, p)); if (pi != job.ProgressPct) { job.ProgressPct = pi; PublishProgress?.Invoke(job); } }
            string outp = ContentTaggedPath(job, src, null, "PATCHED", settings);

            // Fast NSCB-style path: patch in place; never (de)compress the big body.
            // RSV lives in the uncompressed .cnmt.nca; keygen lives in each NCA/NCZ embedded header.
            // Only PatchCnmtRsv does one whole-file copy; the keygen edit is header-only (in place).
            Mark(job, $"[{idx + 1}/{count}] {ActionOfJob(job.Type)}：{Path.GetFileName(src)}（修改固件要求 RSV）");
            ContainerPatcher.PatchCnmtRsv(src, outp, keys, rsv, true, b => Report(job, b), ct);
            if (kg is int k && k >= 1)
            {
                Mark(job, $"[{idx + 1}/{count}] {ActionOfJob(job.Type)}：{Path.GetFileName(src)}（修改密钥 keygen→{k}）");
                var (changed, newHashes) = ContainerPatcher.PatchKeyGenerationInPlace(outp, keys, k, b => Report(job, b), ct);
                try
                {
                    if (changed == 0)
                        NSLog.Warn($"[job {job.Id}] keygen 未修改（对应 master key 超出可改写范围或无相应密钥），本次仅降低了固件要求 RSV。");
                    else
                    {
                        NSLog.Info($"[job {job.Id}] keygen 已降低：{changed} 个 NCA → gen {k}。");
                        // Re-wrapping the standard-crypto NCA headers changes their whole-file SHA256; sync the cnmt
                        // content-record hashes to the new values so a strict SHA256 verifier (NSGManager) passes.
                        // (Fixed-key header Signature1 still can't be re-created without Nintendo's private key.)
                        if (newHashes.Count > 0)
                        {
                            ContainerPatcher.SyncContentHashes(outp, newHashes, keys);
                            NSLog.Info($"[job {job.Id}] 已同步 {newHashes.Count} 个 NCA 的 cnmt 内容哈希（SHA256 校验可通过；固定密钥签名仍不可重签，属正常）。");
                        }
                    }
                }
                catch { }
            }
            job.OutputPath = outp;
            SetPct(hi);
            // RSV lives in the .cnmt (Meta rebuilt) and keygen edits the NCA header 0x206 — both are inside the
            // 0x200–0x400 fixed-key Signature1 range, so those NCAs' header signatures are necessarily invalidated
            // (content SHA256 still consistent; installers don't check header sig). Mirror the merge caveat.
            try { NSLog.Warn($"[job {job.Id}] 降版本改动了 Meta/头部：受影响 NCA 的固定密钥签名(Signature1)必然失效（内容 SHA256 仍通过；安装不受影响）。") ; } catch { }
        }
    }

    private static void RunPack(NscbJob job, NscbKeys? keys, AppSettings settings, Action<long> progress, CancellationToken ct)
    {
        var inputs = ExpandPackInputs(job.Inputs);
        if (inputs.Count == 0) throw new InvalidOperationException("没有可打包的文件（请添加 NSP/NSZ/XCI/XCZ 或包含它们的文件夹）。") ;

        string first = Path.GetFullPath(inputs[0]);
        // Explicit outDir option wins; else honour the configured 默认输出目录 (created if missing); else next to the first input.
        string? optOd = job.Options.TryGetValue("outDir", out var od) && !string.IsNullOrWhiteSpace(od) ? od : null;
        string outDir = OutDir(settings, first, optOd);
        Directory.CreateDirectory(outDir);

        // NSCB-style name; allow manual outName override (strip a trailing .xci/.xcz so the field can show the full name).
        string stem = job.Options.TryGetValue("outName", out var onm) && !string.IsNullOrWhiteSpace(onm)
            ? System.Text.RegularExpressions.Regex.Replace(onm.Trim(), @"\.(xci|xcz)$", "", System.Text.RegularExpressions.RegexOptions.IgnoreCase)
            : (BuildPackName(inputs, keys, settings) ?? Path.GetFileNameWithoutExtension(first));
        string outp = Path.Combine(outDir, MakeSafe(stem) + PackExtension(inputs));

        // Content-aware: if ANY input is compressed (NSZ/XCZ/NCZ), first convert the uncompressed ones so the
        // whole pack is uniformly compressed → XCZ. Only plain NSP/XCI (no compressed) → pack as-is → XCI.
        // Conversions honour the compress/decompress thread count (NCA-level) and multi-file parallelism.
        bool hasCompressed = inputs.Any(f => new[] { ".nsz", ".xcz", ".ncz" }.Contains(Path.GetExtension(f).ToLowerInvariant()));
        if (hasCompressed && keys is null) throw new InvalidOperationException("打包含压缩文件需要 prod.keys（转换 NSP→NSZ 需要）。");
        string Tmp(string e) => Path.Combine(Path.GetTempPath(), "nscb-pack-" + Guid.NewGuid().ToString("N") + e);
        var temps = new List<string>();
        var packInputs = new List<string>(inputs);
        int stages = hasCompressed ? 2 : 1;                 // [1] 预处理转换(仅含未压缩输入时) + [2] 打包
        try
        {
            if (hasCompressed)
            {
                int threads = GetParallel(job, settings), level = GetLevel(job, settings);
                int degree = Math.Min(inputs.Count, threads);              // files in parallel
                int inner = Math.Max(1, threads / Math.Max(1, degree));    // per-NCA zstd MT workers
                int n = inputs.Count; var norm = new string[n];
                // Weight the preprocessing band [3,78] by the size of the files that actually get converted
                // (already-compressed inputs pass through at ~0 cost). This makes the bar track real time share.
                long[] cw = new long[n]; long cwtot = 0;
                for (int i = 0; i < n; i++)
                {
                    string e0 = Path.GetExtension(inputs[i]).ToLowerInvariant();
                    long w = 0;
                    if (e0 == ".nsp" || e0 == ".xci") { try { w = Math.Max(1, new FileInfo(inputs[i]).Length); } catch { w = 1; } }
                    cw[i] = w; cwtot += w;
                }
                if (cwtot <= 0) cwtot = 1;
                NscbCore.Compression.Parallelizer.ForIndex(n, degree, i =>
                {
                    ct.ThrowIfCancellationRequested();
                    string f = inputs[i]; string e = Path.GetExtension(f).ToLowerInvariant();
                    if (e == ".nsp" || e == ".xci")
                    {
                        string outE = e == ".nsp" ? ".nsz" : ".xcz";
                        string o = Tmp(outE);
                        long before = 0; for (int q = 0; q < i; q++) before += cw[q];
                        var (lo, hi) = NscbCore.Progress.ProgressBand.SliceBand(before, cw[i], cwtot, 3, 78);
                        long flen = Math.Max(1, cw[i]);
                        string lbl = $"[1/{stages}] 打包·预处理 {i + 1}/{n}→{outE}：{Path.GetFileName(f)}";
                        var rep = Band(job, flen, lo, hi, lbl);
                        Phase(job, lo, lbl);
                        if (e == ".nsp") NszConverter.NspToNsz(f, o, keys!, level, rep, ct, inner);
                        else NszConverter.XciToXcz(f, o, keys!, level, rep, ct, inner);
                        temps.Add(o); norm[i] = o;
                    }
                    else norm[i] = f;   // already compressed — pass through
                }, ct);
                packInputs = norm.ToList();
            }
            long packBytes = 0; foreach (var s in packInputs) { try { packBytes += new FileInfo(s).Length; } catch { } }
            string pLbl = $"[{stages}/{stages}] 打包：{Path.GetFileName(outp)}";
            Mark(job, pLbl);
            XciPacker.Pack(packInputs, outp, keys, Band(job, Math.Max(1, packBytes), hasCompressed ? 80 : 3, 99, pLbl), ct);
        }
        catch { try { if (File.Exists(outp)) File.Delete(outp); } catch { } throw; }   // never leave a partial packed output on failure/cancel
        finally { foreach (var t in temps) { try { File.Delete(t); } catch { } } }

        if (!File.Exists(outp) || new FileInfo(outp).Length == 0)
            throw new InvalidOperationException("打包未生成有效文件（输出为空）。") ;
        job.OutputPath = outp;
    }

    /// <summary>Expand file/folder inputs into the supported game files inside them (public so the UI can
    /// preview the derived pack name via /api/packname).</summary>
    public static List<string> ExpandPackInputs(IEnumerable<string> raw)
    {
        static bool Supported(string f)
        {
            string e = Path.GetExtension(f).ToLowerInvariant();
            return e is ".nsp" or ".nsz" or ".xci" or ".xcz" or ".nca" or ".ncz" || NscbCore.Splitting.Fat32Splitter.IsSplitPart(Path.GetFileName(f));
        }
        var list = new List<string>();
        foreach (var i in raw)
        {
            if (Directory.Exists(i))
            {
                // Include files in subfolders too (walk the tree; tolerate inaccessible dirs).
                try { list.AddRange(Directory.EnumerateFiles(i, "*", System.IO.SearchOption.AllDirectories).Where(Supported)); }
                catch { list.AddRange(Directory.EnumerateFiles(i).Where(Supported)); }
            }
            else if (File.Exists(i)) list.Add(i);
        }
        return list;
    }

    /// <summary>Packed card extension follows the content: compressed NCAs (NSZ/XCZ/NCZ inputs, copied
    /// without decompression) produce an XCZ; otherwise an XCI.</summary>
    public static string PackExtension(IEnumerable<string> inputs)
        => NscbCore.Packaging.OutputFormat.PackExt(inputs.Select(f => Path.GetExtension(f).ToLowerInvariant()));

    // Derive an NSCB-style pack name by classifying each input (Application=Game / Patch=Update / AddOnContent=DLC).
    public static string? BuildPackName(List<string> inputs, NscbKeys? keys, AppSettings? cfg = null)
    {
        if (keys is null) return null;
        var svc = new TitleInfoService(keys);
        int g = 0, u = 0, d = 0; string? appName = null, anyName = null, baseId = null; ulong ver = 0;
        foreach (var f in inputs)
        {
            try
            {
                var ci = svc.GetFileInfo(f);
                if (cfg is not null && string.IsNullOrWhiteSpace(ci.TitleName))
                {
                    var m = cfg.TryGetTitlesDb()?.Lookup(ci.TitleId ?? ci.BaseTitleId);
                    if (m is not null) ci.TitleName = m.Name;
                }
                if (!string.IsNullOrWhiteSpace(ci.TitleName)) anyName ??= ci.TitleName;
                switch (ci.TitleType)
                {
                    case "Application": appName ??= ci.TitleName; baseId ??= ci.TitleId ?? ci.BaseTitleId; if (ci.TitleVersionRaw is ulong v0 && ver == 0) ver = v0; g++; break;
                    case "Patch": baseId ??= ci.BaseTitleId ?? ci.TitleId; if (ci.TitleVersionRaw is ulong v1 && v1 > ver) ver = v1; u++; break;
                    case "AddOnContent": baseId ??= ci.BaseTitleId ?? ci.TitleId; d++; break;
                    default: g++; break;
                }
            }
            catch { }
        }
        var parts = new List<string>();
        if (g > 0) parts.Add($"{g}G"); if (u > 0) parts.Add($"{u}U"); if (d > 0) parts.Add($"{d}D");
        string counts = parts.Count > 0 ? "(" + string.Join("+", parts) + ")" : "(1G)";
        // Prefer the base game's title; fall back to any title, then a cleaned first filename (never "XCI").
        string name = !string.IsNullOrWhiteSpace(appName) ? appName!
                    : !string.IsNullOrWhiteSpace(anyName) ? anyName!
                    : CleanedBaseName(inputs[0]);
        if (string.IsNullOrWhiteSpace(name)) name = "Pack";
        name = MakeSafe(name);
        baseId = (string.IsNullOrWhiteSpace(baseId) ? "0100000000000000" : baseId!).ToUpperInvariant();
        return $"{name} [{baseId}] [v{ver}] {counts}";
    }

    // Base game name from a filename: drop the extension and any [..] tags / trailing (n).
    private static string CleanedBaseName(string path)
    {
        string s = Path.GetFileNameWithoutExtension(path);
        s = System.Text.RegularExpressions.Regex.Replace(s, @"\[[^\]]*\]", " ");
        s = System.Text.RegularExpressions.Regex.Replace(s, @"\([^)]*\)", " ");
        return System.Text.RegularExpressions.Regex.Replace(s, @"\s+", " ").Trim();
    }

    private static string MakeSafe(string s) => NscbCore.Packaging.RunOptions.SafeFileName(s);

    // Centralised destination-directory resolution, shared by every file-producing operation so the
    // configured “默认输出目录” is honoured consistently (compress/convert/pack previously ignored it and
    // always wrote next to the source; the others silently fell back when the dir did not yet exist).
    // Precedence: explicit per-job outDir option → configured default output dir → next to the source.
    // A set directory is expanded (~ / %VAR%) and created if missing, so a deliberate setting is never
    // silently skipped. Falls back to the source’s own folder only when nothing is configured.
    private static string OutDir(AppSettings? cfg, string src, string? optionOutDir = null)
    {
        if (!string.IsNullOrWhiteSpace(optionOutDir))
        {
            string d = NscbCore.Keys.NscbKeys.ExpandPath(optionOutDir!);
            try { Directory.CreateDirectory(d); } catch { }
            if (Directory.Exists(d)) return d;
        }
        if (cfg?.OutputDir is { Length: > 0 } od)
        {
            string d = NscbCore.Keys.NscbKeys.ExpandPath(od);
            try { Directory.CreateDirectory(d); } catch { }
            if (Directory.Exists(d)) return d;
        }
        return Path.GetDirectoryName(src) is { Length: > 0 } sd ? sd : ".";
    }

    private static string GetOutputPath(NscbJob job, string src, string? dir, string suffix)
    {
        string name = Path.GetFileNameWithoutExtension(src) + suffix + Path.GetExtension(src);
        // Use the configured dir only if it exists; otherwise write next to the source (never create or
        // scatter into a stale/typo'd global output dir).
        string outDir = !string.IsNullOrEmpty(dir) && Directory.Exists(dir) ? dir : (Path.GetDirectoryName(src) ?? ".");
        return Path.Combine(outDir, name);
    }

    private static int GetLevel(NscbJob job, AppSettings settings) =>
        NscbCore.Packaging.RunOptions.ResolveLevel(job.Options, settings.CompressLevel);

    private static uint GetRsv(NscbJob job) =>
        NscbCore.Packaging.RunOptions.ResolveRsv(job.Options);

    // Set progress percent AND the action detail together, so the bar tracks the message (never 100 while Running).
    // Monotonic while Running (never regresses) and only publishes on a real change (whole-% / new label).
    private static void Phase(NscbJob job, int pct, string detail)
    {
        bool ch;
        lock (job)
        {
            int pi = Math.Min(99, Math.Max(job.ProgressPct, Math.Max(0, pct)));
            bool pctCh = pi != job.ProgressPct; job.ProgressPct = pi;
            bool detCh = job.Detail != detail;
            if (detCh) StageEnter(job, detail); else StageTick(job);
            ch = pctCh || detCh;
        }
        if (ch) { try { PublishProgress?.Invoke(job); } catch { } }
    }

    // A progress callback that maps streamed bytes into a fixed [lo,hi] band with an action label, so each phase
    // (convert / merge / recompress) moves the bar AND updates the detail consistently.
    private static Action<long> Band(NscbJob job, long estBytes, int lo, int hi, string detail)
        => Band(job, estBytes, lo, hi, () => detail);

    // Dynamic-label variant: the label is re-read on each progress tick so a converter can report finer
    // sub-steps (e.g. per-NCA “压缩 Program（2021 MB）”) that each become their own stage, still bound to the band.
    private static Action<long> Band(NscbJob job, long estBytes, int lo, int hi, Func<string> labelFn)
    {
        long acc = 0;
        return d =>
        {
            if (d <= 0) return;
            Interlocked.Add(ref acc, d);
            Phase(job, NscbCore.Progress.ProgressBand.Percent(acc, estBytes, lo, hi), labelFn());
        };
    }

    // Merge/pack output format by content precedence: card family if any XCI/XCZ; compressed if any NSZ/XCZ/NCZ.
    //   card+compressed→XCZ, card→XCI, compressed→NSZ, else NSP.
    private static string MergeTargetExt(IEnumerable<string> inputs)
        => NscbCore.Packaging.OutputFormat.MergeTargetExt(inputs.Select(f => Path.GetExtension(f).ToLowerInvariant()));

    private static int GetParallel(NscbJob job, AppSettings settings)
    {
        // Auto CPU budget: cores / (jobs running right now). A lone job gets the whole CPU; a batch of N shares it,
        // so file-parallelism × per-file MT never oversubscribes. Per-job "parallel" option (if set) is still the
        // request but capped to this budget. The division itself lives in RunOptions.ThreadBudget (unit-tested).
        int budget = NscbCore.Packaging.RunOptions.ThreadBudget(Environment.ProcessorCount, settings.ActiveJobs);
        return NscbCore.Packaging.RunOptions.ResolveThreads(job.Options, settings.CompressThreads, budget);
    }

    private static void Mark(NscbJob job, string detail)
    {
        bool ch;
        lock (job) { ch = job.Detail != detail; if (ch) StageEnter(job, detail); }
        if (ch) { try { PublishProgress?.Invoke(job); } catch { } }
    }

    // ── Per-stage timing (drives the UI “阶段/耗时” breakdown) ──
    private static long NowMs(NscbJob job) => job.Sw is null ? 0 : job.Sw.ElapsedMilliseconds;

    // Called under lock(job): close the previous stage, open a new one named `detail`, and set Detail.
    private static void StageEnter(NscbJob job, string detail)
    {
        long now = NowMs(job);
        if (job.Stages.Count > 0) { var l = job.Stages[^1]; if (!l.Done) { l.ElapsedMs = now - l.StartMs; l.Done = true; } }
        job.Stages.Add(new StageTiming { Name = detail, StartMs = now });
        job.Detail = detail;
    }

    // Called under lock(job): refresh the in-progress stage's elapsed so the UI shows live timing.
    private static void StageTick(NscbJob job)
    {
        if (job.Stages.Count > 0) { var l = job.Stages[^1]; if (!l.Done) l.ElapsedMs = NowMs(job) - l.StartMs; }
    }

    public static void CloseStages(NscbJob job)
    {
        lock (job) { if (job.Stages.Count > 0) { var l = job.Stages[^1]; if (!l.Done) { l.ElapsedMs = NowMs(job) - l.StartMs; l.Done = true; } } }
    }

    // ── Adaptive stage weighting: EMA of ms-per-proxy-byte per stage kind, so progress-band widths track the real
    // measured time share instead of a fixed guess. First run falls back to typical defaults; later runs adapt. ──
    private static readonly System.Collections.Concurrent.ConcurrentDictionary<string, double> _stageRate = new();
    private static double StageRate(string kind, double def) => _stageRate.TryGetValue(kind, out var v) && v > 0 ? v : def;
    private static void LearnStageRate(string kind, long proxyBytes, double ms)
    {
        if (proxyBytes <= 0 || ms <= 0) return;
        double r = ms / proxyBytes;
        _stageRate.AddOrUpdate(kind, r, (_, old) => NscbCore.Progress.ProgressBand.Ema(old, r));   // EMA, favor history slightly
    }

    // Unified per-file action label used by every op: "[i+1/total] 动作：文件名" (progress still driven by bytes/Report).
    private static void Detail(NscbJob job, int i, int total, string src)
        => Mark(job, $"[{i + 1}/{total}] {ActionOfJob(job.Type)}：{Path.GetFileName(src)}");

    private static string ActionOfJob(JobType t) => t switch
    {
        JobType.SplitFat32 => "拆分 FAT32 分卷",
        JobType.MergeFat32 => "合并分卷",
        JobType.JoinFile => "合并分卷",
        JobType.TrimXci => "剪裁 XCI",
        JobType.SuperTrimXci => "超级剪裁 XCI",
        JobType.EraseDeltas => "去 Delta 碎片",
        JobType.SplitTitles => "拆分整合包",
        JobType.Extract => "拆包/提取内容",
        JobType.RelinkAccount => "重链账号",
        JobType.SetCgame => "设为卡带",
        JobType.SetEshop => "设为下载版",
        JobType.Restore => "还原 header",
        JobType.SetCnmtTitleId => "改 cnmt TitleID",
        JobType.SetCnmtVersion => "改 cnmt 版本",
        JobType.RemoveTitleKey => "去 title key",
        JobType.ReadNpdm => "读取 NPDM",
        JobType.GenXml => "生成 XML",
        JobType.Rename => "按内容重命名",
        JobType.Verify => "校验",
        JobType.CompressNsz => "压缩 NSP→NSZ",
        JobType.CompressXcz => "压缩 XCI→XCZ",
        JobType.DecompressNsz => "解压 NSZ→NSP",
        JobType.DecompressXcz => "解压 XCZ→XCI",
        JobType.ConvertNspToXci => "转换 NSP→XCI",
        JobType.ConvertXciToNsp => "转换 XCI→NSP",
        JobType.PackXci => "打包",
        JobType.UpdBase => "合并 update",
        JobType.PatchRsv => "兼容旧固件",
        _ => "处理",
    };

    private static void Report(NscbJob job, long delta)
    {
        if (delta <= 0) return;
        int pct;
        lock (job)
        {
            job.BytesDone += delta;
            if (job.BytesTotal <= 0) return;
            pct = (int)Math.Min(99, job.BytesDone * 100 / job.BytesTotal);   // never 100 while Running; Done sets 100
            if (pct == job.ProgressPct) return;   // throttle to whole-percent changes
            job.ProgressPct = pct;
            StageTick(job);   // advance the current stage's live elapsed even for byte-driven ops
        }
        PublishProgress?.Invoke(job);
    }
}

#if WINDOWS
/// <summary>user32 helpers to pick a screen-resolution-adaptive initial window size + centered position.</summary>
internal static class NativeScreen
{
    [System.Runtime.InteropServices.DllImport("user32.dll")] public static extern int GetSystemMetrics(int nIndex);
    [System.Runtime.InteropServices.DllImport("user32.dll")] public static extern uint GetDpiForSystem();

    /// <summary>Returns (width,height,left,top) in Photino DIP units for ~<paramref name="frac"/> of the primary screen, centered.</summary>
    public static (int w, int h, int x, int y) Fit(double wFrac, double hFrac)
    {
        try
        {
            // SM_CXSCREEN / SM_CYSCREEN (physical px). Photino maps Width/Height ~1:1 to these.
            int sw = GetSystemMetrics(0), sh = GetSystemMetrics(1);
            int w = (int)(sw * wFrac), h = (int)(sh * hFrac);
            int x = (int)(sw * (1 - wFrac) / 2), y = (int)(sh * (1 - hFrac) / 2);
            return (Math.Max(w, 640), Math.Max(h, 640), Math.Max(x, 0), Math.Max(y, 0));
        }
        catch { return (960, 900, 60, 40); }
    }

    /// <summary>A near-square window whose side is <paramref name="frac"/> of the shorter screen dimension, centered.</summary>
    public static (int w, int h, int x, int y) Square(double frac)
    {
        try
        {
            int sw = GetSystemMetrics(0), sh = GetSystemMetrics(1);
            int side = (int)(Math.Min(sw, sh) * frac);
            side = Math.Max(side, 480);
            return (side, side, Math.Max((sw - side) / 2, 0), Math.Max((sh - side) / 2, 0));
        }
        catch { return (720, 720, 80, 60); }
    }

    /// <summary>Width×height box: height = <paramref name="hFrac"/> of the screen, width = height×<paramref name="aspect"/>, clamped to the screen and centered.</summary>
    public static (int w, int h, int x, int y) Box(double hFrac, double aspect)
    {
        try
        {
            int sw = GetSystemMetrics(0), sh = GetSystemMetrics(1);
            int h = (int)(sh * hFrac);
            int w = (int)(h * aspect);
            if (w > (int)(sw * 0.92)) { w = (int)(sw * 0.92); h = (int)(w / aspect); }
            w = Math.Max(w, 760); h = Math.Max(h, 480);
            return (w, h, Math.Max((sw - w) / 2, 0), Math.Max((sh - h) / 2, 0));
        }
        catch { return (1000, 740, 80, 60); }
    }

    /// <summary>
    /// Initial window box from the primary screen's <b>WorkingArea</b> (excludes the taskbar and is
    /// DPI-consistent with Form.SetBounds): takes min(<paramref name="frac"/> of each dimension,
    /// <paramref name="maxW"/>/maxH). The cap keeps 1080p filling the screen yet 2K/4K comfortably
    /// sized (not enormous); the working-area clamp guarantees the whole window is always on-screen.
    /// Centered within the working area.
    /// </summary>
    public static (int w, int h, int x, int y) WorkBox(double frac, int maxW, int maxH)
    {
        try
        {
            var scr = System.Windows.Forms.Screen.PrimaryScreen;
            if (scr is null) return (1100, 760, 60, 40);
            var wa = scr.WorkingArea;
            int availW = Math.Max(wa.Width - 16, 320), availH = Math.Max(wa.Height - 16, 320);
            int w = Math.Min(Math.Max((int)(wa.Width * frac), 640), maxW);
            int h = Math.Min(Math.Max((int)(wa.Height * frac), 480), maxH);
            w = Math.Min(w, availW); h = Math.Min(h, availH);   // never exceed the working area
            int x = wa.Left + (wa.Width - w) / 2;
            int y = wa.Top + (wa.Height - h) / 2;
            return (w, h, Math.Max(x, wa.Left), Math.Max(y, wa.Top));
        }
        catch { return (1100, 760, 60, 40); }
    }
}

/// <summary>WinForms host embedding WebView2, with real OS file/folder drag-drop (absolute paths).
/// The page calls chrome.webview.postMessageWithAdditionalObjects on drop; each dropped item arrives
/// here as a CoreWebView2File whose Path we push back into the page via window.__nativeDrop.</summary>
internal sealed class NscbWindow : Form
{
    private readonly WebView2 _wv = new();
    private readonly string _url;

    public NscbWindow(string url)
    {
        _url = url;
        Text = "NSC_BUILDER";
        var (w, h, x, y) = NativeScreen.WorkBox(0.90, 1600, 1000);   // ~90% of the working area, capped so 2K/4K aren't oversized and it always fits 1080p; taskbar/DPI aware
        StartPosition = FormStartPosition.Manual;
        SetBounds(x, y, w, h);
        MinimumSize = new Size(560, 460);
        BackColor = Color.FromArgb(238, 241, 245);
        _wv.Dock = DockStyle.Fill;
        Controls.Add(_wv);
        Load += async (_, _) => { try { await InitAsync(); } catch (Exception ex) { NSLog.Error("WebView2 init failed", ex); } };
    }

    private async Task InitAsync()
    {
        string userData = Path.Combine(Path.GetTempPath(), "nscb-webview2");
        try { Directory.CreateDirectory(userData); } catch { }
        var options = new CoreWebView2EnvironmentOptions("--disable-gpu --disable-gpu-compositing --disable-direct-composition --no-default-browser-check");
        var env = await CoreWebView2Environment.CreateAsync(null, userData, options);
        await _wv.EnsureCoreWebView2Async(env);
        var cv = _wv.CoreWebView2;
        cv.Settings.IsStatusBarEnabled = false;
        cv.Settings.AreDevToolsEnabled = true;
        try { _wv.AllowExternalDrop = true; } catch { }
        try { NSLog.Info("WebView2 init: titlebar ready, drop bridge wired"); } catch { }
        cv.WebMessageReceived += (_, a) =>
        {
            var paths = new List<string>();
            try
            {
                var objs = a.AdditionalObjects;
                if (objs != null) foreach (object o in objs)
                {
                    if (o is CoreWebView2File f) { try { if (!string.IsNullOrEmpty(f.Path)) paths.Add(f.Path); } catch { } }
                    else { try { var p = o?.GetType().GetProperty("Path")?.GetValue(o) as string; if (!string.IsNullOrEmpty(p)) paths.Add(p); } catch { } }
                }
            }
            catch (Exception ex) { NSLog.Error("drop enumerate failed", ex); }
            if (paths.Count > 0)
            {
                NSLog.Info($"drop paths=[{string.Join(", ", paths)}]");
                try { _ = cv.ExecuteScriptAsync($"window.__nativeDrop && window.__nativeDrop({JsonSerializer.Serialize(paths)})"); }
                catch (Exception ex) { NSLog.Error("drop __nativeDrop failed", ex); }
                return;
            }
            // Control message from the page (native file/folder pick request).
            try
            {
                using var jd = JsonDocument.Parse(a.WebMessageAsJson ?? "{}");
                var root = jd.RootElement;
                if (root.ValueKind == JsonValueKind.Object && root.TryGetProperty("t", out var tp) && tp.GetString() == "pick")
                {
                    bool multi = root.TryGetProperty("multi", out var mv) && mv.ValueKind == JsonValueKind.True;
                    bool folders = root.TryGetProperty("folders", out var fv) && fv.ValueKind == JsonValueKind.True;
                    bool anyFile = root.TryGetProperty("anyFile", out var av) && av.ValueKind == JsonValueKind.True;
                    HandlePick(cv, folders, multi, anyFile);
                }
            }
            catch { }
        };
        cv.Navigate(_url);
    }

    // Show the real Windows file/folder dialog and return the chosen path(s) to the page via window.__onPick.
    private void HandlePick(CoreWebView2 cv, bool folders, bool multi, bool anyFile = false)
    {
        var picked = new List<string>();
        try
        {
            if (folders)
            {
                using var fb = new FolderBrowserDialog { AutoUpgradeEnabled = true, Description = "选择文件夹" };
                if (fb.ShowDialog(this) == DialogResult.OK) picked.Add(fb.SelectedPath);
            }
            else
            {
                // Config-file picks (keys / titles.json / …) must not be hidden behind the game-only filter;
                // game-file picks keep “Switch 游戏” first. anyFile → show everything.
                string filter = anyFile
                    ? "所有文件 (*.*)|*.*|配置/密钥 (*.json;*.keys;*.txt;*.cfg;*.db)|*.json;*.keys;*.txt;*.cfg;*.db"
                    : "Switch 游戏|*.nsp;*.nsz;*.xci;*.xcz;*.nca;*.ncz|所有文件 (*.*)|*.*";
                using var ofd = new OpenFileDialog { Multiselect = multi, Filter = filter, Title = "选择文件" };
                if (ofd.ShowDialog(this) == DialogResult.OK) { if (multi) picked.AddRange(ofd.FileNames); else picked.Add(ofd.FileName); }
            }
        }
        catch (Exception ex) { NSLog.Error("native pick failed", ex); }
        try { _ = cv.ExecuteScriptAsync($"window.__onPick && window.__onPick({JsonSerializer.Serialize(picked)})"); } catch { }
    }
}
#endif
