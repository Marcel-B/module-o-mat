namespace ModuleOMat.Domain;

public enum ErrorKind
{
    NotFound,
    Validation,
    FallbackType,
    Maintenance,
    EmptyObservations,
    InvalidCurrentValue,
    Unprocessable
}

public sealed record AppError(
    ErrorKind Kind,
    string Message,
    IReadOnlyDictionary<string, object>? Details = null)
{
    public static AppError NotFound(string message) =>
        new(ErrorKind.NotFound, message);

    public static AppError Validation(IReadOnlyDictionary<string, object> details) =>
        new(ErrorKind.Validation, "Validierung fehlgeschlagen", details);

    public static AppError FallbackType() =>
        new(
            ErrorKind.FallbackType,
            $"Der Typ \"{TypeRules.FallbackTypeName}\" kann nicht umbenannt oder geloescht werden.");

    public static AppError Maintenance() =>
        new(ErrorKind.Maintenance, "Datensicherung laeuft. Bitte warte einen Moment.");

    public static AppError EmptyObservations() =>
        new(ErrorKind.EmptyObservations, "observations darf nicht leer sein");

    public static AppError InvalidCurrentValue() =>
        new(ErrorKind.InvalidCurrentValue, "current_value ist ungueltig");

    public static AppError Unprocessable(string message) =>
        new(ErrorKind.Unprocessable, message);
}
