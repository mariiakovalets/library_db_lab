using Npgsql;

namespace LibraryLab.Api.Data;

public interface IUnitOfWorkFactory
{
    /// <summary>Starts a unit of work. <c>staffId</c> is the staff user who makes the changes, null for read-only work.</summary>
    Task<IUnitOfWork> BeginAsync(int? staffId = null, CancellationToken ct = default);
}

public sealed class UnitOfWorkFactory(NpgsqlDataSource dataSource) : IUnitOfWorkFactory
{
    public async Task<IUnitOfWork> BeginAsync(int? staffId = null, CancellationToken ct = default) =>
        await UnitOfWork.BeginAsync(dataSource, staffId, ct);
}
