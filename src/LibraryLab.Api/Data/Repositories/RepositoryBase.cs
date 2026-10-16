using Dapper;
using Npgsql;

namespace LibraryLab.Api.Data.Repositories;

/// <summary>
/// Common code for repositories. Every query runs on the unit of work's connection and transaction.
/// Repositories read from views and functions and write through stored procedures only.
/// </summary>
public abstract class RepositoryBase(NpgsqlConnection connection, NpgsqlTransaction transaction)
{
    protected Task<IEnumerable<T>> QueryAsync<T>(string sql, object? param = null) =>
        connection.QueryAsync<T>(sql, param, transaction);

    protected Task<T?> QuerySingleOrDefaultAsync<T>(string sql, object? param = null) =>
        connection.QuerySingleOrDefaultAsync<T>(sql, param, transaction);

    protected Task<T?> ScalarAsync<T>(string sql, object? param = null) =>
        connection.ExecuteScalarAsync<T>(sql, param, transaction);

    protected Task ExecuteAsync(string sql, object? param = null) =>
        connection.ExecuteAsync(sql, param, transaction);

    /// <summary>
    /// Runs CALL for a procedure whose last INOUT parameter returns the id of the new row.
    /// </summary>
    protected async Task<int> CallReturningIdAsync(string sql, object? param = null) =>
        await connection.ExecuteScalarAsync<int?>(sql, param, transaction)
        ?? throw new InvalidOperationException($"Procedure returned no id: {sql}");
}
