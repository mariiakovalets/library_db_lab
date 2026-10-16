using Npgsql;

namespace LibraryLab.Api.Data.Repositories;

public interface IPaymentRepository
{
    Task<int> PayFineAsync(int fineId, string paymentMethod);
    Task<int> PayServiceOrderAsync(int orderId, string paymentMethod);
}

public sealed class PaymentRepository(NpgsqlConnection connection, NpgsqlTransaction transaction)
    : RepositoryBase(connection, transaction), IPaymentRepository
{
    public Task<int> PayFineAsync(int fineId, string paymentMethod) =>
        CallReturningIdAsync(
            "CALL sp_pay_fine(@FineId, @PaymentMethod, NULL)",
            new { FineId = fineId, PaymentMethod = paymentMethod });

    public Task<int> PayServiceOrderAsync(int orderId, string paymentMethod) =>
        CallReturningIdAsync(
            "CALL sp_pay_service_order(@OrderId, @PaymentMethod, NULL)",
            new { OrderId = orderId, PaymentMethod = paymentMethod });
}
