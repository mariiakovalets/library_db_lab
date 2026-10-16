using LibraryLab.Api.Models;
using Npgsql;

namespace LibraryLab.Api.Data.Repositories;

public interface IReaderRepository
{
    Task<IEnumerable<ReaderBalance>> GetAllAsync();
    Task<ReaderBalance?> GetByIdAsync(int id);
    Task<bool> CanBorrowAsync(int id);
    Task<int> CreateAsync(CreateReaderRequest reader);
    Task SoftDeleteAsync(int id);
    Task<int> BuyMembershipAsync(int readerId, int planId, string paymentMethod);
}

public sealed class ReaderRepository(NpgsqlConnection connection, NpgsqlTransaction transaction)
    : RepositoryBase(connection, transaction), IReaderRepository
{
    public Task<IEnumerable<ReaderBalance>> GetAllAsync() =>
        QueryAsync<ReaderBalance>("SELECT * FROM vw_reader_balance ORDER BY full_name");

    public Task<ReaderBalance?> GetByIdAsync(int id) =>
        QuerySingleOrDefaultAsync<ReaderBalance>("SELECT * FROM vw_reader_balance WHERE reader_id = @Id", new { Id = id });

    public async Task<bool> CanBorrowAsync(int id) =>
        await ScalarAsync<bool>("SELECT fn_reader_can_borrow(@Id)", new { Id = id });

    public Task<int> CreateAsync(CreateReaderRequest reader) =>
        CallReturningIdAsync(
            "CALL sp_create_reader(@LibraryCardNumber, @FullName, @Email, @Phone, @BirthDate::date, NULL)",
            new
            {
                reader.LibraryCardNumber,
                reader.FullName,
                reader.Email,
                reader.Phone,
                BirthDate = reader.BirthDate?.ToDateTime(TimeOnly.MinValue)
            });

    public Task SoftDeleteAsync(int id) =>
        ExecuteAsync("CALL sp_soft_delete_reader(@Id)", new { Id = id });

    public Task<int> BuyMembershipAsync(int readerId, int planId, string paymentMethod) =>
        CallReturningIdAsync(
            "CALL sp_buy_membership(@ReaderId, @PlanId, @PaymentMethod, NULL)",
            new { ReaderId = readerId, PlanId = planId, PaymentMethod = paymentMethod });
}
