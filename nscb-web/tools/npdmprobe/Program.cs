using System.Buffers.Binary;
using LibHac.FsSystem;
using NscbCore.Formats;
using NscbCore.Keys;
using NscbCore.Nsz;

// Probe: for the Program .ncz of a solid NSZ, print the authoritative NCZ section table and locate
// where each section's offset/size live in the stored NCA header (so the "prefix" cutoff can be pinned
// from real data instead of guessed header offsets).

if (args.Length < 2) { Console.Error.WriteLine("usage: npdmprobe <file.nsz> <prod.keys>"); return 1; }
string path = args[0];
var keys = NscbKeys.Load(args[1]);
NscbCore.Keys.TicketTitleKeys.RegisterFromContainer(keys, path);   // rights-id key derived from the container's own ticket

ContainerKind kind = ContainerReader.DetectKind(path);
List<ContainerEntry> entries;
using (var probe = File.OpenRead(path)) entries = ContainerReader.ReadEntries(probe, kind);

foreach (var e in entries.Where(x => x.IsNcz))
{
    using var raw = new FileStream(path, FileMode.Open, FileAccess.Read, FileShare.ReadWrite);
    raw.Position = e.Offset;
    var ncz = NczHeader.Parse(raw);
    Console.WriteLine($"\n=== NCZ entry {e.BaseName}  DecompressedSize=0x{ncz.DecompressedSize:X} ({ncz.DecompressedSize})  block={ncz.IsBlockCompressed} sections={ncz.Sections.Count} hdr={ncz.NcaHeader.Length} ===");
    foreach (var (s, i) in ncz.Sections.Select((s, i) => (s, i)))
        Console.WriteLine($"  sec{i}: offset=0x{s.Offset:X}(/{0x200}={s.Offset / 0x200:X}) size=0x{s.Size:X}(/{0x200}={s.Size / 0x200:X}) crypto={s.UseCrypto}");

    // Match each section offset/size (in 0x200 units) to a u32 position inside the stored NCA header.
    var h = ncz.NcaHeader;
    for (int i = 0; i < ncz.Sections.Count; i++)
    {
        var s = ncz.Sections[i];
        Console.WriteLine($"  sec{i}: offset/0x200 found at header bytes [{FindU32(h, (uint)(s.Offset / 0x200))}] ; size/0x200 at [{FindU32(h, (uint)(s.Size / 0x200))}]");
    }
    break; // one (program) entry is enough
}

static string FindU32(byte[] header, uint value)
{
    var hits = new List<string>();
    for (int p = 0; p + 4 <= Math.Min(header.Length, 0x400); p += 4)
        if (BinaryPrimitives.ReadUInt32LittleEndian(header.AsSpan(p, 4)) == value && value != 0)
            hits.Add("0x" + p.ToString("X"));
    return hits.Count > 0 ? string.Join(",", hits) : "-";
}
return 0;
