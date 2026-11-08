using System.IO;
using NscbCore.Info;
using NscbCore.Keys;
using System.Text.Json;
using Xunit;

namespace NscbCore.Tests;

/// <summary>MODE 5 database export: folder scan (supported ext only) + format rendering, no real keys needed.</summary>
public class DatabaseExporterTests
{
    // A minimal dummy prod.keys so NscbKeys.Load succeeds without real keys; the exporter's per-file
    // GetFileInfo runs with zero keys (garbage files still yield an Error row, empty folders yield none).
    private static NscbKeys? _keys;
    private static NscbKeys Keys => _keys ??= MakeKeys();
    private static NscbKeys MakeKeys()
    {
        string p = Path.Combine(Path.GetTempPath(), "nscb_dbtest_prod.keys");
        File.WriteAllText(p, "header_key = " + new string('0', 64) + "\nmaster_key_00 = " + new string('0', 64) + "\n");
        return NscbKeys.Load(p);
    }

    [Fact]
    public void Export_EmptyFolder_JsonIsEmptyArray()
    {
        string dir = Directory.CreateTempSubdirectory("dbempty").FullName;
        try
        {
            string json = DatabaseExporter.Export([dir], "json", Keys);
            Assert.Equal("[]", json.Trim());
        }
        finally { Directory.Delete(dir, true); }
    }

    [Fact]
    public void Export_Csv_HasHeaderRow()
    {
        string dir = Directory.CreateTempSubdirectory("dbcsv").FullName;
        try
        {
            string csv = DatabaseExporter.Export([dir], "csv", Keys);
            string[] lines = csv.Split("\r\n", StringSplitOptions.RemoveEmptyEntries);
            Assert.StartsWith("File,Format,TitleId,BaseTitleId,TitleType,TitleName", lines[0]);
            Assert.Single(lines); // header only, no files
        }
        finally { Directory.Delete(dir, true); }
    }

    [Fact]
    public void Export_ScansOnlySupportedExtensions_Recursively()
    {
        string dir = Directory.CreateTempSubdirectory("dbscan").FullName;
        try
        {
            File.WriteAllText(Path.Combine(dir, "readme.txt"), "x");            // unsupported → skipped
            Directory.CreateDirectory(Path.Combine(dir, "sub"));
            File.WriteAllText(Path.Combine(dir, "sub", "junk.nsp"), "not-an-nsp"); // supported ext → 1 row (with error)

            string json = DatabaseExporter.Export([dir], "json", Keys);
            using var doc = JsonDocument.Parse(json);
            Assert.Equal(JsonValueKind.Array, doc.RootElement.ValueKind);
            Assert.Equal(1, doc.RootElement.GetArrayLength()); // only the .nsp, .txt ignored
            var el = doc.RootElement[0];
            Assert.Contains("junk.nsp", el.GetProperty("File").GetString());
        }
        finally { Directory.Delete(dir, true); }
    }

    [Fact]
    public void Export_Tsv_UsesTabDelimiter()
    {
        string dir = Directory.CreateTempSubdirectory("dbtsv").FullName;
        try
        {
            string tsv = DatabaseExporter.Export([dir], "tsv", Keys);
            Assert.Contains('\t', tsv.Split('\n')[0]);
        }
        finally { Directory.Delete(dir, true); }
    }
}
