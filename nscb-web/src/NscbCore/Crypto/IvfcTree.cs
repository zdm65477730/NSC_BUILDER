using System.Security.Cryptography;

namespace NscbCore.Crypto;

/// <summary>
/// Computes a Switch IVFC (Integrity Verification Flat Cache) hierarchical hash tree over
/// raw content, matching LibHac's read-only path (<c>IntegrityVerificationStorage.CalcBlockHash</c>
/// → <c>GenerateHash</c>): each block is <b>plain SHA-256, zero-padded to the block size, with NO
/// salt</b>. (Salt is only applied on the writable path, which also sets a validation bit — not
/// how published NCAs store their hashes.)
/// </summary>
/// <remarks>
/// Region layout (as used by <c>Nca.InitIvfcForRomFs</c> and observed in real NCAs): region index
/// ascends from the <b>top</b> (lowest offset, fewest blocks) down to the <b>content</b> at the
/// highest offset. For consecutive active regions, <c>region[i] = SHA-256 blocks of region[i+1]</c>
/// with block size <c>1 &lt;&lt; step[i]</c>; the header <c>MasterHash = SHA-256 blocks of region[0]</c>
/// with block size <c>1 &lt;&lt; step[0]</c>. A region whose stored size is 0 is inactive.
/// </remarks>
public static class IvfcTree
{
    private static byte[] HashBlock(ReadOnlySpan<byte> block, int blockSize)
    {
        byte[] buf = new byte[blockSize];
        int len = Math.Min(blockSize, block.Length);
        block[..len].CopyTo(buf);
        return SHA256.HashData(buf);
    }

    /// <summary>Hash <paramref name="child"/> into a region of 32-byte digests, block size <paramref name="bs"/>.</summary>
    public static byte[] HashRegion(ReadOnlySpan<byte> child, int bs)
    {
        long n = (child.Length + bs - 1L) / bs;
        if (n == 0) n = 1; // an empty child still yields one (all-zero) block hash
        byte[] region = new byte[n * 0x20];
        for (long j = 0; j < n; j++)
        {
            long off = j * bs;
            int len = (int)Math.Max(0, Math.Min(bs, child.Length - off));
            byte[] h = HashBlock(child.Slice((int)off, len), bs);
            h.CopyTo(region, (int)(j * 0x20));
        }
        return region;
    }

    /// <summary>
    /// Build the full IVFC chain for <paramref name="content"/> using per-region block powers
    /// <paramref name="step"/> (region i hashes region i+1 with block <c>1&lt;&lt;step[i]</c>).
    /// Returns <c>regions[0..activeCount-1]</c> top→content and the header <c>masterHash</c>.
    /// <paramref name="step"/> is indexed by region; only the first <c>activeCount</c> are used.
    /// </summary>
    public static (byte[][] Regions, byte[] Master) Build(byte[] content, int[] step, int activeCount)
    {
        var regions = new byte[activeCount][];
        regions[activeCount - 1] = content;
        for (int i = activeCount - 2; i >= 0; i--)
            regions[i] = HashRegion(regions[i + 1], 1 << step[i]);
        byte[] master = HashRegion(regions[0], 1 << step[0]);
        return (regions, master);
    }
}
