using LibraryLab.Api.Models;
using LibraryLab.Api.Services;
using Microsoft.AspNetCore.Mvc;

namespace LibraryLab.Api.Controllers;

[Route("api/loans")]
public class LoansController(LibraryService library) : ApiControllerBase
{
    /// <summary>Books that readers hold now (vw_active_loans).</summary>
    [HttpGet("active")]
    public Task<IEnumerable<ActiveLoan>> GetActive([FromQuery] int? readerId) => library.GetActiveLoansAsync(readerId);

    /// <summary>Overdue loans with the expected fine (vw_overdue_loans).</summary>
    [HttpGet("overdue")]
    public Task<IEnumerable<OverdueLoan>> GetOverdue() => library.GetOverdueLoansAsync();

    /// <summary>
    /// Issues a book: fn_reader_can_borrow, a free copy from vw_available_copies,
    /// sp_issue_loan and sp_fulfill_reservation in one transaction.
    /// </summary>
    [HttpPost]
    public Task<ActiveLoan> Issue(IssueLoanRequest request) => library.IssueBookAsync(StaffId, request);

    /// <summary>
    /// Returns a book (sp_return_loan) and, with payFineNow, pays the fine (sp_pay_fine) in the same transaction.
    /// Try paymentMethod "bitcoin" on an overdue loan: the payment fails and the return is rolled back.
    /// </summary>
    [HttpPost("{id:int}/return")]
    public Task<ReturnLoanResult> Return(int id, ReturnLoanRequest request) => library.ReturnBookAsync(StaffId, id, request);
}
