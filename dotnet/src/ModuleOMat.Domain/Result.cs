namespace ModuleOMat.Domain;

public readonly record struct Unit
{
    public static readonly Unit Value = default;
}

public readonly struct Result<T>
{
    private readonly T? _value;
    private readonly AppError? _error;

    private Result(T value)
    {
        IsOk = true;
        _value = value;
        _error = null;
    }

    private Result(AppError error)
    {
        IsOk = false;
        _value = default;
        _error = error;
    }

    public bool IsOk { get; }
    public bool IsError => !IsOk;
    public T Value => IsOk ? _value! : throw new InvalidOperationException("Result is an error.");
    public AppError Error => IsError ? _error! : throw new InvalidOperationException("Result is ok.");

    public static Result<T> Ok(T value) => new(value);
    public static Result<T> Fail(AppError error) => new(error);

    public Result<TNext> Map<TNext>(Func<T, TNext> map) =>
        IsOk ? Result<TNext>.Ok(map(Value)) : Result<TNext>.Fail(Error);

    public async Task<Result<TNext>> Bind<TNext>(Func<T, Task<Result<TNext>>> bind) =>
        IsOk ? await bind(Value).ConfigureAwait(false) : Result<TNext>.Fail(Error);
}

public static class Result
{
    public static Result<Unit> Ok() => Result<Unit>.Ok(Unit.Value);
    public static Result<T> Ok<T>(T value) => Result<T>.Ok(value);
    public static Result<T> Fail<T>(AppError error) => Result<T>.Fail(error);
    public static Result<Unit> Fail(AppError error) => Result<Unit>.Fail(error);
}
