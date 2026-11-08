using System.Text;
using System.Text.Json;
using NscbCore.Keys;

namespace NscbCore.Info;

/// <summary>
/// MODE 5 "Database" — mass info export over files and/or folders (searched recursively).
/// Produces CSV / TSV / JSON / TXT with the fixed column set. Reuses <see cref="TitleInfoService"/>
/// per file, so it inherits the same info/keys handling. CSV/TSV/TXT neutralise spreadsheet formula
/// injection (a leading =, +, -, @ is prefixed with a single quote), matching NSCB's database output.
/// </summary>
public static class DatabaseExporter
{
    public static readonly string[] SupportedExtensions = [".nsp", ".nsz", ".xci", ".xcz", ".nca", ".ncz"];

    private static readonly string[] Columns =
    [
        "File", "Format", "TitleId", "BaseTitleId", "TitleType", "TitleName", "DisplayVersion",
        "TitleVersion", "KeyGeneration", "FirmwareRequirement", "TitleKeyCrypto", "TitleKeyAvailable",
        "HasTicket", "FileSize", "ContentCount", "Error",
    ];

    /// <summary>Exports <paramref name="inputs"/> (files or folders) to a serialized table string.</summary>
    public static string Export(IEnumerable<string> inputs, string format, NscbKeys keys,
        Action<int, int>? progress = null, CancellationToken ct = default)
    {
        var files = Enumerate(inputs).ToList();
        var svc = new TitleInfoService(keys);
        var rows = new List<Dictionary<string, string?>>(files.Count);
        for (int idx = 0; idx < files.Count; idx++)
        {
            ct.ThrowIfCancellationRequested();
            string f = files[idx];
            ContainerFileInfo info;
            try { info = svc.GetFileInfo(f); }
            catch (Exception ex) { info = new ContainerFileInfo { Path = f, Error = ex.Message }; }
            rows.Add(ToRow(info, f));
            progress?.Invoke(idx + 1, files.Count);
        }

        return (format ?? "csv").Trim().ToLowerInvariant() switch
        {
            "json" => JsonSerializer.Serialize(rows, new JsonSerializerOptions { WriteIndented = true }),
            "html" => Html(rows),
            "tsv"  => Delimited(rows, '\t'),
            _      => Delimited(rows, ','),
        };
    }

    private static IEnumerable<string> Enumerate(IEnumerable<string> inputs)
    {
        foreach (string input in inputs)
        {
            if (Directory.Exists(input))
            {
                foreach (string f in Directory.EnumerateFiles(input, "*", SearchOption.AllDirectories))
                    if (IsSupported(f)) yield return f;
            }
            else if (File.Exists(input) && IsSupported(input))
                yield return input;
        }
    }

    private static bool IsSupported(string path) =>
        SupportedExtensions.Contains(Path.GetExtension(path).ToLowerInvariant());

    private static Dictionary<string, string?> ToRow(ContainerFileInfo i, string path) => new()
    {
        ["File"] = path,
        ["Format"] = i.Format,
        ["TitleId"] = i.TitleId,
        ["BaseTitleId"] = i.BaseTitleId,
        ["TitleType"] = i.TitleType,
        ["TitleName"] = i.TitleName,
        ["DisplayVersion"] = i.DisplayVersion,
        ["TitleVersion"] = i.TitleVersion,
        ["KeyGeneration"] = i.KeyGeneration?.ToString(),
        ["FirmwareRequirement"] = i.FirmwareRequirement,
        ["TitleKeyCrypto"] = OnOff(i.HasTitleKeyCrypto),
        ["TitleKeyAvailable"] = OnOff(i.TitleKeyAvailable),
        ["HasTicket"] = OnOff(i.HasTicket),
        ["FileSize"] = i.FileSize > 0 ? i.FileSize.ToString() : (File.Exists(path) ? new FileInfo(path).Length.ToString() : ""),
        ["ContentCount"] = i.Contents.Count.ToString(),
        ["Error"] = i.Error,
    };

    private static string OnOff(bool b) => b ? "Yes" : "No";

    // Simple escaped HTML table (for the html export option).
    private static string Html(List<Dictionary<string, string?>> rows)
    {
        static string E(string? s) => System.Net.WebUtility.HtmlEncode(s ?? "");
        var sb = new StringBuilder();
        sb.Append("<!doctype html><meta charset='utf-8'><title>NSC_BUILDER database</title>");
        sb.Append("<style>body{font-family:system-ui,'Segoe UI',Arial;font-size:13px}table{border-collapse:collapse}th,td{border:1px solid #ccc;padding:4px 8px;text-align:left}th{background:#eee;position:sticky;top:0}tr:nth-child(even) td{background:#fafafa}</style>");
        sb.Append("<table><thead><tr>");
        foreach (var c in Columns) { sb.Append("<th>").Append(E(c)).Append("</th>"); }
        sb.Append("</tr></thead><tbody>");
        foreach (var r in rows) { sb.Append("<tr>"); foreach (var c in Columns) { sb.Append("<td>").Append(E(r.TryGetValue(c, out var v) ? v : null)).Append("</td>"); } sb.Append("</tr>"); }
        sb.Append("</tbody></table>");
        return sb.ToString();
    }

    private static string Delimited(List<Dictionary<string, string?>> rows, char sep)
    {
        var sb = new StringBuilder();
        sb.AppendLine(string.Join(sep, Columns));
        foreach (var r in rows)
            sb.AppendLine(string.Join(sep, Columns.Select(c => Cell(r.TryGetValue(c, out var v) ? v : null, sep))));
        return sb.ToString();
    }

    // Escape + neutralise formula injection. For JSON the raw value is kept (safe in JSON).
    private static string Cell(string? v, char sep)
    {
        v ??= "";
        if (v.Length > 0 && (v[0] == '=' || v[0] == '+' || v[0] == '-' || v[0] == '@' || v[0] == '\t' || v[0] == '\r'))
            v = "'" + v;
        bool needsQuote = v.Contains('"') || v.Contains(sep) || v.Contains('\n') || v.Contains('\r');
        if (!needsQuote) return v;
        return "\"" + v.Replace("\"", "\"\"") + "\"";
    }
}
