using System.Security.Cryptography;
using NscbCore.Crypto;
using Xunit;

namespace NscbCore.Tests;

/// <summary>
/// Pure regression tests for the IVFC hash-tree primitive (the read-only NCA IVFC = plain SHA-256,
/// no salt; region index 0 = top, content = last). These lock the exact convention that the delta
/// rebuild path and Meta/IvfcNcaBuilder rely on, independent of any real sample.
/// </summary>
public class IvfcTreeTests
{
    private static byte[] Pad(byte[] b, int bs)
    {
        int blocks = Math.Max(1, (b.Length + bs - 1) / bs);
        byte[] r = new byte[blocks * bs];
        b.CopyTo(r, 0);
        return r;
    }

    [Fact]
    public void HashRegion_Length_IsBlocksTimes32()
    {
        byte[] child = new byte[1000];
        int bs = 64;
        byte[] r = IvfcTree.HashRegion(child, bs);
        int blocks = (1000 + bs - 1) / bs; // 16
        Assert.Equal(blocks * 32, r.Length);
    }

    [Fact]
    public void HashRegion_Empty_ProducesOneBlockHashOfZeros()
    {
        byte[] r = IvfcTree.HashRegion(ReadOnlySpan<byte>.Empty, 64);
        // zero-length child still yields at least one digest (all-zero block)
        Assert.Equal(32, r.Length);
        Assert.Equal(SHA256.HashData(new byte[64]), r);
    }

    [Fact]
    public void HashRegion_MatchesManualShaPerBlock()
    {
        var rng = new Random(1234);
        byte[] child = new byte[200];
        rng.NextBytes(child);
        int bs = 64;
        byte[] r = IvfcTree.HashRegion(child, bs);
        byte[] padded = Pad(child, bs);
        for (int k = 0; k * bs < padded.Length; k++)
        {
            byte[] want = SHA256.HashData(padded.AsSpan(k * bs, bs));
            byte[] got = r.AsSpan(k * 32, 32).ToArray();
            Assert.Equal(want, got);
        }
    }

    [Fact]
    public void Build_IsSelfConsistent_ChainAndMaster()
    {
        byte[] content = new byte[5000];
        new Random(7).NextBytes(content);
        int[] step = { 10, 10, 10 }; // block sizes 1<<10
        var (regions, master) = IvfcTree.Build(content, step, activeCount: 3);

        Assert.Equal(3, regions.Length);          // activeCount regions, index 0=top .. 2=content
        Assert.Equal(32, master.Length);
        Assert.Equal(content, regions[2]);        // last region is the content itself

        // Each region[i] = SHA-blocks(region[i+1]) with block = 1<<step[i]; top stored region
        // hashes the content; master = SHA-blocks(region[0]).
        Assert.Equal(IvfcTree.HashRegion(content, 1 << step[1]), regions[1]);
        Assert.Equal(IvfcTree.HashRegion(regions[1], 1 << step[0]), regions[0]);
        Assert.Equal(IvfcTree.HashRegion(regions[0], 1 << step[0]), master);
    }

    [Fact]
    public void Build_RegionsStrictlyShrink()
    {
        byte[] content = new byte[1 << 20]; // 1 MiB
        int[] step = { 12, 12, 12, 12 };
        var (regions, _) = IvfcTree.Build(content, step, activeCount: 5);
        for (int i = 0; i < regions.Length - 1; i++)
            Assert.True(regions[i].Length <= regions[i + 1].Length / 32 * 32,
                $"region {i} should be far smaller than region {i + 1}");
    }
}
