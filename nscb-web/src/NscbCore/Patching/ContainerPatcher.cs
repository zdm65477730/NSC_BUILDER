using System.Buffers.Binary;
using LibHac.Common.Keys;
using LibHac.FsSystem;
using LibHac.Tools.FsSystem.NcaUtils;
using NscbCore.Formats;
using NscbCore.Info;
using NscbCore.Keys;
using NscbCore.Nsz;
using NscbCore.Crypto;

namespace NscbCore.Patching;

/// <summary>
/// Container-level patching: applies NCA patches to all relevant entries in NSP/NSZ/XCI/XCZ files.
/// Operations are done in-place (the output file is a copy of the input with patches applied).
/// </summary>
public static class ContainerPatcher
{
    /// <summary>
    /// Patch all Meta NCAs in the container to set RequiredSystemVersion = <paramref name="newRsv"/>.
    /// Also optionally patches the XCI Game_info FW field when <paramref name="patchXciHeader"/> is true.
    /// </summary>
    public static void PatchCnmtRsv(
        string containerPath, string outputPath, NscbKeys keys, uint newRsv,
        bool patchXciHeader = true,
        Action<long>? progress = null, CancellationToken ct = default)
    {
        ContainerKind kind = ContainerReader.DetectKind(containerPath);
        if (kind is not (ContainerKind.Nsp or ContainerKind.Nsz or ContainerKind.Xci or ContainerKind.Xcz))
            throw new InvalidDataException($"Unsupported container: {kind}");

        // Copy to output first (so we modify the copy in-place).
        File.Copy(containerPath, outputPath, overwrite: true);

        using var fs = new FileStream(outputPath, FileMode.Open, FileAccess.ReadWrite);

        // Read entries (Meta NCAs only).
        List<ContainerEntry> allEntries;
        fs.Position = 0;
        allEntries = ContainerReader.ReadEntries(fs, kind);

        int patchedCount = 0;
        foreach (var entry in allEntries)
        {
            ct.ThrowIfCancellationRequested();
            // Strict path: modify the Meta cnmt's RSV field and rebuild the NCA hash chain so
            // the result passes a full verifier. Only PFS0/Sha256 Meta sections qualify
            // (NcaCnmtPatcher returns false otherwise).
            if (!entry.Name.EndsWith(".cnmt.nca", StringComparison.OrdinalIgnoreCase)) continue;
            bool ok = NcaCnmtPatcher.SetCnmtRequiredSystemVersion(
                fs, entry.Offset, entry.Size, keys.KeySet, newRsv);
            if (ok) patchedCount++;
            progress?.Invoke(entry.Size);
        }

        if (patchedCount == 0)
            throw new InvalidOperationException("No rebuildable Meta (PFS0/Sha256) NCAs found to patch.");

        // For XCI: also patch the Game_info FW field.
        if (patchXciHeader && (kind == ContainerKind.Xci || kind == ContainerKind.Xcz)
            && keys.HasXciHeaderKey)
        {
            Span<byte> xciKey = stackalloc byte[0x10];
            if (keys.TryCopyXciHeaderKey(xciKey))
            {
                fs.Position = 0;
                // NSCB writes RSV into Game_info as-is; we do the same.
                NcaPatcher.PatchXciGameInfoFwVersion(fs, xciKey, newRsv);
            }
        }
    }

    /// <summary>
    /// Change the key generation bytes in all Program and Data NCAs (not Meta) to
    /// <paramref name="newKeyGen"/>. Re-encrypts the key area with the new key_area_key.
    /// </summary>
    public static int PatchKeyGeneration(
        string containerPath, string outputPath, NscbKeys keys, int newKeyGen,
        Action<long>? progress = null, CancellationToken ct = default)
    {
        ContainerKind kind = ContainerReader.DetectKind(containerPath);
        if (kind is not (ContainerKind.Nsp or ContainerKind.Nsz or ContainerKind.Xci or ContainerKind.Xcz))
            throw new InvalidDataException($"Unsupported container: {kind}");
        if (!keys.HasHeaderKey)
            throw new InvalidOperationException("prod.keys with header_key is required to rewrite NCA headers.");

        File.Copy(containerPath, outputPath, overwrite: true);
        using var fs = new FileStream(outputPath, FileMode.Open, FileAccess.ReadWrite);

        List<ContainerEntry> entries;
        fs.Position = 0;
        entries = ContainerReader.ReadEntries(fs, kind);

        int changed = 0;
        foreach (var entry in entries)
        {
            ct.ThrowIfCancellationRequested();
            if (!entry.IsNca && !entry.IsNcz) continue;
            if (NcaPatcher.PatchKeyGeneration(fs, entry.Offset, entry.Size, keys.KeySet, newKeyGen)) changed++;
            progress?.Invoke(entry.Size);
        }
        return changed;
    }

    /// <summary>In-place keygen lowering on the file itself (no copy): edits each NCA/NCZ embedded header. Supports NSZ/XCZ.</summary>
    public static (int Changed, Dictionary<string, byte[]> NewHashesByNcaId) PatchKeyGenerationInPlace(string containerPath, NscbKeys keys, int newKeyGen,
        Action<long>? progress = null, CancellationToken ct = default)
    {
        var newHashes = new Dictionary<string, byte[]>(StringComparer.OrdinalIgnoreCase);
        // Rights-id NCAs need the game title key; with title.keys removed, derive it from the container's own ticket.
        TicketTitleKeys.RegisterFromContainer(keys, containerPath);
        ContainerKind kind = ContainerReader.DetectKind(containerPath);
        if (kind is not (ContainerKind.Nsp or ContainerKind.Nsz or ContainerKind.Xci or ContainerKind.Xcz))
            throw new InvalidDataException($"Unsupported container: {kind}");
        if (!keys.HasHeaderKey)
            throw new InvalidOperationException("prod.keys with header_key is required to rewrite NCA headers.");

        using var fs = new System.IO.FileStream(containerPath, System.IO.FileMode.Open, System.IO.FileAccess.ReadWrite);
        fs.Position = 0;
        var entries = ContainerReader.ReadEntries(fs, kind);
        int changed = 0;
        foreach (var entry in entries)
        {
            ct.ThrowIfCancellationRequested();
            if (!entry.IsNca && !entry.IsNcz) continue;
            if (!NcaPatcher.PatchKeyGeneration(fs, entry.Offset, entry.Size, keys.KeySet, newKeyGen)) { progress?.Invoke(entry.Size); continue; }
            changed++;
            // Capture the re-wrapped NCA's NEW whole-file SHA256 (raw .nca only; NSZ/XCZ contents are handled
            // separately and not synced here) so SyncContentHashes can update the cnmt record hash.
            if (entry.IsNca)
            {
                string id = System.IO.Path.GetFileNameWithoutExtension(entry.BaseName);
                if (id.Length >= 32) newHashes[id[..32].ToLowerInvariant()] = RangeSha256(fs, entry.Offset, entry.Size);
            }
            progress?.Invoke(entry.Size);
        }
        return (changed, newHashes);
    }

    /// <summary>SHA256 of a byte range in a file stream, streamed (no full load). Restores position.</summary>
    private static byte[] RangeSha256(System.IO.FileStream fs, long off, long size)
    {
        using var sha = System.Security.Cryptography.SHA256.Create();
        long saved = fs.Position; fs.Position = off;
        long rem = size; byte[] buf = new byte[1 << 16];
        while (rem > 0) { int r = fs.Read(buf, 0, (int)Math.Min(buf.Length, rem)); if (r <= 0) break; sha.TransformBlock(buf, 0, r, null, 0); rem -= r; }
        sha.TransformFinalBlock(System.Array.Empty<byte>(), 0, 0);
        fs.Position = saved; return sha.Hash!;
    }

    /// <summary>
    /// After keygen lowering, rewrite the cnmt content-record hashes to the re-wrapped NCAs' new whole-file
    /// SHA256 so a strict SHA256 verifier (NSGManager) passes again. Handled only for raw .nca Metas in
    /// NSP/XCI (size-preserving chain rebuild via NcaCnmtPatcher.RewriteContentHashes); NSZ/XCZ are skipped
    /// here (their compressed Metas would need a decompress→edit→recompress path). The fixed-key Signature1
    /// cannot be re-created and still fails — same inherent limitation as NSCB.
    /// </summary>
    public static void SyncContentHashes(string containerPath, IReadOnlyDictionary<string, byte[]> newHashesByNcaId, NscbKeys keys)
    {
        if (newHashesByNcaId is null || newHashesByNcaId.Count == 0) return;
        ContainerKind kind = ContainerReader.DetectKind(containerPath);
        if (kind is not (ContainerKind.Nsp or ContainerKind.Xci)) return;
        using var fs = new System.IO.FileStream(containerPath, System.IO.FileMode.Open, System.IO.FileAccess.ReadWrite);
        fs.Position = 0;
        foreach (var e in ContainerReader.ReadEntries(fs, kind))
        {
            if (!e.IsNca || !e.BaseName.EndsWith(".cnmt.nca", StringComparison.OrdinalIgnoreCase)) continue;
            try { NcaCnmtPatcher.RewriteContentHashes(fs, e.Offset, e.Size, keys.KeySet, newHashesByNcaId); } catch { }
        }
    }

    /// <summary>
    /// Remove title-key encryption from all NCAs that have a RightsID.
    /// Re-encrypts content with the application key_area_key and clears RightsID.
    /// The title key is derived on demand from the container's own ticket (+ prod.keys); no title.keys file is used.
    /// </summary>
    public static void RemoveTitleKeyCrypto(
        string containerPath, string outputPath, NscbKeys keys,
        Action<long>? progress = null, CancellationToken ct = default)
    {
        ContainerKind kind = ContainerReader.DetectKind(containerPath);
        if (kind is not (ContainerKind.Nsp or ContainerKind.Nsz))
            throw new InvalidDataException($"Title key removal currently supports NSP/NSZ only; got: {kind}");
        if (!keys.HasHeaderKey)
            throw new InvalidOperationException("prod.keys with header_key is required for title key removal.");

        File.Copy(containerPath, outputPath, overwrite: true);
        using var fs = new FileStream(outputPath, FileMode.Open, FileAccess.ReadWrite);

        List<ContainerEntry> entries;
        fs.Position = 0;
        entries = ContainerReader.ReadEntries(fs, kind);

        foreach (var entry in entries)
        {
            ct.ThrowIfCancellationRequested();
            if (!entry.IsNca) continue;

            // RemoveTitleKey decrypts the header itself and detects RightsID/keygen via LibHac
            // (returns early-and-success for NCAs that are already null-crypto). The raw 0x230
            // bytes are ciphertext on an encrypted header, so they must not be sniffed here.
            bool ok = NcaPatcher.RemoveTitleKey(fs, entry.Offset, entry.Size, keys.KeySet);
            progress?.Invoke(entry.Size);
            if (!ok)
                throw new InvalidOperationException(
                    $"Failed to remove title key from NCA '{entry.BaseName}'. " +
                    "Ensure prod.keys covers this firmware (master_key) and the container carries a decryptable retail ticket.");
        }
    }

    /// <summary>
    /// set_cnmt_titleid: rewrite the TitleID in the container's Meta cnmt and rebuild the NCA
    /// hash chain so the result passes strict verification. Copies the container to
    /// <paramref name="outputPath"/> first.
    /// </summary>
    public static void SetCnmtTitleId(string containerPath, string outputPath, NscbKeys keys, ulong titleId,
        Action<long>? progress = null, CancellationToken ct = default)
        => PatchFirstCnmt(containerPath, outputPath, keys,
            (fs, off, size) => NcaCnmtPatcher.SetCnmtTitleId(fs, off, size, keys.KeySet, titleId), progress, ct);

    /// <summary>set_cnmt_version: rewrite the TitleVersion (u32) in the Meta cnmt + rebuild chain.</summary>
    public static void SetCnmtTitleVersion(string containerPath, string outputPath, NscbKeys keys, uint version,
        Action<long>? progress = null, CancellationToken ct = default)
        => PatchFirstCnmt(containerPath, outputPath, keys,
            (fs, off, size) => NcaCnmtPatcher.SetCnmtTitleVersion(fs, off, size, keys.KeySet, version), progress, ct);

    private static void PatchFirstCnmt(string containerPath, string outputPath, NscbKeys keys,
        Func<FileStream, long, long, bool> patch, Action<long>? progress, CancellationToken ct)
    {
        ContainerKind kind = ContainerReader.DetectKind(containerPath);
        if (kind is not (ContainerKind.Nsp or ContainerKind.Nsz or ContainerKind.Xci or ContainerKind.Xcz))
            throw new InvalidDataException($"Unsupported container: {kind}");
        if (!keys.HasHeaderKey)
            throw new InvalidOperationException("prod.keys with header_key is required to rewrite NCA headers.");

        ContainerEntry? meta;
        using (var probe = File.OpenRead(containerPath))
            meta = ContainerReader.ReadEntries(probe, kind)
                .FirstOrDefault(e => e.Name.EndsWith(".cnmt.nca", StringComparison.OrdinalIgnoreCase));
        if (meta is null) throw new InvalidOperationException("No Meta (cnmt) NCA found in container.");

        File.Copy(containerPath, outputPath, overwrite: true);
        using var fs = new FileStream(outputPath, FileMode.Open, FileAccess.ReadWrite);
        ct.ThrowIfCancellationRequested();
        if (!patch(fs, meta.Offset, meta.Size))
            throw new InvalidOperationException("Failed to patch cnmt / rebuild hash chain (unsupported section hash type?).");
        progress?.Invoke(meta.Size);
    }

    /// <summary>
    /// setcgame / seteshop: rewrite the distribution-type byte of every NCA header in the
    /// container (GameCard ⇄ Download) in place. Requires the header key. Returns the number
    /// of NCA headers updated.
    /// </summary>
    public static int SetDistribution(
        string containerPath, string outputPath, NscbKeys keys, NcaDistribution dist,
        Action<long>? progress = null, CancellationToken ct = default)
    {
        ContainerKind kind = ContainerReader.DetectKind(containerPath);
        if (kind is not (ContainerKind.Nsp or ContainerKind.Nsz or ContainerKind.Xci or ContainerKind.Xcz))
            throw new InvalidDataException($"Unsupported container: {kind}");
        if (!keys.HasHeaderKey)
            throw new InvalidOperationException("prod.keys with header_key is required to rewrite NCA headers.");

        List<ContainerEntry> ncaEntries;
        using (var probe = File.OpenRead(containerPath))
            ncaEntries = ContainerReader.ReadEntries(probe, kind)
                .Where(e => e.IsNca && e.Size >= XtsHelper.HeaderSize)
                .ToList();
        if (ncaEntries.Count == 0)
            throw new InvalidOperationException("No NCA entries found.");

        File.Copy(containerPath, outputPath, overwrite: true);
        using var fs = new FileStream(outputPath, FileMode.Open, FileAccess.ReadWrite);

        int updated = 0;
        foreach (var entry in ncaEntries)
        {
            ct.ThrowIfCancellationRequested();
            if (NcaPatcher.SetDistribution(fs, entry.Offset, entry.Size, keys.KeySet, dist))
                updated++;
            progress?.Invoke(entry.Size);
        }
        return updated;
    }

    /// <summary>
    /// MODE 9 restore: reconstruct each NCA's original secure-block1 (flipping the GameCard/Download
    /// distribution byte) and rewrite it in place when the result validates against the NCA's own
    /// RSA-PSS signature1. Self-contained — no external backup needed. Returns (#headers-changed, #restorable-checks-passed).
    /// </summary>
    public static (int Changed, int Valid) Restore(
        string containerPath, string outputPath, NscbKeys keys,
        Action<long>? progress = null, CancellationToken ct = default)
    {
        ContainerKind kind = ContainerReader.DetectKind(containerPath);
        if (kind is not (ContainerKind.Nsp or ContainerKind.Xci))
            throw new InvalidDataException("Restore requires an uncompressed NSP/XCI (decompress NSZ/XCZ first).");
        if (!keys.HasHeaderKey)
            throw new InvalidOperationException("prod.keys with header_key is required to rewrite NCA headers.");

        List<ContainerEntry> ncaEntries;
        using (var probe = File.OpenRead(containerPath))
            ncaEntries = ContainerReader.ReadEntries(probe, kind)
                .Where(e => e.IsNca && e.Size >= XtsHelper.HeaderSize)
                .ToList();

        File.Copy(containerPath, outputPath, overwrite: true);
        using var fs = new FileStream(outputPath, FileMode.Open, FileAccess.ReadWrite);

        int changed = 0, valid = 0;
        foreach (var entry in ncaEntries)
        {
            ct.ThrowIfCancellationRequested();
            byte[] header = new byte[XtsHelper.HeaderSize];
            fs.Position = entry.Offset;
            fs.ReadExactly(header);
            var r = NcaHeaderRestorer.RestoreHeaderInPlace(header, keys.KeySet);
            if (r.SignatureValid) valid++;
            if (r.Changed)
            {
                fs.Position = entry.Offset;
                fs.Write(header);
                changed++;
            }
            progress?.Invoke(entry.Size);
        }
        return (changed, valid);
    }
}
