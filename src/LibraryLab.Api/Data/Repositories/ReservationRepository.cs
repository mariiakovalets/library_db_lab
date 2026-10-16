using Npgsql;

namespace LibraryLab.Api.Data.Repositories;

public interface IReservationRepository
{
    Task<int> ReserveAsync(int readerId, int bookId);
    Task FulfillAsync(int readerId, int bookId);
}

public sealed class ReservationRepository(NpgsqlConnection connection, NpgsqlTransaction transaction)
    : RepositoryBase(connection, transaction), IReservationRepository
{
    public Task<int> ReserveAsync(int readerId, int bookId) =>
        CallReturningIdAsync(
            "CALL sp_reserve_book(@ReaderId, @BookId, NULL)",
            new { ReaderId = readerId, BookId = bookId });

    public Task FulfillAsync(int readerId, int bookId) =>
        ExecuteAsync(
            "CALL sp_fulfill_reservation(@ReaderId, @BookId)",
            new { ReaderId = readerId, BookId = bookId });
}
