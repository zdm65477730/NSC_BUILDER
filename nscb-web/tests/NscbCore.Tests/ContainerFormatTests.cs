using System.Buffers.Binary;
using System.Security.Cryptography;
using System.Text;
using LibHac.Common.Keys;
using NscbCore.Formats;
using NscbCore.Info;
using NscbCore.Keys;
using NscbCore.Nsz;
using NscbCore.Patching;
using Xunit;

namespace NscbCore.Tests;

public class NcaHeaderFieldsTests
{
    [Fact]
    public void Parse_ExtractsFieldsFromSyntheticNca3Header()
    {
        byte[] header = new byte[0x4000];
        "NCA3"u8.CopyTo(header.AsSpan(0x200));
        header[0x204] = 1;                        // gamecard distribution
        header[0x205] = 2;                        // control
        header[0x206] = 17;                       // keygen old
        header[0x207] = 0;                        // kaek index
        BinaryPrimitives.WriteInt64LittleEndian(header.AsSpan(0x208), 0x1FFC00);
        BinaryPrimitives.WriteUInt64LittleEndian(header.AsSpan(0x210), 0x0100A3B00ABC8000UL);
        header[0x220] = 0;                        // crypto type 2
        header[0x221] = 18;                       // keygen new
        header[0x230] = 0xAB; // rights id first byte
        var fields = NcaHeaderFields.Parse(header);
        Assert.True(fields.IsNca3);
        Assert.Equal(2, fields.ContentTypeByte);
        Assert.Equal(1, fields.DistributionType);
        Assert.Equal(17, fields.KeyGenerationOld);
        Assert.Equal(18, fields.KeyGenerationNew);
        Assert.Equal(18, fields.KeyGeneration);
        Assert.Equal(0x1FFC00, fields.NcaSize);
        Assert.Equal(0x0100A3B00ABC8000UL, fields.TitleId);
        Assert.True(fields.HasRightsId);
        Assert.Equal("Control", NcaHeaderFields.ContentTypeString(fields.ContentTypeByte));
        Assert.Equal("GameCard", NcaHeaderFields.DistributionTypeString(fields.DistributionType));
    }

    [Fact]
    public void Parse_RejectsInvalidHeader()
    {
        byte[] header = new byte[0x4000];
        Assert.Throws<InvalidDataException>(() => NcaHeaderFields.Parse(header));
    }
}

public class NacpInfoTests
{
    [Fact]
    public void Parse_ExtractsLanguageEntriesAndCoreFields()
    {
        byte[] nacp = new byte[0x4000];
        Encoding.UTF8.GetBytes("Zelda: Tears of the Kingdom\0").CopyTo(nacp, 0x0000);
        Encoding.UTF8.GetBytes("Nintendo\0").CopyTo(nacp, 0x0200);
        "\u585e\u5c14\u8fbe\u4f20\u8bf4 \u738b\u56fd\u4e4b\u6cea\0"u8.CopyTo(nacp.AsSpan(14 * 0x300)); // SimplifiedChinese entry
        "1.1.0\0"u8.CopyTo(nacp.AsSpan(0x3060));
        nacp[0x3212] = 2; // program index
        BinaryPrimitives.WriteUInt64LittleEndian(nacp.AsSpan(0x3078), 0x0100000000000ABCUL);

        var info = NacpInfo.Parse(nacp);

        Assert.Equal(2, info.Languages.Count);
        Assert.Equal("AmericanEnglish", info.Languages[0].Language);
        Assert.Equal("Zelda: Tears of the Kingdom", info.Languages[0].Name);
        Assert.Equal("Nintendo", info.Languages[0].Publisher);
        // SimplifiedChinese preferred for the aggregate display name
        Assert.Equal("SimplifiedChinese", info.Languages[1].Language);
        Assert.Equal("\u585e\u5c14\u8fbe\u4f20\u8bf4 \u738b\u56fd\u4e4b\u6cea", info.DisplayName);
        Assert.Equal("Nintendo", info.Publisher);
        Assert.Equal("1.1.0", info.DisplayVersion);
        Assert.Equal(2, info.ProgramIndex);
        Assert.Equal(0x0100000000000ABCUL, info.SaveDataOwnerId);
    }

    [Fact]
    public void Parse_EmptyNacp_YieldsEmptyDefaults()
    {
        var info = NacpInfo.Parse(new byte[0x4000]);
        Assert.Empty(info.Languages);
        Assert.Equal("", info.DisplayName);
        Assert.Equal("", info.Publisher);
        Assert.Equal("", info.DisplayVersion);
    }
}

public class Pfs0Tests
{
    [Fact]
    public void ReadEntries_ParsesSyntheticContainer()
    {
        byte[] file1 = Encoding.ASCII.GetBytes("hello world");
        byte[] file2 = new byte[0x40];
        byte[] container = BuildPfs0([("test.nca", file1), ("0100000000010800.cnmt", file2)]);

        using var ms = new MemoryStream(container);
        var entries = Pfs0.ReadEntries(ms);

        Assert.Equal(2, entries.Count);
        Assert.Equal("test.nca", entries[0].Name);
        Assert.Equal(file1.Length, entries[0].Size);
        Assert.True(entries[0].IsNca);
        Assert.Equal(container.Length - file2.Length, entries[1].DataOffset);
        Assert.EndsWith(".cnmt", entries[1].Name, StringComparison.Ordinal);
    }

    [Fact]
    public void ReadEntries_RejectsNonPfs0()
    {
        Assert.Throws<InvalidDataException>(() =>
        {
            using var ms = new MemoryStream(new byte[0x100]);
            Pfs0.ReadEntries(ms);
        });
    }

    /// <summary>Builds a minimal PFS0: header + entry table + string table + data.</summary>
    internal static byte[] BuildPfs0((string Name, byte[] Data)[] files)
    {
        int count = files.Length;
        int stringTableSize = files.Sum(f => Encoding.ASCII.GetByteCount(f.Name) + 1);
        int headerSize = 0x10 + count * 0x18 + stringTableSize;

        long offset = 0;
        var entryBytes = new List<byte>();
        var stringBytes = new List<byte>();
        foreach (var (name, _) in files)
        {
            int nameOffset = stringBytes.Count;
            stringBytes.AddRange(Encoding.ASCII.GetBytes(name));
            stringBytes.Add(0);

            byte[] e = new byte[0x18];
            BinaryPrimitives.WriteInt64LittleEndian(e.AsSpan(0, 8), offset);
            BinaryPrimitives.WriteInt64LittleEndian(e.AsSpan(8, 8), files.First(f => f.Name == name).Data.Length);
            BinaryPrimitives.WriteInt32LittleEndian(e.AsSpan(0x10, 4), nameOffset);
            entryBytes.AddRange(e);
            offset += files.First(f => f.Name == name).Data.Length;
        }

        using var ms = new MemoryStream();
        ms.Write("PFS0"u8);
        WriteI32(ms, count);
        WriteI32(ms, stringTableSize);
        WriteI32(ms, 0);
        ms.Write([.. entryBytes]);
        ms.Write([.. stringBytes]);
        foreach (var (_, data) in files)
            ms.Write(data);
        return ms.ToArray();
    }

    internal static void WriteI32(Stream s, int v)
    {
        Span<byte> b = stackalloc byte[4];
        System.Buffers.Binary.BinaryPrimitives.WriteInt32LittleEndian(b, v);
        s.Write(b);
    }
}

public class Hfs0Tests
{
    [Fact]
    public void ReadEntries_ParsesSyntheticPartition()
    {
        byte[] data = Encoding.ASCII.GetBytes("x");
        int count = 1;
        int stringTableSize = 8; // "secure\0" + padding
        int headerSize = 0x10 + count * 0x40 + stringTableSize;

        using var ms = new MemoryStream();
        ms.Write("HFS0"u8);
        Pfs0Tests.WriteI32(ms, count);
        Pfs0Tests.WriteI32(ms, stringTableSize);
        Pfs0Tests.WriteI32(ms, 0);

        byte[] entry = new byte[0x40];
        BinaryPrimitives.WriteInt64LittleEndian(entry.AsSpan(0, 8), 0);            // offset
        BinaryPrimitives.WriteInt64LittleEndian(entry.AsSpan(8, 8), data.Length);  // size
        BinaryPrimitives.WriteInt32LittleEndian(entry.AsSpan(0x10, 4), 0);         // name offset
        BinaryPrimitives.WriteInt32LittleEndian(entry.AsSpan(0x14, 4), 0x200);     // hashed size
        ms.Write(entry);

        byte[] names = new byte[stringTableSize];
        Encoding.ASCII.GetBytes("secure\0").CopyTo(names, 0);
        ms.Write(names);
        ms.Write(data);

        using var readable = new MemoryStream(ms.ToArray());
        var entries = Hfs0.ReadEntries(readable, 0);

        var e = Assert.Single(entries);
        Assert.Equal("secure", e.Name);
        Assert.Equal(1, e.Size);
        Assert.Equal(headerSize, e.DataOffset);
        Assert.Equal(0x200, e.HashedSize);
        Assert.All(e.Hash, b => Assert.Equal(0, b));
    }
}

public class NczHeaderTests
{
    [Fact]
    public void Parse_SolidSections_WithFakeSectionForGap()
    {
        byte[] ncz = new byte[0x4000];
        "NCA3"u8.CopyTo(ncz.AsSpan(0x200));
        using var ms = new MemoryStream();
        ms.Write(ncz);                                  // NCA header 0x4000
        ms.Write("NCZSECTN"u8);
        WriteI64(ms, 2);                                // section count

        WriteSection(ms, offset: 0x4000, size: 0x10000, cryptoType: 3, key: 0x11, counter: 0x22);
        WriteSection(ms, offset: 0x14000, size: 0x20000, cryptoType: 1, key: 0, counter: 0);

        ms.Write("zstd-frame-data"u8);
        ms.Position = 0;

        var hdr = NczHeader.Parse(ms);
        Assert.False(hdr.IsBlockCompressed);
        Assert.Equal(2, hdr.Sections.Count);            // no gap -> no fake section inserted
        Assert.Equal(0x4000, hdr.Sections[0].Offset);
        Assert.Equal(0x10000, hdr.Sections[0].Size);
        Assert.Equal(0x4000 + 0x90, hdr.DataOffset);   // 0x10 header/magic + 2×0x40 sections
        Assert.Equal(0x4000 + 0x10000 + 0x20000, hdr.DecompressedSize);
        Assert.Equal(3, hdr.Sections[0].CryptoType);
        Assert.True(hdr.Sections[0].UseCrypto);
        Assert.Equal(0x11, hdr.Sections[0].CryptoKey[0]);
        Assert.Equal(1, hdr.Sections[1].CryptoType);
        Assert.False(hdr.Sections[1].UseCrypto);
    }

    [Fact]
    public void Parse_BlockCompressed_ParsesBlockTable()
    {
        byte[] ncz = new byte[0x4000];
        using var ms = new MemoryStream();
        ms.Write(ncz);
        ms.Write("NCZSECTN"u8);
        WriteI64(ms, 1);
        WriteSection(ms, offset: 0x4000, size: 0x30000, cryptoType: 1, key: 0, counter: 0);

        ms.Write("NCZBLOCK"u8);
        ms.WriteByte(2);        // version
        ms.WriteByte(1);        // type
        ms.WriteByte(0);        // unused
        ms.WriteByte(16);       // exponent -> 64 KiB blocks
        WriteI32(ms, 3);        // block count
        WriteI64(ms, 0x30000);  // decompressed size
        WriteI32(ms, 0x8000);   // block 0 compressed size
        WriteI32(ms, 0x10000);  // block 1 (stored)
        WriteI32(ms, 0x9000);   // block 2
        ms.Write("payload"u8);
        ms.Position = 0;

        var hdr = NczHeader.Parse(ms);
        Assert.True(hdr.IsBlockCompressed);
        var block = hdr.Block!;
        Assert.Equal(16, block.BlockSizeExponent);
        Assert.Equal(0x10000, block.BlockSize);
        Assert.Equal(3, block.NumberOfBlocks);
        Assert.Equal(new[] { 0x8000, 0x10000, 0x9000 }, block.CompressedBlockSizeList);
        Assert.Equal(0x30000, block.DecompressedSize);
    }

    [Fact]
    public void Parse_RejectsUnknownMagic()
    {
        using var ms = new MemoryStream(new byte[0x4008]);
        ms.Write(new byte[0x4000]);
        ms.Write("NOTMAGIC"u8);
        ms.Position = 0;
        Assert.Throws<InvalidDataException>(() => NczHeader.Parse(ms));
    }

    private static void WriteSection(Stream s, long offset, long size, long cryptoType, byte key, byte counter)
    {
        byte[] buf = new byte[0x40];
        BinaryPrimitives.WriteInt64LittleEndian(buf.AsSpan(0, 8), offset);
        BinaryPrimitives.WriteInt64LittleEndian(buf.AsSpan(8, 8), size);
        BinaryPrimitives.WriteInt64LittleEndian(buf.AsSpan(0x10, 8), cryptoType);
        if (key != 0) buf[0x20] = key;
        if (counter != 0) buf[0x30] = counter;
        s.Write(buf);
    }

    private static void WriteI64(Stream s, long v)
    {
        Span<byte> b = stackalloc byte[8];
        System.Buffers.Binary.BinaryPrimitives.WriteInt64LittleEndian(b, v);
        s.Write(b);
    }

    private static void WriteI32(Stream s, int v)
    {
        Span<byte> b = stackalloc byte[4];
        System.Buffers.Binary.BinaryPrimitives.WriteInt32LittleEndian(b, v);
        s.Write(b);
    }
}

public class XciCardHeaderTests
{
    [Fact]
    public void ReadCardHeader_DecryptsFirmwareVersion()
    {
        byte[] key = new byte[0x10];
        Random.Shared.NextBytes(key);
        ulong rsv = 0x4C000000; // 19.0.0

        byte[] container = BuildXci(key, rsv);
        using var ms = new MemoryStream(container);

        Assert.True(XciReader.IsXci(ms));

        var header = XciReader.ReadCardHeader(ms, key);
        Assert.True(header.IsHeaderEncryptedAreaDecrypted);
        Assert.Equal(rsv, header.FwVersion);
        Assert.Equal((byte)0xE1, header.RomSizeFlag);
        Assert.Equal(0x11223344U, header.PackageId);
    }

    [Fact]
    public void ReadCardHeader_WithoutKey_SkipsEncryptedArea()
    {
        byte[] key = new byte[0x10];
        Random.Shared.NextBytes(key);
        byte[] container = BuildXci(key, 0x4C000000);
        using var ms = new MemoryStream(container);

        var header = XciReader.ReadCardHeader(ms, ReadOnlySpan<byte>.Empty);
        Assert.False(header.IsHeaderEncryptedAreaDecrypted);
        Assert.Null(header.FwVersion);
    }

    private static byte[] BuildXci(byte[] headerKey, ulong rsv)
    {
        byte[] xci = new byte[0xF000 + 0x10];
        "HEAD"u8.CopyTo(xci.AsSpan(0x100));
        BinaryPrimitives.WriteUInt32LittleEndian(xci.AsSpan(0x10D - 1), 0); // kek/titlekey index byte
        xci[0x10D] = 0xE1;                                                  // rom size 16GB
        BinaryPrimitives.WriteUInt32LittleEndian(xci.AsSpan(0x118), 0x1234);
        BinaryPrimitives.WriteUInt64LittleEndian(xci.AsSpan(0x110), 0x11223344UL); // package id
        BinaryPrimitives.WriteUInt64LittleEndian(xci.AsSpan(0x130), 0xF000UL);     // partition fs address

        byte[] iv = new byte[0x10];
        Random.Shared.NextBytes(iv);
        iv.CopyTo(xci.AsSpan(0x120));

        byte[] plain = new byte[0x70];
        BinaryPrimitives.WriteUInt64LittleEndian(plain.AsSpan(0), rsv);

        using Aes aes = Aes.Create();
        aes.Key = headerKey;
        aes.Mode = CipherMode.CBC;
        aes.Padding = PaddingMode.None;
        byte[] encIv = (byte[])iv.Clone();
        Array.Reverse(encIv);
        aes.IV = encIv;
        byte[] encrypted = aes.CreateEncryptor().TransformFinalBlock(plain, 0, plain.Length);
        encrypted.CopyTo(xci.AsSpan(0x190));

        return xci;
    }
}

public class NczProcessorTests
{
    /// <summary>
    /// Builds a minimal synthetic NCZ with two plaintext sections (cryptoType=1) so the
    /// decompressor path can be tested without any keys.
    /// </summary>
    [Fact]
    public void NczSolidDecompress_ReconstructsNcaBody()
    {
        // ── 1. Prepare NCA header (0x4000 bytes, magic "NCA3") ────────────────
        byte[] ncaHeader = new byte[0x4000];
        ncaHeader[0x200] = (byte)'N'; ncaHeader[0x201] = (byte)'C';
        ncaHeader[0x202] = (byte)'A'; ncaHeader[0x203] = (byte)'3';
        // Section table at 0x240: one enabled section at offset 0x4000, size 0x200.
        BinaryPrimitives.WriteInt64LittleEndian(ncaHeader.AsSpan(0x240), 0x4000);
        BinaryPrimitives.WriteInt64LittleEndian(ncaHeader.AsSpan(0x248), 0x200);

        // ── 2. Two plaintext body sections ────────────────────────────────────
        // Section A: gap 0x4000..0x4100 (256 bytes of plaintext)
        // Section B: data 0x4100..0x4200 (256 bytes of plaintext)
        byte[] secA = new byte[0x100];
        byte[] secB = new byte[0x100];
        Array.Fill(secA, (byte)0xAA);
        Array.Fill(secB, (byte)0xBB);
        byte[] bodyPlain = [.. secA, .. secB]; // contiguous body

        // ── 3. Build NCZ section table (2 sections, both plaintext) ───────────
        var sections = new List<NczSection>
        {
            new() { Offset = 0x4000, Size = 0x100, CryptoType = 1 },
            new() { Offset = 0x4100, Size = 0x100, CryptoType = 1 },
        };
        byte[] sectTable = BuildSectionTable(sections);

        // ── 4. Zstd-compress the body ─────────────────────────────────────────
        using var zstdCompressed = new MemoryStream();
        {
            using var comp = new ZstdSharp.Compressor(3);
            byte[] compressed = comp.Wrap(bodyPlain).ToArray();
            zstdCompressed.Write(compressed);
        }
        zstdCompressed.Position = 0;

        // ── 5. Assemble synthetic NCZ ─────────────────────────────────────────
        using var nczStream = new MemoryStream();
        nczStream.Write(ncaHeader);   // 0x4000
        nczStream.Write(sectTable);   // NCZSECTN + sections
        zstdCompressed.CopyTo(nczStream);
        nczStream.Position = 0;

        // ── 6. Decompress ─────────────────────────────────────────────────────
        using var ncaOut = new MemoryStream();
        NczProcessor.Decompress(nczStream, ncaOut);
        ncaOut.Position = 0;

        // ── 7. Verify NCA structure ───────────────────────────────────────────
        byte[] result = new byte[ncaOut.Length];
        ncaOut.ReadExactly(result);

        // Header is preserved.
        Assert.Equal(ncaHeader, result.AsSpan(0, 0x4000).ToArray());
        // Body sections are placed in order.
        Assert.Equal(secA, result.AsSpan(0x4000, 0x100).ToArray());
        Assert.Equal(secB, result.AsSpan(0x4100, 0x100).ToArray());
    }

    private static byte[] BuildSectionTable(List<NczSection> sections)
    {
        byte[] buf = new byte[16 + sections.Count * 0x40];
        NczHeader.MagicSolidNew.CopyTo(buf);
        BinaryPrimitives.WriteInt64LittleEndian(buf.AsSpan(8), sections.Count);
        for (int i = 0; i < sections.Count; i++)
        {
            var s = sections[i];
            int o = 16 + i * 0x40;
            BinaryPrimitives.WriteInt64LittleEndian(buf.AsSpan(o),        s.Offset);
            BinaryPrimitives.WriteInt64LittleEndian(buf.AsSpan(o + 8),    s.Size);
            BinaryPrimitives.WriteInt64LittleEndian(buf.AsSpan(o + 0x10), s.CryptoType);
            // key/counter remain zero for plaintext sections
        }
        return buf;
    }
}

public class NcaPatcherTests
{
    /// <summary>
    /// Builds a minimal synthetic Meta NCA (NCA2 Download, plaintext header) whose
    /// cnmt PFS0 lives at LibHac section index 1 (Data section).
    /// Returns the NCA bytes and the absolute RSV byte offset inside the file.
    /// </summary>
    private static byte[] BuildSyntheticMetaNca(uint initialRsv, out int rsvFileOffset)
    {
        const long HeaderSize = 0x4000;
        const int MetaFsIdx = 0; // LibHac section index 0 for Meta NCA PFS0

        // PFS0 layout: 1 file named "cnmt", 0x30-byte cnmt data (RSV at +0x28)
        string cnmtName = "cnmt";
        int nameTableSize = cnmtName.Length + 1; // NUL-terminated
        int rawH = 0x10 + 0x18 + nameTableSize;
        int rem  = (0x10 - rawH % 0x10) % 0x10;
        int pfs0Hdr = rawH + rem;
        const int cnmtDataSize = 0x30;
        int pfs0Total = pfs0Hdr + cnmtDataSize;
        // Section must be 0x200-byte aligned in the NCA FsEntry block scheme
        int ncaSectionBytes = ((pfs0Total + 0x1FF) / 0x200) * 0x200;

        byte[] nca = new byte[HeaderSize + ncaSectionBytes];

        // NCA header magic and basic fields
        nca[0x200] = (byte)'N'; nca[0x201] = (byte)'C'; nca[0x202] = (byte)'A'; nca[0x203] = (byte)'3';
        nca[0x204] = 0;  // distribution = Download → plaintext header
        nca[0x205] = 1;  // contentType = Meta
        nca[0x206] = 0;  // keygen old
        nca[0x221] = 0;  // keygen new
        BinaryPrimitives.WriteInt64LittleEndian(nca.AsSpan(0x208), nca.Length);
        BinaryPrimitives.WriteUInt64LittleEndian(nca.AsSpan(0x210), 0x0100000000010000UL);

        // FsEntry[MetaFsIdx] at 0x240 + MetaFsIdx*0x10:
        // u32 dataStartBlock (0x200-byte blocks from NCA byte 0)
        // u32 dataEndBlock
        int startBlock = (int)(HeaderSize / 0x200);
        int endBlock   = (int)((HeaderSize + ncaSectionBytes) / 0x200);
        int fe = 0x240 + MetaFsIdx * 0x10;
        BinaryPrimitives.WriteInt32LittleEndian(nca.AsSpan(fe),     startBlock);
        BinaryPrimitives.WriteInt32LittleEndian(nca.AsSpan(fe + 4), endBlock);

        // FsHeader[MetaFsIdx] at 0x400 + MetaFsIdx*0x200:
        // LibHac enum values: FormatType.Pfs0=1, HashType.None=1, EncryptionType.None=1
        int fh = 0x400 + MetaFsIdx * 0x200;
        nca[fh + 0x03] = 1; // formatType = Pfs0
        nca[fh + 0x04] = 1; // hashType = None
        nca[fh + 0x05] = 1; // cryptoType = None (plaintext)

        // PFS0 data starts at HeaderSize
        int p = (int)HeaderSize;
        BinaryPrimitives.WriteUInt32LittleEndian(nca.AsSpan(p,      4), 0x30534650); // "PFS0"
        BinaryPrimitives.WriteInt32LittleEndian(nca.AsSpan(p + 4),  1);               // fileCount
        BinaryPrimitives.WriteInt32LittleEndian(nca.AsSpan(p + 8),  nameTableSize + rem);
        // Entry[0]: offset=0 (data starts right after PFS0 hdr), size=cnmtDataSize
        BinaryPrimitives.WriteInt64LittleEndian(nca.AsSpan(p + 0x10), 0);
        BinaryPrimitives.WriteInt64LittleEndian(nca.AsSpan(p + 0x18), cnmtDataSize);
        Encoding.ASCII.GetBytes(cnmtName).CopyTo(nca.AsSpan(p + 0x28)); // name

        // cnmt data: RSV at cnmt_start + 0x28
        int cnmtStart = p + pfs0Hdr;
        rsvFileOffset = cnmtStart + 0x28;
        BinaryPrimitives.WriteUInt32LittleEndian(nca.AsSpan(rsvFileOffset), initialRsv);

        // Compute and store hblock hash for FsHeader[MetaFsIdx] (LibHac verifies this).
        byte[] fsHdrBlock = nca[fh..(fh + 0x200)];
        byte[] hblockHash = SHA256.HashData(fsHdrBlock);
        hblockHash.CopyTo(nca, 0x280 + 0x20 * MetaFsIdx);

        return nca;
    }

    // End-to-end cnmt RSV patch behaviour is validated against real Switch samples by
    // tools/itest/run_all.py (test #7), which exercises the full LibHac + AES-CTR path.

    [Fact]
    public void PatchCnmtRsv_ReturnsFalseForNonMetaNca()
    {
        byte[] nca = BuildSyntheticMetaNca(0x1E, out _);
        nca[0x205] = 0; // Program, not Meta
        using var ms = new MemoryStream(nca);
        Assert.False(NcaPatcher.PatchCnmtRequiredSystemVersion(
            ms, 0, nca.Length, KeySet.CreateDefaultKeySet(), 0x0A));
    }

    [Fact]
    public void PatchXciGameInfoFwVersion_ModifiesFwField()
    {
        byte[] key = RandomNumberGenerator.GetBytes(0x10);
        byte[] iv  = RandomNumberGenerator.GetBytes(0x10);
        byte[] plain = new byte[0x70];
        BinaryPrimitives.WriteUInt64LittleEndian(plain.AsSpan(0, 8), 0x99);

        byte[] header = new byte[0x200];
        header[0x100] = (byte)'H'; header[0x101] = (byte)'E';
        header[0x102] = (byte)'A'; header[0x103] = (byte)'D';
        iv.CopyTo(header.AsSpan(0x120));

        byte[] revIv = (byte[])iv.Clone(); Array.Reverse(revIv);
        using (var aes = System.Security.Cryptography.Aes.Create())
        {
            aes.Key = key; aes.IV = revIv;
            aes.Mode = System.Security.Cryptography.CipherMode.CBC;
            aes.Padding = System.Security.Cryptography.PaddingMode.None;
            byte[] enc = aes.CreateEncryptor().TransformFinalBlock(plain, 0, plain.Length);
            enc.CopyTo(header.AsSpan(0x190));
        }

        using var ms = new MemoryStream();
        ms.Write(header); ms.Position = 0;

        Assert.True(NcaPatcher.PatchXciGameInfoFwVersion(ms, key, 0x42));

        ms.Position = 0;
        var hdr = new byte[0x200]; ms.ReadExactly(hdr);
        byte[] revIv2 = hdr[0x120..0x130]; Array.Reverse(revIv2);
        using (var aes2 = System.Security.Cryptography.Aes.Create())
        {
            aes2.Key = key; aes2.IV = revIv2;
            aes2.Mode = System.Security.Cryptography.CipherMode.CBC;
            aes2.Padding = System.Security.Cryptography.PaddingMode.None;
            byte[] dec = aes2.CreateDecryptor().TransformFinalBlock(hdr[0x190..0x200], 0, 0x70);
            Assert.Equal(0x42UL, BinaryPrimitives.ReadUInt64LittleEndian(dec));
        }
    }
}
