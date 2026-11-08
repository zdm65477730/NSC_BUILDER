using NscbCore.Crypto;
using Xunit;

namespace NscbCore.Tests;

/// <summary>
/// Verifies <see cref="XtsHelper.TransformNcaHeader"/> is its own exact inverse across the
/// version-dependent data-unit scheme (Nca3 sequential sectors 2..5; Nca2 all-zero sector).
/// No keys or samples needed — the encrypt/decrypt pair must restore the original bytes.
/// </summary>
public class XtsHeaderTests
{
    private static byte[] HeaderKey() => [.. Enumerable.Range(0, 32).Select(i => (byte)(i * 7 + 3))];

    private static byte[] MakeHeader(char versionDigit)
    {
        var h = new byte[XtsHelper.HeaderSize];
        for (int i = 0; i < h.Length; i++) h[i] = (byte)((i * 131 + 7) & 0xFF);
        h[0x200] = (byte)'N'; h[0x201] = (byte)'C'; h[0x202] = (byte)'A';
        h[0x203] = (byte)versionDigit;          // 'NCA3' / 'NCA2'
        return h;
    }

    [Theory]
    [InlineData('3')]
    [InlineData('2')]
    [InlineData('0')]
    public void EncryptThenDecrypt_RestoresOriginal(char versionDigit)
    {
        byte[] hk = HeaderKey();
        byte[] original = MakeHeader(versionDigit);
        var work = (byte[])original.Clone();

        XtsHelper.TransformNcaHeader(work, hk, decrypt: false); // encrypt
        // The magic must be scrambled, i.e. XTS actually applied over the header.
        Assert.NotEqual("NCA", System.Text.Encoding.ASCII.GetString(work[0x200..0x203]));

        XtsHelper.TransformNcaHeader(work, hk, decrypt: true); // decrypt
        Assert.Equal(original, work);
    }

    [Fact]
    public void Nca3_And_Nca2_Schemes_Differ()
    {
        // Same 0xC00 content but different version digit → the 0x400..0xBFF blocks use different
        // data-unit indices, so their ciphertext must differ.
        byte[] hk = HeaderKey();
        var h3 = MakeHeader('3'); var h2 = MakeHeader('2');
        // Align content except the version digit so only the scheme differs.
        h2[0x200] = h3[0x200]; // same magic bytes region content otherwise identical patterns
        XtsHelper.TransformNcaHeader(h3, hk, decrypt: false);
        XtsHelper.TransformNcaHeader(h2, hk, decrypt: false);
        Assert.False(h3[0x400..0xC00].SequenceEqual(h2[0x400..0xC00]));
    }

    [Fact]
    public void RejectsShortBuffer()
    {
        Assert.Throws<ArgumentException>(() =>
            XtsHelper.TransformNcaHeader(new byte[0x100], HeaderKey(), decrypt: true));
    }

    [Fact]
    public void RejectsWrongKeySize()
    {
        var h = new byte[XtsHelper.HeaderSize];
        Assert.Throws<ArgumentException>(() =>
            XtsHelper.TransformNcaHeader(h, new byte[16], decrypt: true));
    }
}
