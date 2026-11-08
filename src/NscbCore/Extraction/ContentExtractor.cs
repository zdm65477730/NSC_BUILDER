using LibHac.Fs;
using LibHac.FsSystem;
using LibHac.Tools.FsSystem.NcaUtils;
using NscbCore.Formats;
using NscbCore.Keys;
using IOPath = System.IO.Path;

namespace NscbCore.Extraction;

public enum ExtractFilter { All, Program, Meta, Control, Manual, Data, PublicData, Ticket, Cert, Xml, Html, Jpg, NcaOnly }

/// <summary>
/// Extract individual file types out of an NSP/XCI (equivalent to NSCB's --NSP_copy_* / --XCI_copy_*).
/// Files are copied verbatim (NCAs stay encrypted), so no hash chain work is needed.
/// </summary>
public static class ContentExtractor
{
    public static List<string> Extract(
        string containerPath, string outDir, NscbKeys keys, ExtractFilter filter,
        Action<long>? progress = null, CancellationToken ct = default)
    {
        Directory.CreateDirectory(outDir);
        ContainerKind kind = ContainerReader.DetectKind(containerPath);
        List<ContainerEntry> entries;
        using (var probe = File.OpenRead(containerPath))
            entries = ContainerReader.ReadEntries(probe, kind)
                .Where(e => !e.Name.StartsWith("normal/", StringComparison.OrdinalIgnoreCase)
                         && !e.Name.StartsWith("logo/", StringComparison.OrdinalIgnoreCase))
                .ToList();

        var produced = new List<string>();
        byte[] buf = new byte[0x80000];
        using var src = File.OpenRead(containerPath);
        foreach (var e in entries)
        {
            ct.ThrowIfCancellationRequested();
            if (!Matches(e, src, keys, filter)) continue;
            string dst = IOPath.Combine(outDir, IOPath.GetFileName(e.Name));
            using var o = File.Create(dst);
            src.Position = e.Offset;
            long rem = e.Size;
            while (rem > 0)
            {
                int r = src.Read(buf, 0, (int)Math.Min(buf.Length, rem));
                if (r == 0) break;
                o.Write(buf, 0, r);
                rem -= r;
                progress?.Invoke(r);
            }
            produced.Add(dst);
        }
        return produced;
    }

    private static bool Matches(ContainerEntry e, Stream src, NscbKeys keys, ExtractFilter f)
    {
        if (f == ExtractFilter.All) return true;
        if (f == ExtractFilter.Ticket) return e.IsTicket;
        if (f == ExtractFilter.Cert)   return e.IsCert;
        if (f == ExtractFilter.Xml)    return e.IsXml;
        if (f == ExtractFilter.Html)   return e.IsHtml;
        if (f == ExtractFilter.Jpg)    return e.IsJpg;
        if (f == ExtractFilter.NcaOnly) return e.IsNca || e.IsNcz;

        // By NCA content type: sniff the plaintext at 0x205 in the decrypted header.
        if (e.IsNca || e.IsNcz)
        {
            try
            {
                long saved = src.Position;
                src.Position = e.Offset;
                byte[] hdr = new byte[Math.Min(0x4000, e.Size)];
                src.ReadExactly(hdr);
                src.Position = saved;
                using var ms = new MemoryStorage(hdr);
                var nca = new Nca(keys.KeySet, ms);
                NcaContentType ct = nca.Header.ContentType;
                return f switch
                {
                    ExtractFilter.Program    => ct == NcaContentType.Program,
                    ExtractFilter.Meta       => ct == NcaContentType.Meta,
                    ExtractFilter.Control    => ct == NcaContentType.Control,
                    ExtractFilter.Manual     => ct == NcaContentType.Manual,
                    ExtractFilter.Data       => ct == NcaContentType.Data,
                    ExtractFilter.PublicData => ct == NcaContentType.PublicData,
                    _ => false,
                };
            }
            catch { return false; }
        }
        return false;
    }
}
