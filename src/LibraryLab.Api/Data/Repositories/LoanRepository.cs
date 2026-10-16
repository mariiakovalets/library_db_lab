using LibraryLab.Api.Models;
using Npgsql;

namespace LibraryLab.Api.Data.Repositories;

public interface ILoanRepository
{
    Task<IEnumerable<ActiveLoan>> GetActiveAsync(int? readerId = null);
    Task<ActiveLoan?> GetActiveByIdAsync(int loanId);
    Task<IEnumerable<OverdueLoan>> GetOverdueAsync();
    Task<decimal> CalculateFineAsync(int loanId);
    Task<int> IssueAsync(int readerId, int copyId);

    /// <returns>Id of the fine created for a late return, or null.</returns>
    Task<int?> ReturnAsync(int loanId);
}

public sealed class LoanRepository(NpgsqlConnection connection, NpgsqlTransaction transaction)
    : RepositoryBase(connection, transaction), ILoanRepository
{
    public Task<IEnumerable<ActiveLoan>> GetActiveAsync(int? readerId = null) =>
        QueryAsync<ActiveLoan>(
            "SELECT * FROM vw_active_loans WHERE @ReaderId::int IS NULL OR reader_id = @ReaderId ORDER BY due_date",
            new { ReaderId = readerId });

    public Task<ActiveLoan?> GetActiveByIdAsync(int loanId) =>
        QuerySingleOrDefaultAsync<ActiveLoan>("SELECT * FROM vw_active_loans WHERE loan_id = @LoanId", new { LoanId = loanId });

    public Task<IEnumerable<OverdueLoan>> GetOverdueAsync() =>
        QueryAsync<OverdueLoan>("SELECT * FROM vw_overdue_loans ORDER BY days_overdue DESC");

    public async Task<decimal> CalculateFineAsync(int loanId) =>
        await ScalarAsync<decimal>("SELECT fn_calculate_fine(@LoanId)", new { LoanId = loanId });

    public Task<int> IssueAsync(int readerId, int copyId) =>
        CallReturningIdAsync(
            "CALL sp_issue_loan(@ReaderId, @CopyId, NULL)",
            new { ReaderId = readerId, CopyId = copyId });

    public Task<int?> ReturnAsync(int loanId) =>
        ScalarAsync<int?>("CALL sp_return_loan(@LoanId, NULL)", new { LoanId = loanId });
}
