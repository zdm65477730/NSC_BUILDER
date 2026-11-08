using NscbCore.Formats;
using IOPath = System.IO.Path;

namespace NscbCore.Patching;

/// <summary>
/// remlinkacc: clear the account/console binding from tickets so they behave as
/// common tickets again. This is a pure byte edit (no re-signing): the 8-byte
/// account id at <see cref="AccountIdOffset"/> is zeroed. Tinfoil installs do not
/// check the signature over this field, so clearing it is enough to detach a
/// personal ticket from its original account. Port of NSCB's ticket account reset.
/// </summary>
public static class TicketAccountPatcher
{
    /// <summary>Absolute offset of the 8-byte account id inside a ticket.</summary>
    public const long AccountIdOffset = 0x198;
    public const int AccountIdSize = 8;

    /// <summary>Result of one ticket patch: the bytes that were present before zeroing.</summary>
    public sealed record PatchedTicket(string Name, byte[] PreviousBytes)
    {
        public bool WasCleared => PreviousBytes.Any(b => b != 0);
    }

    /// <summary>Patch a single standalone <c>.tik</c> file in place. Returns the previous account id bytes.</summary>
    public static PatchedTicket PatchTicketFile(string tikPath)
    {
        byte[] data = File.ReadAllBytes(tikPath);
        PatchedTicket r = PatchTicketBytesInPlace(data, IOPath.GetFileName(tikPath));
        File.WriteAllBytes(tikPath, data);
        return r;
    }

    /// <summary>
    /// Copy a container (NSP/NSZ/XCI/XCZ) to <paramref name="outputPath"/> and clear the
    /// account id of every ticket it contains. Returns one record per ticket found.
    /// </summary>
    public static IReadOnlyList<PatchedTicket> PatchContainer(string containerPath, string outputPath,
        CancellationToken ct = default)
    {
        ContainerKind kind = ContainerReader.DetectKind(containerPath);
        List<ContainerEntry> tickets;
        using (var probe = File.OpenRead(containerPath))
            tickets = ContainerReader.ReadEntries(probe, kind)
                .Where(e => e.IsTicket)
                .ToList();

        if (tickets.Count == 0)
            throw new InvalidOperationException($"No tickets found in: {containerPath}");

        if (!ReferenceEquals(containerPath, outputPath))
            File.Copy(containerPath, outputPath, overwrite: true);

        var results = new List<PatchedTicket>();
        using var fs = new FileStream(outputPath, FileMode.Open, FileAccess.ReadWrite);
        foreach (var t in tickets)
        {
            ct.ThrowIfCancellationRequested();
            byte[] buf = new byte[t.Size];
            fs.Position = t.Offset;
            fs.ReadExactly(buf);
            results.Add(PatchTicketBytesInPlace(buf, IOPath.GetFileName(t.Name)));
            fs.Position = t.Offset;
            fs.Write(buf, 0, buf.Length);
        }
        return results;
    }

    /// <summary>Zero the account id bytes within an in-memory ticket image.</summary>
    private static PatchedTicket PatchTicketBytesInPlace(byte[] ticket, string name)
    {
        if (ticket.Length < AccountIdOffset + AccountIdSize)
            throw new InvalidDataException($"Ticket '{name}' is too small ({ticket.Length} B) to contain an account id.");

        byte[] prev = new byte[AccountIdSize];
        Array.Copy(ticket, (int)AccountIdOffset, prev, 0, AccountIdSize);
        Array.Clear(ticket, (int)AccountIdOffset, AccountIdSize);
        return new PatchedTicket(name, prev);
    }
}
