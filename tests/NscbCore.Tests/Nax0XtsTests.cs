using NscbCore.Crypto;
using Xunit;

namespace NscbCore.Tests;

/// <summary>
/// Golden vectors produced by the NAX0 AES-128-XTS Python reference (sector=0x4000,
/// GF(2^128) right-shift + 0xE1). Keys k1=00..0F, k2=F0..FF. Input bytes are generated
/// by <c>(i*31 + sector*7 + 0x81) &amp; 0xFF</c>. These lock the C# port to the reference.
/// </summary>
public class Nax0XtsTests
{
    private static readonly byte[] K1 = [.. Enumerable.Range(0, 16).Select(i => (byte)i)];
    private static readonly byte[] K2 = [.. Enumerable.Range(0, 16).Select(i => (byte)(15 - i))];

    private static byte[] Pattern(int len, ulong sector)
    {
        var b = new byte[len];
        for (int i = 0; i < len; i++) b[i] = (byte)(((ulong)i * 31 + sector * 7 + 0x81) & 0xFF);
        return b;
    }

    private static byte[] EncSector(byte[] plain, ulong sector)
    {
        var data = (byte[])plain.Clone();
        Nax0Xts.TransformSector(data, K1, K2, sector, encrypt: true);
        return data;
    }

    [Theory]
    // name, sector, len, expected base64 of full ciphertext
    [InlineData(0ul, 32, "GmI1HKgZXL29eq/q3ef2/mtNXfVghBCOXliE1T0Xft4=")]                 // full blocks
    [InlineData(5ul, 48, "cG2mXqwtzB3tUYfg5AvSUSzKDLQSA8WQlCENI7MDptX5USwNIDtW9e+u6WhrfQGu")]
    [InlineData(0ul, 50, "GmI1HKgZXL29eq/q3ef2/mtNXfVghBCOXliE1T0Xft7RB6RcqaeloVA34anVl4//stU=")] // CTS
    [InlineData(12345ul, 33, "zkVJItXRoK1jRRmcVsGIZbxC+o2lyYy+Hg2kkHCsdn/B")]                    // CTS
    public void MatchesReferenceVectors(ulong sector, int len, string expectedB64)
    {
        byte[] enc = EncSector(Pattern(len, sector), sector);
        Assert.Equal(expectedB64, Convert.ToBase64String(enc));
    }

    [Fact]
    public void FullSector_MatchesReference_And_RoundTrips()
    {
        const int sectorSize = Nax0Xts.SectorSize;
        byte[] plain = Pattern(sectorSize, 0);
        byte[] enc = EncSector(plain, 0);

        // First 64 bytes match the reference ciphertext for a full sector at index 0.
        Assert.Equal(
            "GmI1HKgZXL29eq/q3ef2/mtNXfVghBCOXliE1T0Xft70YjYor7cYCOhemZ7UEQ7btiSPgnYlyQoGCsEsHl3lCQ==",
            Convert.ToBase64String(enc.AsSpan(0, 64).ToArray()));

        var dec = (byte[])enc.Clone();
        Nax0Xts.TransformSector(dec, K1, K2, 0, encrypt: false);
        Assert.Equal(plain, dec);
    }

    [Fact]
    public void Sector0And7_HaveIndependentTweaks()
    {
        // Different sector index must yield different ciphertext for the same plaintext.
        var p = Pattern(48, 0);
        Assert.NotEqual(EncSector(p, 0), EncSector(p, 7));
    }

    [Fact]
    public void Transform_SplitsMultiSectorBuffer_WithIncrementingIndex()
    {
        // Two sectors: first full (0x4000), second partial. Verify against per-sector enc.
        const int ss = Nax0Xts.SectorSize;
        byte[] plain = Pattern(ss + 16, 0);
        for (int i = 0; i < 16; i++) plain[ss + i] = (byte)(0x40 + i);

        var buf = (byte[])plain.Clone();
        Nax0Xts.Transform(buf, K1, K2, 0, encrypt: true);

        // Sector 0 result must equal the standalone full-sector encryption.
        var s0 = EncSector(plain[..ss], 0);
        Assert.Equal(s0, buf[..ss]);
        // Sector 1 (16 bytes) uses index 1.
        var s1 = EncSector(plain[ss..], 1);
        Assert.Equal(s1, buf[ss..]);
    }

    [Fact]
    public void RejectsOversizedSector()
    {
        var big = new byte[Nax0Xts.SectorSize + 16];
        Assert.Throws<ArgumentException>(() =>
            Nax0Xts.TransformSector(big, K1, K2, 0, encrypt: true));
    }
}
