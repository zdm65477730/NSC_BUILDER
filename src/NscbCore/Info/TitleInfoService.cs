using LibHac.Common;
using LibHac.Fs;
using LibHac.Fs.Fsa;
using LibHac.FsSystem;
using LibHac.Tools.Es;
using LibHac.Tools.FsSystem;
using LibHac.Tools.FsSystem.NcaUtils;
using LibHac.Tools.FsSystem.RomFs;
using LibHac.Ncm;
using LibHac.Tools.Ncm;
using System.Text;
using NscbCore.Formats;
using NscbCore.Keys;
using NscbCore.Nsz;

namespace NscbCore.Info;

/// <summary>
/// Extracts title information (cnmt / nacp / icon / firmware requirements)
/// from NSP/NSZ/XCI/XCZ containers and standalone NCA/NCZ files.
/// </summary>
public sealed class TitleInfoService
{
    private readonly NscbKeys _keys;

    public TitleInfoService(NscbKeys keys) => _keys = keys;

    public ContainerFileInfo GetFileInfo(string path)
    {
        var kind = ContainerReader.DetectKind(path);
        var info = new ContainerFileInfo
        {
            Path = path,
            Format = kind.ToString().ToLowerInvariant(),
            KeysAvailable = _keys.HasHeaderKey,
        };

        if (kind == ContainerKind.Unknown)
        {
            info.Error = "Unsupported file format";
            return info;
        }

        info.FileSize = new FileInfo(path).Length;

        using var fs = new FileStream(path, FileMode.Open, FileAccess.Read, FileShare.Read);
        using var storage = new LocalStorage(path, FileAccess.Read);

        if (kind is ContainerKind.Xci or ContainerKind.Xcz)
            ReadCardHeader(fs, info);

        List<ContainerEntry> entries;
        try
        {
            entries = ContainerReader.ReadEntries(fs, kind);
        }
        catch (Exception ex)
        {
            info.Error = ex.Message;
            return info;
        }

        int maxKg = -1;
        Cnmt? cnmt = null;
        NacpInfo? nacp = null;
        ulong? headerTitleId = null;
        bool hasTicket = false;
        bool titleKeyAvailable = false;
        bool hasTitleKeyCrypto = false;

        foreach (var entry in entries)
        {
            var e = new ContentEntryInfo
            {
                Name = entry.Name,
                Size = entry.Size,
                Compressed = entry.IsCompressed,
            };
            info.Contents.Add(e);

            try
            {
                if (entry.IsNcz)
                {
                    e.Kind = "ncz";
                    fs.Position = entry.Offset;
                    NczHeader ncz = NczHeader.Parse(fs);
                    var fields = NcaHeaderFields.Parse(ncz.NcaHeader);
                    FillEntryFromHeaderFields(e, fields);
                    maxKg = Math.Max(maxKg, fields.KeyGeneration);
                    hasTitleKeyCrypto |= fields.HasRightsId;
                    headerTitleId ??= fields.TitleId;

                    info.Compression = new CompressionInfo
                    {
                        IsBlockCompressed = ncz.IsBlockCompressed,
                        BlockSizeExponent = ncz.Block?.BlockSizeExponent ?? 0,
                        DecompressedSize = ncz.DecompressedSize,
                        SectionCount = ncz.Sections.Count,
                    };
                }
                else if (entry.IsNca)
                {
                    e.Kind = "nca";
                    var sub = new SubStorage(storage, entry.Offset, entry.Size);
                    var nca = new Nca(_keys.KeySet, sub);
                    FillEntryFromNca(e, nca);
                    maxKg = Math.Max(maxKg, nca.Header.KeyGeneration);
                    hasTitleKeyCrypto |= nca.Header.HasRightsId;
                    headerTitleId ??= nca.Header.TitleId;

                    if (nca.Header.ContentType == NcaContentType.Meta && cnmt is null)
                        cnmt = TryReadCnmt(nca);
                    else if (nca.Header.ContentType == NcaContentType.Control && nacp is null)
                        (nacp, _) = TryReadControl(nca);
                }
                else if (entry.IsTicket)
                {
                    e.Kind = "ticket";
                    hasTicket = true;
                    fs.Position = entry.Offset;
                    byte[] tikBuf = new byte[entry.Size];
                    fs.ReadExactly(tikBuf);
                    try
                    {
                        var tik = new Ticket(new MemoryStream(tikBuf));
                        byte[]? key = tik.GetTitleKey(_keys.KeySet);
                        if (key is { } k && k.Any(b => b != 0))
                        {
                            titleKeyAvailable = true;
                            e.HasTitleKeyCrypto = true;
                        }
                    }
                    catch (Exception ex)
                    {
                        info.Warnings.Add($"Ticket '{entry.Name}': {ex.Message}");
                    }
                }
                else if (entry.IsCert)
                    e.Kind = "cert";
                else if (entry.IsXml)
                    e.Kind = "xml";
                else if (entry.IsHtml)
                    e.Kind = "html";
                else
                    e.Kind = "other";
            }
            catch (Exception ex)
            {
                e.Error = ex.Message;
            }
        }

        // Aggregate title metadata.
        if (cnmt is not null)
        {
            info.TitleId = cnmt.TitleId.ToString("x16");
            info.TitleType = ContentMetaTypeStrings.From((byte)cnmt.Type);
            info.BaseTitleId = GetBaseTitleId(cnmt.TitleId, cnmt.Type).ToString("x16");
            info.TitleVersion = FormatTitleVersion(cnmt.TitleVersion);
            info.TitleVersionRaw = cnmt.TitleVersion.Version;
            // Some cnmt — notably AddOnContent (DLC) — omit MinimumSystemVersion, so guard the access;
            // otherwise GetFileInfo throws and callers (e.g. pack-name G/U/D classification) silently drop the title.
            uint rsv = 0;
            try { rsv = cnmt.MinimumSystemVersion.Version; } catch { rsv = 0; }
            info.RequiredSystemVersion = rsv != 0 ? FirmwareTables.FwStringFromRsv(rsv) : null;

            foreach (var ce in cnmt.ContentEntries)
            {
                string id = NcaIdFormatter.ToHex(ce.NcaId);
                var match = info.Contents.FirstOrDefault(c =>
                    !c.Compressed && c.Name.Contains(id, StringComparison.OrdinalIgnoreCase));
                if (match is null) continue;
                match.NcaId = id;
                match.NcaType ??= ContentTypeStrings.From((byte)ce.Type);
            }
        }

        if (nacp is not null)
        {
            info.TitleName ??= nacp.DisplayName;
            info.Publisher = nacp.Publisher;
            info.DisplayVersion = nacp.DisplayVersion;
        }

        info.TitleId ??= headerTitleId?.ToString("x16");
        info.TitleType ??= headerTitleId is { } tid ? InferTitleType(tid) : null;
        info.BaseTitleId ??= headerTitleId is { } tid2 ? InferBaseTitleId(tid2).ToString("x16") : null;

        if (maxKg >= 0)
        {
            info.KeyGeneration = maxKg;
            info.FirmwareRangeFromKg = FirmwareTables.FwRangeForKeyGeneration(maxKg);
        }

        info.HasTitleKeyCrypto = hasTitleKeyCrypto;
        info.HasTicket = hasTicket;
        info.TitleKeyAvailable = titleKeyAvailable;
        if (hasTitleKeyCrypto && !titleKeyAvailable)
            info.Warnings.Add("Title key crypto detected but the title key could not be derived \u2014 prod.keys must cover this firmware (master_key) and the container must carry a decryptable retail ticket (title.keys is no longer used).");

        info.FirmwareRequirement = BuildFirmwareSummary(info);
        info.HasIcon = nacp is not null; // icon lives in the control NCA alongside nacp
        return info;
    }

    /// <summary>Extracts the first icon (256px JPEG) from the control NCA, if present.</summary>
    public (byte[] Data, string ContentType)? GetIcon(string path)
    {
        var kind = ContainerReader.DetectKind(path);
        if (kind is not (ContainerKind.Nsp or ContainerKind.Nsz or ContainerKind.Xci
                or ContainerKind.Xcz or ContainerKind.Nca))
            return null;

        using var fs = new FileStream(path, FileMode.Open, FileAccess.Read, FileShare.Read);
        using var storage = new LocalStorage(path, FileAccess.Read);

        List<ContainerEntry> entries;
        try
        {
            entries = ContainerReader.ReadEntries(fs, kind);
        }
        catch
        {
            return null;
        }

        foreach (var entry in entries)
        {
            if (!entry.IsNca || entry.IsCompressed)
                continue;
            try
            {
                var sub = new SubStorage(storage, entry.Offset, entry.Size);
                var nca = new Nca(_keys.KeySet, sub);
                if (nca.Header.ContentType != NcaContentType.Control)
                    continue;

                (_, byte[]? icon) = TryReadControl(nca);
                if (icon is { Length: > 0 })
                    return (icon, "image/jpeg");
            }
            catch
            {
                // try next control NCA
            }
        }

        return null;
    }

    private void ReadCardHeader(FileStream fs, ContainerFileInfo info)
    {
        try
        {
            var card = XciReader.ReadCardHeader(fs, _keys.KeySet.XciHeaderKey.DataRo);
            info.Card = new CardHeaderInfo
            {
                RomSizeFlag = card.RomSizeFlag,
                RomSize = FirmwareTables.CardSizeName(card.RomSizeFlag),
                PackageId = card.PackageId,
                ValidDataEndAddress = card.ValidDataEndAddress,
                FirmwareVersionRaw = card.FwVersion,
                FirmwareVersion = card.FwVersion is { } rsv
                    ? FirmwareTables.FwStringFromRsv((uint)rsv)
                    : null,
                KekIndex = card.KekIndex,
                TitleKeyDecIndex = card.TitleKeyDecIndex,
            };
        }
        catch (Exception ex)
        {
            info.Warnings.Add($"Card header: {ex.Message}");
        }
        finally
        {
            fs.Position = 0;
        }
    }

    private static void FillEntryFromNca(ContentEntryInfo e, Nca nca)
    {
        e.NcaType = nca.Header.ContentType.ToString();
        e.Distribution = nca.Header.DistributionType.ToString();
        e.TitleId = nca.Header.TitleId;
        e.KeyGeneration = nca.Header.KeyGeneration;
        e.HasTitleKeyCrypto = nca.Header.HasRightsId;
        e.FirmwareRangeFromKg = FirmwareTables.FwRangeForKeyGeneration(nca.Header.KeyGeneration);
    }

    private static void FillEntryFromHeaderFields(ContentEntryInfo e, NcaHeaderFields f)
    {
        e.NcaType = NcaHeaderFields.ContentTypeString(f.ContentTypeByte);
        e.Distribution = NcaHeaderFields.DistributionTypeString(f.DistributionType);
        e.TitleId = f.TitleId;
        e.KeyGeneration = f.KeyGeneration;
        e.HasTitleKeyCrypto = f.HasRightsId;
        e.FirmwareRangeFromKg = FirmwareTables.FwRangeForKeyGeneration(f.KeyGeneration);
    }

    private (NacpInfo? Nacp, byte[]? Icon) TryReadControl(Nca nca)
    {
        using var fs = OpenAnyFileSystem(nca);
        if (fs is null) return (null, null);
        List<string> names = ListFsEntries(fs, "/");

        string? nacpName = names.FirstOrDefault(n =>
            n.Equals("control.dat", StringComparison.OrdinalIgnoreCase)
            || n.EndsWith(".nacp", StringComparison.OrdinalIgnoreCase));
        string? iconName = names.FirstOrDefault(n =>
            n.StartsWith("icon_", StringComparison.OrdinalIgnoreCase)
            && (n.EndsWith(".dat", StringComparison.OrdinalIgnoreCase)
                || n.EndsWith(".jpg", StringComparison.OrdinalIgnoreCase)));

        NacpInfo? nacp = null;
        if (nacpName is not null)
            nacp = NacpInfo.Parse(ReadFsFile(fs, "/" + nacpName));

        byte[]? icon = null;
        if (iconName is not null)
            icon = ReadFsFile(fs, "/" + iconName);

        return (nacp, icon);
    }

    private static Cnmt? TryReadCnmt(Nca nca)
    {
        using var fs = OpenAnyFileSystem(nca);
        if (fs is null) return null;
        foreach (string name in ListFsEntries(fs, "/"))
        {
            if (!name.EndsWith(".cnmt", StringComparison.OrdinalIgnoreCase))
                continue;
            byte[] data = ReadFsFile(fs, "/" + name);
            return new Cnmt(new MemoryStream(data));
        }

        return null;
    }

    /// <summary>
    /// Opens whichever filesystem section is present: some NCAs (Meta / Control) put
    /// their content at section 0 (PFS0), others at section 1 (RomFS).
    /// </summary>
    private static IFileSystem? OpenAnyFileSystem(Nca nca)
    {
        for (int i = 0; i < 4; i++)
        {
            if (!nca.CanOpenSection(i)) continue;
            try
            {
                return nca.OpenFileSystem(i, IntegrityCheckLevel.None);
            }
            catch { /* not a filesystem section, keep searching */ }
        }
        return null;
    }

    private static LibHac.Fs.Path ToFsPath(string path)
    {
        var p = new LibHac.Fs.Path();
        p.Initialize(Encoding.UTF8.GetBytes(path)).ThrowIfFailure();
        return p;
    }

    private static List<string> ListFsEntries(IFileSystem fs, string dir)
    {
        UniqueRef<IDirectory> handle = default;
        fs.OpenDirectory(ref handle, ToFsPath(dir), OpenDirectoryMode.All).ThrowIfFailure();
        try
        {
            var names = new List<string>();
            var buffer = new DirectoryEntry[64];
            while (true)
            {
                handle.Get.Read(out long read, buffer).ThrowIfFailure();
                for (int i = 0; i < read; i++)
                    names.Add(DecodeName(buffer[i].Name));
                if (read < buffer.Length) break;
            }
            return names;
        }
        finally { handle.Destroy(); }
    }

    /// <summary>Decodes a DirectoryEntry.Name (fixed-size 769-byte buffer, NUL-terminated) to a string.</summary>
    private static string DecodeName(LibHac.Common.FixedArrays.Array769<byte> nameArr)
    {
        ReadOnlySpan<byte> span = nameArr.ItemsRo;
        int end = span.IndexOf((byte)0);
        if (end < 0) end = span.Length;
        return Encoding.UTF8.GetString(span[..end]);
    }

    private static byte[] ReadFsFile(IFileSystem fs, string path)
    {
        UniqueRef<IFile> handle = default;
        fs.OpenFile(ref handle, ToFsPath(path), OpenMode.Read).ThrowIfFailure();
        try
        {
            handle.Get.GetSize(out long size).ThrowIfFailure();
            if (size < 0 || size > int.MaxValue)
                throw new InvalidDataException($"File '{path}' has invalid size {size}");
            byte[] buffer = new byte[size];
            handle.Get.Read(out long read, 0, buffer, ReadOption.None).ThrowIfFailure();
            if (read != size)
                throw new InvalidDataException($"Short read from '{path}': {read}/{size}");
            return buffer;
        }
        finally { handle.Destroy(); }
    }

    private static string FormatTitleVersion(TitleVersion version)
    {
        var s = $"{version.Major}.{version.Minor}.{version.Patch}";
        if (version.Revision > 0)
            s += $".{version.Revision}";
        return s;
    }

    /// <summary>Maps a title id to its base application id (NSCB semantics).</summary>
    internal static ulong GetBaseTitleId(ulong titleId, ContentMetaType type) => type switch
    {
        ContentMetaType.Patch => titleId - 0x800,
        ContentMetaType.AddOnContent => titleId - 0x100000000,
        _ => titleId,
    };

    internal static ulong InferBaseTitleId(ulong titleId) => (titleId & 0x800) != 0
        ? titleId - 0x800
        : (titleId & 0xFFFFFFFF00000000) != 0 && (titleId & 0xFFFFFFFF) != 0
            ? titleId - 0x100000000
            : titleId;

    internal static string InferTitleType(ulong titleId) => (titleId & 0x800) != 0
        ? "Patch"
        : (titleId & 0xFFFFFFFF00000000) != 0 && (titleId & 0xFFFFFFFF) != 0
            ? "AddOnContent"
            : "Application";

    private static string? BuildFirmwareSummary(ContainerFileInfo info)
    {
        // Prefer the RSV requirement from cnmt; fall back to the key generation range.
        if (info.RequiredSystemVersion is { } rsv && rsv != "(1.0.0)")
            return rsv;
        return info.FirmwareRangeFromKg;
    }
}
