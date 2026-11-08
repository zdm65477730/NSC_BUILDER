using System.Buffers.Binary;
using System.Security.Cryptography;
using System.Text;
using NscbCore.Formats;
using NscbCore.Splitting;
using Xunit;

namespace NscbCore.Tests;

public class Pfs0BuilderTests
{
    [Fact]
    public void BuildHeader_RoundTripsThroughReader()
    {
        var files = new List<(string Name, long Size)>
        {
            ("0100000000010000.cnmt.nca", 0x400),
            ("certs/whatever.cert", 0x1F),
            ("file.xml", 0x77),
        };

        byte[] header = Pfs0Builder.BuildHeader(files);
        Assert.Equal(0, header.Length % 0x10);

        using var ms = new MemoryStream();
        ms.Write(header);
        foreach (var (_, size) in files)
            ms.Write(new byte[size]); // placeholder data
        ms.Position = 0;

        var entries = Pfs0.ReadEntries(ms);
        Assert.Equal(files.Count, entries.Count);
        long dataStart = header.Length;
        for (int i = 0; i < files.Count; i++)
        {
            Assert.Equal(files[i].Name, entries[i].Name);
            Assert.Equal(dataStart + files.Take(i).Sum(f => f.Size), entries[i].DataOffset);
            Assert.Equal(files[i].Size, entries[i].Size);
        }
    }

    [Fact]
    public void BuildHeader_PadsTo16Bytes()
    {
        // A single short name: header is 0x10 + 0x18 + 26 bytes = 0x3A -> padded 0x40 (NSCB remainder >= 1).
        byte[] header = Pfs0Builder.BuildHeader([("0123456789abcdef.nca", 1)]);
        Assert.Equal(0x40, header.Length);
    }
}

public class Hfs0BuilderTests
{
    private static Hfs0File MakeFile(string name, long size, byte[] firstBytes)
    {
        return new Hfs0File
        {
            Name = name,
            Size = size,
            Hash = SHA256.HashData(firstBytes.AsSpan(0, (int)Math.Min(0x200, firstBytes.Length))),
        };
    }

    [Fact]
    public void PartitionHeader_RoundTripsThroughReader()
    {
        byte[] contentA = new byte[0x400];
        RandomNumberGenerator.Fill(contentA);
        byte[] contentB = new byte[0x80];
        Array.Fill(contentB, (byte)'B');

        var files = new List<Hfs0File>
        {
            MakeFile("0100000000010000.cnmt.nca", contentA.Length, contentA),
            MakeFile("stuff.cert", contentB.Length, contentB),
        };

        byte[] header = Hfs0Builder.BuildPartitionHeader(files);
        Assert.Equal(0, header.Length % 0x200);

        using var ms = new MemoryStream();
        ms.Write(header);
        ms.Write(contentA);
        ms.Write(contentB);
        ms.Position = 0;

        var entries = Hfs0.ReadEntries(ms);
        Assert.Equal(2, entries.Count);
        long dataStart = header.Length;
        for (int i = 0; i < files.Count; i++)
        {
            Assert.Equal(files[i].Name, entries[i].Name);
            Assert.Equal(dataStart + files.Take(i).Sum(f => f.Size), entries[i].DataOffset);
            Assert.Equal(files[i].Size, entries[i].Size);
            Assert.Equal(0x200, entries[i].HashedSize);
            Assert.Equal(files[i].Hash, entries[i].Hash);
        }
    }

    [Fact]
    public void RootHeader_MatchesNscbLayout()
    {
        var update = new Hfs0Partition("update", Hfs0Builder.BuildPartitionHeader([]), 0);
        var normal = new Hfs0Partition("normal", Hfs0Builder.BuildPartitionHeader([]), 0);
        var secureFiles = new List<Hfs0File>
        {
            MakeFile("a.nca", 0x200, new byte[0x200]),
        };
        var secure = new Hfs0Partition("secure", Hfs0Builder.BuildPartitionHeader(secureFiles), 0x200);

        byte[] root = Hfs0Builder.BuildRootHeader([update, normal, secure]);

        using var ms = new MemoryStream();
        ms.Write(root);
        ms.Write(update.Header);
        ms.Write(normal.Header);
        ms.Write(secure.Header);
        ms.Position = 0;

        var entries = Hfs0.ReadEntries(ms);
        Assert.Equal(3, entries.Count);
        Assert.Equal("update", entries[0].Name);
        Assert.Equal("normal", entries[1].Name);
        Assert.Equal("secure", entries[2].Name);

        // ReadEntries returns absolute offsets; compare relative to the root data start.
        long rootDataStart = entries[0].DataOffset;
        Assert.Equal(0, entries[0].DataOffset - rootDataStart);
        Assert.Equal(update.TotalSize, entries[1].DataOffset - rootDataStart);
        Assert.Equal(update.TotalSize + normal.TotalSize, entries[2].DataOffset - rootDataStart);

        // Sizes cover header + data; hashed region is the whole partition header.
        Assert.Equal(update.TotalSize, entries[0].Size);
        Assert.Equal(normal.TotalSize, entries[1].Size);
        Assert.Equal(secure.TotalSize, entries[2].Size);
        Assert.Equal(update.Header.Length, entries[0].HashedSize);
        Assert.Equal(SHA256.HashData(update.Header), entries[0].Hash);
        Assert.Equal(SHA256.HashData(normal.Header), entries[1].Hash);
        Assert.Equal(SHA256.HashData(secure.Header), entries[2].Hash);
    }

    [Fact]
    public void ComputeFileHash_HashesFirstSector()
    {
        byte[] data = new byte[0x300];
        RandomNumberGenerator.Fill(data);
        using var ms = new MemoryStream(data);

        byte[] expected = SHA256.HashData(data.AsSpan(0, 0x200));
        Assert.Equal(expected, Hfs0Builder.ComputeFileHash(ms, data.Length));
    }

    [Fact]
    public void ComputeFileHash_ShortFileHashesEverything()
    {
        byte[] data = [1, 2, 3, 4];
        using var ms = new MemoryStream(data);
        Assert.Equal(SHA256.HashData(data), Hfs0Builder.ComputeFileHash(ms, data.Length));
    }
}

public class XciBuilderTests
{
    /// <summary>Builds an XCI from synthetic in-memory files.</summary>
    private static (byte[] Xci, List<Hfs0File> Files) BuildXci(List<byte[]> contents, bool hasKey = false, byte[]? key = null)
    {
        string[] names = ["0100000000010000.cnmt.nca", "01000000000100000000000000000A00.nca"];
        var files = contents.Select((c, i) => new Hfs0File
        {
            Name = names[i],
            Size = c.Length,
            Hash = SHA256.HashData(c.AsSpan(0, (int)Math.Min(0x200, c.Length))),
        }).ToList();

        var dict = new Dictionary<string, byte[]>();
        for (int i = 0; i < contents.Count; i++)
            dict[files[i].Name] = contents[i];

        using var ms = new MemoryStream();
        XciBuilder.Build(ms, files,
            f => new MemoryStream(dict[f.Name]),
            hasKey, hasKey ? key.AsSpan() : default);
        return (ms.ToArray(), files);
    }

    [Fact]
    public void BuiltXci_ParsesAsXciWithConsistentHeader()
    {
        var contents = new List<byte[]> { new byte[0x400], new byte[0x600] };
        RandomNumberGenerator.Fill(contents[0]);
        RandomNumberGenerator.Fill(contents[1]);

        byte[] xci = BuildXci(contents).Xci;

        using var ms = new MemoryStream(xci);
        Assert.True(XciReader.IsXci(ms));

        var header = XciReader.ReadCardHeader(ms, default);

        // NSCB writes the package id big endian; readers parse it LE, so only the
        // byte sequence itself is authoritative.
        byte[] expectedBe = [0x87, 0x50, 0xF4, 0xC0, 0xA9, 0xC5, 0xA9, 0x66];
        Assert.Equal(expectedBe, xci[XciLayout.HdrPackageId..(XciLayout.HdrPackageId + 8)]);
        Assert.Equal(header.PackageId, BinaryPrimitives.ReadUInt64LittleEndian(xci.AsSpan(XciLayout.HdrPackageId, 8)));

        var rootEntries = Hfs0.ReadEntries(ms, XciLayout.RootHfs0Offset);
        Assert.Equal(3, rootEntries.Count);

        // Total file size includes the 0xF000 image header + root HFS0 header + all partitions.
        long rootHeaderSize = rootEntries[0].DataOffset - XciLayout.RootHfs0Offset; // 0x200 (aligned)
        long totalSize = XciLayout.RootHfs0Offset + rootHeaderSize
            + rootEntries[0].Size + rootEntries[1].Size + rootEntries[2].Size;
        Assert.Equal((totalSize - 1) / XciLayout.PageSize, (long)header.ValidDataEndAddress);

        // Card size flag buckets follow NSCB's getGCsize.
        double gb = Math.Round(totalSize / 1073741824.0, 2);
        byte expectedFlag = gb >= 32 ? (byte)0xE3 : gb >= 16 ? (byte)0xE2 : gb >= 8 ? (byte)0xE1
            : gb >= 4 ? (byte)0xE0 : gb >= 2 ? (byte)0xF0 : gb >= 1 ? (byte)0xF8 : (byte)0xFA;
        Assert.Equal(expectedFlag, header.RomSizeFlag);
    }

    [Fact]
    public void BuiltXci_SecurePartitionContainsSourceData()
    {
        var contents = new List<byte[]> { new byte[0x400], new byte[0x600] };
        RandomNumberGenerator.Fill(contents[0]);
        RandomNumberGenerator.Fill(contents[1]);

        var (xci, files) = BuildXci(contents);

        using var ms = new MemoryStream(xci);
        var secureEntry = Hfs0.ReadEntries(ms, XciLayout.RootHfs0Offset).Single(e => e.Name == "secure");
        var entries = Hfs0.ReadEntries(ms, secureEntry.DataOffset);

        Assert.Equal(2, entries.Count);
        for (int i = 0; i < entries.Count; i++)
        {
            Assert.Equal(files[i].Name, entries[i].Name);
            Assert.Equal(files[i].Size, entries[i].Size);

            byte[] data = new byte[entries[i].Size];
            ms.Position = entries[i].DataOffset;
            ms.ReadExactly(data);
            Assert.Equal(contents[i], data);

            // Entry hash covers the first 0x200 bytes of the data.
            Assert.Equal(
                SHA256.HashData(contents[i].AsSpan(0, (int)Math.Min(0x200, contents[i].Length))),
                entries[i].Hash);
        }
    }

    [Fact]
    public void BuiltXci_WithoutKey_UsesNscbFixedIvAndBlob()
    {
        byte[] xci = BuildXci([new byte[0x400], new byte[0x600]]).Xci;

        // Fixed IV 5B408B145E277E81E5BF677C94888D7B at 0x120.
        Assert.Equal(0x5B, xci[0x120]);
        Assert.Equal(0x40, xci[0x121]);
        Assert.Equal(0x7B, xci[0x12F]);

        // Certificate area is 0xFF filled.
        Assert.All(xci[0x7000..0x7008], b => Assert.Equal(0xFF, b));
        // Padding area after the 0x200 header is zero.
        Assert.All(xci[0x200..0x208], b => Assert.Equal(0x00, b));
    }

    [Fact]
    public void BuiltXci_WithKey_GameInfoRoundTrips()
    {
        byte[] key = RandomNumberGenerator.GetBytes(0x10);
        byte[] xci = BuildXci([new byte[0x400], new byte[0x600]], hasKey: true, key: key).Xci;

        using var ms = new MemoryStream(xci);
        var header = XciReader.ReadCardHeader(ms, key);

        // The plaintext Game_info starts with firm_version = 1 (LE).
        Assert.True(header.IsHeaderEncryptedAreaDecrypted);
        Assert.Equal(1UL, header.FwVersion);
    }

    [Fact]
    public void BuiltXci_RomAreaStartPageMatchesSecureData()
    {
        byte[] xci = BuildXci([new byte[0x400], new byte[0x600]]).Xci;

        using var ms = new MemoryStream(xci);
        var header = XciReader.ReadCardHeader(ms, default);

        var rootEntries = Hfs0.ReadEntries(ms, XciLayout.RootHfs0Offset);
        var secureEntry = rootEntries.Single(e => e.Name == "secure");
        // NSCB formula: (secure entry offset within the root data + 0xF000 + 0x200) / 0x200.
        long rootHeaderSize = rootEntries[0].DataOffset - XciLayout.RootHfs0Offset;
        long secureDataOffset = secureEntry.DataOffset - XciLayout.RootHfs0Offset - rootHeaderSize;
        uint expected = (uint)((secureDataOffset + XciLayout.RootHfs0Offset + 0x200) / XciLayout.PageSize);
        Assert.Equal(expected, header.RomAreaStartPage);
    }

    [Fact]
    public void BuiltXci_WithNonEmptyUpdatePartition_IsReadable()
    {
        // Regression: each partition's data must immediately follow its own header so the
        // root-header offsets stay correct. Previously update data was appended after the
        // secure header, which broke the update partition whenever it was non-empty.
        byte[] updData = RandomNumberGenerator.GetBytes(0x3000);
        byte[] secData = RandomNumberGenerator.GetBytes(0x1A00);

        var update = new List<Hfs0File>
        {
            new() { Name = "0100000000010000.cnmt.nca", Size = updData.Length, Hash = SHA256.HashData(updData.AsSpan(0, 0x200)) },
        };
        var secure = new List<Hfs0File>
        {
            new() { Name = "01000000000100000000000000000A00.nca", Size = secData.Length, Hash = SHA256.HashData(secData.AsSpan(0, 0x200)) },
        };
        var data = new Dictionary<string, byte[]> { [update[0].Name] = updData, [secure[0].Name] = secData };

        using var ms = new MemoryStream();
        XciBuilder.Build(ms, secure, f => new MemoryStream(data[f.Name]), false, default,
            updateFiles: update);
        byte[] xci = ms.ToArray();

        using var rd = new MemoryStream(xci);
        var entries = ContainerReader.ReadEntries(rd, ContainerKind.Xci);
        var ue = entries.Single(e => e.Name == "update/" + update[0].Name);
        var se = entries.Single(e => e.Name == "secure/" + secure[0].Name);

        byte[] readU = new byte[ue.Size]; rd.Position = ue.Offset; rd.ReadExactly(readU);
        byte[] readS = new byte[se.Size]; rd.Position = se.Offset; rd.ReadExactly(readS);
        Assert.Equal(updData, readU);
        Assert.Equal(secData, readS);
    }
}

public class ContainerConverterTests : IDisposable
{
    private readonly string _dir;

    public ContainerConverterTests()
    {
        _dir = Path.Combine(Path.GetTempPath(), "nscb-tests-" + Guid.NewGuid().ToString("N"));
        Directory.CreateDirectory(_dir);
    }

    public void Dispose()
    {
        try { Directory.Delete(_dir, recursive: true); } catch { /* best effort */ }
    }

    private static byte[] BuildNspFile(IReadOnlyList<(string Name, byte[] Data)> files)
    {
        using var ms = new MemoryStream();
        var writer = new Pfs0Writer(ms);
        foreach (var (name, data) in files)
            writer.AddFile(name, data.Length);
        writer.WriteHeader();
        foreach (var (_, data) in files)
            ms.Write(data);
        return ms.ToArray();
    }

    [Fact]
    public void NspToXciAndBack_PreservesContent()
    {
        var files = new List<(string Name, byte[] Data)>
        {
            ("0100000000010000.cnmt.nca", RandomNumberGenerator.GetBytes(0x400)),
            ("01000000000100000000000000000A00.nca", RandomNumberGenerator.GetBytes(0x600)),
        };
        string nspPath = Path.Combine(_dir, "test.nsp");
        File.WriteAllBytes(nspPath, BuildNspFile(files));

        string xciPath = Path.Combine(_dir, "test.xci");
        ContainerConverter.NspToXci(nspPath, xciPath, keys: null);
        Assert.True(File.Exists(xciPath));
        Assert.True(XciReader.IsXci(File.OpenRead(xciPath)));

        string roundTripped = Path.Combine(_dir, "round.nsp");
        ContainerConverter.XciToNsp(xciPath, roundTripped);

        using var ms = File.OpenRead(roundTripped);
        var entries = Pfs0.ReadEntries(ms);
        Assert.Equal(files.Count, entries.Count);
        foreach (var (name, data) in files)
        {
            var entry = entries.Single(e => e.Name == name);
            Assert.Equal(data.Length, entry.Size);
            byte[] read = new byte[data.Length];
            ms.Position = entry.DataOffset;
            ms.ReadExactly(read);
            Assert.Equal(data, read);
        }
    }

    [Fact]
    public void NspToXci_RejectsNonNspSource()
    {
        string xciPath = Path.Combine(_dir, "in.xci");
        File.WriteAllBytes(xciPath, new byte[0x1000]);
        Assert.Throws<InvalidDataException>(() =>
            ContainerConverter.NspToXci(xciPath, Path.Combine(_dir, "out.xci"), keys: null));
    }

    [Fact]
    public void XciToNsp_RejectsNonXciSource()
    {
        string nspPath = Path.Combine(_dir, "in.nsp");
        File.WriteAllBytes(nspPath, new byte[0x1000]);
        Assert.Throws<InvalidDataException>(() =>
            ContainerConverter.XciToNsp(nspPath, Path.Combine(_dir, "out.nsp")));
    }
}

public class Fat32SplitterTests : IDisposable
{
    private readonly string _dir;

    public Fat32SplitterTests()
    {
        _dir = Path.Combine(Path.GetTempPath(), "nscb-fat-" + Guid.NewGuid().ToString("N"));
        Directory.CreateDirectory(_dir);
    }

    public void Dispose()
    {
        try { Directory.Delete(_dir, recursive: true); } catch { }
    }

    [Fact]
    public void SplitAndMerge_SmallFile_RoundTrips()
    {
        // A file smaller than BlockSize: split → one .00 part; merge → original.
        byte[] data = RandomNumberGenerator.GetBytes(0x2000);
        string src = Path.Combine(_dir, "test.bin");
        File.WriteAllBytes(src, data);

        int parts = Fat32Splitter.Split(src);
        Assert.Equal(1, parts);
        Assert.True(File.Exists(src + ".00"));

        string merged = Path.Combine(_dir, "merged.bin");
        Assert.True(Fat32Splitter.Merge(src, merged));
        Assert.Equal(data, File.ReadAllBytes(merged));
    }

    [Fact]
    public void SplitAndMerge_LargeFile_ProducesMultipleParts()
    {
        // Create a 3-block file using a small BlockSize override via manual split.
        // We simulate by splitting a 3*BlockSize-sized array manually.
        const long blockSize = Fat32Splitter.BlockSize;
        // Use a sparse file: set length then write at specific offsets.
        string src = Path.Combine(_dir, "big.bin");
        using (var fs = File.Create(src))
        {
            fs.SetLength(3 * blockSize);
            // Write a distinctive marker at the start of each block.
            for (int i = 0; i < 3; i++)
            {
                fs.Position = i * blockSize;
                fs.WriteByte((byte)i);
            }
        }

        int parts = Fat32Splitter.Split(src);
        Assert.Equal(3, parts);
        Assert.True(File.Exists(src + ".00"));
        Assert.True(File.Exists(src + ".01"));
        Assert.True(File.Exists(src + ".02"));

        string merged = Path.Combine(_dir, "big_merged.bin");
        Assert.True(Fat32Splitter.Merge(src, merged));

        using var ms = File.OpenRead(merged);
        Assert.Equal(3 * blockSize, ms.Length);
        for (int i = 0; i < 3; i++)
        {
            ms.Position = i * blockSize;
            Assert.Equal(i, ms.ReadByte());
        }
    }

    [Fact]
    public void IsSplitPart_CorrectlyDetects()
    {
        Assert.True(Fat32Splitter.IsSplitPart("game.xci.00"));
        Assert.True(Fat32Splitter.IsSplitPart("game.xci.01"));
        Assert.False(Fat32Splitter.IsSplitPart("game.xci"));
        Assert.False(Fat32Splitter.IsSplitPart("game.nsp"));
    }
}
