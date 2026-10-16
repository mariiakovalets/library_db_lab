using LibraryLab.Api.Models;
using LibraryLab.Api.Services;
using Microsoft.AspNetCore.Mvc;

namespace LibraryLab.Api.Controllers;

/// <summary>Additional services: printing, scanning, reading room, interlibrary loan, consultations.</summary>
[Route("api/extra-services")]
public class ExtraServicesController(LibraryService library) : ApiControllerBase
{
    /// <summary>vw_service_catalog</summary>
    [HttpGet]
    public Task<IEnumerable<ServiceCatalogItem>> GetCatalog() => library.GetServiceCatalogAsync();

    /// <summary>vw_service_orders</summary>
    [HttpGet("orders")]
    public Task<IEnumerable<ServiceOrderItem>> GetOrders([FromQuery] int? readerId) => library.GetServiceOrdersAsync(readerId);

    /// <summary>Orders a service (sp_order_service) and, with payNow, pays for it (sp_pay_service_order) in one transaction.</summary>
    [HttpPost("orders")]
    public Task<ServiceOrderItem> Order(OrderServiceRequest request) => library.OrderServiceAsync(StaffId, request);

    /// <summary>sp_pay_service_order</summary>
    [HttpPost("orders/{id:int}/pay")]
    public Task<ServiceOrderItem> Pay(int id, PayRequest request) => library.PayServiceOrderAsync(StaffId, id, request);
}
