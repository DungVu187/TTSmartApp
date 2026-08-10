namespace TTSmart.Api.Common.Exceptions;

public sealed class ServiceUnavailableException(string message, Exception? innerException = null)
    : Exception(message, innerException);
