using System.Text;
using System.Text.RegularExpressions;
using NscbCore.Info;
using NscbCore.Keys;

namespace NscbCore.Renaming;

/// <summary>Options for NSCB-style content renaming.</summary>
public readonly record struct RenameOptions(
    bool IncludeVersion = true, bool IncludeTypeTag = true, bool UseContentName = true);

/// <summary>
/// Pure NSCB filename building + sanitising (features #12/#18). Format:
/// <c>{Name} [{TITLEID}][v{rawVersion}][{Base|UPD|DLC}]{ext}</c>. No file IO — testable on its own.
/// </summary>
public static class FileNamer
{
    private static readonly Regex Illegal = new(@"[<>:""/\|?*\x00-\x1F]", RegexOptions.Compiled);
    private static readonly Regex TrailingTags = new(@"(\s*\[[^\]]*\])+\s*$", RegexOptions.Compiled);
    private static readonly HashSet<string> ReservedNames = new(StringComparer.OrdinalIgnoreCase)
    {
        "CON","PRN","AUX","NUL",
        "COM1","COM2","COM3","COM4","COM5","COM6","COM7","COM8","COM9",
        "LPT1","LPT2","LPT3","LPT4","LPT5","LPT6","LPT7","LPT8","LPT9",
    };

    /// <summary>Strip filesystem-illegal/control characters, collapse spaces, trim edges, guard Windows
    /// reserved device names, cap length.</summary>
    public static string Sanitize(string name)
    {
        name = Illegal.Replace(name, "");
        name = Regex.Replace(name, @"\s{2,}", " ");
        name = name.Trim('.', ' ');
        if (name.Length > 200) name = name[..200].TrimEnd('.', ' ');
        // Windows: a filename whose stem is CON/PRN/AUX/NUL/COMn/LPTn (any extension) is invalid.
        int dot = name.IndexOf('.');
        string stem = dot >= 0 ? name[..dot] : name;
        if (ReservedNames.Contains(stem.TrimEnd('.', ' '))) name = "_" + name;
        return name;
    }

    /// <summary>Remove trailing NSCB tag groups (e.g. <c>[0100..][v0][Base]</c>) from a filename stem.</summary>
    public static string StripTags(string stem) => TrailingTags.Replace(stem, "").TrimEnd(' ', '.');

    public static string TypeTag(string? titleType) => titleType switch
    {
        "Application" => "Base",
        "Patch" => "UPD",
        "Delta" => "UPD",
        "SystemUpdate" => "UPD",
        "AddOnContent" => "DLC",
        _ => "",
    };

    /// <summary>Builds the NSCB-style target filename for a parsed container (falls back to the original stem).</summary>
    public static string BuildFileName(ContainerFileInfo info, string originalPath, RenameOptions opt)
    {
        string ext = Path.GetExtension(originalPath);
        string stem = Path.GetFileNameWithoutExtension(originalPath);

        string name = opt.UseContentName && !string.IsNullOrWhiteSpace(info.TitleName)
            ? info.TitleName!
            : StripTags(stem);
        name = Sanitize(name);
        if (name.Length == 0) name = "untitled";

        var sb = new StringBuilder(name);

        string id = (info.TitleId ?? ExtractId(stem)).ToUpperInvariant();
        if (id.Length > 0) sb.Append(" [").Append(id).Append(']');

        if (opt.IncludeVersion && info.TitleVersionRaw is { } v)
            sb.Append("[v").Append(v.ToString(System.Globalization.CultureInfo.InvariantCulture)).Append(']');

        if (opt.IncludeTypeTag)
        {
            string tag = TypeTag(info.TitleType);
            if (tag.Length > 0) sb.Append('[').Append(tag).Append(']');
        }
        return sb.Append(ext).ToString();
    }

    // Recover a 16-hex title id already present in the filename (e.g. "[0100ABCD000000FF]").
    private static string ExtractId(string stem)
    {
        foreach (Match m in Regex.Matches(stem, @"\[([0-9a-fA-F]{16})\]"))
            return m.Groups[1].Value;
        return "";
    }
}

/// <summary>Applies <see cref="FileNamer"/> over files/folders; copies or moves to the new name.</summary>
public static class FileRenamer
{
    public sealed record Result(string OldPath, string NewPath, bool Applied, string? Error);

    public static IReadOnlyList<Result> Rename(
        IEnumerable<string> inputs, NscbKeys keys, string? outDir, RenameOptions opt, bool apply,
        CancellationToken ct = default)
    {
        var svc = new TitleInfoService(keys);
        var results = new List<Result>();
        foreach (string file in Enumerate(inputs))
        {
            ct.ThrowIfCancellationRequested();
            try
            {
                var info = svc.GetFileInfo(file);
                string newName = FileNamer.BuildFileName(info, file, opt);
                string targetDir = string.IsNullOrWhiteSpace(outDir) ? (Path.GetDirectoryName(file) ?? ".") : outDir!;
                Directory.CreateDirectory(targetDir);
                string target = Path.Combine(targetDir, newName);
                if (apply && Path.GetFullPath(target) != Path.GetFullPath(file))
                    File.Move(file, target, overwrite: false);
                results.Add(new Result(file, target, apply, null));
            }
            catch (Exception ex) { results.Add(new Result(file, "", false, ex.Message)); }
        }
        return results;
    }

    private static IEnumerable<string> Enumerate(IEnumerable<string> inputs)
    {
        foreach (string i in inputs)
        {
            if (Directory.Exists(i))
            {
                foreach (string f in Directory.EnumerateFiles(i, "*", SearchOption.AllDirectories))
                    if (IsSupported(f)) yield return f;
            }
            else if (File.Exists(i) && IsSupported(i)) yield return i;
        }
    }

    private static bool IsSupported(string p) =>
        DatabaseExporter.SupportedExtensions.Contains(Path.GetExtension(p).ToLowerInvariant());
}
