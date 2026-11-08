namespace NscbCore.Packaging;

/// <summary>
/// Pure NSCB-style classification of title content-meta types into a pack/split composition
/// (Game / Update / DLC), and rendering of the "(1G+1U+1D)" tag. This is the SINGLE source of truth
/// for the G/U/D tally, used by the server pack-name builder (JobRunner.BuildPackName) and by
/// TitleSplitter.Composition. Key- and I/O-free, so it is fully unit-testable.
/// </summary>
public static class PackComposition
{
    /// <summary>
    /// Classify content-meta type strings (as produced by LibHac ContentMetaType.ToString /
    /// ContentMetaTypeStrings) into (games, updates, dlcs):
    ///   AddOnContent → DLC; Patch / Delta / SystemUpdate → Update;
    ///   Application / null / anything else → Game (a lone or unrecognized container is treated as
    ///   the base game, matching NSCB naming — so a pack of one NSP is always "(1G)").
    /// </summary>
    public static (int games, int updates, int dlcs) Classify(IEnumerable<string?> titleTypes)
    {
        int g = 0, u = 0, d = 0;
        foreach (var t in titleTypes)
            switch (t)
            {
                case "AddOnContent": d++; break;
                case "Patch":
                case "Delta":
                case "SystemUpdate": u++; break;
                default: g++; break;   // "Application", null, or unknown → base game
            }
        return (g, u, d);
    }

    /// <summary>Render the inline composition tag "(1G+1U+1D)" (no leading space); always at least "(1G)".</summary>
    public static string Tag(IEnumerable<string?> titleTypes)
    {
        var (g, u, d) = Classify(titleTypes);
        var parts = new List<string>();
        if (g > 0) parts.Add($"{g}G");
        if (u > 0) parts.Add($"{u}U");
        if (d > 0) parts.Add($"{d}D");
        return parts.Count > 0 ? "(" + string.Join("+", parts) + ")" : "(1G)";
    }
}
