using System.Buffers.Binary;
using System.Collections.Concurrent;
using System.IO.Compression;
using System.Security.Cryptography;
using System.Text;
using NscbCore.Compression;
using NscbCore.Info;
using NscbCore.Joiner;
using NscbCore.Patching;
using NscbCore.Splitting;
using Xunit;

namespace NscbCore.Tests;

public class ParallelizerTests
{
    [Theory]
    [InlineData(1)]
    [InlineData(8)]
    public void ForIndex_VisitsEveryIndexExactlyOnce(int parallelism)
    {
        var seen = new ConcurrentBag<int>();
        Parallelizer.ForIndex(200, parallelism, i => seen.Add(i));
        Assert.Equal(Enumerable.Range(0, 200), seen.OrderBy(x => x));
    }

    [Fact]
    public void Clamp_RespectsBoundsAndItemCount()
    {
        Assert.Equal(1, Parallelizer.Clamp(0, 10));      // floor at 1
        Assert.Equal(4, Parallelizer.Clamp(4, 10));      // within range
        Assert.Equal(3, Parallelizer.Clamp(99, 3));      // capped by item count
    }
}

public class TicketAccountPatcherTests : IDisposable
{
    private readonly string _dir = Path.Combine(Path.GetTempPath(), "nscb-tik-" + Guid.NewGuid().ToString("N"));

    public TicketAccountPatcherTests() => Directory.CreateDirectory(_dir);
    public void Dispose() { try { Directory.Delete(_dir, true); } catch { } }

    [Fact]
    public void PatchTicketFile_ZerosAccountId()
    {
        byte[] tik = new byte[0x1C0];
        RandomNumberGenerator.Fill(tik);
        // Make the account-id region distinctive and non-zero.
        for (int i = 0; i < 8; i++) tik[TicketAccountPatcher.AccountIdOffset + i] = (byte)(0xA0 + i);
        byte[] before = (byte[])tik.Clone();
        string p = Path.Combine(_dir, "t.tik");
        File.WriteAllBytes(p, tik);

        var res = TicketAccountPatcher.PatchTicketFile(p);
        Assert.True(res.WasCleared);

        byte[] after = File.ReadAllBytes(p);
        for (int i = 0; i < 8; i++)
            Assert.Equal(0, after[TicketAccountPatcher.AccountIdOffset + i]);
        // Everything outside the account-id region must be untouched.
        for (int i = 0; i < after.Length; i++)
            if (i < TicketAccountPatcher.AccountIdOffset || i >= TicketAccountPatcher.AccountIdOffset + 8)
                Assert.Equal(before[i], after[i]);
    }

    [Fact]
    public void PatchTicketFile_RejectsTooSmallTicket()
    {
        string p = Path.Combine(_dir, "short.tik");
        File.WriteAllBytes(p, new byte[0x10]);
        Assert.Throws<InvalidDataException>(() => TicketAccountPatcher.PatchTicketFile(p));
    }
}

public class FileJoinerTests : IDisposable
{
    private readonly string _dir = Path.Combine(Path.GetTempPath(), "nscb-join-" + Guid.NewGuid().ToString("N"));

    public FileJoinerTests() => Directory.CreateDirectory(_dir);
    public void Dispose() { try { Directory.Delete(_dir, true); } catch { } }

    [Fact]
    public void Join_SplitParts_RoundTrips()
    {
        byte[] data = new byte[0x5000];
        RandomNumberGenerator.Fill(data);
        string src = Path.Combine(_dir, "game.xci");
        File.WriteAllBytes(src, data);
        Fat32Splitter.Split(src); // small → single .00 part

        string joined = FileJoiner.Join(src + ".00", Path.Combine(_dir, "out.xci"));
        Assert.Equal(data, File.ReadAllBytes(joined));
    }

    [Fact]
    public void Join_SingleEntryZip_ExtractsToTargetFile()
    {
        byte[] payload = RandomNumberGenerator.GetBytes(0x3000);
        string inner = Path.Combine(_dir, "real.nsp");
        File.WriteAllBytes(inner, payload);

        string zip = Path.Combine(_dir, "bundle.zip");
        using (var archive = ZipFile.Open(zip, ZipArchiveMode.Create))
            archive.CreateEntryFromFile(inner, "real.nsp");

        string outNsp = Path.Combine(_dir, "unpacked.nsp");
        string result = FileJoiner.Join(zip, outNsp);
        Assert.Equal(outNsp, result);
        Assert.Equal(payload, File.ReadAllBytes(result));
    }

    [Fact]
    public void Join_RejectsNonJoinable()
    {
        string p = Path.Combine(_dir, "plain.txt");
        File.WriteAllText(p, "hi");
        Assert.Throws<InvalidDataException>(() => FileJoiner.Join(p));
    }
}

public class NpdmInfoReaderTests
{
    [Fact]
    public void Parse_ExtractsAci0TitleIdAndAcidRange()
    {
        var buf = new byte[0x940];

        // "META" descriptive header at 0x0.
        Encoding.ASCII.GetBytes("META").CopyTo(buf.AsSpan(0));
        Encoding.ASCII.GetBytes("Application").CopyTo(buf.AsSpan(0x20));

        // ACI0 block: magic + title id (u64 LE) at block+0x10.
        int aci0 = 0x400;
        Encoding.ASCII.GetBytes("ACI0").CopyTo(buf.AsSpan(aci0));
        BinaryPrimitives.WriteUInt64LittleEndian(buf.AsSpan(aci0 + 0x10), 0x0100_8BC0_24FDE000UL);

        // ACID block: magic at block+0x200; flags/min/max follow it.
        int acidMagic = 0x900;
        Encoding.ASCII.GetBytes("ACID").CopyTo(buf.AsSpan(acidMagic));
        BinaryPrimitives.WriteUInt32LittleEndian(buf.AsSpan(acidMagic + 0x0C), 3);        // AcidFlags
        BinaryPrimitives.WriteUInt64LittleEndian(buf.AsSpan(acidMagic + 0x10), 0x0100_0000_0001_0000UL);
        BinaryPrimitives.WriteUInt64LittleEndian(buf.AsSpan(acidMagic + 0x18), 0x01FF_FFFF_FFFF_FFFFUL);

        var npdm = NpdmInfoReader.Parse(buf, "main.npdm");

        Assert.Equal("01008bc024fde000", npdm.TitleId);
        Assert.Equal("0100000000010000", npdm.AllowedIdMin);
        Assert.Equal("01ffffffffffffff", npdm.AllowedIdMax);
        Assert.Equal(3u, npdm.AcidFlags);
        Assert.Equal("Application", npdm.TitleName);
        Assert.Equal("Regular title", npdm.ProcessCategory);
    }
}
