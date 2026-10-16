using Dapper;
using LibraryLab.Api.Data.Repositories;
using Npgsql;

namespace LibraryLab.Api.Data;

public sealed class UnitOfWork : IUnitOfWork
{
    private readonly NpgsqlConnection _connection;
    private readonly NpgsqlTransaction _transaction;
    private bool _isCompleted;

    // repositories are created on first use and all share the same connection and transaction
    private IBookRepository? _books;
    private IBookCopyRepository? _copies;
    private IReaderRepository? _readers;
    private ILoanRepository? _loans;
    private IReservationRepository? _reservations;
    private IPaymentRepository? _payments;
    private IServiceOrderRepository? _serviceOrders;

    private UnitOfWork(NpgsqlConnection connection, NpgsqlTransaction transaction)
    {
        _connection = connection;
        _transaction = transaction;
    }

    public IBookRepository Books => _books ??= new BookRepository(_connection, _transaction);
    public IBookCopyRepository Copies => _copies ??= new BookCopyRepository(_connection, _transaction);
    public IReaderRepository Readers => _readers ??= new ReaderRepository(_connection, _transaction);
    public ILoanRepository Loans => _loans ??= new LoanRepository(_connection, _transaction);
    public IReservationRepository Reservations => _reservations ??= new ReservationRepository(_connection, _transaction);
    public IPaymentRepository Payments => _payments ??= new PaymentRepository(_connection, _transaction);
    public IServiceOrderRepository ServiceOrders => _serviceOrders ??= new ServiceOrderRepository(_connection, _transaction);

    /// <summary>
    /// Opens a connection, starts a transaction and tells the database which staff user works in it.
    /// Triggers write this user into updated_by, procedures use it for issued_by and received_by.
    /// </summary>
    public static async Task<UnitOfWork> BeginAsync(NpgsqlDataSource dataSource, int? staffId, CancellationToken ct = default)
    {
        var connection = await dataSource.OpenConnectionAsync(ct);
        var transaction = await connection.BeginTransactionAsync(ct);

        if (staffId is not null)
        {
            // is_local = true: the setting lives only until this transaction ends
            await connection.ExecuteAsync(
                "SELECT set_config('app.current_user_id', @StaffId, true)",
                new { StaffId = staffId.Value.ToString() },
                transaction);
        }

        return new UnitOfWork(connection, transaction);
    }

    public async Task CommitAsync(CancellationToken ct = default)
    {
        await _transaction.CommitAsync(ct);
        _isCompleted = true;
    }

    public async Task RollbackAsync(CancellationToken ct = default)
    {
        if (_isCompleted)
        {
            return;
        }

        await _transaction.RollbackAsync(ct);
        _isCompleted = true;
    }

    public async ValueTask DisposeAsync()
    {
        // a unit of work that was not committed is rolled back, so a failed step leaves no partial changes
        await RollbackAsync();
        await _transaction.DisposeAsync();
        await _connection.DisposeAsync();
    }
}
