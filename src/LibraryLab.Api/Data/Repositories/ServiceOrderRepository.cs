using LibraryLab.Api.Models;
using Npgsql;

namespace LibraryLab.Api.Data.Repositories;

public interface IServiceOrderRepository
{
    Task<IEnumerable<ServiceCatalogItem>> GetCatalogAsync();
    Task<IEnumerable<ServiceOrderItem>> GetOrdersAsync(int? readerId = null);
    Task<ServiceOrderItem?> GetOrderAsync(int orderId);
    Task<int> CreateAsync(int readerId, int serviceId, int quantity, DateTimeOffset? scheduledAt);
}

public sealed class ServiceOrderRepository(NpgsqlConnection connection, NpgsqlTransaction transaction)
    : RepositoryBase(connection, transaction), IServiceOrderRepository
{
    public Task<IEnumerable<ServiceCatalogItem>> GetCatalogAsync() =>
        QueryAsync<ServiceCatalogItem>("SELECT * FROM vw_service_catalog ORDER BY name");

    public Task<IEnumerable<ServiceOrderItem>> GetOrdersAsync(int? readerId = null) =>
        QueryAsync<ServiceOrderItem>(
            "SELECT * FROM vw_service_orders WHERE @ReaderId::int IS NULL OR reader_id = @ReaderId ORDER BY created_at DESC",
            new { ReaderId = readerId });

    public Task<ServiceOrderItem?> GetOrderAsync(int orderId) =>
        QuerySingleOrDefaultAsync<ServiceOrderItem>("SELECT * FROM vw_service_orders WHERE order_id = @OrderId", new { OrderId = orderId });

    public Task<int> CreateAsync(int readerId, int serviceId, int quantity, DateTimeOffset? scheduledAt) =>
        CallReturningIdAsync(
            "CALL sp_order_service(@ReaderId, @ServiceId, @Quantity, @ScheduledAt, NULL)",
            new
            {
                ReaderId = readerId,
                ServiceId = serviceId,
                Quantity = quantity,
                // PostgreSQL timestamptz accepts only UTC values from Npgsql
                ScheduledAt = scheduledAt?.ToUniversalTime()
            });
}
