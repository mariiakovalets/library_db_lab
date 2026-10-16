using LibraryLab.Api.Data.Repositories;

namespace LibraryLab.Api.Data;

/// <summary>
/// One database transaction shared by all repositories.
/// Changes made through any repository are saved together by <see cref="CommitAsync"/>
/// or discarded together by <see cref="RollbackAsync"/> (or by disposing without a commit).
/// </summary>
public interface IUnitOfWork : IAsyncDisposable
{
    IBookRepository Books { get; }
    IBookCopyRepository Copies { get; }
    IReaderRepository Readers { get; }
    ILoanRepository Loans { get; }
    IReservationRepository Reservations { get; }
    IPaymentRepository Payments { get; }
    IServiceOrderRepository ServiceOrders { get; }

    Task CommitAsync(CancellationToken ct = default);
    Task RollbackAsync(CancellationToken ct = default);
}
