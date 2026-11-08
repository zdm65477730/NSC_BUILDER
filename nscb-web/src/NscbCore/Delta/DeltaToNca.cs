using LibHac.Common.Keys;
using LibHac.Fs;
using LibHac.FsSystem;
using LibHac.Tools.FsSystem;
using LibHac.Tools.FsSystem.NcaUtils;
using NscbCore.Ncm;

namespace NscbCore.Delta;

/// <summary>
/// Materializes a Switch delta fragment into a standalone NCA: applies the delta over its base
/// section (verified via LibHac's <c>OpenStorageWithPatch</c> under <see cref="IntegrityCheckLevel.ErrorOnInvalid"/>,
/// which throws unless the base+delta pairing AND the final hash chain are correct), then rebuilds
/// that section's IVFC hash tree in the base NCA to produce a full, self-contained updated NCA.
/// </summary>
/// <remarks>
/// Operates on NCAs small enough to hold in memory (Data/AocData/section-replace cases). Program
/// NCAs (multi-GB) with ACFC/LZ4-compressed RomFS are a separate path (needs a stream-based IVFC
/// rebuild + compression handling — see the compressed-section follow-up).
/// </remarks>
public static class DeltaToNca
{
    /// <summary>Apply <paramref name="deltaNca"/> over <paramref name="baseNca"/> section <paramref name="index"/>;
    /// returns the full patched logical content, throwing if the pairing/chain is invalid.</summary>
    public static byte[] Apply(byte[] baseNca, byte[] deltaNca, KeySet keySet, int index)
    {
        var b = new Nca(keySet, new MemoryStorage(baseNca));
        var d = new Nca(keySet, new MemoryStorage(deltaNca));
        IStorage st = b.OpenStorageWithPatch(d, index, IntegrityCheckLevel.ErrorOnInvalid);
        st.GetSize(out long size).ThrowIfFailure();
        byte[] outBuf = new byte[size];
        st.Read(0, outBuf).ThrowIfFailure(); // full read → verifies every block
        return outBuf;
    }

    /// <summary>
    /// Materialize a standalone updated NCA: patched section content written back into a copy of the
    /// base NCA's IVFC section <paramref name="index"/> (resized + hash chain rebuilt). Throws if that
    /// section is not IVFC-hashed.
    /// </summary>
    public static byte[] Materialize(byte[] baseNca, byte[] deltaNca, KeySet keySet, int index)
    {
        byte[] patched = Apply(baseNca, deltaNca, keySet, index);
        return IvfcNcaBuilder.RebuildWithContent(baseNca, keySet, index, patched);
    }

    /// <summary>Whether the base NCA's section <paramref name="index"/> is IVFC-hashed (materializable).</summary>
    public static bool SectionIsIvfc(byte[] nca, KeySet keySet, int index)
    {
        try { return new Nca(keySet, new MemoryStorage(nca)).GetFsHeader(index).HashType == NcaHashType.Ivfc; }
        catch { return false; }
    }

    /// <summary>
    /// Streaming materialization: patches <paramref name="baseNca"/> section <paramref name="index"/> with
    /// <paramref name="deltaNca"/> and rebuilds a standalone NCA into <paramref name="dst"/>, holding only
    /// bounded buffers (works for multi-GB Program RomFS). The patched read + rebuild are
    /// <c>ErrorOnInvalid</c>, so a wrong pairing or an invalid rebuilt chain throws. Caller computes the
    /// new content id (SHA-256 of the output) from <paramref name="dst"/>.
    /// </summary>
    public static void MaterializeStreaming(IStorage baseNca, IStorage deltaNca, int index, KeySet keySet, Stream dst)
    {
        var b = new Nca(keySet, baseNca);
        var d = new Nca(keySet, deltaNca);
        IStorage patched = b.OpenStorageWithPatch(d, index, IntegrityCheckLevel.ErrorOnInvalid);
        patched.GetSize(out long contentLen).ThrowIfFailure();
        IvfcNcaBuilder.RebuildStreaming(baseNca, index, patched, contentLen, keySet, dst);
    }
}
