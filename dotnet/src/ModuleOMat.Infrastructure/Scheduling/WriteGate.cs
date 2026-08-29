using ModuleOMat.Domain;
using ModuleOMat.Domain.Ports;

namespace ModuleOMat.Infrastructure.Scheduling;

public sealed class WriteGate : IMaintenanceGate
{
    private readonly object _sync = new();
    private int _inFlightWrites;
    private bool _maintenance;
    private bool _running;
    private Action? _onChange;

    public bool IsMaintenance
    {
        get
        {
            lock (_sync)
            {
                return _maintenance || _running;
            }
        }
    }

    public bool HasInFlightWrites
    {
        get
        {
            lock (_sync)
            {
                return _inFlightWrites > 0;
            }
        }
    }

    public void SetChangeHandler(Action onChange) => _onChange = onChange;

    public Result<Unit> BeginWrite()
    {
        lock (_sync)
        {
            if (_maintenance || _running)
            {
                return Result.Fail(AppError.Maintenance());
            }

            _inFlightWrites++;
            return Result.Ok();
        }
    }

    public void EndWrite()
    {
        lock (_sync)
        {
            _inFlightWrites = Math.Max(_inFlightWrites - 1, 0);
        }
    }

    public void ScheduleAfterChange() => _onChange?.Invoke();

    public void SetMaintenance(bool value)
    {
        lock (_sync)
        {
            _maintenance = value;
        }
    }

    public void SetRunning(bool value)
    {
        lock (_sync)
        {
            _running = value;
        }
    }
}

public sealed class SystemClock : IClock
{
    public DateTime UtcNow => DateTime.UtcNow;
    public DateOnly UtcToday => DateOnly.FromDateTime(DateTime.UtcNow);
}
