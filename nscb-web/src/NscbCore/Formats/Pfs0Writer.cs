using System.Buffers.Binary;
using System.Text;

namespace NscbCore.Formats;

/// <summary>
/// Builds PFS0 (NSP) container headers, mirroring NSCB's <c>gen_nsp_header</c>:
/// NUL separated string table (no trailing NUL) and the whole header padded
/// to a 0x10 boundary (always adding at least one padding byte).
/// </summary>
public static class Pfs0Builder
{
    public const int HeaderSize = 0x10;
    public const int EntrySize = 0x18;

    /// <summary>Builds a PFS0 header for the given files; data offsets are relative to the header end.</summary>
    public static byte[] BuildHeader(IReadOnlyList<(string Name, long Size)> files)
    {
        string stringTable = string.Join("\0", files.Select(f => f.Name));
        int nameTableBytes = Encoding.UTF8.GetByteCount(stringTable);
        int headerLength = HeaderSize + files.Count * EntrySize + nameTableBytes;
        int remainder = HeaderSize - headerLength % HeaderSize;
        int paddedLength = headerLength + remainder;

        var buffer = new byte[paddedLength];
        BinaryPrimitives.WriteUInt32LittleEndian(buffer, Pfs0.Magic);
        BinaryPrimitives.WriteInt32LittleEndian(buffer.AsSpan(4), files.Count);
        BinaryPrimitives.WriteInt32LittleEndian(buffer.AsSpan(8), nameTableBytes + remainder);
        // bytes 0x0C..0x10 stay zero.

        long offset = 0;
        int nameOffset = 0;
        int nameTableStart = HeaderSize + files.Count * EntrySize;
        for (int i = 0; i < files.Count; i++)
        {
            int e = HeaderSize + i * EntrySize;
            BinaryPrimitives.WriteInt64LittleEndian(buffer.AsSpan(e, 8), offset);
            BinaryPrimitives.WriteInt64LittleEndian(buffer.AsSpan(e + 8, 8), files[i].Size);
            BinaryPrimitives.WriteInt32LittleEndian(buffer.AsSpan(e + 0x10, 4), nameOffset);
            // e+0x14..0x18 stays zero.

            offset += files[i].Size;
            nameOffset += Encoding.UTF8.GetByteCount(files[i].Name) + 1;
        }

        Encoding.UTF8.GetBytes(stringTable, buffer.AsSpan(nameTableStart));
        return buffer;
    }
}

/// <summary>
/// Streaming PFS0 (NSP) writer: add files (name + known size), write the header,
/// then append each file's data sequentially. Data sizes must be added up-front
/// because the header encodes them.
/// </summary>
public sealed class Pfs0Writer(Stream output) : IDisposable
{
    private readonly List<(string Name, long Size)> _files = [];
    private bool _headerWritten;
    private long _headerLength;

    /// <summary>Total bytes written so far (for progress reporting).</summary>
    public long BytesWritten => output.Position;

    public void AddFile(string name, long size)
    {
        if (_headerWritten)
            throw new InvalidOperationException("Files must be added before WriteHeader is called.");
        if (size < 0)
            throw new ArgumentOutOfRangeException(nameof(size));
        _files.Add((name, size));
    }

    /// <summary>Writes the container header at offset 0 and leaves the stream at the first file's data.</summary>
    public void WriteHeader()
    {
        if (_headerWritten)
            throw new InvalidOperationException("Header already written.");
        byte[] header = Pfs0Builder.BuildHeader(_files);
        output.Position = 0;
        output.Write(header);
        _headerLength = header.Length;
        _headerWritten = true;
    }

    /// <summary>
    /// Copies exactly <paramref name="size"/> bytes from <paramref name="source"/> (already
    /// positioned at the file data) to the output. The output stream is sequential.
    /// </summary>
    public void CopyFileData(Stream source, long size, Action<long>? progress = null, CancellationToken ct = default)
    {
        if (!_headerWritten)
            throw new InvalidOperationException("Call WriteHeader before copying file data.");

        byte[] buffer = new byte[0x80000];
        long remaining = size;
        while (remaining > 0)
        {
            ct.ThrowIfCancellationRequested();
            int read = source.Read(buffer, 0, (int)Math.Min(buffer.Length, remaining));
            if (read == 0)
                throw new EndOfStreamException($"Source stream ended early; {remaining} bytes missing.");
            output.Write(buffer, 0, read);
            remaining -= read;
            progress?.Invoke(read);
        }
    }

    public void Dispose()
    {
        // Do not dispose the caller's stream by default.
    }
}
