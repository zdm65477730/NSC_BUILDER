using NscbCore.Keys;
using Xunit;

namespace NscbCore.Tests;

public class FirmwareTablesTests
{
    [Theory]
    [InlineData(0, 0)]
    [InlineData(1, 0)]
    [InlineData(2, 1)]
    [InlineData(12, 11)]
    [InlineData(23, 22)]
    public void MasterKeyIndex_FollowsSwitchbrewRule(int keyGeneration, int expectedMasterIndex)
        => Assert.Equal(expectedMasterIndex, FirmwareTables.MasterKeyIndexFromKeyGeneration(keyGeneration));

    [Theory]
    [InlineData(0, 0)]
    [InlineData(1, 2)]
    [InlineData(11, 12)]
    [InlineData(22, 23)]
    public void KeyGenerationFromMasterKeyIndex_RoundTrips(int masterIndex, int expectedKeyGeneration)
        => Assert.Equal(expectedKeyGeneration, FirmwareTables.KeyGenerationFromMasterKeyIndex(masterIndex));

    [Theory]
    [InlineData(450u, "(1.0.0-450)")]
    [InlineData(0u, "(1.0.0)")]
    // 2.x values keep the original NSC_BUILDER display quirk (sec = RSV/65536).
    [InlineData(65536u, "(2.1.0)")]
    [InlineData(262144u, "(2.4.0)")]
    [InlineData(201326592u, "(3.0.0)")]
    [InlineData(201457664u, "(3.0.2)")]
    [InlineData(201392128u, "(3.0.1)")]
    [InlineData(536870912u, "(8.0.0)")]
    [InlineData(1275068416u, "(19.0.0)")]
    [InlineData(1342177280u, "(20.0.0)")]
    [InlineData(1543503872u, "(23.0.0)")]
    [InlineData(1543569408u, "(23.0.1)")]
    public void FwStringFromRsv_MatchesNscbSemantics(uint rsv, string expected)
        => Assert.Equal(expected, FirmwareTables.FwStringFromRsv(rsv));

    [Theory]
    [InlineData("3.0.0", 201326592u)]
    [InlineData("19.0.0", 1275068416u)]
    [InlineData("19.0.1", 1275133952u)]
    [InlineData("23.0.0", 1543503872u)]
    [InlineData("23.0.1", 1543569408u)]
    [InlineData("20.0.0", 1342177280u)]
    // 2.x keeps the original NSC_BUILDER encoding quirk (base 0x10000 + minor).
    [InlineData("2.0.0", 65536u)]
    [InlineData("2.3.0", 65539u)]
    [InlineData("1.0.0", 0u)]
    [InlineData("", 0u)]
    [InlineData("10.2.0-420", 673186212u)]
    public void RsvFromFwString_MatchesNscbSemantics(string firmware, uint expectedRsv)
        => Assert.Equal(expectedRsv, FirmwareTables.RsvFromFwString(firmware));

    [Fact]
    public void RsvFromFwString_ThenFwString_RoundTripsForModernFirmware()
    {
        foreach (string fw in new[] { "6.2.0", "9.0.1", "12.0.3", "16.1.0", "18.1.1", "21.0.0" })
        {
            uint rsv = FirmwareTables.RsvFromFwString(fw);
            Assert.Equal($"({fw})", FirmwareTables.FwStringFromRsv(rsv));
        }
    }

    [Theory]
    [InlineData(1543569408u, 23)]
    [InlineData(1543503872u, 23)]
    [InlineData(1476395008u, 22)]
    [InlineData(1275068416u, 19)]
    [InlineData(450u, 0)]
    [InlineData(201326592u, 2)]
    [InlineData(65536u, 1)]
    public void KeyGenerationFromRsv_ResolvesExactTableValues(uint rsv, int expectedKg)
        => Assert.Equal(expectedKg, FirmwareTables.KeyGenerationFromRsv(rsv));

    [Fact]
    public void KeyGenerationFromRsv_FallsBackToRangeForUnseenValues()
    {
        // Between kg 11 minimum and kg 12 minimum -> 11
        Assert.Equal(11, FirmwareTables.KeyGenerationFromRsv(800000000));
        // Tiny values map to generation 0
        Assert.Equal(0, FirmwareTables.KeyGenerationFromRsv(1));
    }

    [Fact]
    public void MinAndTopRsv_AreSortedDescendingPerGeneration()
    {
        for (int kg = 0; kg <= FirmwareTables.MaxKnownKeyGeneration; kg++)
        {
            uint min = FirmwareTables.MinRsvForKeyGeneration(kg);
            uint top = FirmwareTables.TopRsvForKeyGeneration(kg);
            Assert.True(top >= min, $"kg {kg}: top {top} < min {min}");
            if (kg > 0)
                Assert.True(min > FirmwareTables.TopRsvForKeyGeneration(kg - 1),
                    $"kg {kg} range overlaps previous generation");
        }
    }

    [Fact]
    public void FwRangeForKeyGeneration_CoversKnownRange()
    {
        Assert.Equal("unknown", FirmwareTables.FwRangeForKeyGeneration(-1));
        Assert.Equal("1.0.0 - 2.3.0", FirmwareTables.FwRangeForKeyGeneration(0));
        Assert.Contains("23.0.0", FirmwareTables.FwRangeForKeyGeneration(23));
        Assert.StartsWith("keygen 99", FirmwareTables.FwRangeForKeyGeneration(99));
    }

    [Theory]
    [InlineData(23, "23.0.0")]
    [InlineData(19, "19.0.0")]
    [InlineData(-1, "unknown")]
    public void FirstFwForKeyGeneration_TakesRangeStart(int kg, string expected)
        => Assert.Equal(expected, FirmwareTables.FirstFwForKeyGeneration(kg));

    [Theory]
    [InlineData(0xFA, "1GB")]
    [InlineData(0xF8, "2GB")]
    [InlineData(0xF0, "4GB")]
    [InlineData(0xE0, "8GB")]
    [InlineData(0xE1, "16GB")]
    [InlineData(0xE2, "32GB")]
    public void CardSizeNames_MatchSwitchbrew(byte flag, string expected)
        => Assert.Equal(expected, FirmwareTables.CardSizeName(flag));

    [Fact]
    public void CardSizeFlagForBytes_PicksSmallestFittingCard()
    {
        Assert.Equal<byte?>(0xFA, FirmwareTables.CardSizeFlagForBytes(0x3AF400000));
        Assert.Equal<byte?>(0xE2, FirmwareTables.CardSizeFlagForBytes(0x7530000000));
        Assert.Null(FirmwareTables.CardSizeFlagForBytes(0x7530000001));
    }
}
