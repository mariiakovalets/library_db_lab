using System.ComponentModel.DataAnnotations;

namespace LibraryLab.Api.Models;

/// <summary>Row of vw_reader_balance.</summary>
public class ReaderBalance
{
    public int ReaderId { get; set; }
    public string LibraryCardNumber { get; set; } = "";
    public string FullName { get; set; } = "";
    public string? Email { get; set; }
    public string? Phone { get; set; }
    public string? PlanName { get; set; }
    public DateTime? MembershipEndDate { get; set; }
    public int ActiveLoans { get; set; }
    public decimal UnpaidFines { get; set; }
    public bool CanBorrow { get; set; }
    public DateTime? UpdatedAt { get; set; }
    public int? UpdatedBy { get; set; }
}

public class CreateReaderRequest
{
    [Required, StringLength(20)] public string LibraryCardNumber { get; init; } = "";
    [Required, StringLength(255)] public string FullName { get; init; } = "";
    [EmailAddress] public string? Email { get; init; }
    [StringLength(20)] public string? Phone { get; init; }
    public DateOnly? BirthDate { get; init; }
}

public class BuyMembershipRequest
{
    public int PlanId { get; init; }
    /// <summary>cash or card</summary>
    [Required] public string PaymentMethod { get; init; } = "card";
}

public class ReserveBookRequest
{
    public int BookId { get; init; }
}
