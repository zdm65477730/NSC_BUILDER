using System.Reflection;
using Microsoft.Extensions.FileProviders;
using Microsoft.Extensions.Primitives;

namespace NscbServer;

/// <summary>
/// Read-only <see cref="IFileProvider"/> over the assembly's embedded <c>wwwroot</c> resources, so the
/// published app is a single self-contained exe with no side-by-side <c>wwwroot/</c> folder.
/// Resources are embedded with the logical prefix <c>NscbServer.wwwroot.</c> (path separators → '.').
/// </summary>
public sealed class WebRootFileProvider : IFileProvider
{
    private const string Prefix = "NscbServer.wwwroot.";
    private readonly Assembly _asm;

    public WebRootFileProvider(Assembly asm) => _asm = asm;

    public IFileInfo GetFileInfo(string subpath)
    {
        string rel = subpath.TrimStart('/', '\\');
        // Embedded logical names use '.', '/' or '\\' for subfolders depending on the build host's
        // separator — try each so nested assets (css/, mif/) resolve regardless.
        foreach (string name in Candidates(rel))
            if (_asm.GetManifestResourceInfo(name) is not null)
                return new ResourceFileInfo(_asm, name, Path.GetFileName(subpath));
        return new NotFoundFileInfo(subpath);
    }

    private static IEnumerable<string> Candidates(string rel)
    {
        yield return Prefix + rel.Replace('\\', '.').Replace('/', '.');
        yield return Prefix + rel.Replace('\\', '/');
        yield return Prefix + rel.Replace('/', '\\');
    }

    public IDirectoryContents GetDirectoryContents(string subpath) => new NotFoundDirectoryContents();

    public IChangeToken Watch(string filter) => NullChangeToken.Singleton;

    private sealed class ResourceFileInfo : IFileInfo
    {
        private readonly Assembly _asm;
        private readonly string _resource;
        public ResourceFileInfo(Assembly asm, string resource, string name) { _asm = asm; _resource = resource; Name = name; }
        public bool Exists => true;
        public long Length { get { using var s = _asm.GetManifestResourceStream(_resource)!; return s.Length; } }
        public string? PhysicalPath => null;
        public string Name { get; }
        public DateTimeOffset LastModified { get; } = DateTimeOffset.UnixEpoch;
        public bool IsDirectory => false;
        public Stream CreateReadStream() => _asm.GetManifestResourceStream(_resource)
            ?? throw new FileNotFoundException(_resource);
    }
}
