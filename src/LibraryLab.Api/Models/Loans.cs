namespace LibraryLab.Api.Models;

/// <summary>Row of vw_active_loans.</summary>
public class ActiveLoan
{
    public int LoanId { get; set; }
    public int ReaderId { get; set; }
    public string ReaderName { get; set; } = "";
    public string LibraryCardNumber { get; set; } = "";
    public int CopyId { get; set; }
    public string InventoryNumber { get; set; } = "";
    public int BookId { get; set; }
    public string Title { get; set; } = "";
    public DateTime IssuedAt { get; set; }
    public DateTime DueDate { get; set; }
    public int DaysLeft { get; set; }
}

/// <summary>Row of vw_overdue_loans.</summary>
public class OverdueLoan
{
    public int LoanId { get; set; }
    public int ReaderId { get; set; }
    public string ReaderName { get; set; } = "";
    public string LibraryCardNumber { get; set; } = "";
    public string InventoryNumber { get; set; } = "";
    public string Title { get; set; } = "";
    public DateTime IssuedAt { get; set; }
    public DateTime DueDate { get; set; }
    public int DaysOverdue { get; set; }
    public decimal ExpectedFine { get; set; }
}

public class IssueLoanRequest
{
    public int ReaderId { get; init; }
    public int BookId { get; init; }
}

public class ReturnLoanRequest
{
    /// <summary>Pay the fine at the desk right away, in the same transaction as the return.</summary>
    public bool PayFineNow { get; init; }
    /// <summary>cash or card</summary>
    public string PaymentMethod { get; init; } = "cash";
}

public record ReturnLoanResult(int LoanId, int? FineId, decimal FineAmount, int? PaymentId);
