using System.IO;
using LibHac.Common;
using LibHac.Fs;
using LibHac.Spl;
using LibHac.Tools.Es;
using NscbCore.Formats;

namespace NscbCore.Keys;

/// <summary>
/// Recovers title keys from a container's OWN tickets and registers them into the shared KeySet's
/// ExternalKeySet — the same store ExternalKeyReader fills from title.keys. This lets rights-id NCAs be
/// opened with only prod.keys (the master keys), matching NSGManager/NUT: the game's title key no longer
/// has to appear in a title.keys / titles.json, so end users never need to dump it per-title.
///
/// Best-effort and idempotent: a common/key-area ticket (zero rights-id) or one whose master key is
/// absent is skipped (its GetTitleKey would fail), leaving the existing title.keys / titles.json path
/// as the fallback. Device-bound (personal) tickets genuinely cannot be recovered from public prod.keys.
/// </summary>
public static class TicketTitleKeys
{
    // ExternalKeySet is a shared List; serialise mutation. With the default serial job queue this is
    // uncontended; with Workers>1 the writes are locked and re-registering an existing key is a no-op.
    private static readonly object Gate = new();

    /// <summary>Register any recoverable title keys found in <paramref name="containerPath"/>'s tickets.
    /// Returns how many new (rights-id → title key) pairs were added.</summary>
    public static int RegisterFromContainer(NscbKeys? keys, string? containerPath)
    {
        if (keys is null || string.IsNullOrWhiteSpace(containerPath) || !File.Exists(containerPath)) return 0;
        int added = 0;
        try
        {
            ContainerKind kind = ContainerReader.DetectKind(containerPath);
            if (kind is not (ContainerKind.Nsp or ContainerKind.Nsz or ContainerKind.Xci or ContainerKind.Xcz)) return 0;

            List<ContainerEntry> entries;
            using (var probe = File.OpenRead(containerPath))
                entries = ContainerReader.ReadEntries(probe, kind);

            foreach (var e in entries)
            {
                if (!e.IsTicket || e.Size <= 0 || e.Size > 0x10000) continue;
                RightsId rid; AccessKey key;
                try
                {
                    byte[] tik = new byte[(int)e.Size];
                    using (var s = File.OpenRead(containerPath)) { s.Position = e.Offset; s.ReadExactly(tik); }
                    using var ms = new MemoryStream(tik);
                    var t = new Ticket(ms);
                    byte[] ridb = t.RightsId!;
                    if (ridb is null || ridb.Length < 0x10) continue;
                    bool zero = true; for (int i = 0; i < 0x10; i++) if (ridb[i] != 0) { zero = false; break; }
                    if (zero) continue;                            // key-area/common ticket → no rights-id key needed
                    byte[] tk = t.GetTitleKey(keys.KeySet);        // derive via titlekek[masterKeyRev] from prod.keys
                    if (tk is null || tk.Length < 0x10) continue;
                    rid = new RightsId(ridb);
                    key = new AccessKey(tk);
                }
                catch { continue; }                                // missing master key / odd ticket → skip, no crash
                lock (Gate)
                {
                    var eks = keys.KeySet.ExternalKeySet;
                    if (!eks.Contains(rid)) { eks.Add(rid, key); added++; }
                }
            }
        }
        catch { }
        return added;
    }
}
