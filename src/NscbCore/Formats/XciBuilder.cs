using System.Buffers.Binary;
using System.Security.Cryptography;
using LibHac.Crypto;

namespace NscbCore.Formats;

/// <summary>
/// Builds complete XCI images, mirroring NSCB's <c>get_xciheader</c> byte-for-byte:
/// random signature, "HEAD" card header, AES-CBC encrypted Game_info area (or NSCB's
/// fixed pre-encrypted blob when the XCI header key is unavailable), zero padding,
/// a 0xFF-filled fake certificate area, the root/update/normal/secure HFS0 headers
/// and finally the streamed secure partition contents.
/// </summary>
public static class XciBuilder
{
    /// <summary>Size of the image header region: card header + Game_info + padding + certificate.</summary>
    public const long ImageHeaderSize = 0xF000;

    /// <summary>Fixed package id written by NSCB (big endian on file).</summary>
    public const ulong PackageId = 0x8750F4C0A9C5A966;

    /// <summary>Fixed initial data hash used by NSCB.</summary>
    private const string InitialDataHashHex =
        "1AB7C7B263E74E44CD3C68E40F7EF4A4D6571551D043FCA8ECF5C489F2C66E7E";

    /// <summary>IV NSCB pairs with the fixed pre-encrypted Game_info blob (big endian on file).</summary>
    private const ulong FixedIvHigh = 0x5B408B145E277E81;
    private const ulong FixedIvLow = 0xE5BF677C94888D7B;

    /// <summary>
    /// Writes a full XCI image to <paramref name="output"/>.
    /// </summary>
    /// <param name="secureFiles">Files for the secure partition, in write order.</param>
    /// <param name="openFileData">
    /// Opens the data of a file for reading (positioned at its start). The returned stream
    /// is not disposed by the builder; at least <see cref="Hfs0File.Size"/> bytes must be readable.
    /// </param>
    /// <param name="hasXciHeaderKey">Whether the real AES-CBC Game_info encryption can be used.</param>
    /// <param name="xciHeaderKey">The 16-byte XCI header key (ignored when <paramref name="hasXciHeaderKey"/> is false).</param>
    /// <param name="progress">Receives the number of bytes written.</param>
    public static void Build(
        Stream output,
        IReadOnlyList<Hfs0File> secureFiles,
        Func<Hfs0File, Stream> openFileData,
        bool hasXciHeaderKey,
        ReadOnlySpan<byte> xciHeaderKey,
        Action<long>? progress = null,
        CancellationToken ct = default,
        IReadOnlyList<Hfs0File>? updateFiles = null)
    {
        // Update partition defaults to empty (only headers) for backward compatibility.
        updateFiles ??= [];
        var update = new Hfs0Partition("update", Hfs0Builder.BuildPartitionHeader(updateFiles),
            updateFiles.Sum(f => f.Size));
        var normal = new Hfs0Partition("normal", Hfs0Builder.BuildPartitionHeader([]), 0);
        var secure = new Hfs0Partition("secure", Hfs0Builder.BuildPartitionHeader(secureFiles),
            secureFiles.Sum(f => f.Size));

        byte[] rootHeader = Hfs0Builder.BuildRootHeader([update, normal, secure]);
        long totalSize = ImageHeaderSize + rootHeader.Length + update.TotalSize + normal.TotalSize + secure.TotalSize;

        byte[] imageHeader = BuildImageHeader(rootHeader, totalSize, hasXciHeaderKey, xciHeaderKey);
        output.Position = 0;
        output.Write(imageHeader, 0, imageHeader.Length);
        progress?.Invoke(imageHeader.Length);

        output.Write(rootHeader);
        progress?.Invoke(rootHeader.Length);

        // Each HFS0 partition's data must immediately follow its own header, matching the
        // per-partition offsets recorded in the root header (see Hfs0Builder.BuildRootHeader).
        output.Write(update.Header);
        progress?.Invoke(update.Header.Length);
        foreach (var file in updateFiles)
        {
            ct.ThrowIfCancellationRequested();
            using Stream source = openFileData(file);
            CopyExact(output, source, file.Size, progress, ct);
        }

        output.Write(normal.Header);
        progress?.Invoke(normal.Header.Length);

        output.Write(secure.Header);
        progress?.Invoke(secure.Header.Length);
        foreach (var file in secureFiles)
        {
            ct.ThrowIfCancellationRequested();
            using Stream source = openFileData(file);
            CopyExact(output, source, file.Size, progress, ct);
        }
    }

    /// <summary>Builds the first 0xF000 bytes: card header + Game_info + zero padding + 0xFF certificate.</summary>
    public static byte[] BuildImageHeader(byte[] rootHeader, long totalSize, bool hasXciHeaderKey, ReadOnlySpan<byte> xciHeaderKey)
    {
        var header = new byte[0x200];

        // 0x000-0x100: random signature (NSCB uses random hex).
        RandomNumberGenerator.Fill(header.AsSpan(0, 0x100));
        "HEAD"u8.CopyTo(header.AsSpan(XciLayout.HdrMagic, 4));

        // Secure partition data offset (from the root header's third entry) in 0x200 pages.
        long secureDataOffset = BinaryPrimitives.ReadInt64LittleEndian(rootHeader.AsSpan(0x90, 8));
        uint secureStartPage = (uint)((secureDataOffset + ImageHeaderSize + 0x200) / XciLayout.PageSize);

        (byte sizeFlag, string accessFreq) = GetGamecardSize(totalSize);

        BinaryPrimitives.WriteUInt32LittleEndian(header.AsSpan(XciLayout.HdrRomAreaStartPage), secureStartPage);
        BinaryPrimitives.WriteUInt32LittleEndian(header.AsSpan(XciLayout.HdrBackupAreaStartPage), 0xFFFFFFFF);
        header[XciLayout.HdrKekTitleKeyIndex] = 0x00;
        header[XciLayout.HdrRomSize] = sizeFlag;
        header[XciLayout.HdrVersion] = 0x00;
        header[XciLayout.HdrFlags] = 0x00;
        BinaryPrimitives.WriteUInt64BigEndian(header.AsSpan(XciLayout.HdrPackageId), PackageId);
        BinaryPrimitives.WriteUInt64LittleEndian(header.AsSpan(XciLayout.HdrValidDataEndAddress), (ulong)((totalSize - 1) / XciLayout.PageSize));

        // IV: random when the XCI header key is available, NSCB's fixed one otherwise.
        var iv = new byte[0x10];
        if (hasXciHeaderKey)
            RandomNumberGenerator.Fill(iv);
        else
        {
            BinaryPrimitives.WriteUInt64BigEndian(iv.AsSpan(0, 8), FixedIvHigh);
            BinaryPrimitives.WriteUInt64BigEndian(iv.AsSpan(8, 8), FixedIvLow);
        }

        iv.CopyTo(header.AsSpan(XciLayout.HdrIv, 0x10));
        BinaryPrimitives.WriteUInt64LittleEndian(header.AsSpan(XciLayout.HdrPartitionFsHeaderAddress), (ulong)ImageHeaderSize);
        BinaryPrimitives.WriteUInt64LittleEndian(header.AsSpan(XciLayout.HdrPartitionFsHeaderSize), (ulong)rootHeader.Length);
        SHA256.HashData(rootHeader.AsSpan(0, Math.Min(0x200, rootHeader.Length)))
            .CopyTo(header.AsSpan(XciLayout.HdrPartitionFsHeaderHash, 0x20));
        Convert.FromHexString(InitialDataHashHex).CopyTo(header.AsSpan(XciLayout.HdrInitialDataHash, 0x20));
        BinaryPrimitives.WriteUInt32LittleEndian(header.AsSpan(XciLayout.HdrSelSec), 0x01);
        BinaryPrimitives.WriteUInt32LittleEndian(header.AsSpan(XciLayout.HdrSelT1Key), 0x02);
        BinaryPrimitives.WriteUInt32LittleEndian(header.AsSpan(XciLayout.HdrSelKey), 0x00);
        BinaryPrimitives.WriteUInt32LittleEndian(header.AsSpan(XciLayout.HdrLimArea), secureStartPage);

        // 0x190-0x200: Game_info (encrypted).
        if (hasXciHeaderKey)
        {
            byte[] plain = BuildGameInfoPlain(accessFreq);
            var encrypted = new byte[plain.Length];
            var cbcIv = new byte[0x10];
            iv.AsSpan().CopyTo(cbcIv);
            Array.Reverse(cbcIv); // gamecardInfoIV = IV reversed
            var cbc = new AesCbcEncryptor(xciHeaderKey[..0x10], cbcIv);
            cbc.Transform(plain, encrypted);
            encrypted.CopyTo(header.AsSpan(XciLayout.HdrEncryptedData, XciLayout.HdrEncryptedDataSize));
        }
        else
        {
            byte[] blob = GetFixedEncryptedGameInfo(totalSize);
            blob.CopyTo(header.AsSpan(XciLayout.HdrEncryptedData, XciLayout.HdrEncryptedDataSize));
        }

        // 0x200-0x7000: zero padding; 0x7000-0xF000: fake certificate filled with 0xFF.
        var image = new byte[ImageHeaderSize];
        header.CopyTo(image, 0);
        Array.Fill(image, (byte)0xFF, XciLayout.CertAreaOffset, XciLayout.CertAreaSize);
        return image;
    }

    /// <summary>Builds the 0x70 byte plaintext Game_info area (NSCB layout).</summary>
    private static byte[] BuildGameInfoPlain(string accessFreq)
    {
        var info = new byte[0x70];
        int p = 0;
        WriteHex(info, ref p, "0100000000000000");      // firm_version
        WriteHex(info, ref p, accessFreq);              // access control frequency
        WriteHex(info, ref p, "88130000");              // read wait time 1
        WriteHex(info, ref p, "00000000");              // read wait time 2
        WriteHex(info, ref p, "00000000");              // write wait time 1
        WriteHex(info, ref p, "00000000");              // write wait time 2
        WriteHex(info, ref p, "00110C00");              // firmware mode
        WriteHex(info, ref p, "5a000200");              // CUP version
        WriteHex(info, ref p, "00000000");              // reserved
        WriteHex(info, ref p, "9bfb03ddbb7c5fca");      // update partition hash (stub)
        WriteHex(info, ref p, "1608000000000001");      // CUP id
        // remaining 0x38 bytes stay zero
        return info;
    }

    /// <summary>NSCB's fixed pre-encrypted Game_info blob for images built without the XCI header key.</summary>
    private static byte[] GetFixedEncryptedGameInfo(long totalSize)
    {
        double gb = Math.Round(totalSize / 1073741824.0, 2);
        return gb >= 4
            ? ConcatHex(
                "9298F35088F09F7D", "a89a60d4", "cba6f96f", "a45bb6ac", "abc751f9", "5d398742",
                "6b38c3f2", "10da0b70", "0e5ece29", "a13cbe1da6d052cb", "f2087ce9af590538",
                "570d78b9cdd27fbeb4a0ac2adff9ba77754dd6675ac76223506b3bdabcb2e212fa465111ab7d51afc8b5b2b21c4b3f40654598620282add6")
            : ConcatHex(
                "9109FF82971EE993", "5011ca06", "3f3c4d87", "a13d28a9", "928d74f1", "49919eb7",
                "82e1f0cf", "e4a5a3bd", "f978295c", "d52639a4991bdb1f", "ed841779a3f85d23",
                "aa4242135616f5187c03cf0d97e5d218fdb245381fd1cf8dfb796fbeda4bf7f7d6b128ce89bc9eaa8552d42f597c5db866c67bb0dd8eea11");
    }

    /// <summary>NSCB's getGCsize: gamecard size flag and access frequency for a total image size.</summary>
    private static (byte Flag, string AccessFreq) GetGamecardSize(long totalSize)
    {
        double gb = Math.Round(totalSize / 1073741824.0, 2);
        byte flag = gb >= 32 ? (byte)0xE3
            : gb >= 16 ? (byte)0xE2
            : gb >= 8 ? (byte)0xE1
            : gb >= 4 ? (byte)0xE0
            : gb >= 2 ? (byte)0xF0
            : gb >= 1 ? (byte)0xF8
            : (byte)0xFA;
        return (flag, gb >= 4 ? "1000a100" : "1100a100");
    }

    private static void WriteHex(byte[] target, ref int position, string hex)
    {
        int bytes = hex.Length / 2;
        Convert.FromHexString(hex).CopyTo(target.AsSpan(position, bytes));
        position += bytes;
    }

    private static byte[] ConcatHex(params string[] parts)
        => Convert.FromHexString(string.Concat(parts));

    private static void CopyExact(Stream output, Stream source, long size, Action<long>? progress, CancellationToken ct)
    {
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
}
