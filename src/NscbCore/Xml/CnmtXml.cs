using System.Text;
using LibHac.Fs;
using LibHac.FsSystem;
using LibHac.Ncm;
using LibHac.Tools.FsSystem;
using LibHac.Tools.FsSystem.NcaUtils;
using LibHac.Tools.Ncm;
using NscbCore.Formats;
using NscbCore.Info;
using NscbCore.Keys;
using IOPath = System.IO.Path;

namespace NscbCore.Xml;

/// <summary>
/// Generate NSCB-compatible cnmt XML from an NCA (Meta content type) or from a container
/// by extracting the first cnmt. Output shape matches NSCB's --xml_gen.
/// </summary>
public static class CnmtXml
{
    public static string GenerateFromContainer(string containerPath, NscbKeys keys)
    {
        ContainerKind kind = ContainerReader.DetectKind(containerPath);
        List<ContainerEntry> entries;
        using (var probe = File.OpenRead(containerPath))
            entries = ContainerReader.ReadEntries(probe, kind);
        var meta = entries.FirstOrDefault(e => e.Name.EndsWith(".cnmt.nca", StringComparison.OrdinalIgnoreCase)
                                           || e.Name.EndsWith(".cnmt.ncz", StringComparison.OrdinalIgnoreCase));
        if (meta is null) throw new InvalidDataException("no cnmt NCA in container");
        using var src = File.OpenRead(containerPath);
        src.Position = meta.Offset;
        byte[] raw = new byte[meta.Size]; src.ReadExactly(raw);
        using var ms = new MemoryStorage(raw);
        var nca = new Nca(keys.KeySet, ms);
        Cnmt cn = ReadFirstCnmt(nca) ?? throw new InvalidDataException("cnmt not readable");
        return Serialize(cn, IOPath.GetFileNameWithoutExtension(meta.Name));
    }

    public static Cnmt? ReadFirstCnmt(Nca nca)
    {
        if (!nca.CanOpenSection(0)) return null;
        var fsys = nca.OpenFileSystem(0, IntegrityCheckLevel.None);
        LibHac.Common.UniqueRef<LibHac.Fs.Fsa.IFile> h = default;
        var path = new LibHac.Fs.Path();
        foreach (var name in Enumerate(fsys))
        {
            if (!name.EndsWith(".cnmt", StringComparison.OrdinalIgnoreCase)) continue;
            path.Initialize(Encoding.UTF8.GetBytes("/" + name)).ThrowIfFailure();
            fsys.OpenFile(ref h, in path, LibHac.Fs.OpenMode.Read).ThrowIfFailure();
            h.Get.GetSize(out long sz).ThrowIfFailure();
            byte[] buf = new byte[sz];
            h.Get.Read(out _, 0, buf, LibHac.Fs.ReadOption.None).ThrowIfFailure();
            h.Destroy();
            return new Cnmt(new MemoryStream(buf));
        }
        return null;
    }

    private static IEnumerable<string> Enumerate(LibHac.Fs.Fsa.IFileSystem fs)
    {
        LibHac.Common.UniqueRef<LibHac.Fs.Fsa.IDirectory> d = default;
        var p = new LibHac.Fs.Path();
        p.Initialize(Encoding.UTF8.GetBytes("/")).ThrowIfFailure();
        fs.OpenDirectory(ref d, in p, LibHac.Fs.Fsa.OpenDirectoryMode.All).ThrowIfFailure();
        try
        {
            var buf = new LibHac.Fs.DirectoryEntry[64];
            while (true)
            {
                d.Get.Read(out long read, buf).ThrowIfFailure();
                for (int i = 0; i < read; i++)
                {
                    var nm = buf[i].Name.ItemsRo;
                    int e = nm.IndexOf((byte)0); if (e < 0) e = nm.Length;
                    yield return Encoding.UTF8.GetString(nm[..e]);
                }
                if (read < buf.Length) break;
            }
        }
        finally { d.Destroy(); }
    }

    public static string Serialize(Cnmt cn, string targetName)
    {
        var sb = new StringBuilder();
        sb.AppendLine("<?xml version=\"1.0\" encoding=\"utf-8\"?>");
        sb.AppendLine("<ContentMeta>");
        sb.AppendLine($"  <Type>{cn.Type}</Type>");
        sb.AppendLine($"  <Id>0x{cn.TitleId:x16}</Id>");
        sb.AppendLine($"  <Version>{cn.TitleVersion.Version}</Version>");
        // AddOnContent (DLC) cnmt can omit MinimumSystemVersion → guard, else GenXml throws on a DLC.
        uint minSv = 0;
        try { minSv = cn.MinimumSystemVersion.Version; } catch { minSv = 0; }
        sb.AppendLine($"  <RequiredDownloadSystemVersion>{minSv}</RequiredDownloadSystemVersion>");
        foreach (var ce in cn.ContentEntries)
        {
            sb.AppendLine("  <Content>");
            sb.AppendLine($"    <Type>{ce.Type}</Type>");
            sb.AppendLine($"    <Id>{NcaIdFormatter.ToHex(ce.NcaId ?? new byte[0x10])}</Id>");
            sb.AppendLine($"    <Size>{ce.Size}</Size>");
            sb.AppendLine($"    <Hash>{NcaIdFormatter.ToHex(ce.Hash ?? new byte[0x20])}</Hash>");
            sb.AppendLine("  </Content>");
        }
        sb.AppendLine("</ContentMeta>");
        return sb.ToString();
    }
}
