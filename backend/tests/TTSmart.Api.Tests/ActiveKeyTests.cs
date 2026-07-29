using TTSmart.Api.Features.Authorization;

namespace TTSmart.Api.Tests;

public sealed class ActiveKeyTests
{
    [Fact]
    public void Validate_ChiNhan9KyTuNhiPhan()
    {
        Assert.True(ActiveKeyValue.IsValid("111111111"));
        Assert.True(ActiveKeyValue.IsValid("010000001"));
        Assert.False(ActiveKeyValue.IsValid("11111111"));
        Assert.False(ActiveKeyValue.IsValid("1111111111"));
        Assert.False(ActiveKeyValue.IsValid("11111111x"));
        Assert.False(ActiveKeyValue.IsValid(null));
    }

    [Fact]
    public void SetVaAllows_DungThuTu9Quyen()
    {
        var key = ActiveKeyValue.Set(ActiveKeyValue.None, ActiveKeyPermission.View, true);
        key = ActiveKeyValue.Set(key, ActiveKeyPermission.DSach, true);

        Assert.Equal("100000001", key);
        Assert.True(ActiveKeyValue.Allows(key, ActiveKeyPermission.View));
        Assert.True(ActiveKeyValue.Allows(key, ActiveKeyPermission.DSach));
        Assert.False(ActiveKeyValue.Allows(key, ActiveKeyPermission.Print));
    }

    [Fact]
    public void Merge_HopNhatTheoOrTungBitVaFullLaTrangThaiTongHop()
    {
        var merged = ActiveKeyValue.Merge(["100000000", "010000000", "000000001"]);

        Assert.Equal("110000001", merged);
        Assert.False(ActiveKeyValue.IsFull(merged));
        Assert.True(ActiveKeyValue.IsFull(ActiveKeyValue.Full));
    }

    [Fact]
    public void Set_BatTatDuCa9Quyen()
    {
        foreach (var permission in Enum.GetValues<ActiveKeyPermission>())
        {
            var enabled = ActiveKeyValue.Set(ActiveKeyValue.None, permission, true);
            Assert.True(ActiveKeyValue.Allows(enabled, permission));
            Assert.Equal(1, enabled.Count(character => character == '1'));

            var disabled = ActiveKeyValue.Set(enabled, permission, false);
            Assert.Equal(ActiveKeyValue.None, disabled);
        }
    }

    [Fact]
    public void Set_ActiveKeyKhongHopLe_ThrowArgumentException()
    {
        Assert.Throws<ArgumentException>(() =>
            ActiveKeyValue.Set("invalid", ActiveKeyPermission.View, true));
    }
}
