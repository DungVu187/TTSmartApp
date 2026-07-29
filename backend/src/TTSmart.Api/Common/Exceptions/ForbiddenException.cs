namespace TTSmart.Api.Common.Exceptions;

public sealed class ForbiddenException(string message) : Exception(message);
