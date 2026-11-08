using System.Buffers.Binary;

namespace NscbCore.Nsz;

/// <summary>NCZ section descriptor (mirrors the NSZ NCZSECTN/NCZSECTOK layout).</summary>
public sealed class NczSection
{
    public long Offset { get; init; }
    public long Size { get; init; }

    /// <summary>1 = plaintext, 3 = AES-CTR, 4 = AES-CTR (rare).</summary>
    public long CryptoType { get; init; }

    public byte[] CryptoKey { get; init; } = new byte[0x10];
    public byte[] CryptoCounter { get; init; } = new byte[0x10];

    public bool UseCrypto => CryptoType is 3 or 4;
}

/// <summary>NCZ block header (block-compressed variant, magic "NCZBLOCK").</summary>
public sealed class NczBlockHeader
{
    public byte Version { get; init; }
    public byte Type { get; init; }
    public byte BlockSizeExponent { get; init; }
    public int NumberOfBlocks { get; init; }
    public long DecompressedSize { get; init; }
    public int[] CompressedBlockSizeList { get; init; } = [];

    public int BlockSize => 1 << BlockSizeExponent;
}

/// <summary>Parsed NCZ header: NCA header (0x4000 plaintext) + sections and optional block table.</summary>
public sealed class NczHeader
{
    public const int NcaHeaderSize = 0x4000;
    public static readonly byte[] MagicSolidNew = "NCZSECTN"u8.ToArray();
    public static readonly byte[] MagicSolidOld = "NCZSECTOK"u8.ToArray()[..8]; // legacy NSC_BUILDER/nsz
    public static readonly byte[] MagicBlock = "NCZBLOCK"u8.ToArray();

    public byte[] NcaHeader { get; init; } = new byte[NcaHeaderSize];
    public List<NczSection> Sections { get; init; } = [];
    public NczBlockHeader? Block { get; init; }

    /// <summary>Offset right after all headers - where the zstd stream / block data begins.</summary>
    public long DataOffset { get; init; }

    /// <summary>Total size of the decompressed NCA.</summary>
    public long DecompressedSize { get; init; }

    public bool IsBlockCompressed => Block is not null;

    public static bool IsNcz(ReadOnlySpan<byte> header)
        => header.Length >= 0x4000
            && (header[0x100] == (byte)'N' && header[0x101] == (byte)'C'
                && header[0x102] == (byte)'A' && (header[0x103] == (byte)'3' || header[0x103] == (byte)'2'));

    /// <summary>Parses the NCZ header from the current stream position (must be at file offset 0).</summary>
    public static NczHeader Parse(Stream stream)
    {
        var ncaHeader = new byte[NcaHeaderSize];
        if (stream.Read(ncaHeader) != NcaHeaderSize)
            throw new InvalidDataException("Truncated NCZ NCA header");

        Span<byte> magic = stackalloc byte[8];
        if (stream.Read(magic) != 8)
            throw new InvalidDataException("Truncated NCZ magic");

        bool isSection = magic.SequenceEqual(MagicSolidNew) || magic.SequenceEqual(MagicSolidOld);
        bool isBlock = magic.SequenceEqual(MagicBlock);

        if (!isSection && !isBlock)
            throw new InvalidDataException("No NCZSECTN/NCZSECTOK/NCZBLOCK magic found - not an NCZ file?");

        var sections = new List<NczSection>();
        NczBlockHeader? block = null;

        if (isSection)
        {
            byte[] countBuf = new byte[8];
            stream.ReadExactly(countBuf);
            long sectionCount = BinaryPrimitives.ReadInt64LittleEndian(countBuf);
            if (sectionCount < 0 || sectionCount > 4096)
                throw new InvalidDataException("Invalid NCZ section count");

            byte[] buf = new byte[0x40];
            for (int i = 0; i < sectionCount; i++)
            {
                stream.ReadExactly(buf);
                sections.Add(new NczSection
                {
                    Offset = BinaryPrimitives.ReadInt64LittleEndian(buf.AsSpan(0, 8)),
                    Size = BinaryPrimitives.ReadInt64LittleEndian(buf.AsSpan(8, 8)),
                    CryptoType = BinaryPrimitives.ReadInt64LittleEndian(buf.AsSpan(0x10, 8)),
                    CryptoKey = buf[0x20..0x30],
                    CryptoCounter = buf[0x30..0x40],
                });
            }

            // Leading gap between the fixed NCA header and the first section
            // is plaintext; model it as a fake section like nsz does.
            if (sections.Count > 0 && sections[0].Offset - NcaHeaderSize > 0)
            {
                sections.Insert(0, new NczSection
                {
                    Offset = NcaHeaderSize,
                    Size = sections[0].Offset - NcaHeaderSize,
                    CryptoType = 1,
                });
            }

            long decompressed = NcaHeaderSize;
            foreach (var s in sections)
                decompressed += s.Size;

            block = TryParseBlock(stream);

            return new NczHeader
            {
                NcaHeader = ncaHeader,
                Sections = sections,
                Block = block,
                DataOffset = stream.Position,
                DecompressedSize = decompressed,
            };
        }
        else
        {
            // Block magic directly after the NCA header: sections are absent; the
            // whole body (minus header) is block compressed.
            throw new InvalidDataException(
                "Standalone NCZBLOCK without NCZSECTN is not supported");
        }
    }

    /// <summary>Parses an optional NCZBLOCK table placed after the section list.</summary>
    private static NczBlockHeader? TryParseBlock(Stream stream)
    {
        long pos = stream.Position;
        Span<byte> magic = stackalloc byte[8];
        if (stream.Read(magic) != 8 || !magic.SequenceEqual(MagicBlock))
        {
            stream.Position = pos;
            return null;
        }

        int version = stream.ReadByte();
        int type = stream.ReadByte();
        stream.ReadByte(); // unused
        int exponent = stream.ReadByte();
        byte[] u32buf = new byte[4];
        stream.ReadExactly(u32buf);
        int numberOfBlocks = BinaryPrimitives.ReadInt32LittleEndian(u32buf);
        byte[] u64buf = new byte[8];
        stream.ReadExactly(u64buf);
        long decompressedSize = BinaryPrimitives.ReadInt64LittleEndian(u64buf);

        if (exponent is < 14 or > 32)
            throw new InvalidDataException("Corrupted NCZBLOCK header: block size exponent out of range");
        if (numberOfBlocks < 0 || numberOfBlocks > 10_000_000)
            throw new InvalidDataException("Corrupted NCZBLOCK header: block count out of range");

        int[] sizes = new int[numberOfBlocks];
        byte[] listBuf = new byte[4 * numberOfBlocks];
        stream.ReadExactly(listBuf);
        for (int i = 0; i < numberOfBlocks; i++)
            sizes[i] = BinaryPrimitives.ReadInt32LittleEndian(listBuf.AsSpan(i * 4, 4));

        _ = version;
        _ = type;
        return new NczBlockHeader
        {
            Version = (byte)version,
            Type = (byte)type,
            BlockSizeExponent = (byte)exponent,
            NumberOfBlocks = numberOfBlocks,
            DecompressedSize = decompressedSize,
            CompressedBlockSizeList = sizes,
        };
    }
}
