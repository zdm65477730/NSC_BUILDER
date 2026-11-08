using System.Collections.Concurrent;
using System.Text.Json.Serialization;

namespace NscbJobs;

// ── Job types ────────────────────────────────────────────────────────────────────

public enum JobType
{
    ConvertNspToXci,
    ConvertXciToNsp,
    CompressNsz,
    CompressXcz,
    DecompressNsz,
    DecompressXcz,
    PatchRsv,
    RemoveTitleKey,
    PackXci,
    SplitFat32,
    MergeFat32,
    SplitTitles,
    Extract,
    GenXml,
    Verify,
    TrimXci,
    SuperTrimXci,
    EraseDeltas,
    UpdBase,
    ReadNpdm,
    JoinFile,
    RelinkAccount,
    Restore,
    SetCgame,
    SetEshop,
    SetCnmtTitleId,
    SetCnmtVersion,
    Database,
    Rename,
}

public enum JobStatus { Queued, Running, Done, Failed, Cancelled }

/// <summary>One named step of a job with its wall-clock timing (ms since the job started).</summary>
public sealed class StageTiming
{
    public string Name { get; set; } = "";
    public long StartMs { get; set; }
    public long ElapsedMs { get; set; }
    public bool Done { get; set; }
}

// ── Job model ────────────────────────────────────────────────────────────────────

public sealed class NscbJob
{
    public string Id { get; init; } = Guid.NewGuid().ToString("N");
    public JobType Type { get; init; }
    public IReadOnlyList<string> Inputs { get; init; } = [];
    public Dictionary<string, string> Options { get; init; } = [];
    public string? OutputPath { get; set; }

    public JobStatus Status { get; set; } = JobStatus.Queued;

    /// <summary>0–100 (percent).</summary>
    public int ProgressPct { get; set; }

    /// <summary>Human-readable current step, e.g. "2/5 · game.nsz：解压". Shown under the progress bar.</summary>
    public string? Detail { get; set; }

    /// <summary>Per-stage timing breakdown. The LAST item is the in-progress stage (Done=false) until the
    /// job finishes; earlier items are completed stages with elapsed milliseconds. Drives the UI's expandable
    /// “阶段/耗时” detail.</summary>
    public List<StageTiming> Stages { get; } = new();

    [JsonIgnore]
    public System.Diagnostics.Stopwatch? Sw { get; set; }   // started when the job begins running; times stages

    /// <summary>Total bytes processed so far.</summary>
    public long BytesDone { get; set; }

    /// <summary>Estimated total bytes (or -1 if unknown).</summary>
    public long BytesTotal { get; set; } = -1;

    public DateTime CreatedAt { get; init; } = DateTime.UtcNow;
    public DateTime? StartedAt { get; set; }
    public DateTime? FinishedAt { get; set; }
    public string? Error { get; set; }

    [JsonIgnore]
    public CancellationTokenSource Cts { get; } = new();
}

// ── Job events (for SSE) ─────────────────────────────────────────────────────────

public sealed record JobEvent(string JobId, string Type, int Progress, string? Message, JobStatus Status);

// ── Job engine ───────────────────────────────────────────────────────────────────

public sealed class JobEngine
{
    private readonly BlockingCollection<NscbJob> _queue = [];
    private readonly ConcurrentDictionary<string, NscbJob> _jobs = new();
    private readonly Action<JobEvent> _publish;
    private readonly Func<NscbJob, CancellationToken, Task> _runner;
    private readonly List<Task> _consumers = new();
    private readonly object _cgate = new();

    /// <param name="publish">Called (on any thread) to push SSE events.</param>
    /// <param name="runner">Async delegate that executes a single job.</param>
    public JobEngine(Action<JobEvent> publish, Func<NscbJob, CancellationToken, Task> runner, int concurrency = 1)
    {
        _publish = publish;
        _runner = runner;
        SetConcurrency(concurrency);   // spawn N consumers up front; can grow later via SetConcurrency
    }

    /// <summary>Raise the number of concurrent job consumers (never lowers below current; extra consumers
    /// simply idle until the queue drains). Lets a settings change to “workers” apply without restarting.</summary>
    public void SetConcurrency(int n)
    {
        lock (_cgate)
        {
            n = Math.Max(1, n);
            while (_consumers.Count < n) _consumers.Add(Task.Run(WorkerLoop));
        }
    }

    public IReadOnlyCollection<NscbJob> Jobs => _jobs.Values.ToArray();

    public NscbJob? GetJob(string id) => _jobs.TryGetValue(id, out var j) ? j : null;

    public NscbJob Submit(JobType type, IReadOnlyList<string> inputs, Dictionary<string, string>? options = null)
    {
        var job = new NscbJob { Type = type, Inputs = inputs, Options = options ?? [] };
        _jobs[job.Id] = job;
        _queue.Add(job);
        _publish(new JobEvent(job.Id, "queued", 0, null, JobStatus.Queued));
        return job;
    }

    public bool Cancel(string id)
    {
        if (!_jobs.TryGetValue(id, out var job)) return false;
        if (job.Status is JobStatus.Done or JobStatus.Failed or JobStatus.Cancelled) return false;
        job.Cts.Cancel();
        return true;
    }

    private async Task WorkerLoop()
    {
        foreach (var job in _queue.GetConsumingEnumerable())
        {
            job.Status = JobStatus.Running;
            job.StartedAt = DateTime.UtcNow;
            _publish(new JobEvent(job.Id, "start", 0, null, JobStatus.Running));

            try
            {
                await _runner(job, job.Cts.Token);
                job.Status = JobStatus.Done;
            }
            catch (OperationCanceledException)
            {
                job.Status = JobStatus.Cancelled;
            }
            catch (Exception ex)
            {
                job.Status = JobStatus.Failed;
                job.Error = ex.Message;
                _publish(new JobEvent(job.Id, "error", job.ProgressPct, ex.Message, job.Status));
            }
            finally
            {
                job.FinishedAt = DateTime.UtcNow;
                _publish(new JobEvent(job.Id, "done", job.ProgressPct, job.Error, job.Status));
            }
        }
    }

    /// <summary>Report progress from a running job (0–100 percent).</summary>
    public void ReportProgress(NscbJob job, long done, long total)
    {
        job.BytesDone = done;
        job.BytesTotal = total;
        job.ProgressPct = total > 0 ? (int)Math.Min(100, done * 100 / total) : 0;
        _publish(new JobEvent(job.Id, "progress", job.ProgressPct, null, job.Status));
    }

    public void ReportLog(NscbJob job, string msg)
    {
        _publish(new JobEvent(job.Id, "log", job.ProgressPct, msg, job.Status));
    }

    public void Dispose() => _queue.CompleteAdding();
}
