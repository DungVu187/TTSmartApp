namespace TTSmart.Api.Features.Authorization;

public static class ManagementFunctionCodes
{
    public const string Users = "QLND";
    public const string Roles = "QLQ";
    public const string Functions = "QLCN";
    public const string Companies = "QLCT";
    public const string Branches = "QLTT";

    public static bool IsReserved(string code) =>
        code is Users or Roles or Functions or Companies or Branches;
}
