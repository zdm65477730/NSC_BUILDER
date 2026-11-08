using System.Buffers.Binary;
using System.Text;

namespace NscbCore.Formats;

/// <summary>Entry of a PFS0/NSP/NSZ container.</summary>
public readonly record struct Pfs0Entry(string Name, long DataOffset, long Size)
{
    public bool IsNca => Name.EndsWith(".nca", StringComparison.OrdinalIgnoreCase);
    public bool IsNcz => Name.EndsWith(".ncz", StringComparison.OrdinalIgnoreCase);
    public bool IsTicket => Name.EndsWith(".tik", StringComparison.OrdinalIgnoreCase);
    public bool IsCert => Name.EndsWith(".cert", StringComparison.OrdinalIgnoreCase);
}

/// <summary>
/// Read-only parser for the PFS0 container used by NSP/NSZ files
/// (magic "PFS0", 0x18 byte entries, trailing string table).
/// </summary>
public static class Pfs0
{
    public const uint Magic = 0x30534650; // "PFS0" little endian

    public static bool IsPfs0(ReadOnlySpan<byte> header)
        => header.Length >= 4 && BinaryPrimitives.ReadUInt32LittleEndian(header) == Magic;

    /// <summary>Parses the container header and returns entries with absolute data offsets.</summary>
    public static List<Pfs0Entry> ReadEntries(Stream stream, long baseOffset = 0)
    {
        Span<byte> header = stackalloc byte[0x10];
        stream.Position = baseOffset;
        if (stream.Read(header) != header.Length)
            throw new InvalidDataException("Truncated PFS0 header");

        if (BinaryPrimitives.ReadUInt32LittleEndian(header) != Magic)
            throw new InvalidDataException("Not a PFS0 container");

        int fileCount = BinaryPrimitives.ReadInt32LittleEndian(header[4..]);
        int stringTableSize = BinaryPrimitives.ReadInt32LittleEndian(header[8..]);
        if (fileCount < 0 || stringTableSize < 0 || fileCount > 4096)
            throw new InvalidDataException("Invalid PFS0 header values");

        int entriesSize = 0x18 * fileCount;
        byte[] table = new byte[entriesSize + stringTableSize];
        if (stream.Read(table) != table.Length)
            throw new InvalidDataException("Truncated PFS0 entry/string table");

        long dataStart = baseOffset + 0x10 + table.Length;

        var entries = new List<Pfs0Entry>(fileCount);
        for (int i = 0; i < fileCount; i++)
        {
            int e = i * 0x18;
            long offset = BinaryPrimitives.ReadInt64LittleEndian(table.AsSpan(e, 8));
            long size = BinaryPrimitives.ReadInt64LittleEndian(table.AsSpan(e + 8, 8));
            int nameOffset = BinaryPrimitives.ReadInt32LittleEndian(table.AsSpan(e + 0x10, 4));

            string name = ReadCString(table, entriesSize + nameOffset);
            entries.Add(new Pfs0Entry(name, dataStart + offset, size));
        }

        return entries;
    }

    private static string ReadCString(byte[] table, int start)
    {
        if (start < 0 || start >= table.Length)
            return string.Empty;
        int end = Array.IndexOf(table, (byte)0, start);
        if (end < 0)
            end = table.Length;
        return Encoding.ASCII.GetString(table, start, end - start);
    }
}
