namespace NscbCore.Packaging;

/// <summary>
/// Pure output-format / tag rules shared by the server (Pack and upd_base) and covered by unit tests.
/// All take already-lowercased file EXTENSIONS so they are I/O- and key-free.
/// </summary>
public static class OutputFormat
{
    /// <summary>
    /// Merge/pack target extension by content precedence: card family if any .xci/.xcz; compressed if any
    /// .nsz/.xcz/.ncz. → card+compressed .xcz · card .xci · compressed .nsz · else .nsp.
    /// </summary>
    public static string MergeTargetExt(IEnumerable<string> exts)
    {
        bool card = false, comp = false;
        foreach (var e in exts)
        {
            if (e is ".xci" or ".xcz") card = true;
            if (e is ".nsz" or ".xcz" or ".ncz") comp = true;
        }
        return card ? (comp ? ".xcz" : ".xci") : (comp ? ".nsz" : ".nsp");
    }

    /// <summary>Packed card extension: any compressed input → .xcz, else .xci.</summary>
    public static string PackExt(IEnumerable<string> exts)
    {
        foreach (var e in exts) if (e is ".nsz" or ".xcz" or ".ncz") return ".xcz";
        return ".xci";
    }

    /// <summary>Combined-pack tag " (1G+1U)"; empty for a single title (g+u+d ≤ 1).</summary>
    public static string CompositionTag(int games, int updates, int dlc)
    {
        if (games + updates + dlc <= 1) return "";
        var parts = new List<string>();
        if (games > 0) parts.Add($"{games}G");
        if (updates > 0) parts.Add($"{updates}U");
        if (dlc > 0) parts.Add($"{dlc}D");
        return " (" + string.Join("+", parts) + ")";
    }
}
