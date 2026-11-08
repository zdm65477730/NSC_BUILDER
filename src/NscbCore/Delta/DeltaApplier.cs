using LibHac.Common.Keys;
using LibHac.Fs;
using LibHac.FsSystem;
using LibHac.Tools.FsSystem;
using LibHac.Tools.FsSystem.NcaUtils;

namespace NscbCore.Delta;

/// <summary>
/// Applies Switch "delta fragment" NCAs over their base NCA using LibHac's
/// <see cref="Nca.OpenStorageWithPatch"/> path (which walks the delta's relocation +
/// encryption trees), yielding the patched logical content of a section.
/// </summary>
/// <remarks>
/// This produces the patched *content bytes* (a logical filesystem). Materializing a delta
/// result back into a standalone NCA additionally requires rebuilding that section's hash tree
/// (IVFC for RomFS), which callers do here via <see cref="Patching.NcaCnmtPatcher"/>-style
/// chains when the target is a flat-hash (PFS0/Sha256) section; IVFC-bearing sections
/// (Program/Data RomFS) are out of scope for full standalone re-packaging.
/// </remarks>
public static class DeltaApplier
{
    /// <summary>
    /// Apply <paramref name="deltaNca"/> (a DeltaFragment NCA) over <paramref name="baseNca"/>
    /// for the given section index and return the patched logical content.
    /// </summary>
    public static byte[] Apply(byte[] baseNca, byte[] deltaNca, KeySet keySet, int index = 0)
    {
        var patched = OpenPatchedStorage(new MemoryStorage(baseNca), new MemoryStorage(deltaNca), keySet, index);
        patched.GetSize(out long size).ThrowIfFailure();
        byte[] outBuf = new byte[size];
        patched.Read(0, outBuf).ThrowIfFailure();
        return outBuf;
    }

    /// <summary>
    /// Stream-backed variant: works on large NCAs without loading them whole. The returned
    /// storage lazily patches; a wrong (base, delta) pairing fails when the delta's applied
    /// info is validated on first access.
    /// </summary>
    public static IStorage OpenPatchedStorage(IStorage baseNca, IStorage deltaNca, KeySet keySet,
        int index = 0, IntegrityCheckLevel level = IntegrityCheckLevel.ErrorOnInvalid)
        => new Nca(keySet, baseNca).OpenStorageWithPatch(new Nca(keySet, deltaNca), index, level);

    /// <summary>Logical size of a section's filesystem storage (the un-patched base content length).</summary>
    public static long GetSectionSize(byte[] nca, KeySet keySet, int index = 0)
    {
        var n = new Nca(keySet, new MemoryStorage(nca));
        var st = n.OpenStorage(index, IntegrityCheckLevel.None);
        st.GetSize(out long sz).ThrowIfFailure();
        return sz;
    }
}
