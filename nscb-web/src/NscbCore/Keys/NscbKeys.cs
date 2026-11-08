using LibHac.Common;
using LibHac.Common.Keys;
using LibHac.Crypto;

namespace NscbCore.Keys;

/// <summary>
/// Loads and wraps a LibHac <see cref="KeySet"/> from prod.keys (master keys). Rights-id title keys are
/// derived on demand from each container's own ticket (see TicketTitleKeys); titles.json is metadata only.
/// The keyset has no artificial key generation cap: any master_key_NN present in the
/// key file is usable, so titles built for the latest firmware are supported.
/// </summary>
public sealed class NscbKeys
{
    private sealed class NullProgress : IProgressReport
    {
        public void LogMessage(string message) { }
        public void Report(long value) { }
        public void ReportAdd(long value) { }
        public void SetTotal(long value) { }
    }

    public KeySet KeySet { get; }

    public string? ProdKeysPath { get; }

    /// <summary>True when a header key could be derived (needed to decrypt NCA headers).</summary>
    public bool HasHeaderKey => !KeySet.HeaderKey.IsZeros();

    /// <summary>True when the XCI header key is available (needed to encrypt/decrypt the card Game_info area).</summary>
    public bool HasXciHeaderKey => !KeySet.XciHeaderKey.IsZeros();

    /// <summary>Highest master key index (master_key_NN) available in the loaded key set.</summary>
    public int MaxMasterKeyIndex { get; private set; } = -1;

    /// <summary>Highest key generation whose keys are available (0 when no keys).</summary>
    public int MaxKeyGeneration => MaxMasterKeyIndex < 0 ? -1 : MaxMasterKeyIndex + 1;

    private NscbKeys(KeySet keySet, string? prodKeysPath)
    {
        KeySet = keySet;
        ProdKeysPath = prodKeysPath;
    }

    /// <exception cref="InvalidOperationException">when prod.keys could not be found.</exception>
    public static NscbKeys Load(string? prodKeysPath)
    {
        KeySet keySet = KeySet.CreateDefaultKeySet();
        var progress = new NullProgress();

        // prod.keys (the master keys) is the ONLY key input. Rights-id title keys are recovered on demand from
        // each container's own ticket (see TicketTitleKeys): for a standard eShop ticket, K =
        // AES-ECB(titlekek[masterKeyRev]).decrypt(ticket.EncTitleKey), and titlekek[i] derives from
        // master_key[i] in prod.keys — so every title key is derivable. titles.json is therefore NOT used for
        // keys; it supplies metadata only (name/dev/publisher/genre/region), exactly like NSGManager.
        // Personal/device-bound tickets are out of scope (unrecoverable from public keys; NSGManager too).
        string? prod = ResolveKeyFile(prodKeysPath, "prod.keys");
        if (prod is null)
            throw new InvalidOperationException(
                "No key file found. Set prod.keys in the settings page, or place prod.keys next to the program.");
        ExternalKeyReader.ReadKeyFile(keySet, prod, null, null, progress);

        keySet.DeriveKeys(progress);
        var keys = new NscbKeys(keySet, prod);
        keys.ScanAvailableGenerations();
        return keys;
    }

    /// <summary>Locate a key file from a configured path (file or folder, with ~ / %VAR% expansion) or standard fallbacks.</summary>
    private static string? ResolveKeyFile(string? configured, string defaultName)
    {
        foreach (string cand in KeyFileCandidates(configured, defaultName))
            if (File.Exists(cand)) return Path.GetFullPath(cand);
        return null;
    }

    private static IEnumerable<string> KeyFileCandidates(string? configured, string defaultName)
    {
        string home = Environment.GetFolderPath(Environment.SpecialFolder.UserProfile);
        string exeDir = AppContext.BaseDirectory;
        if (!string.IsNullOrWhiteSpace(configured))
        {
            string p = ExpandPath(configured!);
            yield return p;                                   // a file path
            if (Directory.Exists(p))                          // a folder → look inside it and its .switch
            {
                yield return Path.Combine(p, defaultName);
                yield return Path.Combine(p, ".switch", defaultName);
            }
        }
        yield return Path.Combine(exeDir, defaultName);        // next to the exe
        yield return Path.Combine(exeDir, ".switch", defaultName);
        yield return Path.Combine(home, ".switch", defaultName);
    }

    /// <summary>Expand a leading ~ and %ENV_VAR% tokens; otherwise return the path unchanged.</summary>
    public static string ExpandPath(string path)
    {
        string home = Environment.GetFolderPath(Environment.SpecialFolder.UserProfile);
        if (path == "~") return home;
        if (path.StartsWith("~/") || path.StartsWith("~\\")) path = home + path[1..];
        return Environment.ExpandEnvironmentVariables(path);
    }

    private void ScanAvailableGenerations()
    {
        for (int i = 0; i < 0x20; i++)
        {
            if (!KeySet.MasterKeys[i].IsZeros())
                MaxMasterKeyIndex = i;
        }
    }

    /// <summary>Key area key (application channel) for a key generation.</summary>
    public AesKey GetApplicationKeyAreaKey(int keyGeneration, int keyTypeIndex)
        => KeySet.KeyAreaKeys[keyGeneration][keyTypeIndex];

    /// <summary>Copies the 16-byte XCI header key into <paramref name="destination"/>; false when unavailable.</summary>
    public bool TryCopyXciHeaderKey(Span<byte> destination)
    {
        if (!HasXciHeaderKey || destination.Length < 0x10)
            return false;
        KeySet.XciHeaderKey.DataRo[..0x10].CopyTo(destination);
        return true;
    }
}
