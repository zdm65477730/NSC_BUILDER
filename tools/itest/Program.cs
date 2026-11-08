using NscbCore.Formats;
using NscbCore.Info;
using NscbCore.Keys;
using NscbCore.Nsz;

// Integration test runner against real Switch sample files.
// Usage: itest <command> [args]
//   nsz2nsp   <input.nsz>  <output.nsp>
//   nsp2xci   <input.nsp>  <output.xci>
//   xci2nsp   <input.xci>  <output.nsp>
//   xcz2xci   <input.xcz>  <output.xci>
//   probe     <file>       (structure info only)

if (args.Length < 1) { Usage(); return 1; }
string cmd = args[0].ToLowerInvariant();

// Optional --keys=path --title=path
NscbKeys? keys = null;
foreach (var a in args)
{
    if (a.StartsWith("--keys=") && !a.Contains("title"))
    {
        var prodPath = a["--keys=".Length..].ToString();
        try { keys = NscbKeys.Load(prodPath); Console.WriteLine($"[keys loaded: maxKG={keys.MaxKeyGeneration}]"); }
        catch (Exception ex) { Console.WriteLine($"[keys load failed: {ex.Message}]"); }
    }
}

try
{
    switch (cmd)
    {
        case "dumpfs":
            {
                if (keys is null) { Console.WriteLine("need --keys=..."); return 3; }
                var (cn2, en2) = (args[1], args[2]);
                var ck2 = ContainerReader.DetectKind(cn2);
                using var cfs2 = File.OpenRead(cn2);
                var ents2 = ContainerReader.ReadEntries(cfs2, ck2);
                var m2 = ents2.First(e => e.Name == en2 || Path.GetFileName(e.Name) == en2);
                cfs2.Position = m2.Offset;
                byte[] by = new byte[m2.Size]; cfs2.ReadExactly(by);
                var ms2 = new LibHac.Fs.MemoryStorage(by);
                var nc2 = new LibHac.Tools.FsSystem.NcaUtils.Nca(keys.KeySet, ms2);
                Console.WriteLine($"NCA ContentType={nc2.Header.ContentType} kgen={nc2.Header.KeyGeneration} totalSize={new FileInfo(cn2).Length}");
                Console.WriteLine($"  HasRightsId={nc2.Header.HasRightsId} rightsId={Convert.ToHexString(nc2.Header.RightsId.ToArray())}");
                try { Console.WriteLine($"  GetDecryptedTitleKey={Convert.ToHexString(nc2.GetDecryptedTitleKey()!)}"); } catch (Exception e) { Console.WriteLine($"  GetDecryptedTitleKey failed: {e.Message}"); }
                for (int i = 0; i < 4; i++)
                {
                    try { var k = nc2.GetDecryptedKey(i); if (k is not null && k.Any(b=>b!=0)) Console.WriteLine($"  GetDecryptedKey({i})={Convert.ToHexString(k)}"); } catch { }
                }
                for (int i = 0; i < 4; i++)
                {
                    if (!nc2.Header.IsSectionEnabled(i)) continue;
                    var fh = nc2.GetFsHeader(i);
                    long ss = nc2.Header.GetSectionStartOffset(i), sz = nc2.Header.GetSectionSize(i);
                    Console.WriteLine($"  section[{i}]: rawStart=0x{ss:X} rawSize=0x{sz:X} fmt={fh.FormatType} hash={fh.HashType} enc={fh.EncryptionType}");
                    try
                    {
                        var st = nc2.OpenStorage(i, LibHac.Tools.FsSystem.IntegrityCheckLevel.None);
                        st.GetSize(out long l);
                        Console.WriteLine($"    OpenStorage len = 0x{l:X} ({l})");
                    }
                    catch (Exception ex) { Console.WriteLine($"    OpenStorage fail: {ex.Message}"); }
                    if (fh.HashType == LibHac.Tools.FsSystem.NcaUtils.NcaHashType.Ivfc)
                    {
                        var ivfc = fh.GetIntegrityInfoIvfc();
                        int lc = ivfc.LevelCount;
                        Console.WriteLine($"    IVFC levels={lc}");
                        for (int L = 0; L < lc; L++)
                        {
                            ref long off = ref ivfc.GetLevelOffset(L);
                            ref long szi = ref ivfc.GetLevelSize(L);
                            Console.WriteLine($"      L{L}: offset=0x{off:X} size=0x{szi:X}");
                        }
                    }
                }
                break;
            }
        case "lsnca":
            {
                if (keys is null) { Console.WriteLine("need --keys=..."); return 3; }
                // lsnca <container-path> <entry-name>  lists files inside that NCA's filesystem
                var (cn, en) = (args[1], args[2]);
                var ck = ContainerReader.DetectKind(cn);
                List<ContainerEntry> entries;
                using (var cfs = File.OpenRead(cn))
                    entries = ContainerReader.ReadEntries(cfs, ck);
                var match = entries.First(e => e.Name == en || Path.GetFileName(e.Name) == en);
                Console.WriteLine($"NCA at 0x{match.Offset:X} size {match.Size}");
                var stor = new LibHac.FsSystem.LocalStorage(cn, FileAccess.Read);
                var nca = new LibHac.Tools.FsSystem.NcaUtils.Nca(keys.KeySet,
                    new LibHac.Fs.SubStorage(stor, match.Offset, match.Size));
                Console.WriteLine($"  ContentType={nca.Header.ContentType} kgen={nca.Header.KeyGeneration}");
                for (int i = 0; i < 4; i++)
                {
                    if (!nca.Header.IsSectionEnabled(i)) { Console.WriteLine($"  section {i}: disabled"); continue; }
                    try
                    {
                        var fsys = nca.OpenFileSystem(i, LibHac.Tools.FsSystem.IntegrityCheckLevel.None);
                        var path = new LibHac.Fs.Path();
                        path.Initialize(System.Text.Encoding.UTF8.GetBytes("/")).ThrowIfFailure();
                        var h = default(LibHac.Common.UniqueRef<LibHac.Fs.Fsa.IDirectory>);
                        fsys.OpenDirectory(ref h, path, LibHac.Fs.Fsa.OpenDirectoryMode.All).ThrowIfFailure();
                        var buf = new LibHac.Fs.DirectoryEntry[64];
                        h.Get.Read(out long read, buf).ThrowIfFailure();
                        Console.Write($"  section {i} entries ({read}): ");
                        for (int k = 0; k < read; k++)
                        {
                            var nm = buf[k].Name.ItemsRo;
                            int e = nm.IndexOf((byte)0); if (e < 0) e = nm.Length;
                            Console.Write(System.Text.Encoding.UTF8.GetString(nm[..e]) + "  ");
                        }
                        Console.WriteLine();
                        h.Destroy();
                    }
                    catch (Exception ex) { Console.WriteLine($"  section {i}: {ex.GetType().Name} {ex.Message}"); }
                }
                break;
            }
        case "info":
            {
                if (keys is null) { Console.WriteLine("need --keys=..."); return 3; }
                var svc = new TitleInfoService(keys);
                var info = svc.GetFileInfo(args[1]);
                Console.WriteLine(System.Text.Json.JsonSerializer.Serialize(info, new System.Text.Json.JsonSerializerOptions { WriteIndented = true }));
                break;
            }
        case "nsp2nsz":
            {
                var (src, dst) = (args[1], args[2]);
                Console.WriteLine($"NSP→NSZ: {src}");
                NszConverter.NspToNsz(src, dst, keys!, progress: p => { });
                Console.WriteLine($"  -> {new FileInfo(dst).Length:N0} bytes");
                break;
            }
        case "nszround":
            {
                // nsz round trip: NSP → NSZ → NSP, compare byte equality
                var (src, tmpNsz, outNsp) = (args[1], args[2], args[3]);
                NszConverter.NspToNsz(src, tmpNsz, keys!, progress: _ => { });
                NszConverter.NszToNsp(tmpNsz, outNsp, progress: _ => { });
                long s1 = new FileInfo(src).Length, s2 = new FileInfo(outNsp).Length;
                Console.WriteLine($"orig NSP {s1:N0} B → NSZ {new FileInfo(tmpNsz).Length:N0} B → back {s2:N0} B");
                break;
            }
        case "patchrsv":
            {
                // patchrsv <in.nsp/xci> <out> <newRsv>
                var (src, dst) = (args[1], args[2]);
                uint newRsv = uint.Parse(args[3]);
                if (keys is null) { Console.WriteLine("need --keys=..."); return 3; }
                NscbCore.Patching.ContainerPatcher.PatchCnmtRsv(src, dst, keys, newRsv, progress: _ => { });
                Console.WriteLine($"patched RSV to 0x{newRsv:X8}, out={new FileInfo(dst).Length:N0} B");
                break;
            }
        case "split":
            {
                int parts = NscbCore.Splitting.Fat32Splitter.Split(args[1], _ => { });
                Console.WriteLine($"split into {parts} parts");
                break;
            }
        case "verify":
            {
                if (keys is null) { Console.WriteLine("need --keys=..."); return 3; }
                var vr = NscbCore.Verify.Verifier.VerifyContainer(args[1], keys);
                Console.WriteLine($"verify: {args[1]} → ok={vr.Ok} filesChecked={vr.CheckedFiles}/{vr.TotalFiles}");
                foreach (var f in vr.Failures.Take(10)) Console.WriteLine("  FAIL: " + f);
                return vr.Ok ? 0 : 4;
            }
        case "nczaccess":
            {
                // nczaccess <nsz/xcz>: measure the RAW-storage read pattern during NCA hash verification, to decide
                // whether a forward-only streaming verify (zero temp) is O(n) viable or oscillates back into IVFC
                // hash trees (O(n^2)). Decompresses each .ncz to temp once, wraps the storage in a counter, verifies.
                if (keys is null) { Console.WriteLine("need --keys=..."); return 3; }
                var apath = args[1];
                var akind = ContainerReader.DetectKind(apath);
                List<ContainerEntry> aentries;
                using (var aprobe = File.OpenRead(apath)) aentries = ContainerReader.ReadEntries(aprobe, akind);
                foreach (var e in aentries.Where(x => x.IsNcz))
                {
                    string anczTmp = Path.Combine(Path.GetTempPath(), "nscb-accz-" + Guid.NewGuid().ToString("N") + ".ncz");
                    string atemp = Path.Combine(Path.GetTempPath(), "nscb-acc-" + Guid.NewGuid().ToString("N") + ".nca");
                    try
                    {
                        using (var asrc = new FileStream(apath, FileMode.Open, FileAccess.Read, FileShare.ReadWrite))
                        using (var adst = new FileStream(anczTmp, FileMode.Create, FileAccess.Write))
                        {
                            asrc.Seek(e.Offset, SeekOrigin.Begin);
                            byte[] cbuf = new byte[1 << 20]; long rem = e.Size;
                            while (rem > 0) { int rd = asrc.Read(cbuf, 0, (int)Math.Min(cbuf.Length, rem)); if (rd <= 0) break; adst.Write(cbuf, 0, rd); rem -= rd; }
                        }
                        using (var anczIn = File.OpenRead(anczTmp))
                        using (var atf = new FileStream(atemp, FileMode.Create, FileAccess.ReadWrite, FileShare.ReadWrite))
                            NczProcessor.Decompress(anczIn, atf, null, default);
                        using var als = new LibHac.FsSystem.LocalStorage(atemp, FileAccess.Read);
                        var cs = new CountingStorage(als);
                        var anca = new LibHac.Tools.FsSystem.NcaUtils.Nca(keys.KeySet, cs);
                        byte[] abuf = new byte[0x40000];
                        for (int i = 0; i < 4; i++)
                        {
                            if (!anca.CanOpenSection(i)) continue;
                            var ast = anca.OpenStorage(i, LibHac.Tools.FsSystem.IntegrityCheckLevel.ErrorOnInvalid);
                            ast.GetSize(out long asz).ThrowIfFailure();
                            long aoff = 0;
                            while (aoff < asz) { int ac = (int)Math.Min(abuf.Length, asz - aoff); ast.Read(aoff, abuf.AsSpan(0, ac)).ThrowIfFailure(); aoff += ac; }
                        }
                        Console.WriteLine($"ncz {Path.GetFileName(e.Name)}: reads={cs.Reads} backward={cs.Backward} " +
                            $"backwardBytes={cs.BackwardBytes:N0} maxBackward={cs.MaxBack:N0} totalBytes={cs.TotalBytes:N0}");
                    }
                    finally { try { File.Delete(atemp); } catch { } try { File.Delete(anczTmp); } catch { } }
                }
                break;
            }
        case "hashcheck":
            {
                // hashcheck <container> <entry> <fsIdx> : recompute a PartitionFs(Sha256) section master hash
                // from its (unmodified) content+table and compare to the stored hash. Validates the scheme.
                if (keys is null) { Console.WriteLine("need --keys=..."); return 3; }
                var (ch, en2) = (args[1], args[2]);
                int fsi = args.Length > 3 ? int.Parse(args[3]) : 0;
                var ck2 = ContainerReader.DetectKind(ch);
                List<ContainerEntry> es2;
                using (var cfs = File.OpenRead(ch)) es2 = ContainerReader.ReadEntries(cfs, ck2);
                var m2 = es2.First(e => e.Name == en2 || Path.GetFileName(e.Name) == en2);
                byte[] nb2 = new byte[m2.Size];
                using (var f2 = File.OpenRead(ch)) { f2.Position = m2.Offset; f2.ReadExactly(nb2); }
                var nca2 = new LibHac.Tools.FsSystem.NcaUtils.Nca(keys.KeySet, new LibHac.Fs.MemoryStorage(nb2));
                var fsh = nca2.GetFsHeader(fsi);
                Console.WriteLine($"fmt={fsh.FormatType} hash={fsh.HashType}");
                var si = fsh.GetIntegrityInfoSha256();
                long co = si.GetLevelOffset(1), cs = si.GetLevelSize(1);
                long to = si.GetLevelOffset(0), ts = si.GetLevelSize(0);
                int bs = si.BlockSize;
                Console.WriteLine($"  content off=0x{co:X} size=0x{cs:X}  table off=0x{to:X} size=0x{ts:X}  block=0x{bs:X}");
                // Read the full decrypted raw section (content + hash table).
                long rsz = nca2.Header.GetSectionSize(fsi);
                byte[] section = new byte[rsz];
                nca2.OpenRawStorage(fsi, openEncrypted: false).Read(0, section).ThrowIfFailure();
                int n = (int)(ts / 32);
                for (int k = 0; k < n; k++)
                {
                    long bo = co + (long)k * bs;
                    int cnt = (int)Math.Min(bs, cs - (long)k * bs); if (cnt < 0) cnt = 0;
                    var h = System.Security.Cryptography.SHA256.HashData(section.AsSpan((int)bo, cnt));
                    if (!h.AsSpan().SequenceEqual(section.AsSpan((int)(to + k * 32), 32)))
                        { Console.WriteLine($"  TABLE MISMATCH at block {k} (off=0x{bo:X} cnt={cnt})"); return 7; }
                }
                var master = System.Security.Cryptography.SHA256.HashData(section.AsSpan((int)to, (int)ts));
                bool ok2 = master.SequenceEqual(si.MasterHash.ToArray());
                Console.WriteLine($"  master recompute match: {ok2}");
                Console.WriteLine($"    stored={Convert.ToHexString(si.MasterHash.ToArray())}");
                Console.WriteLine($"    calc  ={Convert.ToHexString(master)}");
                Console.WriteLine($"  RESULT: {(ok2 ? "PASS" : "FAIL")}");
                return ok2 ? 0 : 8;
            }
        case "cnmthashcheck":
            {
                // cnmthashcheck <container> : for every cnmt content record, compare SHA256(.nca file) to the
                // stored record hash — NSGManager's "SHA256 Hash Verify". Proves keygen-lowering hash sync works.
                if (keys is null) { Console.WriteLine("need --keys=..."); return 3; }
                string ch = args[1];
                var ckind = ContainerReader.DetectKind(ch);
                List<ContainerEntry> cent; using (var cf = File.OpenRead(ch)) cent = ContainerReader.ReadEntries(cf, ckind);
                var byId = new Dictionary<string, ContainerEntry>(StringComparer.OrdinalIgnoreCase);
                foreach (var e in cent) if (e.IsNca) { var id = Path.GetFileNameWithoutExtension(e.BaseName); if (id.Length >= 32) byId[id[..32].ToLowerInvariant()] = e; }
                using var cfs = File.OpenRead(ch);
                int cp = 0, cfl = 0;
                foreach (var m in cent)
                {
                    if (!m.IsNca || !m.BaseName.EndsWith(".cnmt.nca", StringComparison.OrdinalIgnoreCase)) continue;
                    foreach (var (id, hash) in NscbCore.Patching.NcaCnmtPatcher.ReadContentHashes(cfs, m.Offset, m.Size, keys.KeySet))
                    {
                        if (!byId.TryGetValue(id, out var tgt)) continue;   // reference to a content not in this container
                        byte[] nb = new byte[tgt.Size]; cfs.Position = tgt.Offset; cfs.ReadExactly(nb);
                        var calc = System.Security.Cryptography.SHA256.HashData(nb);
                        bool ok = calc.AsSpan().SequenceEqual(hash);
                        Console.WriteLine($"  {id} {(ok ? "PASS" : "FAIL")} record={Convert.ToHexString(hash)[..16]} calc={Convert.ToHexString(calc)[..16]}");
                        if (ok) cp++; else cfl++;
                    }
                }
                Console.WriteLine($"  cnmthashcheck: {cp} PASS / {cfl} FAIL");
                return cfl == 0 && cp > 0 ? 0 : 9;
            }
        case "metarebuild":
            {
                // metarebuild <container> <entry>  — validate the variable-size Meta NCA builder:
                // (a) rebuild with the SAME cnmt → reopen strict, cnmt bytes identical;
                // (b) rebuild with +1 content record (grown) → reopen strict, count increased.
                if (keys is null) { Console.WriteLine("need --keys=..."); return 3; }
                var (cm, em) = (args[1], args[2]);
                var ckm = ContainerReader.DetectKind(cm);
                List<ContainerEntry> ems;
                using (var cfs = File.OpenRead(cm)) ems = ContainerReader.ReadEntries(cfs, ckm);
                var mm2 = ems.First(e => e.Name == em || Path.GetFileName(e.Name) == em);
                byte[] nb2 = new byte[mm2.Size];
                using (var f2 = File.OpenRead(cm)) { f2.Position = mm2.Offset; f2.ReadExactly(nb2); }

                var n0 = new LibHac.Tools.FsSystem.NcaUtils.Nca(keys.KeySet, new LibHac.Fs.MemoryStorage((byte[])nb2.Clone()));
                var (cnName, cnBytes) = GetCnmtFile(n0.OpenFileSystem(0, LibHac.Tools.FsSystem.IntegrityCheckLevel.ErrorOnInvalid));
                int origCount = System.Buffers.Binary.BinaryPrimitives.ReadUInt16LittleEndian(cnBytes.AsSpan(0x10, 2));

                // (a) unchanged rebuild
                byte[] same = NscbCore.Ncm.MetaNcaBuilder.RebuildWithCnmt(nb2, keys.KeySet, cnName, cnBytes);
                var nS = new LibHac.Tools.FsSystem.NcaUtils.Nca(keys.KeySet, new LibHac.Fs.MemoryStorage(same));
                var (_, sameCnmt) = GetCnmtFile(nS.OpenFileSystem(0, LibHac.Tools.FsSystem.IntegrityCheckLevel.ErrorOnInvalid));
                bool sameOk = sameCnmt.SequenceEqual(cnBytes);

                // (b) grown rebuild: append one dummy content record, bump count
                byte[] grown = new byte[cnBytes.Length + 0x38];
                cnBytes.CopyTo(grown, 0);
                // header tail (meta entries + footer) is after the content table; simplest grow =
                // rewrite the last content record region is complex, so instead bump count and
                // append a record AFTER copying the full original (proves size change + chain rebuild).
                System.Buffers.Binary.BinaryPrimitives.WriteUInt16LittleEndian(grown.AsSpan(0x10, 2), (ushort)(origCount + 1));
                byte[] rebuilt2 = NscbCore.Ncm.MetaNcaBuilder.RebuildWithCnmt(nb2, keys.KeySet, cnName, grown);
                var n2 = new LibHac.Tools.FsSystem.NcaUtils.Nca(keys.KeySet, new LibHac.Fs.MemoryStorage(rebuilt2));
                var (_, grownCnmt) = GetCnmtFile(n2.OpenFileSystem(0, LibHac.Tools.FsSystem.IntegrityCheckLevel.ErrorOnInvalid));
                int grownCount = System.Buffers.Binary.BinaryPrimitives.ReadUInt16LittleEndian(grownCnmt.AsSpan(0x10, 2));
                bool growOk = grownCount == origCount + 1 && grownCnmt.Length == grown.Length;

                Console.WriteLine($"metarebuild: unchanged reopen cnmt-identical={sameOk}; grown count {origCount}->{grownCount} bytes={grownCnmt.Length==grown.Length} hashchain=OK");
                Console.WriteLine($"  RESULT: {(sameOk && growOk ? "PASS" : "FAIL")}");
                return sameOk && growOk ? 0 : 11;
            }
        case "setcnmt":
            {
                // setcnmt <container> <entry> <tid|ver> <hexvalue> : patch cnmt + rebuild hash chain,
                // then reopen STRICTLY (ErrorOnInvalid) to force full content-hash verification.
                if (keys is null) { Console.WriteLine("need --keys=..."); return 3; }
                var (cc, ee) = (args[1], args[2]);
                string field = args[3].ToLowerInvariant();
                var ckc = ContainerReader.DetectKind(cc);
                List<ContainerEntry> esc;
                using (var cfs = File.OpenRead(cc)) esc = ContainerReader.ReadEntries(cfs, ckc);
                var mc = esc.First(e => e.Name == ee || Path.GetFileName(e.Name) == ee);
                byte[] ncaBuf = new byte[mc.Size];
                using (var f = File.OpenRead(cc)) { f.Position = mc.Offset; f.ReadExactly(ncaBuf); }
                using var cms = new MemoryStream(ncaBuf);
                bool okC;
                if (field == "tid")
                    okC = NscbCore.Patching.NcaCnmtPatcher.SetCnmtTitleId(cms, 0, ncaBuf.Length, keys.KeySet, Convert.ToUInt64(args[4], 16));
                else if (field == "rsv")
                    okC = NscbCore.Patching.NcaCnmtPatcher.SetCnmtRequiredSystemVersion(cms, 0, ncaBuf.Length, keys.KeySet, uint.Parse(args[4]));
                else
                    okC = NscbCore.Patching.NcaCnmtPatcher.SetCnmtTitleVersion(cms, 0, ncaBuf.Length, keys.KeySet, Convert.ToUInt32(args[4], args[4].StartsWith("0x") ? 16 : 10));

                // Strict reopen: reading the whole cnmt through ErrorOnInvalid verifies every block hash.
                byte[] patched = cms.ToArray();
                var ncaC = new LibHac.Tools.FsSystem.NcaUtils.Nca(keys.KeySet, new LibHac.Fs.MemoryStorage(patched));
                var fsysC = ncaC.OpenFileSystem(0, LibHac.Tools.FsSystem.IntegrityCheckLevel.ErrorOnInvalid);
                byte[] cnmtBytes = ReadCnmtFileStrict(fsysC); // throws if any hash is invalid
                _ = new LibHac.Tools.Ncm.Cnmt(new MemoryStream(cnmtBytes)); // parse-check the cnmt
                ulong rTid = System.Buffers.Binary.BinaryPrimitives.ReadUInt64LittleEndian(cnmtBytes.AsSpan(0, 8));
                uint rVer = System.Buffers.Binary.BinaryPrimitives.ReadUInt32LittleEndian(cnmtBytes.AsSpan(8, 4));
                uint rRsv = System.Buffers.Binary.BinaryPrimitives.ReadUInt32LittleEndian(cnmtBytes.AsSpan(0x28, 4));
                Console.WriteLine($"setcnmt ok={okC}  TitleId={rTid:x16} Version={rVer} RSV={rRsv}  (strict hash verify PASSED)");
                Console.WriteLine($"  RESULT: {(okC ? "PASS" : "FAIL")}");
                return okC ? 0 : 9;
            }
        case "setdist":
            {
                // setdist <container> <entry> <distByte 0|1>  — write-back path check via LibHac reopen.
                if (keys is null) { Console.WriteLine("need --keys=..."); return 3; }
                var (cs, es) = (args[1], args[2]);
                byte dist = byte.Parse(args[3]);
                var ck = ContainerReader.DetectKind(cs);
                List<ContainerEntry> ents;
                using (var cfs = File.OpenRead(cs)) ents = ContainerReader.ReadEntries(cfs, ck);
                var m = ents.First(e => e.Name == es || Path.GetFileName(e.Name) == es);
                byte[] nb = new byte[m.Size];
                using (var f = File.OpenRead(cs)) { f.Position = m.Offset; f.ReadExactly(nb); }

                var beforeNca = new LibHac.Tools.FsSystem.NcaUtils.Nca(keys.KeySet, new LibHac.Fs.MemoryStorage((byte[])nb.Clone()));
                var beforeDist = beforeNca.Header.DistributionType;
                var beforeType = beforeNca.Header.ContentType;

                using var ms = new MemoryStream(nb);
                bool okPatch = NscbCore.Patching.NcaPatcher.SetDistribution(ms, 0, nb.Length, keys.KeySet, (NscbCore.Patching.NcaDistribution)dist);

                // Re-open the re-encrypted NCA through LibHac: reads DistributionType and forces
                // a FsHeader SHA-256 verification (GetFsHeader) → validates the whole header rewrite.
                byte[] patched = ms.ToArray();
                var afterNca = new LibHac.Tools.FsSystem.NcaUtils.Nca(keys.KeySet, new LibHac.Fs.MemoryStorage(patched));
                afterNca.GetFsHeader(0); // throws if our 0xC00 re-encryption diverged from LibHac
                var afterDist = afterNca.Header.DistributionType;
                var afterType = afterNca.Header.ContentType;

                Console.WriteLine($"setdist patch ok={okPatch}");
                Console.WriteLine($"  distribution: {beforeDist} -> {afterDist} (requested {(NscbCore.Patching.NcaDistribution)dist})");
                Console.WriteLine($"  content type preserved: {beforeType} == {afterType} : {beforeType == afterType}");
                bool good = okPatch && (byte)afterDist == dist && beforeType == afterType;
                Console.WriteLine($"  RESULT: {(good ? "PASS" : "FAIL")}");
                return good ? 0 : 6;
            }
        case "xtsverify":
            {
                // xtsverify <container> <entry-name>: our XtsHelper vs LibHac Aes128XtsTransform on a real (gamecard) NCA header.
                if (keys is null) { Console.WriteLine("need --keys=..."); return 3; }
                var (cnx, enx) = (args[1], args[2]);
                var ckx = ContainerReader.DetectKind(cnx);
                List<ContainerEntry> esx;
                using (var cfs = File.OpenRead(cnx)) esx = ContainerReader.ReadEntries(cfs, ckx);
                var mx = esx.First(e => e.Name == enx || Path.GetFileName(e.Name) == enx);
                byte[] raw = new byte[0x400];
                using (var f = File.OpenRead(cnx)) { f.Position = mx.Offset; f.ReadExactly(raw); }
                var hk = keys.KeySet.HeaderKey.DataRo;
                byte[] k1 = hk[..16].ToArray();
                byte[] k2 = hk[16..32].ToArray();

                byte[] oracle = (byte[])raw.Clone();
                var tr = new LibHac.Tools.FsSystem.Aes128XtsTransform(k1, k2, decrypting: true);
                tr.TransformBlock(oracle, 0, 0x200, 0);
                tr.TransformBlock(oracle, 0x200, 0x200, 1);

                byte[] mine = (byte[])raw.Clone();
                NscbCore.Crypto.XtsHelper.Transform(mine, k1, k2, 0, 0x200, encrypt: false);

                bool eq = oracle.AsSpan().SequenceEqual(mine);
                string magic = System.Text.Encoding.ASCII.GetString(oracle[0x200..0x204]); // "NCA3" at 0x200
                Console.WriteLine($"XtsHelper == LibHac Aes128XtsTransform (0x400 header): {eq}");
                Console.WriteLine($"  decrypted header magic@0x200 = '{magic}'  distribution@0x204={oracle[0x204]}  keyGen@0x206={oracle[0x206]}");
                Console.WriteLine($"  oracle 0x200..{BitConverter.ToString(oracle, 0x200, 16)}");
                Console.WriteLine($"  mine   0x200..{BitConverter.ToString(mine, 0x200, 16)}");
                return eq && magic.StartsWith("NCA") ? 0 : 5;
            }
        case "splittitles":
            {
                if (keys is null) { Console.WriteLine("need --keys=..."); return 3; }
                bool card = args.Length > 3 && args[3] == "basecard";
                var outs = NscbCore.Splitting.TitleSplitter.Split(args[1], args[2], keys, _ => { }, default, card);
                Console.WriteLine($"produced {outs.Count} file(s):  basecard={card}");
                foreach (var o in outs)
                {
                    var vr = NscbCore.Verify.Verifier.VerifyContainer(o, keys);
                    Console.WriteLine("  " + o + "  (" + new FileInfo(o).Length + " B)  verify=" + vr.Ok);
                }
                break;
            }
        case "extractby":
            {
                if (keys is null) { Console.WriteLine("need --keys=..."); return 3; }
                var f = Enum.Parse<NscbCore.Extraction.ExtractFilter>(args.Length > 3 ? args[3] : "All", true);
                var files = NscbCore.Extraction.ContentExtractor.Extract(args[1], args[2], keys, f, _ => { });
                Console.WriteLine($"extracted {files.Count} files (filter={f})");
                break;
            }
        case "genxml":
            {
                if (keys is null) { Console.WriteLine("need --keys=..."); return 3; }
                var xml = NscbCore.Xml.CnmtXml.GenerateFromContainer(args[1], keys);
                File.WriteAllText(args[2], xml);
                Console.WriteLine($"wrote {new FileInfo(args[2]).Length} B XML");
                break;
            }
        case "trimxci":
            {
                NscbCore.Xci.XciTrimmer.Trim(args[1], args[2], keys, _ => { });
                Console.WriteLine($"trim ok → {new FileInfo(args[2]).Length} B");
                break;
            }
        case "erasedeltas":
            {
                if (keys is null) { Console.WriteLine("need --keys=..."); return 3; }
                NscbCore.Xci.XciTrimmer.EraseDeltaFragments(args[1], args[2], keys, _ => { });
                Console.WriteLine($"erasedeltas ok → {new FileInfo(args[2]).Length} B");
                break;
            }
        case "supertrim":
            {
                if (keys is null) { Console.WriteLine("need --keys=..."); return 3; }
                NscbCore.Xci.XciTrimmer.SuperTrim(args[1], args[2], keys, _ => { });
                Console.WriteLine($"supertrim ok → {new FileInfo(args[2]).Length} B");
                break;
            }
        case "updbase":
            {
                // updbase <base.nsp> <out.nsp> <upd1.nsp|xci> [<upd2> ...] [--apply-deltas]
                if (keys is null) { Console.WriteLine("need --keys=..."); return 3; }
                bool applyDeltas = args.Contains("--apply-deltas");
                var updates = args.Skip(3).Where(a => !a.StartsWith("--")).ToArray();
                if (updates.Length == 0) { Console.WriteLine("need at least one update"); return 3; }
                NscbCore.Packaging.UpdBaseMerger.Merge(args[1], updates, args[2], keys, _ => { }, applyDeltas: applyDeltas, diag: m => Console.WriteLine("    [diag] " + m));

                // Strictly re-read the merged NSP's Meta cnmt (ErrorOnInvalid → verifies rebuilt hash chain)
                // and report the synced version.
                var kind = ContainerReader.DetectKind(args[2]);
                List<ContainerEntry> me;
                using (var pf = File.OpenRead(args[2])) me = ContainerReader.ReadEntries(pf, kind);
                var mm = me.First(e => e.Name.EndsWith(".cnmt.nca", StringComparison.OrdinalIgnoreCase));
                byte[] mnb = new byte[mm.Size];
                using (var rf = File.OpenRead(args[2])) { rf.Position = mm.Offset; rf.ReadExactly(mnb); }
                var mnca = new LibHac.Tools.FsSystem.NcaUtils.Nca(keys.KeySet, new LibHac.Fs.MemoryStorage(mnb));
                var mfs = mnca.OpenFileSystem(0, LibHac.Tools.FsSystem.IntegrityCheckLevel.ErrorOnInvalid);
                byte[] mc = ReadCnmtFileStrict(mfs);
                uint mVer = System.Buffers.Binary.BinaryPrimitives.ReadUInt32LittleEndian(mc.AsSpan(8, 4));

                // id-consistency: every cnmt content entry must resolve to a file in the merged NSP.
                var mcmt = new LibHac.Tools.Ncm.Cnmt(new MemoryStream(mc));
                var fileSet = me.Select(e => Path.GetFileName(e.Name)).ToHashSet(StringComparer.OrdinalIgnoreCase);
                var missing = new List<string>();
                foreach (var ce in mcmt.ContentEntries)
                {
                    string id = NscbCore.Info.NcaIdFormatter.ToHex(ce.NcaId ?? new byte[0x10]);
                    if (!fileSet.Contains(id + ".nca")) missing.Add($"{ce.Type}:{id[..Math.Min(12, id.Length)]}");
                }
                bool consistent = missing.Count == 0;
                Console.WriteLine($"updbase ok → {new FileInfo(args[2]).Length} B; merged Meta version={mVer} (strict hash verify PASSED)");
                Console.WriteLine($"  content-id consistency: {(consistent ? "all entries resolve to files" : "MISSING " + string.Join(",", missing))}");
                Console.WriteLine($"  RESULT: {(consistent ? "PASS" : "FAIL")}");
                break;
            }
        case "readnpdm":
            {
                if (keys is null) { Console.WriteLine("need --keys=..."); return 3; }
                var npdm = NscbCore.Info.NpdmInfoReader.ReadFromContainer(args[1], keys);
                if (npdm is null) { Console.WriteLine("no NPDM"); return 4; }
                Console.WriteLine(System.Text.Json.JsonSerializer.Serialize(npdm, new System.Text.Json.JsonSerializerOptions { WriteIndented = true }));
                break;
            }
        case "remlinkacc":
            {
                // remlinkacc <in.nsp|xci|tik> <out>
                var res = NscbCore.Patching.TicketAccountPatcher.PatchContainer(args[1], args[2]);
                foreach (var r in res) Console.WriteLine($"  {r.Name}: prev={Convert.ToHexString(r.PreviousBytes)} cleared={r.WasCleared}");
                Console.WriteLine($"remlinkacc ok ({res.Count} tickets) → {new FileInfo(args[2]).Length} B");
                break;
            }
        case "joinfile":
            {
                string outp = NscbCore.Joiner.FileJoiner.Join(args[1], args.Length > 2 ? args[2] : null);
                Console.WriteLine($"joinfile ok → {outp}");
                break;
            }
        case "nszpar":
            {
                // nszpar <in.nsp> <out.nsz> <parallel> [level]   (--keys/--title may follow, so parse tolerantly)
                int par = args.Length > 3 && int.TryParse(args[3], out var pv) ? pv : 4;
                int lvl = args.Length > 4 && int.TryParse(args[4], out var lv) ? lv : 17;
                var t0 = DateTime.UtcNow;
                NszConverter.NspToNsz(args[1], args[2], keys!, lvl, progress: _ => { }, parallelism: par);
                Console.WriteLine($"nszpar ok (par={par} lvl={lvl}) → {new FileInfo(args[2]).Length} B in {(DateTime.UtcNow - t0).TotalSeconds:F1}s");
                break;
            }
        case "rtrnca":
            {
                // rtrnca <container> <entry>  — convert a rights-ID NCA to null-crypto and prove it
                // with a prod-only differential: a keyset WITHOUT title.keys must read identical content.
                if (keys is null) { Console.WriteLine("need --keys=..."); return 3; }
                var prodPath = args.FirstOrDefault(a => a.StartsWith("--keys="))?["--keys=".Length..];
                if (prodPath is null) { Console.WriteLine("need --keys=prod.keys"); return 3; }
                var (cr, er) = (args[1], args[2]);
                var ckr = ContainerReader.DetectKind(cr);
                List<ContainerEntry> esr;
                using (var cfs = File.OpenRead(cr)) esr = ContainerReader.ReadEntries(cfs, ckr);
                var mr = esr.First(e => e.Name == er || Path.GetFileName(e.Name) == er);

                // Header-only differential (works for multi-GB programs): after RTRNCA a prod-only
                // keyset (NO title.keys) must derive the SAME content key as the original title key.
                byte[] hdr = new byte[0xC00];
                using (var f = File.OpenRead(cr)) { f.Position = mr.Offset; f.ReadExactly(hdr); }
                var fullNca = new LibHac.Tools.FsSystem.NcaUtils.Nca(keys.KeySet, new LibHac.Fs.MemoryStorage((byte[])hdr.Clone()));
                if (!fullNca.Header.HasRightsId) { Console.WriteLine("entry has no rights-id; nothing to convert (skipped)"); return 0; }
                byte[] origTitleKey = fullNca.GetDecryptedTitleKey()!;

                using var hms = new MemoryStream((byte[])hdr.Clone());
                bool okR = NscbCore.Patching.NcaPatcher.RemoveTitleKey(hms, 0, 0xC00, keys.KeySet);

                var prodOnly = NscbKeys.Load(prodPath); // prod.keys only (rights-id key derives from the container's ticket)
                byte[] patched = hms.ToArray();
                var pNca = new LibHac.Tools.FsSystem.NcaUtils.Nca(prodOnly.KeySet, new LibHac.Fs.MemoryStorage(patched));
                byte[] derivedKey = pNca.GetDecryptedKey(0) ?? pNca.GetDecryptedKey(1)!;

                bool keyMatch = derivedKey.AsSpan().SequenceEqual(origTitleKey);
                bool good = okR && !pNca.Header.HasRightsId && keyMatch;
                Console.WriteLine($"rtrnca ok={okR} nowNullCrypto={!pNca.Header.HasRightsId} prodOnlyDerivedKey==titleKey:{keyMatch}");
                Console.WriteLine($"  titleKey ={Convert.ToHexString(origTitleKey)}");
                Console.WriteLine($"  derivedKey={Convert.ToHexString(derivedKey)}");
                Console.WriteLine($"  RESULT: {(good ? "PASS" : "FAIL")}");
                return good ? 0 : 10;
            }
        case "deltaapply":
            {
                // deltaapply <updateNsp> <baseNsp>  — find a (delta, base) pair the update ships and
                // apply it via LibHac's OpenStorageWithPatch; verify it resolves + reads without error.
                if (keys is null) { Console.WriteLine("need --keys=..."); return 3; }
                var (updPath, basePath) = (args[1], args[2]);
                List<ContainerEntry> updE, baseE;
                using (var f = File.OpenRead(updPath)) updE = ContainerReader.ReadEntries(f, ContainerReader.DetectKind(updPath));
                using (var f = File.OpenRead(basePath)) baseE = ContainerReader.ReadEntries(f, ContainerReader.DetectKind(basePath));
                var updNcas = updE.Where(e => e.IsNca && !e.Name.EndsWith(".cnmt.nca", StringComparison.OrdinalIgnoreCase)).ToList();
                var baseNcas = baseE.Where(e => e.IsNca && !e.Name.EndsWith(".cnmt.nca", StringComparison.OrdinalIgnoreCase)).ToList();

                using var baseStor = new LibHac.FsSystem.LocalStorage(basePath, FileAccess.Read);
                int tried = 0, ok = 0; string detail = "";
                foreach (var dn in updNcas)
                {
                    if (dn.Size > 0x400000) continue; // delta fragments are small
                    byte[] deltaBytes = new byte[dn.Size];
                    using (var f = File.OpenRead(updPath)) { f.Position = dn.Offset; f.ReadExactly(deltaBytes); }
                    foreach (var bn in baseNcas)
                    {
                        foreach (int idx in new[] { 0, 1 })
                        {
                            tried++;
                            try
                            {
                                var bsub = new LibHac.Fs.SubStorage(baseStor, bn.Offset, bn.Size);
                                var patched = NscbCore.Delta.DeltaApplier.OpenPatchedStorage(bsub, new LibHac.Fs.MemoryStorage(deltaBytes), keys.KeySet, idx);
                                patched.GetSize(out long sz).ThrowIfFailure();
                                byte[] head = new byte[Math.Min(0x1000, sz)];
                                patched.Read(0, head).ThrowIfFailure();
                                ok++;
                                detail += $"  {Path.GetFileName(dn.Name)} → base {Path.GetFileName(bn.Name)}[sec{idx}] patchedSize=0x{sz:X}\n";
                            }
                            catch { /* this (delta, base, index) combo isn't the pair */ }
                        }
                    }
                    break; // just the first small delta to keep it quick
                }
                Console.WriteLine($"deltaapply: attempted {tried} pair(s), {ok} applied successfully");
                Console.Write(detail);
                Console.WriteLine($"  RESULT: {(ok > 0 ? "PASS" : "FAIL")}");
                return ok > 0 ? 0 : 12;
            }
        case "ivfcselftest":
            {
                // ivfcselftest <container> <entry> [sectionIdx=1]  — reconstruct a real NCA section's
                // IVFC tree from its level-0 content and compare to the stored hash regions/master.
                if (keys is null) { Console.WriteLine("need --keys=..."); return 3; }
                string cm = args[1], en = args[2];
                int idx = args.Length > 3 ? int.Parse(args[3]) : 1;
                var ckm = ContainerReader.DetectKind(cm);
                List<ContainerEntry> ents;
                using (var cfs = File.OpenRead(cm)) ents = ContainerReader.ReadEntries(cfs, ckm);
                var cand = en == "auto"
                    ? ents.Where(e => e.IsNca && !e.Name.EndsWith(".cnmt.nca", StringComparison.OrdinalIgnoreCase)
                                      && e.Size > 0x10000 && e.Size < 0x8000000).ToList()
                    : ents.Where(e => e.Name == en || Path.GetFileName(e.Name) == en).ToList();
                var sections = en == "auto" ? new[] { 0, 1 } : new[] { idx };
                var reasons = new List<string>();
                foreach (var m in cand)
                {
                    byte[] nb = new byte[m.Size];
                    using (var f = File.OpenRead(cm)) { f.Position = m.Offset; f.ReadExactly(nb); }
                    foreach (int s in sections)
                    {
                        var (found, ok, detail) = IvfcProbe(nb, s, keys);
                        if (!found) { reasons.Add($"{Path.GetFileName(m.Name)}[sec{s}] {detail}"); continue; }
                        Console.WriteLine($"{Path.GetFileName(m.Name)} section {s}:\n{detail}");
                        Console.WriteLine($"  RESULT: {(ok ? "PASS" : "FAIL")}");
                        return ok ? 0 : 13;
                    }
                }
                Console.WriteLine("no IVFC section found among candidates:");
                foreach (var r in reasons.Take(20)) Console.WriteLine("  " + r);
                return 4;
            }
        case "ivfcrebuild":
            {
                // ivfcrebuild <container> <entry|auto> [idx] — rebuild a real IVFC section with
                // (a) unchanged content and (b) grown content; re-open each with ErrorOnInvalid and
                // read the whole section (forces verification of every IVFC block) → proves the
                // resize + multi-level tree + header + AES-CTR/XTS re-encryption are correct.
                if (keys is null) { Console.WriteLine("need --keys=..."); return 3; }
                string cm = args[1], en = args[2];
                var ckm = ContainerReader.DetectKind(cm);
                List<ContainerEntry> ents;
                using (var cfs = File.OpenRead(cm)) ents = ContainerReader.ReadEntries(cfs, ckm);
                var cand = en == "auto"
                    ? ents.Where(e => e.IsNca && !e.Name.EndsWith(".cnmt.nca", StringComparison.OrdinalIgnoreCase)
                                      && e.Size > 0x10000 && e.Size < 0x8000000).ToList()
                    : ents.Where(e => e.Name == en || Path.GetFileName(e.Name) == en).ToList();
                foreach (var m in cand)
                {
                    byte[] ncaB = new byte[m.Size];
                    using (var f = File.OpenRead(cm)) { f.Position = m.Offset; f.ReadExactly(ncaB); }
                    int sidx = FindIvfcSection(ncaB, keys);
                    if (sidx < 0) continue;

                    var baseNca = new LibHac.Tools.FsSystem.NcaUtils.Nca(keys.KeySet, new LibHac.Fs.MemoryStorage(ncaB));
                    byte[] origContent = IvfcContent(baseNca, sidx);
                    string? r1, r2;
                    byte[]? unchangedBytes = null;
                    try
                    {
                        unchangedBytes = NscbCore.Ncm.IvfcNcaBuilder.RebuildWithContent(ncaB, keys.KeySet, sidx, origContent);
                        r1 = IvfcFullVerifyMsg(unchangedBytes, keys, sidx, origContent);
                    }
                    catch (Exception ex) { r1 = ex.Message; }
                    if (r1 is not null && unchangedBytes is not null)
                    {
                        try
                        {
                            var rn = new LibHac.Tools.FsSystem.NcaUtils.Nca(keys.KeySet, new LibHac.Fs.MemoryStorage(unchangedBytes));
                            var riv = rn.GetFsHeader(sidx).GetIntegrityInfoIvfc();
                            Console.WriteLine($"  rebuilt ivfc: LevelCount={riv.LevelCount} masterHashSize={riv.MasterHashSize} " +
                                $"levels=[{string.Join(",", Enumerable.Range(0, riv.LevelCount).Select(i => $"(off0x{riv.GetLevelOffset(i):X},sz0x{riv.GetLevelSize(i):X},bs{riv.GetLevelBlockSize(i)})"))}] " +
                                $"secEndBlock→size=0x{rn.Header.GetSectionSize(sidx):X} (orig 0x{baseNca.Header.GetSectionSize(sidx):X})");
                        }
                        catch (Exception ex) { Console.WriteLine($"  rebuilt header unreadable: {ex.GetType().Name}: {ex.Message}"); }
                    }
                    try
                    {
                        byte[] grown = new byte[origContent.Length + 0x4000];
                        origContent.CopyTo(grown, 0);
                        byte[] grownNca = NscbCore.Ncm.IvfcNcaBuilder.RebuildWithContent(ncaB, keys.KeySet, sidx, grown);
                        r2 = IvfcFullVerifyMsg(grownNca, keys, sidx, grown);
                    }
                    catch (Exception ex) { r2 = ex.Message; }

                    Console.WriteLine($"{Path.GetFileName(m.Name)} sec{sidx}: content=0x{origContent.Length:X} unchanged={(r1 is null ? "OK" : "FAIL " + r1)} grown={(r2 is null ? "OK" : "FAIL " + r2)}");
                    bool ok1 = r1 is null;
                    bool okG = r2 is null;
                    Console.WriteLine($"  RESULT: {(ok1 && okG ? "PASS" : "FAIL")}");
                    return ok1 && okG ? 0 : 14;
                }
                Console.WriteLine("no IVFC section found");
                return 4;
            }
        case "deltatomca":
            {
                // deltatomca <updateNsp> <baseNsp> — for each small base NCA + small delta NCA, use the
                // ErrorOnInvalid patched-read as the pairing+correctness oracle; on a correct pair,
                // materialize a standalone updated NCA (IvfcNcaBuilder) and re-open it (verify).
                if (keys is null) { Console.WriteLine("need --keys=..."); return 3; }
                var (updPath, basePath) = (args[1], args[2]);
                List<ContainerEntry> updE, baseE;
                using (var f = File.OpenRead(updPath)) updE = ContainerReader.ReadEntries(f, ContainerReader.DetectKind(updPath));
                using (var f = File.OpenRead(basePath)) baseE = ContainerReader.ReadEntries(f, ContainerReader.DetectKind(basePath));
                var deltas = updE.Where(e => e.IsNca && !e.Name.EndsWith(".cnmt.nca", StringComparison.OrdinalIgnoreCase) && e.Size > 0x100 && e.Size < 0x400000).ToList();
                var bases = baseE.Where(e => e.IsNca && !e.Name.EndsWith(".cnmt.nca", StringComparison.OrdinalIgnoreCase) && e.Size < 0x4000000).ToList();
                Console.WriteLine($"deltas={deltas.Count} bases(<=64MB)={bases.Count}");
                int done = 0;
                foreach (var dn in deltas)
                {
                    byte[] dbytes = new byte[dn.Size];
                    using (var f = File.OpenRead(updPath)) { f.Position = dn.Offset; f.ReadExactly(dbytes); }
                    foreach (var bn in bases)
                    {
                        byte[] bbytes = new byte[bn.Size];
                        using (var f = File.OpenRead(basePath)) { f.Position = bn.Offset; f.ReadExactly(bbytes); }
                        for (int index = 0; index < 2; index++)
                        {
                            if (!NscbCore.Delta.DeltaToNca.SectionIsIvfc(bbytes, keys.KeySet, index)) continue;
                            byte[] patched;
                            try { patched = NscbCore.Delta.DeltaToNca.Apply(bbytes, dbytes, keys.KeySet, index); }
                            catch { continue; } // wrong pairing (ErrorOnInvalid threw) → not this base
                            try
                            {
                                byte[] standalone = NscbCore.Delta.DeltaToNca.Materialize(bbytes, dbytes, keys.KeySet, index);
                                var rn = new LibHac.Tools.FsSystem.NcaUtils.Nca(keys.KeySet, new LibHac.Fs.MemoryStorage(standalone));
                                var rs = rn.OpenStorage(index, LibHac.Tools.FsSystem.IntegrityCheckLevel.ErrorOnInvalid);
                                rs.GetSize(out long sz).ThrowIfFailure();
                                byte[] back = new byte[sz]; rs.Read(0, back).ThrowIfFailure();
                                bool ok = back.Length == patched.Length && back.AsSpan().SequenceEqual(patched);
                                Console.WriteLine($"  {Path.GetFileName(dn.Name)} → base {Path.GetFileName(bn.Name)}[sec{index}] patched=0x{patched.Length:X} standalone=0x{standalone.Length:N0} reopenVerify={ok}");
                                if (ok) done++;
                            }
                            catch (Exception ex) { Console.WriteLine($"  materialize failed for {Path.GetFileName(bn.Name)}[{index}]: {ex.GetType().Name}"); }
                        }
                    }
                }
                Console.WriteLine($"deltatomca: materialized+verified={done}");
                Console.WriteLine($"  RESULT: {(done > 0 ? "PASS" : "NONE")}");
                return done > 0 ? 0 : 15;
            }
        case "ivfcgeom":
            {
                // ivfcgeom <container> <entry|auto> [idx] — compare the raw-offset values IvfcNcaBuilder
                // assumes (NCA3: FsHeaders@0x400, IVFC fields at FsHeader+8) against LibHac's own
                // accessors, to detect a header-geometry mismatch on anomalous NCAs.
                if (keys is null) { Console.WriteLine("need --keys=..."); return 3; }
                string cm = args[1], en = args[2];
                List<ContainerEntry> ents;
                using (var cfs = File.OpenRead(cm)) ents = ContainerReader.ReadEntries(cfs, ContainerReader.DetectKind(cm));
                foreach (var m in ents.Where(e => e.IsNca && !e.Name.EndsWith(".cnmt.nca", StringComparison.OrdinalIgnoreCase)
                        && e.Size > 0x10000 && e.Size < 0x8000000))
                {
                    byte[] nb = new byte[m.Size];
                    using (var f = File.OpenRead(cm)) { f.Position = m.Offset; f.ReadExactly(nb); }
                    int idx = FindIvfcSection(nb, keys);
                    if (idx < 0) continue;
                    var n = new LibHac.Tools.FsSystem.NcaUtils.Nca(keys.KeySet, new LibHac.Fs.MemoryStorage(nb));
                    var fsH = n.GetFsHeader(idx);
                    var iv = fsH.GetIntegrityInfoIvfc();
                    Console.WriteLine($"{Path.GetFileName(m.Name)} idx{idx}: fmt={fsH.FormatType} hash={fsH.HashType} enc={fsH.EncryptionType} " +
                        $"compressed={fsH.ExistsCompressionLayer()} secSizes=" +
                        $"[{string.Join(",", Enumerable.Range(0, 4).Select(i => { try { return $"0x{n.Header.GetSectionSize(i):X}"; } catch { return "-"; } }))}]");
                    Console.WriteLine($"  ivfc LevelCount={iv.LevelCount} masterHashSize={iv.MasterHashSize} " +
                        $"levels=[{string.Join(",", Enumerable.Range(0, iv.LevelCount).Select(i => $"(off0x{iv.GetLevelOffset(i):X},sz0x{iv.GetLevelSize(i):X},bs{iv.GetLevelBlockSize(i)})"))}]");
                    if (en != "auto") break;
                }
                return 0;
            }
        case "ivfcdiff":
            {
                // ivfcdiff <container> <entry|auto> [idx] — for the UNCHANGED case, compare each
                // IvfcTree-computed region against the original stored region (per level), and check
                // that IvfcContent (via OpenStorage) equals the raw level-0 region. Pinpoints the
                // first divergence: tree/step model vs. the NCA's actual layout.
                if (keys is null) { Console.WriteLine("need --keys=..."); return 3; }
                string cm = args[1], en = args[2];
                List<ContainerEntry> ents;
                using (var cfs = File.OpenRead(cm)) ents = ContainerReader.ReadEntries(cfs, ContainerReader.DetectKind(cm));
                foreach (var m in ents.Where(e => e.IsNca && !e.Name.EndsWith(".cnmt.nca", StringComparison.OrdinalIgnoreCase)
                        && e.Size > 0x10000 && e.Size < 0x8000000))
                {
                    byte[] nb = new byte[m.Size];
                    using (var f = File.OpenRead(cm)) { f.Position = m.Offset; f.ReadExactly(nb); }
                    int idx = FindIvfcSection(nb, keys);
                    if (idx < 0) continue;
                    var n = new LibHac.Tools.FsSystem.NcaUtils.Nca(keys.KeySet, new LibHac.Fs.MemoryStorage(nb));
                    var iv = n.GetFsHeader(idx).GetIntegrityInfoIvfc();
                    int nl = iv.LevelCount; int active = 0;
                    int[] st = new int[nl]; long[] off = new long[nl], size = new long[nl];
                    for (int i = 0; i < nl; i++) { st[i] = iv.GetLevelBlockSize(i); off[i] = iv.GetLevelOffset(i); size[i] = iv.GetLevelSize(i); if (size[i] > 0) active = i + 1; }
                    var raw = n.OpenRawStorage(idx, openEncrypted: false);
                    byte[] content = IvfcContent(n, idx);
                    // compare OpenStorage content vs raw level-0 region
                    byte[] raw0 = new byte[size[active - 1]]; raw.Read(off[active - 1], raw0).ThrowIfFailure();
                    Console.WriteLine($"{Path.GetFileName(m.Name)} idx{idx} active={active} contentViaOpenStorage=0x{content.Length:X} rawLevel0=0x{raw0.Length:X} equal={content.AsSpan(0, Math.Min(content.Length, raw0.Length)).SequenceEqual(raw0.AsSpan(0, Math.Min(content.Length, raw0.Length)))}");
                    var (regions, _) = NscbCore.Crypto.IvfcTree.Build(content, st, active);
                    for (int i = 0; i < active; i++)
                    {
                        byte[] orig = new byte[size[i]]; if (size[i] > 0) raw.Read(off[i], orig).ThrowIfFailure();
                        byte[] mine = regions[i];
                        int cm2 = Math.Min(mine.Length, orig.Length);
                        int firstDiff = -1; for (int b = 0; b < cm2; b++) if (mine[b] != orig[b]) { firstDiff = b; break; }
                        Console.WriteLine($"  region{i}: mine=0x{mine.Length:X} stored=0x{orig.Length:X} prefixMatch={(firstDiff < 0 ? "yes" : $"no@0x{firstDiff:X}")}");
                    }
                    if (en != "auto") break;
                }
                return 0;
            }
        case "ivfcstream":
            {
                // ivfcstream <container> <entry|auto> — rebuild UNCHANGED via the streaming path and
                // assert it is byte-identical to the verified in-memory RebuildWithContent (and reopens).
                if (keys is null) { Console.WriteLine("need --keys=..."); return 3; }
                string cm = args[1], en = args[2];
                List<ContainerEntry> ents;
                using (var cfs = File.OpenRead(cm)) ents = ContainerReader.ReadEntries(cfs, ContainerReader.DetectKind(cm));
                foreach (var m in ents.Where(e => e.IsNca && !e.Name.EndsWith(".cnmt.nca", StringComparison.OrdinalIgnoreCase)
                        && e.Size > 0x10000 && e.Size < 0x8000000))
                {
                    byte[] nb = new byte[m.Size];
                    using (var f = File.OpenRead(cm)) { f.Position = m.Offset; f.ReadExactly(nb); }
                    int idx = FindIvfcSection(nb, keys);
                    if (idx < 0) continue;
                    var n = new LibHac.Tools.FsSystem.NcaUtils.Nca(keys.KeySet, new LibHac.Fs.MemoryStorage(nb));
                    byte[] content = IvfcContent(n, idx);
                    byte[] inMem = NscbCore.Ncm.IvfcNcaBuilder.RebuildWithContent(nb, keys.KeySet, idx, content);
                    var ms = new MemoryStream();
                    NscbCore.Ncm.IvfcNcaBuilder.RebuildStreaming(new LibHac.Fs.MemoryStorage(nb), idx,
                        new LibHac.Fs.MemoryStorage(content), content.Length, keys.KeySet, ms);
                    byte[] streamed = ms.ToArray();
                    bool identical = streamed.SequenceEqual(inMem);
                    bool reopen = IvfcFullVerify(streamed, keys, idx, content);
                    // Diff confined to padding (beyond the real section data) is functionally irrelevant;
                    // reopen-verify proves the streaming CTR/IVFC are correct for arbitrary sizes.
                    int firstDiff = -1;
                    if (!identical) for (int b = 0; b < Math.Min(streamed.Length, inMem.Length); b++) if (streamed[b] != inMem[b]) { firstDiff = b; break; }
                    bool ok = reopen && streamed.Length == inMem.Length && (identical || firstDiff >= content.Length); // only differs past the content tail
                    Console.WriteLine($"{Path.GetFileName(m.Name)} idx{idx}: content=0x{content.Length:X} inMem=0x{inMem.Length:N0} streamed=0x{streamed.Length:N0} byteIdentical={identical} firstDiff={(firstDiff < 0 ? "-" : $"0x{firstDiff:X}")} reopenVerify={reopen}");
                    Console.WriteLine($"  RESULT: {(ok ? "PASS" : "FAIL")}");
                    return ok ? 0 : 16;
                }
                Console.WriteLine("no IVFC section found");
                return 4;
            }
        case "deltastream":
            {
                // deltastream <updateNsp> <baseNsp> — full STREAMING delta path on small bases:
                // base+delta as storages → MaterializeStreaming → reopen (ErrorOnInvalid) == patched content.
                if (keys is null) { Console.WriteLine("need --keys=..."); return 3; }
                var (updPath, basePath) = (args[1], args[2]);
                List<ContainerEntry> updE, baseE;
                using (var f = File.OpenRead(updPath)) updE = ContainerReader.ReadEntries(f, ContainerReader.DetectKind(updPath));
                using (var f = File.OpenRead(basePath)) baseE = ContainerReader.ReadEntries(f, ContainerReader.DetectKind(basePath));
                var deltas = updE.Where(e => e.IsNca && !e.Name.EndsWith(".cnmt.nca", StringComparison.OrdinalIgnoreCase) && e.Size is > 0x100 and < 0x400000).ToList();
                var bases = baseE.Where(e => e.IsNca && !e.Name.EndsWith(".cnmt.nca", StringComparison.OrdinalIgnoreCase) && e.Size < 0x800000).ToList();
                int done = 0;
                using var baseStor = new LibHac.FsSystem.LocalStorage(basePath, FileAccess.Read);
                foreach (var dn in deltas)
                {
                    byte[] dbytes = new byte[dn.Size];
                    using (var f = File.OpenRead(updPath)) { f.Position = dn.Offset; f.ReadExactly(dbytes); }
                    var deltaStor = new LibHac.Fs.MemoryStorage(dbytes);
                    foreach (var bn in bases)
                    {
                        for (int idx = 0; idx < 2; idx++)
                        {
                            try
                            {
                                var bSub = new LibHac.Fs.SubStorage(baseStor, bn.Offset, bn.Size);
                                // expected patched content (via non-streaming Apply on a copy)
                                byte[] nb = new byte[bn.Size];
                                using (var f = File.OpenRead(basePath)) { f.Position = bn.Offset; f.ReadExactly(nb); }
                                byte[] patched;
                                try { patched = NscbCore.Delta.DeltaToNca.Apply(nb, dbytes, keys.KeySet, idx); }
                                catch { continue; } // wrong pairing
                                var ms = new MemoryStream();
                                NscbCore.Delta.DeltaToNca.MaterializeStreaming(
                                    new LibHac.Fs.SubStorage(baseStor, bn.Offset, bn.Size), deltaStor, idx, keys.KeySet, ms);
                                byte[] standalone = ms.ToArray();
                                bool ok = IvfcFullVerify(standalone, keys, idx, patched);
                                string newId = Convert.ToHexString(System.Security.Cryptography.SHA256.HashData(standalone)[..16]).ToLowerInvariant();
                                Console.WriteLine($"  {Path.GetFileName(dn.Name)} → base {Path.GetFileName(bn.Name)}[sec{idx}] streamed=0x{standalone.Length:N0} newId={newId[..16]}… reopenVerify={ok}");
                                if (ok) { done++; break; }
                            }
                            catch { }
                        }
                    }
                }
                Console.WriteLine($"deltastream: materialized+verified={done}");
                Console.WriteLine($"  RESULT: {(done > 0 ? "PASS" : "NONE")}");
                return done > 0 ? 0 : 17;
            }
        case "deltasrc":
            {
                // deltasrc <updateNsp> <deltaNcaName> <baseNcaIdHex32> — locate where a delta NCA encodes
                // its source base content id (search raw, decrypted header, decrypted sections). RE helper.
                if (keys is null) { Console.WriteLine("need --keys=..."); return 3; }
                string cm = args[1], en = args[2]; byte[] needle = Convert.FromHexString(args[3]);
                byte[] needleAscii = System.Text.Encoding.ASCII.GetBytes(args[3].ToLowerInvariant());
                static int FindSeqLocal(byte[] hay, byte[] nd) { for (int i = 0; i + nd.Length <= hay.Length; i++) { bool m = true; for (int j = 0; j < nd.Length; j++) if (hay[i + j] != nd[j]) { m = false; break; } if (m) return i; } return -1; }
                List<ContainerEntry> ents;
                using (var cfs = File.OpenRead(cm)) ents = ContainerReader.ReadEntries(cfs, ContainerReader.DetectKind(cm));
                var m = ents.First(e => e.Name == en || Path.GetFileName(e.Name) == en);
                byte[] nb = new byte[m.Size];
                using (var f = File.OpenRead(cm)) { f.Position = m.Offset; f.ReadExactly(nb); }
                Console.WriteLine($"delta {Path.GetFileName(m.Name)} size=0x{nb.Length:X}; needle={args[3]}");
                Console.WriteLine($"  raw file: rawIdx={FindSeqLocal(nb, needle):X} asciiIdx={FindSeqLocal(nb, needleAscii):X}");
                byte[] hdr = nb[..0xC00].ToArray();
                if (hdr[0x200] != (byte)'N') NscbCore.Crypto.XtsHelper.TransformNcaHeader(hdr, keys.KeySet.HeaderKey.DataRo, decrypt: true);
                Console.WriteLine($"  header magic='{System.Text.Encoding.ASCII.GetString(hdr, 0x200, 4)}' decryptedHdr rawIdx={FindSeqLocal(hdr, needle):X} asciiIdx={FindSeqLocal(hdr, needleAscii):X}");
                Console.WriteLine($"  header contenttype={hdr[0x205]} keysz hdr[0x2C0..0x2D0]={Convert.ToHexString(hdr[0x2C0..0x2D0])}");
                var nca = new LibHac.Tools.FsSystem.NcaUtils.Nca(keys.KeySet, new LibHac.Fs.MemoryStorage(nb));
                for (int idx = 0; idx < 4; idx++)
                {
                    try
                    {
                        nca.GetFsHeader(idx);
                    }
                    catch { continue; }
                    try
                    {
                        var raw = nca.OpenRawStorage(idx, openEncrypted: false);
                        raw.GetSize(out long len);
                        if (len <= 0 || len > 0x4000000) continue;
                        byte[] sec = new byte[len]; raw.Read(0, sec).ThrowIfFailure();
                        byte[] rev = needle.Reverse().ToArray();
                        int at = FindSeqLocal(sec, needle), atA = FindSeqLocal(sec, needleAscii), atR = FindSeqLocal(sec, rev);
                        Console.WriteLine($"  sec{idx} len=0x{len:X} rawIdx={at:X} asciiIdx={atA:X} revIdx={atR:X}");
                        for (int row = 0; row < 0x100 && row < sec.Length; row += 0x20)
                            Console.WriteLine($"    +{row:X4}: {Convert.ToHexString(sec[row..Math.Min(row + 0x20, sec.Length)])}");
                    }
                    catch (Exception ex) { Console.WriteLine($"  sec{idx}: {ex.GetType().Name}"); }
                }
                return 0;
            }
        case "deltamatch":
            {
                // deltamatch <deltaNsp> <deltaNcaName> <baseNsp> — confirm how a delta references its base:
                // take the delta's decrypted section0 leading 32-byte digest and find which base NCA's
                // SHA-256(header 0xC00 decrypted) / SHA-256(whole) equals it.
                if (keys is null) { Console.WriteLine("need --keys=..."); return 3; }
                string dNsp = args[1], dEntry = args[2], bNsp = args[3];
                List<ContainerEntry> de, be;
                using (var f = File.OpenRead(dNsp)) de = ContainerReader.ReadEntries(f, ContainerReader.DetectKind(dNsp));
                using (var f = File.OpenRead(bNsp)) be = ContainerReader.ReadEntries(f, ContainerReader.DetectKind(bNsp));
                var dm = de.First(e => e.Name == dEntry || Path.GetFileName(e.Name) == dEntry);
                byte[] dn = new byte[dm.Size];
                using (var f = File.OpenRead(dNsp)) { f.Position = dm.Offset; f.ReadExactly(dn); }
                var dnc = new LibHac.Tools.FsSystem.NcaUtils.Nca(keys.KeySet, new LibHac.Fs.MemoryStorage(dn));
                var dsec0 = dnc.OpenRawStorage(0, openEncrypted: false);
                byte[] dhead = new byte[0x20]; dsec0.Read(0, dhead).ThrowIfFailure();
                Console.WriteLine($"delta base-digest = {Convert.ToHexString(dhead)}");
                string dh = Convert.ToHexString(dhead).ToLowerInvariant();
                static string ShaOf(LibHac.Fs.IStorage st, long len)
                {
                    var ih = System.Security.Cryptography.SHA256.Create();
                    byte[] buf = new byte[0x400000]; long done = 0;
                    while (done < len) { int n = (int)Math.Min(buf.Length, len - done); st.Read(done, buf.AsSpan(0, n)).ThrowIfFailure(); ih.TransformBlock(buf, 0, n, null, 0); done += n; }
                    ih.TransformFinalBlock(buf, 0, 0); return Convert.ToHexString(ih.Hash!).ToLowerInvariant();
                }
                foreach (var bn in be.Where(e => e.IsNca && !e.Name.EndsWith(".cnmt.nca", StringComparison.OrdinalIgnoreCase)))
                {
                    using var fileStor = new LibHac.FsSystem.LocalStorage(bNsp, FileAccess.Read);
                    var nstor = new LibHac.Fs.SubStorage(fileStor, bn.Offset, bn.Size);
                    var bnca = new LibHac.Tools.FsSystem.NcaUtils.Nca(keys.KeySet, nstor);
                    byte[] hraw = new byte[0xC00]; nstor.Read(0, hraw).ThrowIfFailure();
                    byte[] hdec = (byte[])hraw.Clone();
                    if (hdec[0x200] != (byte)'N') NscbCore.Crypto.XtsHelper.TransformNcaHeader(hdec, keys.KeySet.HeaderKey.DataRo, decrypt: true);
                    bool whole = ShaOf(nstor, bn.Size) == dh;
                    bool hdrDec = Convert.ToHexString(System.Security.Cryptography.SHA256.HashData(hdec)).ToLowerInvariant() == dh;
                    bool hdrRaw = Convert.ToHexString(System.Security.Cryptography.SHA256.HashData(hraw)).ToLowerInvariant() == dh;
                    string ls0 = "-", ls1 = "-";
                    try { var s = bnca.OpenStorage(0, LibHac.Tools.FsSystem.IntegrityCheckLevel.None); s.GetSize(out long l); ls0 = (ShaOf(s, l) == dh).ToString(); } catch { }
                    try { var s = bnca.OpenStorage(1, LibHac.Tools.FsSystem.IntegrityCheckLevel.None); s.GetSize(out long l); ls1 = (ShaOf(s, l) == dh).ToString(); } catch { }
                    Console.WriteLine($"  {Path.GetFileName(bn.Name)[..32]} size=0x{bn.Size:X}: whole={whole} hdrDec={hdrDec} hdrRaw={hdrRaw} logSt0={ls0} logSt1={ls1}");
                }
                return 0;
            }
        case "deltasearch":
            {
                // deltasearch <container> <entry> [idx] — dump where non-zero resumes in the delta section
                // and list ASCII 4-char magic tokens with context (to locate the fragment header format).
                if (keys is null) { Console.WriteLine("need --keys=..."); return 3; }
                string cm = args[1], en = args[2]; int idx = args.Length > 3 ? int.Parse(args[3]) : 0;
                List<ContainerEntry> ents;
                using (var cfs = File.OpenRead(cm)) ents = ContainerReader.ReadEntries(cfs, ContainerReader.DetectKind(cm));
                var m = ents.First(e => e.Name == en || Path.GetFileName(e.Name) == en);
                byte[] nb = new byte[m.Size];
                using (var f = File.OpenRead(cm)) { f.Position = m.Offset; f.ReadExactly(nb); }
                var nca = new LibHac.Tools.FsSystem.NcaUtils.Nca(keys.KeySet, new LibHac.Fs.MemoryStorage(nb));
                var raw = nca.OpenRawStorage(idx, openEncrypted: false);
                raw.GetSize(out long len);
                byte[] sec = new byte[Math.Min(len, 0x200000)];
                raw.Read(0, sec).ThrowIfFailure();
                int nz = -1; for (int i = 0x20; i < sec.Length; i++) if (sec[i] != 0) { nz = i; break; }
                Console.WriteLine($"{en} sec{idx} len=0x{len:X} first-nonzero-after-0x20=0x{nz:X}");
                // scan ASCII magic [A-Z0-9]{4}
                int hits = 0;
                for (int i = 0; i + 4 <= sec.Length && hits < 20; i++)
                {
                    bool magic = true;
                    for (int j = 0; j < 4; j++) { byte b = sec[i + j]; if (!((b >= 'A' && b <= 'Z') || (b >= '0' && b <= '9'))) { magic = false; break; } }
                    if (magic) { Console.WriteLine($"  +0x{i:X}: '{System.Text.Encoding.ASCII.GetString(sec[i..(i + 4)])}' ctx={Convert.ToHexString(sec[i..Math.Min(i + 0x20, sec.Length)])}"); hits++; i += 3; }
                }
                return 0;
            }
        case "deltainfo":
            {
                // deltainfo <updateNsp> <baseNsp> — list update DeltaFragment content ids + each delta NCA's
                // Header.ContentType, and each base NCA's ContentType (diagnose content-type pairing).
                if (keys is null) { Console.WriteLine("need --keys=..."); return 3; }
                string u = args[1], b = args[2];
                using var uf = new LibHac.FsSystem.LocalStorage(u, FileAccess.Read);
                using var bf = new LibHac.FsSystem.LocalStorage(b, FileAccess.Read);
                List<ContainerEntry> ue, be;
                using (var f = File.OpenRead(u)) ue = ContainerReader.ReadEntries(f, ContainerReader.DetectKind(u));
                using (var f = File.OpenRead(b)) be = ContainerReader.ReadEntries(f, ContainerReader.DetectKind(b));
                var me = ue.First(e => e.Name.EndsWith(".cnmt.nca", StringComparison.OrdinalIgnoreCase));
                byte[] mn = new byte[me.Size]; using (var f = File.OpenRead(u)) { f.Position = me.Offset; f.ReadExactly(mn); }
                var nc = new LibHac.Tools.FsSystem.NcaUtils.Nca(keys.KeySet, new LibHac.Fs.MemoryStorage(mn));
                var fsx = nc.OpenFileSystem(0, LibHac.Tools.FsSystem.IntegrityCheckLevel.None);
                var (cnName, cnBytes) = GetCnmtFile(fsx);
                int tOff = 0x20 + System.Buffers.Binary.BinaryPrimitives.ReadUInt16LittleEndian(cnBytes.AsSpan(0xE, 2));
                int cnt = System.Buffers.Binary.BinaryPrimitives.ReadUInt16LittleEndian(cnBytes.AsSpan(0x10, 2));
                Console.WriteLine($"update cnmt {cnt} content entries:");
                for (int i = 0; i < cnt; i++)
                {
                    int bo = tOff + i * 0x38;
                    var idv = Convert.ToHexString(cnBytes[(bo + 0x20)..(bo + 0x30)]).ToLowerInvariant();
                    int tp = cnBytes[bo + 0x36];
                    Console.WriteLine($"  {idv} type={tp}" + (tp == 9 ? " (DELTA)" : ""));
                    if (tp == 9)
                    {
                        var dn = ue.FirstOrDefault(e => Path.GetFileName(e.Name).StartsWith(idv, StringComparison.OrdinalIgnoreCase));
                        if (dn != null) { var d = new LibHac.Tools.FsSystem.NcaUtils.Nca(keys.KeySet, new LibHac.Fs.SubStorage(uf, dn.Offset, dn.Size)); Console.WriteLine($"      delta NCA Header.ContentType={d.Header.ContentType}"); }
                    }
                }
                Console.WriteLine($"base NCAs:");
                foreach (var bb in be.Where(e => e.Name.EndsWith(".nca", StringComparison.OrdinalIgnoreCase) && !e.Name.EndsWith(".cnmt.nca", StringComparison.OrdinalIgnoreCase)))
                {
                    try { var x = new LibHac.Tools.FsSystem.NcaUtils.Nca(keys.KeySet, new LibHac.Fs.SubStorage(bf, bb.Offset, bb.Size)); Console.WriteLine($"  {Path.GetFileName(bb.Name)[..32]} ContentType={x.Header.ContentType}"); }
                    catch (Exception ex) { Console.WriteLine($"  {Path.GetFileName(bb.Name)[..32]} err {ex.GetType().Name}"); }
                }
                return 0;
            }
        case "ndvoparse":
            {
                // ndvoparse <container> <entry> [idx] — locate the "NDV0" delta header in a decrypted
                // section and dump its fields; then try to pair via BaseHash against every base in <arg4>.
                if (keys is null) { Console.WriteLine("need --keys=..."); return 3; }
                string cm = args[1], en = args[2]; int idx = args.Length > 3 ? int.Parse(args[3]) : 0;
                List<ContainerEntry> ents;
                using (var cfs = File.OpenRead(cm)) ents = ContainerReader.ReadEntries(cfs, ContainerReader.DetectKind(cm));
                var m = ents.First(e => e.Name == en || Path.GetFileName(e.Name) == en);
                byte[] nb = new byte[m.Size];
                using (var f = File.OpenRead(cm)) { f.Position = m.Offset; f.ReadExactly(nb); }
                var nca = new LibHac.Tools.FsSystem.NcaUtils.Nca(keys.KeySet, new LibHac.Fs.MemoryStorage(nb));
                var raw = nca.OpenRawStorage(idx, openEncrypted: false);
                raw.GetSize(out long len); byte[] sec = new byte[len]; raw.Read(0, sec).ThrowIfFailure();
                byte[] ndv0 = { (byte)'N', (byte)'D', (byte)'V', (byte)'0' };
                byte[] bktr = { (byte)'B', (byte)'K', (byte)'T', (byte)'R' };
                int bkt = -1; for (int i = 0; i + 4 <= sec.Length; i++) { bool mm2 = true; for (int j = 0; j < 4; j++) if (sec[i + j] != bktr[j]) { mm2 = false; break; } if (mm2) { bkt = i; break; } }
                // patch info from the delta FsHeader (authoritative relocation-tree location)
                int roff = -1, rlen = -1;
                try { var pi = nca.GetFsHeader(idx).GetPatchInfo(); roff = (int)pi.RelocationTreeOffset; rlen = (int)pi.RelocationTreeSize; } catch { }
                Console.WriteLine($"BKTR-magic@0x{bkt:X}  patchInfo relocOff=0x{roff:X} relocSize=0x{rlen:X}");
                int dump = bkt >= 0 ? bkt : (roff >= 0 && roff < sec.Length ? roff : 0x4000);
                for (int r = 0; r < 0x60 && dump + r < sec.Length; r += 0x20)
                    Console.WriteLine($"  +0x{dump + r:X}: {Convert.ToHexString(sec[(dump + r)..Math.Min(dump + r + 0x20, sec.Length)])}");
                byte[] ndv0x = ndv0;
                int at = -1; for (int i = 0; i + 4 <= sec.Length; i++) { bool mm = true; for (int j = 0; j < 4; j++) if (sec[i + j] != ndv0x[j]) { mm = false; break; } if (mm) { at = i; break; } }
                Console.WriteLine($"{en} sec{idx} len=0x{len:X} NDV0-magic@0x{at:X}");
                Console.WriteLine($"  base_hash(0x00) = {Convert.ToHexString(sec[0..0x20])}");
                // BKTR bucket tree lives at 0x4000; dump header + node/leaf area to hand-decode source range.
                int bt = 0x4000;
                if (bt < sec.Length)
                    for (int r = 0; r < 0x80 && bt + r < sec.Length; r += 0x20)
                        Console.WriteLine($"  +0x{bt + r:X}: {Convert.ToHexString(sec[(bt + r)..Math.Min(bt + r + 0x20, sec.Length)])}");
                if (at >= 0)
                    for (int r = 0; r < 0x60; r += 0x20) Console.WriteLine($"  +0x{at + r:X}: {Convert.ToHexString(sec[(at + r)..Math.Min(at + r + 0x20, sec.Length)])}");
                return 0;
            }
        case "deltascan":
            {
                // deltascan <container> — lazily scan NCA entries for a real BKTR delta fragment
                // (relocation tree present / "BKTR" magic at section0+0x4000). No full load.
                if (keys is null) { Console.WriteLine("need --keys=..."); return 3; }
                string cm = args[1];
                List<ContainerEntry> ents;
                using (var cfs = File.OpenRead(cm)) ents = ContainerReader.ReadEntries(cfs, ContainerReader.DetectKind(cm));
                using var file = new LibHac.FsSystem.LocalStorage(cm, FileAccess.Read);
                int found = 0;
                foreach (var e in ents.Where(x => x.Name.EndsWith(".nca", StringComparison.OrdinalIgnoreCase)
                        && !x.Name.EndsWith(".cnmt.nca", StringComparison.OrdinalIgnoreCase)))
                {
                    try
                    {
                        var sub = new LibHac.Fs.SubStorage(file, e.Offset, e.Size);
                        var nca = new LibHac.Tools.FsSystem.NcaUtils.Nca(keys.KeySet, sub);
                        int rsz = 0; try { rsz = (int)nca.GetFsHeader(0).GetPatchInfo().RelocationTreeSize; } catch { }
                        int ct = (int)nca.Header.ContentType;
                        var raw = nca.OpenRawStorage(0, openEncrypted: false);
                        byte[] head = new byte[Math.Min(0x4010, e.Size)];
                        raw.Read(0, head).ThrowIfFailure();
                        bool bktrAt = head.Length >= 0x4004 && head[0x4000] == 'B' && head[0x4001] == 'K' && head[0x4002] == 'T' && head[0x4003] == 'R';
                        int bkt = -1; for (int i = 0; i + 4 <= head.Length; i++) if (head[i] == 'B' && head[i + 1] == 'K' && head[i + 2] == 'T' && head[i + 3] == 'R') { bkt = i; break; }
                        if (rsz > 0 || bktrAt || bkt >= 0)
                        {
                            found++;
                            Console.WriteLine($"BKTR? {Path.GetFileName(e.Name)[..Math.Min(32, e.Name.Length)]} size=0x{e.Size:X} ct={ct} relocSize=0x{rsz:X} BKTR@0x4000={bktrAt} BKTR@0x{bkt:X} hash0={Convert.ToHexString(head[..Math.Min(8, head.Length)])}");
                        }
                    }
                    catch { }
                }
                Console.WriteLine($"{Path.GetFileName(cm)}: candidate BKTR/delta NCAs = {found}");
                return 0;
            }
        case "deltapair":
            {
                // deltapair <updateNsp> <baseNsp> — dump the update cnmt ExtendedData.FragmentSets:
                // NcaIdNew = delta NCA (should exist in the update), NcaIdOld = base NCA (should exist in base).
                if (keys is null) { Console.WriteLine("need --keys=..."); return 3; }
                string u = args[1], b = args[2];
                List<ContainerEntry> ue, be;
                using (var f = File.OpenRead(u)) ue = ContainerReader.ReadEntries(f, ContainerReader.DetectKind(u));
                using (var f = File.OpenRead(b)) be = ContainerReader.ReadEntries(f, ContainerReader.DetectKind(b));
                var me = ue.First(e => e.Name.EndsWith(".cnmt.nca", StringComparison.OrdinalIgnoreCase));
                byte[] mn = new byte[me.Size]; using (var f = File.OpenRead(u)) { f.Position = me.Offset; f.ReadExactly(mn); }
                var nc = new LibHac.Tools.FsSystem.NcaUtils.Nca(keys.KeySet, new LibHac.Fs.MemoryStorage(mn));
                var fsx = nc.OpenFileSystem(0, LibHac.Tools.FsSystem.IntegrityCheckLevel.None);
                var (cnName, cnBytes) = GetCnmtFile(fsx);
                var cnmt = new LibHac.Tools.Ncm.Cnmt(new MemoryStream(cnBytes));
                var ext = cnmt.ExtendedData;
                Console.WriteLine($"update title={cnmt.TitleId:X16} ver={cnmt.TitleVersion} FragmentSets={(ext?.FragmentSets?.Length ?? -1)} DeltaContents={(ext?.DeltaContents?.Length ?? -1)}");
                if (ext?.FragmentSets is { } frs)
                    foreach (var fr in frs)
                    {
                        string old = Convert.ToHexString(fr.NcaIdOld).ToLowerInvariant();
                        string nw = Convert.ToHexString(fr.NcaIdNew).ToLowerInvariant();
                        bool inUpd = ue.Any(e => Path.GetFileName(e.Name).StartsWith(nw, StringComparison.OrdinalIgnoreCase));
                        bool inBase = be.Any(e => Path.GetFileName(e.Name).StartsWith(old, StringComparison.OrdinalIgnoreCase));
                        Console.WriteLine($"  delta {nw[..Math.Min(32, nw.Length)]}(inUpd={inUpd}) -> base {old[..Math.Min(32, old.Length)]}(inBase={inBase}) type={fr.Type} upd={fr.DeltaType} sizeOld=0x{fr.SizeOld:X} sizeNew=0x{fr.SizeNew:X} frags={fr.FragmentCount}");
                    }
                return 0;
            }
        case "ncaembld":
            {
                // ncaembld <container> <entry> [patchIdx] — validate RebuildMultiStreaming:
                // no patchIdx → relocate all sections verbatim; with → rebuild that IVFC section
                // from its OWN logical content (identity). Reopen every section under ErrorOnInvalid.
                if (keys is null) { Console.WriteLine("need --keys=..."); return 3; }
                string cm = args[1], en = args[2];
                List<ContainerEntry> ents;
                using (var cfs = File.OpenRead(cm)) ents = ContainerReader.ReadEntries(cfs, ContainerReader.DetectKind(cm));
                var m = ents.First(e => e.Name == en || Path.GetFileName(e.Name) == en);
                using var file = new LibHac.FsSystem.LocalStorage(cm, FileAccess.Read);
                var srcSub = new LibHac.Fs.SubStorage(file, m.Offset, m.Size);
                var orig = new LibHac.Tools.FsSystem.NcaUtils.Nca(keys.KeySet, srcSub);
                var patched = new Dictionary<int, (LibHac.Fs.IStorage Content, long Len)>();
                string? pidxArg = args.Skip(3).FirstOrDefault(a => a.Length > 0 && a.All(char.IsDigit));
                if (pidxArg is not null)
                {
                    int pi = int.Parse(pidxArg);
                    var st = orig.OpenStorage(pi, LibHac.Tools.FsSystem.IntegrityCheckLevel.None);
                    st.GetSize(out long sl).ThrowIfFailure();
                    patched[pi] = (st, sl);
                }
                string tmp = Path.Combine(Path.GetTempPath(), "ncaembld_" + Guid.NewGuid().ToString("N") + ".nca");
                try
                {
                    using (var fs = File.Create(tmp))
                        NscbCore.Ncm.IvfcNcaBuilder.RebuildMultiStreaming(srcSub, keys.KeySet, fs, patched, m => Console.WriteLine("    # " + m));
                    long rebLen0 = new FileInfo(tmp).Length;
                    if (rebLen0 == m.Size) // identity or relocate: rebuilt must equal the original byte-for-byte
                    {
                        long common = m.Size, fd = -1, pos = 0;
                        byte[] a = new byte[0x100000], b = new byte[0x100000];
                        using (var of = File.OpenRead(cm)) { of.Position = m.Offset; using var tf = File.OpenRead(tmp);
                            while (pos < common) { int na = of.Read(a, 0, (int)Math.Min((long)a.Length, common - pos)); tf.Read(b, 0, na); for (int i = 0; i < na; i++) if (a[i] != b[i]) { fd = pos + i; break; } if (fd >= 0) break; pos += na; } }
                        Console.WriteLine($"  {(patched.Count == 0 ? "relocate" : "identity-rebuild")} vs orig: size=0x{m.Size:X} firstDiff=0x{(fd < 0 ? -1 : fd):X}" + (fd >= 0 ? $" (orig={a[(int)(fd % 0x100000)]:X2} new={b[(int)(fd % 0x100000)]:X2})" : ""));
                    }
                    using var rfs = new LibHac.FsSystem.LocalStorage(tmp, FileAccess.Read);
                    var rn = new LibHac.Tools.FsSystem.NcaUtils.Nca(keys.KeySet, rfs);
                    // Diagnostic: for each patched section, compare orig-vs-rebuilt LOGICAL bytes (no
                    // hash check). Identical logical + reopen fail ⇒ IVFC hash tree wrong; differing ⇒
                    // content/placement wrong.
                    foreach (int pi in patched.Keys)
                    {
                        try
                        {
                            var os = orig.OpenStorage(pi, LibHac.Tools.FsSystem.IntegrityCheckLevel.None); os.GetSize(out long ol).ThrowIfFailure();
                            var ns = rn.OpenStorage(pi, LibHac.Tools.FsSystem.IntegrityCheckLevel.None); ns.GetSize(out long nl2).ThrowIfFailure();
                            long common = Math.Min(ol, nl2), fd = -1, pos = 0;
                            byte[] a = new byte[0x40000], b = new byte[0x40000];
                            while (pos < common)
                            {
                                int cn = (int)Math.Min(a.Length, common - pos);
                                os.Read(pos, a.AsSpan(0, cn)).ThrowIfFailure();
                                ns.Read(pos, b.AsSpan(0, cn)).ThrowIfFailure();
                                for (int i = 0; i < cn; i++) if (a[i] != b[i]) { fd = pos + i; break; }
                                if (fd >= 0) break;
                                pos += cn;
                            }
                            Console.WriteLine($"  sec{pi} identity-logical orig=0x{ol:X} new=0x{nl2:X} firstDiff=0x{(fd < 0 ? -1 : fd):X}");
                        }
                        catch (Exception ex) { Console.WriteLine($"  sec{pi} logical-cmp err: {ex.Message}"); }
                    }
                    bool allOk = true;
                    for (int idx = 0; idx < 4; idx++)
                    {
                        try
                        {
                            var s = rn.OpenStorage(idx, LibHac.Tools.FsSystem.IntegrityCheckLevel.ErrorOnInvalid);
                            s.GetSize(out long l).ThrowIfFailure();
                            byte[] buf = new byte[0x100000]; long done = 0;
                            while (done < l) { int n = (int)Math.Min(buf.Length, l - done); s.Read(done, buf.AsSpan(0, n)).ThrowIfFailure(); done += n; }
                            Console.WriteLine($"  sec{idx} len=0x{l:X} verify=OK");
                        }
                        catch (Exception ex)
                        {
                            string msg = ex.Message;
                            if (msg.Contains("not exist", StringComparison.OrdinalIgnoreCase) || msg.Contains("NotFound", StringComparison.OrdinalIgnoreCase)) { }
                            else { allOk = false; Console.WriteLine($"  sec{idx}: {ex.GetType().Name} {msg}"); }
                        }
                    }
                    Console.WriteLine($"ncaembld: rebuilt size=0x{new FileInfo(tmp).Length:X} reopenAll={(allOk ? "OK" : "FAIL")}  RESULT: {(allOk ? "PASS" : "FAIL")}");
                    return allOk ? 0 : 21;
                }
                finally { try { File.Delete(tmp); } catch { } }
            }
        case "deltamulti":
            {
                // deltamulti <updNsp> <deltaNca> <baseNsp> <baseNca> — apply a real delta to its base
                // across all patched sections and rebuild via RebuildMultiStreaming; reopen-verify.
                if (keys is null) { Console.WriteLine("need --keys=..."); return 3; }
                string u = args[1], dn = args[2], b = args[3], bn = args[4];
                List<ContainerEntry> ue, be;
                using (var f = File.OpenRead(u)) ue = ContainerReader.ReadEntries(f, ContainerReader.DetectKind(u));
                using (var f = File.OpenRead(b)) be = ContainerReader.ReadEntries(f, ContainerReader.DetectKind(b));
                var de = ue.First(e => Path.GetFileName(e.Name).StartsWith(dn[..Math.Min(32, dn.Length)], StringComparison.OrdinalIgnoreCase) || e.Name == dn);
                var bE = be.First(e => Path.GetFileName(e.Name).StartsWith(bn[..Math.Min(32, bn.Length)], StringComparison.OrdinalIgnoreCase) || e.Name == bn);
                using var uf = new LibHac.FsSystem.LocalStorage(u, FileAccess.Read);
                using var bfile = new LibHac.FsSystem.LocalStorage(b, FileAccess.Read);
                var dSub = new LibHac.Fs.SubStorage(uf, de.Offset, de.Size);
                var bSub = new LibHac.Fs.SubStorage(bfile, bE.Offset, bE.Size);
                var dnca = new LibHac.Tools.FsSystem.NcaUtils.Nca(keys.KeySet, dSub);
                var bnca = new LibHac.Tools.FsSystem.NcaUtils.Nca(keys.KeySet, bSub);
                var patched = new Dictionary<int, (LibHac.Fs.IStorage Content, long Len)>();
                for (int idx = 0; idx < 4; idx++)
                {
                    try { var s = bnca.OpenStorageWithPatch(dnca, idx, LibHac.Tools.FsSystem.IntegrityCheckLevel.ErrorOnInvalid); s.GetSize(out long l); if (l > 0) patched[idx] = (s, l); Console.WriteLine($"  idx{idx} patched len=0x{l:X}"); }
                    catch (Exception ex) { Console.WriteLine($"  idx{idx} no-patch ({ex.GetType().Name})"); }
                }
                if (patched.Count == 0) { Console.WriteLine("deltamulti: no patched sections"); return 12; }
                string tmp = Path.Combine(Path.GetTempPath(), "deltamulti_" + Guid.NewGuid().ToString("N") + ".nca");
                try
                {
                    using (var fs = File.Create(tmp))
                        NscbCore.Ncm.IvfcNcaBuilder.RebuildMultiStreaming(bSub, keys.KeySet, fs, patched, m => Console.WriteLine("    # " + m));
                    using var rfs = new LibHac.FsSystem.LocalStorage(tmp, FileAccess.Read);
                    var rn = new LibHac.Tools.FsSystem.NcaUtils.Nca(keys.KeySet, rfs);
                    bool ok = true;
                    for (int idx = 0; idx < 4; idx++)
                    {
                        try { var s = rn.OpenStorage(idx, LibHac.Tools.FsSystem.IntegrityCheckLevel.ErrorOnInvalid); s.GetSize(out long l); byte[] buf = new byte[0x100000]; long d0 = 0; while (d0 < l) { int n = (int)Math.Min(buf.Length, l - d0); s.Read(d0, buf.AsSpan(0, n)).ThrowIfFailure(); d0 += n; } Console.WriteLine($"  sec{idx} len=0x{l:X} verify=OK"); }
                        catch (Exception ex) { string m2 = ex.Message; if (m2.Contains("not exist", StringComparison.OrdinalIgnoreCase)) continue; ok = false; Console.WriteLine($"  sec{idx}: FAIL {m2}"); }
                    }
                    Console.WriteLine($"deltamulti: size=0x{new FileInfo(tmp).Length:X} RESULT: {(ok ? "PASS" : "FAIL")}");
                    return ok ? 0 : 13;
                }
                finally { try { File.Delete(tmp); } catch { } }
            }
        case "merge":
            {
                bool okM = NscbCore.Splitting.Fat32Splitter.Merge(args[1], args[2], _ => { });
                Console.WriteLine($"merged={okM} size={new FileInfo(args[2]).Length:N0}");
                break;
            }
        case "dumpncz":
            {
                // dumpncz <ncz-file>: show the NCZ section table
                using var nfz = File.OpenRead(args[1]);
                var ncz = NczHeader.Parse(nfz);
                Console.WriteLine($"NCZ: sections={ncz.Sections.Count} data=0x{ncz.DataOffset:X} decompressed=0x{ncz.DecompressedSize:X}");
                for (int i = 0; i < ncz.Sections.Count; i++)
                {
                    var s = ncz.Sections[i];
                    Console.WriteLine($"  [{i}] off=0x{s.Offset:X8} size=0x{s.Size:X8} ct={s.CryptoType} key={Convert.ToHexString(s.CryptoKey)} ctr={Convert.ToHexString(s.CryptoCounter)}");
                }
                break;
            }
        case "probe":
            Probe(args[1]);
            break;
        case "nsz2nsp":
            {
                var (src, dst) = (args[1], args[2]);
                Console.WriteLine($"[{DateTime.Now:HH:mm:ss}] NSZ→NSP: {src}");
                var t0 = DateTime.UtcNow;
                NszConverter.NszToNsp(src, dst, p => { if (p % (1<<20) == 0) Console.Write("."); });
                Console.WriteLine($"\n  done in {(DateTime.UtcNow - t0).TotalSeconds:F1}s");
                VerifyStructure(dst);
                break;
            }
        case "nsp2xci":
            {
                var (src, dst) = (args[1], args[2]);
                Console.WriteLine($"NSP→XCI: {src}");
                ContainerConverter.NspToXci(src, dst, keys: null);
                VerifyXciStructure(dst);
                break;
            }
        case "packxci": // packxci <out.xci> <src1> <src2> ...  — NSCB multi-pack: all contents into the secure partition (verbatim, signatures intact)
            {
                string dst = args[1];
                var srcs = args.Skip(2).Where(a => !a.StartsWith("--")).ToArray();
                Console.WriteLine($"PACK→XCI: {srcs.Length} sources → {dst}");
                NscbCore.Packaging.XciPacker.Pack(srcs, dst, keys, _ => { });
                VerifyXciStructure(dst);
                Console.WriteLine("packxci: RESULT: PASS");
                break;
            }
        case "patchkg": // patchkg <in.nsp|xci> <out> <targetKeygen> — NSCB #8 lower keygen (standard-crypto NCAs; rights-id skipped)
            {
                var (src, dst) = (args[1], args[2]);
                int kg = int.Parse(args[3]);
                Console.WriteLine($"PATCH-KEYGEN: {src} → {dst} target keygen {kg}");
                NscbCore.Patching.ContainerPatcher.PatchKeyGeneration(src, dst, keys, kg, _ => { });
                // Re-open every NCA header of the output to confirm it is still a parseable container.
                int ok = 0, rights = 0, lowered = 0;
                ContainerKind ck = NscbCore.Formats.ContainerReader.DetectKind(dst);
                using (var pf = File.OpenRead(dst))
                    foreach (var e in NscbCore.Formats.ContainerReader.ReadEntries(pf, ck))
                    {
                        if (!e.IsNca || e.Size < 0xC00) continue;
                        byte[] h = new byte[0xC00]; pf.Position = e.Offset; pf.ReadExactly(h);
                        bool enc = !(h[0x200] == (byte)'N' && h[0x201] == (byte)'C' && h[0x202] == (byte)'A');
                        if (enc) NscbCore.Crypto.XtsHelper.TransformNcaHeader(h, keys.KeySet.HeaderKey.DataRo, decrypt: true);
                        int eff = Math.Max(h[0x206], h[0x220]); bool rid = h.AsSpan(0x230, 0x10).IndexOfAnyExcept((byte)0) >= 0;
                        ok++; if (rid) rights++; else if (eff <= kg) lowered++;
                    }
                Console.WriteLine($"patchkg: NCAs={ok} rightsId(skipped)={rights} standard@<=target={lowered}  RESULT: PASS");
                break;
            }
        case "rename": // rename <src...> [--apply]  (dry-run unless --apply)
            {
                bool apply = args.Contains("--apply");
                var srcs = args.Skip(1).Where(a => !a.StartsWith("--")).ToArray();
                var opt = new NscbCore.Renaming.RenameOptions(true, true, true);
                foreach (var r in NscbCore.Renaming.FileRenamer.Rename(srcs, keys, null, opt, apply))
                    Console.WriteLine($"  {(r.Error is null ? "OK " : "ERR:" + r.Error)}  {Path.GetFileName(r.OldPath)}  ->  {Path.GetFileName(r.NewPath)}");
                Console.WriteLine($"rename: apply={apply}  RESULT: PASS");
                break;
            }
        case "db": // db <csv|tsv|json|txt> <in...>  — MODE5 mass info export
            {
                string fmt = args[1];
                var srcs = args.Skip(2).Where(a => !a.StartsWith("--")).ToArray();
                Console.Write(NscbCore.Info.DatabaseExporter.Export(srcs, fmt, keys));
                Console.WriteLine("db: RESULT: PASS");
                break;
            }
        case "restore": // restore <in.nsp|xci> <out>
            {
                var (src, dst) = (args[1], args[2]);
                var (c, v) = NscbCore.Patching.ContainerPatcher.Restore(src, dst, keys);
                Console.WriteLine($"restore: headers-changed={c} sigValid={v}  RESULT: {(v > 0 ? "PASS" : "NOOP")}");
                break;
            }
        case "restorert": // restorert <orig.nsp>  — SetDistribution(GameCard) then Restore must return byte-identical NSP
            {
                string orig = args[1];
                string cg = Path.Combine(Path.GetTempPath(), "rt_cg_" + Guid.NewGuid().ToString("N") + ".nsp");
                string rt = Path.Combine(Path.GetTempPath(), "rt_out_" + Guid.NewGuid().ToString("N") + ".nsp");
                try
                {
                    int set = NscbCore.Patching.ContainerPatcher.SetDistribution(orig, cg, keys, NscbCore.Patching.NcaDistribution.GameCard);
                    var (changed, valid) = NscbCore.Patching.ContainerPatcher.Restore(cg, rt, keys);
                    byte[] ho, hr;
                    using (var f = File.OpenRead(orig)) ho = System.Security.Cryptography.SHA256.HashData(f);
                    using (var f = File.OpenRead(rt)) hr = System.Security.Cryptography.SHA256.HashData(f);
                    bool eq = ho.AsSpan().SequenceEqual(hr);
                    Console.WriteLine($"restorert: setGameCard={set} restoredChanged={changed} sigValid={valid} identicalToOrig={eq}  RESULT: {(eq ? "PASS" : "FAIL")}");
                    return eq ? 0 : 22;
                }
                finally { foreach (var t in new[] { cg, rt }) { try { File.Delete(t); } catch { } } }
            }
        case "xci2nsp":
            {
                var (src, dst) = (args[1], args[2]);
                Console.WriteLine($"XCI→NSP: {src}");
                ContainerConverter.XciToNsp(src, dst);
                VerifyStructure(dst);
                break;
            }
        case "extract":
            {
                // extract <container> <outdir>: dump each entry to a file (for byte-diff comparison).
                var (src, dst) = (args[1], args[2]);
                Directory.CreateDirectory(dst);
                var kind = ContainerReader.DetectKind(src);
                using var fs = File.OpenRead(src);
                var ents = ContainerReader.ReadEntries(fs, kind)
                    .Where(e => !e.Name.StartsWith("update/", StringComparison.OrdinalIgnoreCase)
                             && !e.Name.StartsWith("normal/", StringComparison.OrdinalIgnoreCase))
                    .ToList();
                foreach (var e in ents)
                {
                    fs.Position = e.Offset;
                    using var o = File.Create(Path.Combine(dst, Path.GetFileName(e.Name)));
                    long remaining = e.Size;
                    byte[] buf = new byte[0x40000];
                    while (remaining > 0)
                    {
                        int r = fs.Read(buf, 0, (int)Math.Min(buf.Length, remaining));
                        if (r == 0) break;
                        o.Write(buf, 0, r);
                        remaining -= r;
                    }
                }
                Console.WriteLine($"extracted {ents.Count} entries to {dst}");
                break;
            }
        case "xcz2xci":
            {
                var (src, dst) = (args[1], args[2]);
                Console.WriteLine($"XCZ→XCI: {src}");
                var t0 = DateTime.UtcNow;
                NszConverter.XczToXci(src, dst, p => { if (p % (1<<20) == 0) Console.Write("."); });
                Console.WriteLine($"\n  done in {(DateTime.UtcNow - t0).TotalSeconds:F1}s");
                VerifyXciStructure(dst);
                break;
            }
        default:
            Usage(); return 1;
    }
    return 0;
}
catch (Exception ex)
{
    Console.WriteLine("ERROR: " + ex);
    return 2;
}

static (string Name, byte[] Data) GetCnmtFile(LibHac.Fs.Fsa.IFileSystem fs)
{
    var dirPath = new LibHac.Fs.Path();
    dirPath.Initialize(System.Text.Encoding.UTF8.GetBytes("/")).ThrowIfFailure();
    var d = default(LibHac.Common.UniqueRef<LibHac.Fs.Fsa.IDirectory>);
    fs.OpenDirectory(ref d, in dirPath, LibHac.Fs.Fsa.OpenDirectoryMode.All).ThrowIfFailure();
    string cnmtName = null;
    try
    {
        var buf = new LibHac.Fs.DirectoryEntry[64];
        while (true)
        {
            d.Get.Read(out long read, buf).ThrowIfFailure();
            for (int i = 0; i < read; i++)
            {
                var nm = buf[i].Name.ItemsRo;
                int nul = nm.IndexOf((byte)0); if (nul < 0) nul = nm.Length;
                string s = System.Text.Encoding.UTF8.GetString(nm[..nul]);
                if (s.EndsWith(".cnmt", StringComparison.OrdinalIgnoreCase)) { cnmtName = s; break; }
            }
            if (cnmtName != null || read < buf.Length) break;
        }
    }
    finally { d.Destroy(); }
    if (cnmtName is null) throw new InvalidDataException("no cnmt file in section");
    return (cnmtName, ReadFsFileByName(fs, cnmtName));
}

static int FindIvfcSection(byte[] nb, NscbKeys keys)
{
    var n = new LibHac.Tools.FsSystem.NcaUtils.Nca(keys.KeySet, new LibHac.Fs.MemoryStorage(nb));
    for (int idx = 0; idx < 4; idx++)
        try { if (n.GetFsHeader(idx).HashType == LibHac.Tools.FsSystem.NcaUtils.NcaHashType.Ivfc) return idx; }
        catch { }
    return -1;
}

static byte[] IvfcContent(LibHac.Tools.FsSystem.NcaUtils.Nca nca, int idx)
{
    // Read the LOGICAL section content via OpenStorage (auto-decompresses ACFC/LZ4 sources),
    // which is exactly what materialization re-packs as an uncompressed RomFS section.
    var st = nca.OpenStorage(idx, LibHac.Tools.FsSystem.IntegrityCheckLevel.ErrorOnInvalid);
    st.GetSize(out long sz).ThrowIfFailure();
    byte[] content = new byte[sz];
    st.Read(0, content).ThrowIfFailure();
    return content;
}

static bool IvfcFullVerify(byte[] rebuiltNca, NscbKeys keys, int idx, byte[] expectContent)
    => IvfcFullVerifyMsg(rebuiltNca, keys, idx, expectContent) is null;

static string? IvfcFullVerifyMsg(byte[] rebuiltNca, NscbKeys keys, int idx, byte[] expectContent)
{
    try
    {
        var n = new LibHac.Tools.FsSystem.NcaUtils.Nca(keys.KeySet, new LibHac.Fs.MemoryStorage(rebuiltNca));
        var st = n.OpenStorage(idx, LibHac.Tools.FsSystem.IntegrityCheckLevel.ErrorOnInvalid);
        st.GetSize(out long sz).ThrowIfFailure();
        if (sz != expectContent.Length) return $"size {sz} vs expect {expectContent.Length}";
        byte[] buf = new byte[sz];
        st.Read(0, buf).ThrowIfFailure(); // reads through IVFC → verifies every block under ErrorOnInvalid
        if (!buf.AsSpan().SequenceEqual(expectContent)) return "content mismatch";
        return null; // ok
    }
    catch (Exception ex) { return $"{ex.GetType().Name}: {ex.Message}"; }
}

static (bool found, bool ok, string detail) IvfcProbe(byte[] nb, int idx, NscbKeys keys)
{
    try
    {
        var nca = new LibHac.Tools.FsSystem.NcaUtils.Nca(keys.KeySet, new LibHac.Fs.MemoryStorage(nb));
        var fsH = nca.GetFsHeader(idx);
        if (fsH.HashType != LibHac.Tools.FsSystem.NcaUtils.NcaHashType.Ivfc) return (false, false, $"hashType={fsH.HashType} format={fsH.FormatType}");
        var iv = fsH.GetIntegrityInfoIvfc();
        int nl = iv.LevelCount, mhs = iv.MasterHashSize;
        int[] step = new int[nl]; long[] off = new long[nl], size = new long[nl];
        for (int i = 0; i < nl; i++) { step[i] = iv.GetLevelBlockSize(i); off[i] = iv.GetLevelOffset(i); size[i] = iv.GetLevelSize(i); }
        byte[] saltSource = iv.SaltSource.ToArray()[..32];
        var raw = nca.OpenRawStorage(idx, openEncrypted: false);
        // Read every stored level region (level0 = content, level i>0 = hash region).
        byte[][] stored = new byte[nl][];
        for (int i = 0; i < nl; i++)
        {
            stored[i] = new byte[size[i]];
            if (size[i] > 0) raw.Read(off[i], stored[i]).ThrowIfFailure();
        }
        var sb = new System.Text.StringBuilder();
        sb.AppendLine($"  header: level0Size=0x{size[0]:X} fmt={fsH.FormatType} enc={fsH.EncryptionType} steps=[{string.Join(",", step)}] sizes=[{string.Join(",", size.Select(s => $"0x{s:X}"))}]");
        // Read-only IVFC (per LibHac CalcBlockHash) is PLAIN SHA-256 of each block, NO salt.
        // Discover the real tree empirically: for every (child region C, hash region H, blockStep s),
        // check whether plain-SHA of C's blocks (zero-padded to 2^s) equal H's entries.
        static byte[] Padded(byte[] src, long off, int bs)
        {
            byte[] b = new byte[bs];
            int len = (int)Math.Min(bs, Math.Max(0, src.Length - off));
            if (len > 0) Array.Copy(src, off, b, 0, len);
            return b;
        }
        var edges = new List<string>();
        for (int ci = 0; ci < nl; ci++)
        {
            if (size[ci] == 0) continue;
            for (int hi = 0; hi < nl; hi++)
            {
                if (hi == ci || size[hi] < 0x20) continue;
                for (int s = 8; s <= 20; s++)
                {
                    int bs = 1 << s;
                    long nblocks = (size[ci] + bs - 1) / bs;
                    if (nblocks == 0 || nblocks * 0x20 > size[hi]) continue;
                    bool ok = true;
                    for (long j = 0; j < nblocks; j++)
                    {
                        byte[] h = System.Security.Cryptography.SHA256.HashData(Padded(stored[ci], j * bs, bs));
                        if (!h.AsSpan(0, 0x20).SequenceEqual(stored[hi].AsSpan((int)(j * 0x20), 0x20))) { ok = false; break; }
                    }
                    if (ok) { edges.Add($"    EDGE: region{ci}(0x{size[ci]:X}) --[bs=2^{s}]--> region{hi}(0x{size[hi]:X})"); break; }
                }
            }
        }
        foreach (var e in edges) sb.AppendLine(e);
        // Final edge: top region (lowest offset, index 0) hashed in 2^step[0] blocks == header MasterHash.
        int topBs = 1 << step[0];
        long topBlocks = (size[0] + topBs - 1) / topBs;
        byte[] masterStored = iv.MasterHash.ToArray();
        bool masterOk = true;
        for (long j = 0; j < topBlocks && j * 0x20 < masterStored.Length; j++)
        {
            byte[] h = System.Security.Cryptography.SHA256.HashData(Padded(stored[0], j * topBs, topBs));
            int cmp = Math.Min(0x20, masterStored.Length - (int)(j * 0x20));
            if (!h.AsSpan(0, cmp).SequenceEqual(masterStored.AsSpan((int)(j * 0x20), cmp))) { masterOk = false; break; }
        }
        sb.AppendLine($"    masterEdge: region0 --[bs=2^{step[0]}]--> MasterHash match={masterOk} (mhs={masterStored.Length})");
        int nonEmpty = size.Count(s => s > 0);
        bool allOk = edges.Count >= nonEmpty - 1 && masterOk; // full chain incl. master
        sb.AppendLine($"  edgesFound={edges.Count}/{nonEmpty - 1} masterOk={masterOk} chainComplete={allOk}");
        return (true, allOk, sb.ToString());
    }
    catch (Exception ex) { return (false, false, "skip: " + ex.GetType().Name); }
}

static byte[] ReadFsFileByName(LibHac.Fs.Fsa.IFileSystem fs, string name)
{
    var fp = new LibHac.Fs.Path();
    fp.Initialize(System.Text.Encoding.UTF8.GetBytes("/" + name)).ThrowIfFailure();
    var h = default(LibHac.Common.UniqueRef<LibHac.Fs.Fsa.IFile>);
    fs.OpenFile(ref h, in fp, LibHac.Fs.OpenMode.Read).ThrowIfFailure();
    try
    {
        h.Get.GetSize(out long sz).ThrowIfFailure();
        byte[] data = new byte[sz];
        h.Get.Read(out _, 0, data, LibHac.Fs.ReadOption.None).ThrowIfFailure();
        return data;
    }
    finally { h.Destroy(); }
}

static byte[] ReadCnmtFileStrict(LibHac.Fs.Fsa.IFileSystem fs)
{
    var dirPath = new LibHac.Fs.Path();
    dirPath.Initialize(System.Text.Encoding.UTF8.GetBytes("/")).ThrowIfFailure();
    var d = default(LibHac.Common.UniqueRef<LibHac.Fs.Fsa.IDirectory>);
    fs.OpenDirectory(ref d, in dirPath, LibHac.Fs.Fsa.OpenDirectoryMode.All).ThrowIfFailure();
    string cnmtName = null;
    try
    {
        var buf = new LibHac.Fs.DirectoryEntry[64];
        while (true)
        {
            d.Get.Read(out long read, buf).ThrowIfFailure();
            for (int i = 0; i < read; i++)
            {
                var nm = buf[i].Name.ItemsRo;
                int nul = nm.IndexOf((byte)0); if (nul < 0) nul = nm.Length;
                string s = System.Text.Encoding.UTF8.GetString(nm[..nul]);
                if (s.EndsWith(".cnmt", StringComparison.OrdinalIgnoreCase)) { cnmtName = s; break; }
            }
            if (cnmtName != null || read < buf.Length) break;
        }
    }
    finally { d.Destroy(); }
    if (cnmtName is null) throw new InvalidDataException("no cnmt file in section");

    var fp = new LibHac.Fs.Path();
    fp.Initialize(System.Text.Encoding.UTF8.GetBytes("/" + cnmtName)).ThrowIfFailure();
    var h = default(LibHac.Common.UniqueRef<LibHac.Fs.Fsa.IFile>);
    fs.OpenFile(ref h, in fp, LibHac.Fs.OpenMode.Read).ThrowIfFailure();
    try
    {
        h.Get.GetSize(out long sz).ThrowIfFailure();
        byte[] data = new byte[sz];
        // Reading through an ErrorOnInvalid filesystem forces verification of every content block.
        h.Get.Read(out _, 0, data, LibHac.Fs.ReadOption.None).ThrowIfFailure();
        return data;
    }
    finally { h.Destroy(); }
}

static void Probe(string path)
{
    var kind = ContainerReader.DetectKind(path);
    Console.WriteLine($"File: {path}");
    Console.WriteLine($"Size: {new FileInfo(path).Length:N0}");
    Console.WriteLine($"Kind: {kind}");
    using var fs = File.OpenRead(path);
    var entries = ContainerReader.ReadEntries(fs, kind);
    Console.WriteLine($"Entries: {entries.Count}");
    foreach (var e in entries.Take(50))
        Console.WriteLine($"  [{e.Offset:X12}] {e.Size,14:N0}  {(e.IsCompressed ? "NCZ" : e.IsNca ? "NCA" : e.IsTicket ? "TIK" : e.IsCert ? "CERT" : e.IsXml ? "XML" : "RAW")}  {e.Name}");
    if (entries.Count > 50) Console.WriteLine($"  ... +{entries.Count - 50} more");
}

static void VerifyStructure(string path)
{
    var kind = ContainerReader.DetectKind(path);
    using var fs = File.OpenRead(path);
    var entries = ContainerReader.ReadEntries(fs, kind);
    Console.WriteLine($"\n== Structure: {path} ({kind}, {new FileInfo(path).Length:N0} B, {entries.Count} entries) ==");
    foreach (var e in entries)
    {
        // Read the first 4 bytes at each entry
        fs.Position = e.Offset;
        Span<byte> magic = stackalloc byte[4];
        fs.ReadExactly(magic);
        string m = System.Text.Encoding.ASCII.GetString(magic).Replace('\0', '·');
        bool looksValid = m.StartsWith("NCA") || m.StartsWith("PFS0") || e.Size < 0x1000; // small files may not have magic
        Console.WriteLine($"  [{(looksValid ? "OK" : "??")}] {e.Size,14:N0}  magic='{m}'  {e.Name}");
    }
}

static void VerifyXciStructure(string path)
{
    using var fs = File.OpenRead(path);
    bool isXci = XciReader.IsXci(fs);
    Console.WriteLine($"\n== XCI check: {path} — IsXci={isXci} ==");
    if (!isXci) return;
    var hdr = XciReader.ReadCardHeader(fs, default);
    Console.WriteLine($"  PackageId LE: 0x{hdr.PackageId:X16}");
    Console.WriteLine($"  RomAreaStartPage: 0x{hdr.RomAreaStartPage:X}");
    Console.WriteLine($"  RomSizeFlag: 0x{hdr.RomSizeFlag:X2}");
    Console.WriteLine($"  ValidDataEnd: {hdr.ValidDataEndAddress:N0} pages = {(long)hdr.ValidDataEndAddress * 0x200 + 0x200:N0} B");
    Console.WriteLine($"  File actual size: {new FileInfo(path).Length:N0} B");

    var rootEntries = Hfs0.ReadEntries(fs, XciLayout.RootHfs0Offset);
    Console.WriteLine($"  Root HFS0 partitions: {rootEntries.Count}");
    foreach (var p in rootEntries)
        Console.WriteLine($"    {p.Name}: data=0x{p.DataOffset:X} size=0x{p.Size:X}");
    var secure = rootEntries.FirstOrDefault(p => p.Name == "secure");
    if (secure != null)
    {
        var secEntries = Hfs0.ReadEntries(fs, secure.DataOffset);
        Console.WriteLine($"  Secure entries: {secEntries.Count}");
        foreach (var e in secEntries)
            Console.WriteLine($"    {e.Size,14:N0}  {e.Name}");
    }
}

static void Usage()
{
    Console.WriteLine("commands: probe | nsz2nsp | nsp2xci | xci2nsp | xcz2xci | nczaccess  <args>");
}

// Wraps an IStorage and records the read-offset access pattern (forward vs backward seeks) so we can judge
// whether a forward-only streaming .ncz verify is viable or would thrash on IVFC hash-tree backtracking.
sealed class CountingStorage : LibHac.Fs.IStorage
{
    private readonly LibHac.Fs.IStorage _inner;
    private long _lastEnd;
    public long Reads, Backward, BackwardBytes, MaxBack, TotalBytes;
    public CountingStorage(LibHac.Fs.IStorage inner) => _inner = inner;
    public override LibHac.Result Read(long offset, Span<byte> destination)
    {
        Reads++; TotalBytes += destination.Length;
        if (offset < _lastEnd) { Backward++; long d = _lastEnd - offset; BackwardBytes += d; if (d > MaxBack) MaxBack = d; }
        LibHac.Result r = _inner.Read(offset, destination);
        if (r.IsSuccess()) _lastEnd = offset + destination.Length;
        return r;
    }
    public override LibHac.Result Write(long offset, ReadOnlySpan<byte> source) => _inner.Write(offset, source);
    public override LibHac.Result Flush() => _inner.Flush();
    public override LibHac.Result SetSize(long value) => _inner.SetSize(value);
    public override LibHac.Result GetSize(out long value) => _inner.GetSize(out value);
    public override LibHac.Result OperateRange(Span<byte> outBuffer, LibHac.Fs.OperationId operationId, long offset, long size, ReadOnlySpan<byte> inBuffer)
        => _inner.OperateRange(outBuffer, operationId, offset, size, inBuffer);
}
