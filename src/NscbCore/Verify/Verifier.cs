using LibHac.Fs;
using LibHac.FsSystem;
using LibHac.Tools.FsSystem;
using LibHac.Tools.FsSystem.NcaUtils;
using NscbCore.Formats;
using NscbCore.Keys;
using NscbCore.Nsz;
using IOPath = System.IO.Path;

namespace NscbCore.Verify;

public sealed record VerifyFile(string Name, string Type, bool Ok, string? Error);

public sealed record VerifyResult(string Path, bool Ok, string? Error, int TotalFiles, int CheckedFiles,
    List<string> Failures, List<VerifyFile> Files);

/// <summary>
/// Verify NCA hash integrity across a container using LibHac's IntegrityCheckLevel.ErrorOnInvalid,
/// mirroring NSCB's --verify / mass_verification actions.
/// </summary>
public static class Verifier
{
    public static VerifyResult VerifyContainer(string path, NscbKeys keys, CancellationToken ct = default)
    {
        TicketTitleKeys.RegisterFromContainer(keys, path);   // recover rights-id title keys from the container's own tickets
        var failures = new List<string>();
        var files = new List<VerifyFile>();
        int total = 0, checkedFiles = 0;
        try
        {
            ContainerKind kind = ContainerReader.DetectKind(path);
            List<ContainerEntry> entries;
            using (var probe = File.OpenRead(path))
                entries = ContainerReader.ReadEntries(probe, kind);
            total = entries.Count;

            // Only NCA / NCZ entries can be hash-verified. Verify them in parallel — each entry opens its OWN
            // file handles (no shared stream state) and only reads the (immutable) KeySet, so it is race-free.
            // The degree is modest: a single large compressed Program usually dominates the wall time anyway.
            var slots = new List<int>();
            for (int i = 0; i < entries.Count; i++) if (entries[i].IsNca || entries[i].IsNcz) slots.Add(i);

            var results = new (VerifyFile vf, bool chk)[slots.Count];
            int degree = Math.Max(1, Math.Min(4, Environment.ProcessorCount));
            Parallel.For(0, slots.Count,
                new ParallelOptions { MaxDegreeOfParallelism = degree, CancellationToken = ct },
                k => results[k] = VerifyEntry(path, entries[slots[k]], keys, ct));

            foreach (var (vf, chk) in results)
            {
                files.Add(vf);
                if (chk) checkedFiles++;
                if (!vf.Ok) failures.Add($"{vf.Name}: {vf.Error}");
            }
            if (checkedFiles == 0 && total > 0)
                failures.Add("no NCA could be opened for verification (missing keys or unsupported container).");
            return new VerifyResult(path, failures.Count == 0, null, total, checkedFiles, failures, files);
        }
        catch (Exception ex) { return new VerifyResult(path, false, ex.Message, total, checkedFiles, failures, files); }
    }

    // Verify a single NCA/NCZ entry. Opens its own handles so it is safe to run concurrently with other entries.
    // Returns (result, whether the entry was actually hash-checked).
    private static (VerifyFile, bool) VerifyEntry(string path, ContainerEntry e, NscbKeys keys, CancellationToken ct)
    {
        string name = IOPath.GetFileName(e.Name);
        string type = "?";
        bool fileOk = true; string? fileErr = null; bool wasChecked = false;
        string? temp = null; string? tempDir = null;
        IDisposable? owner = null;
        try
        {
            IStorage ncaStor;
            if (e.IsNca)
            {
                var ls = new LocalStorage(path, FileAccess.Read);
                owner = ls;
                ncaStor = new SubStorage(ls, e.Offset, e.Size);
            }
            else
            {
                // .ncz → expand to a temp NCA (on a volume with room) so its IVFC/PFS0 hashes can be checked.
                long need = e.Size * 2 + (256L << 20);            // conservative decompressed-size estimate
                (temp, tempDir) = PickTempFile(need, path);
                using (var tf = new FileStream(temp, FileMode.Create, FileAccess.ReadWrite, FileShare.ReadWrite))
                using (var srcF = new FileStream(path, FileMode.Open, FileAccess.Read, FileShare.ReadWrite))
                using (var b = new BoundedReadStream(srcF, e.Offset, e.Size))
                    NczProcessor.Decompress(b, tf, null, ct);
                var lt = new LocalStorage(temp, FileAccess.Read);
                owner = lt;
                ncaStor = lt;
            }

            var nca = new Nca(keys.KeySet, ncaStor);
            type = nca.Header.ContentType.ToString();
            byte[] buf = new byte[0x40000];
            bool anySection = false;
            for (int i = 0; i < 4 && fileOk; i++)
            {
                if (!nca.CanOpenSection(i)) continue;
                anySection = true;
                var st = nca.OpenStorage(i, IntegrityCheckLevel.ErrorOnInvalid);
                st.GetSize(out long sz).ThrowIfFailure();
                long off = 0;
                while (off < sz)
                {
                    ct.ThrowIfCancellationRequested();
                    int chunk = (int)Math.Min(buf.Length, sz - off);
                    var rc = st.Read(off, buf.AsSpan(0, chunk));
                    if (rc.IsFailure()) { fileOk = false; fileErr = $"sec{i} @0x{off:X}: {rc}"; break; }
                    off += chunk;
                }
            }
            if (!anySection) { fileOk = false; fileErr = "no openable section (missing/wrong key?)"; }
            wasChecked = true;
        }
        catch (Exception ex) { fileOk = false; fileErr = ex.Message; }
        finally
        {
            owner?.Dispose();
            if (temp is not null) { try { File.Delete(temp); } catch { } }
            if (tempDir is not null) { try { Directory.Delete(tempDir, false); } catch { } }   // only if empty
        }
        return (new VerifyFile(name, type, fileOk, fileErr), wasChecked);
    }

    // Choose a temp path on a volume with enough free space for the decompressed NCA: system temp first (the
    // normal case), else a dedicated ".nscb-vtmp" on the SOURCE file's own volume (which held the .ncz). Throws a
    // clear, actionable error when nothing has room — previously this surfaced as a cryptic "verify failed".
    private static (string file, string? dir) PickTempFile(long neededBytes, string srcPath)
    {
        var candidates = new List<(string dir, bool owns)>();
        try { candidates.Add((IOPath.GetTempPath(), false)); } catch { }
        try
        {
            string root = IOPath.GetPathRoot(IOPath.GetFullPath(srcPath)) ?? "";
            if (root.Length > 0) candidates.Add((IOPath.Combine(root, ".nscb-vtmp"), true));
        }
        catch { }

        foreach (var (dir, owns) in candidates)
        {
            try
            {
                Directory.CreateDirectory(dir);
                string droot = IOPath.GetPathRoot(IOPath.GetFullPath(dir))!;
                var di = new DriveInfo(droot);
                if (di.IsReady && di.AvailableFreeSpace >= neededBytes)
                    return (IOPath.Combine(dir, "nscb-vf-" + Guid.NewGuid().ToString("N") + ".nca"), owns ? dir : null);
            }
            catch { }
        }
        throw new IOException(
            $"Not enough free space to verify the compressed NCA (needs ~{neededBytes / (1 << 20)} MB). " +
            "Free up space on the temp/system drive, or decompress the NSZ/XCZ to NSP/XCI and verify that instead.");
    }

    /// <summary>Verify every file in a folder and return aggregate results.</summary>
    public static List<VerifyResult> VerifyFolder(string folder, NscbKeys keys, CancellationToken ct = default)
    {
        var results = new List<VerifyResult>();
        IEnumerable<string> walk;
        try { walk = Directory.EnumerateFiles(folder, "*", System.IO.SearchOption.AllDirectories); }   // include subfolders
        catch { walk = Directory.EnumerateFiles(folder); }                                              // inaccessible dir → top-level
        foreach (var f in walk)
        {
            string ext = IOPath.GetExtension(f).ToLowerInvariant();
            if (ext is not (".nsp" or ".nsz" or ".xci" or ".xcz" or ".nca")) continue;
            ct.ThrowIfCancellationRequested();
            results.Add(VerifyContainer(f, keys, ct));
        }
        return results;
    }
}
