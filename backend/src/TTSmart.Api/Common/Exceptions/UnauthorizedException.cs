namespace TTSmart.Api.Common.Exceptions;

public sealed class UnauthorizedException(string message) : Exception(message);
