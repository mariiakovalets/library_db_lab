using LibraryLab.Api.Models;
using Npgsql;

namespace LibraryLab.Api.Data.Repositories;

public interface IBookCopyRepository
{
    Task<IEnumerable<AvailableCopy>> GetAvailableAsync(int bookId);
    Task<AvailableCopy?> FindFirstAvailableAsync(int bookId);
    Task<int> AddAsync(int bookId, string inventoryNumber);
}

public sealed class BookCopyRepository(NpgsqlConnection connection, NpgsqlTransaction transaction)
    : RepositoryBase(connection, transaction), IBookCopyRepository
{
    public Task<IEnumerable<AvailableCopy>> GetAvailableAsync(int bookId) =>
        QueryAsync<AvailableCopy>(
            "SELECT * FROM vw_available_copies WHERE book_id = @BookId ORDER BY inventory_number",
            new { BookId = bookId });

    public Task<AvailableCopy?> FindFirstAvailableAsync(int bookId) =>
        QuerySingleOrDefaultAsync<AvailableCopy>(
            "SELECT * FROM vw_available_copies WHERE book_id = @BookId ORDER BY inventory_number LIMIT 1",
            new { BookId = bookId });

    public Task<int> AddAsync(int bookId, string inventoryNumber) =>
        CallReturningIdAsync(
            "CALL sp_add_book_copy(@BookId, @InventoryNumber, NULL)",
            new { BookId = bookId, InventoryNumber = inventoryNumber });
}
