using System.ComponentModel.DataAnnotations;

namespace LibraryLab.Api.Models;

/// <summary>Row of vw_service_catalog.</summary>
public class ServiceCatalogItem
{
    public int Id { get; set; }
    public string Name { get; set; } = "";
    public string? Description { get; set; }
    public decimal Price { get; set; }
    public string Unit { get; set; } = "";
    public bool RequiresSchedule { get; set; }
}

/// <summary>Row of vw_service_orders.</summary>
public class ServiceOrderItem
{
    public int OrderId { get; set; }
    public int ReaderId { get; set; }
    public string ReaderName { get; set; } = "";
    public int ServiceId { get; set; }
    public string ServiceName { get; set; } = "";
    public int Quantity { get; set; }
    public string Unit { get; set; } = "";
    public decimal TotalPrice { get; set; }
    public DateTime? ScheduledAt { get; set; }
    public string Status { get; set; } = "";
    public bool IsPaid { get; set; }
    public DateTime CreatedAt { get; set; }
}

public class OrderServiceRequest
{
    public int ReaderId { get; init; }
    public int ServiceId { get; init; }
    [Range(1, 1000)] public int Quantity { get; init; } = 1;
    /// <summary>Required for the reading room and consultations, for example 2026-10-20T10:00:00+03:00.</summary>
    public DateTimeOffset? ScheduledAt { get; init; }
    /// <summary>Pay at the desk right away, in the same transaction as the order.</summary>
    public bool PayNow { get; init; }
    /// <summary>cash or card</summary>
    public string PaymentMethod { get; init; } = "cash";
}

public class PayRequest
{
    /// <summary>cash or card</summary>
    [Required] public string PaymentMethod { get; init; } = "cash";
}
