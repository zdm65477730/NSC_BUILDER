using NscbCore.Packaging;
using Xunit;

namespace NscbCore.Tests;

/// <summary>Pure format/tag rules used by Pack and upd_base — the single source the server delegates to.</summary>
public class OutputFormatTests
{
    [Theory]
    [InlineData(new[] { ".nsp", ".nsp" }, ".nsp")]   // all plain NSP
    [InlineData(new[] { ".nsz", ".nsp" }, ".nsz")]   // NSZ + NSP → NSZ (convert NSP→NSZ)
    [InlineData(new[] { ".nsz", ".nsz" }, ".nsz")]
    [InlineData(new[] { ".xci", ".nsp" }, ".xci")]   // XCI base + NSP update → XCI
    [InlineData(new[] { ".xci", ".nsz" }, ".xcz")]   // XCI + NSZ → XCZ
    [InlineData(new[] { ".xcz", ".nsp" }, ".xcz")]   // any XCZ → XCZ
    [InlineData(new[] { ".xci", ".xci" }, ".xci")]   // card, none compressed
    [InlineData(new[] { ".nca", ".nsz" }, ".nsz")]   // nca is neither card nor compressed
    public void MergeTargetExt_Precedence(string[] exts, string expected)
        => Assert.Equal(expected, OutputFormat.MergeTargetExt(exts));

    [Theory]
    [InlineData(new[] { ".nsp", ".nsp" }, ".xci")]   // plain → XCI
    [InlineData(new[] { ".nsz", ".nsp" }, ".xcz")]   // any compressed → XCZ
    [InlineData(new[] { ".xci", ".nsp" }, ".xci")]
    [InlineData(new[] { ".ncz" }, ".xcz")]
    public void PackExt_Rule(string[] exts, string expected)
        => Assert.Equal(expected, OutputFormat.PackExt(exts));

    [Theory]
    [InlineData(1, 0, 0, "")]                 // single app → no tag
    [InlineData(0, 1, 0, "")]                 // single update → no tag
    [InlineData(1, 1, 0, " (1G+1U)")]
    [InlineData(1, 0, 2, " (1G+2D)")]
    [InlineData(2, 1, 1, " (2G+1U+1D)")]
    public void CompositionTag_Rule(int g, int u, int d, string expected)
        => Assert.Equal(expected, OutputFormat.CompositionTag(g, u, d));
}
