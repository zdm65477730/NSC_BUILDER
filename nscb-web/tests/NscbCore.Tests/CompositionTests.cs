using NscbCore.Keys;
using NscbCore.Splitting;
using Xunit;

namespace NscbCore.Tests;

/// <summary>
/// Composition counts the distinct titles (games/updates/DLC) inside a container by scanning its cnmts,
/// and backs the "(1G+1U)" combined-pack tag. These pure tests cover the safe early-exit paths that need
/// no keys or real dumps; the multi-title positive path is exercised in IntegrationE2E (NSCB_E2E_DIR).
/// </summary>
public class CompositionTests
{
    [Fact]
    public void Composition_NonContainer_ReturnsZero_WithoutTouchingKeys()
    {
        // A plain (non-container) file must return (0,0,0) — the kind check precedes any key use, so even a
        // null key set is fine here (guards against a crash on unrelated inputs).
        string tmp = Path.Combine(Path.GetTempPath(), "nscb-comp-" + Guid.NewGuid().ToString("N") + ".txt");
        File.WriteAllText(tmp, "not a container");
        try
        {
            var (g, u, d) = TitleSplitter.Composition(tmp, null!);
            Assert.Equal(0, g); Assert.Equal(0, u); Assert.Equal(0, d);
        }
        finally { try { File.Delete(tmp); } catch { } }
    }

    [Fact]
    public void Composition_TotalOneTitle_ProducesNoTag()
    {
        // The tag is emitted only for genuinely multi-title packs (g+u+d > 1). Uses the shared OutputFormat rule
        // (the same one the server calls), not a local copy.
        Assert.Equal("", NscbCore.Packaging.OutputFormat.CompositionTag(1, 0, 0));   // single app → no tag
        Assert.Equal(" (1G+1U)", NscbCore.Packaging.OutputFormat.CompositionTag(1, 1, 0));
        Assert.Equal(" (1G+2D)", NscbCore.Packaging.OutputFormat.CompositionTag(1, 0, 2));
    }
}
