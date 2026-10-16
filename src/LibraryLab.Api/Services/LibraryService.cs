using LibraryLab.Api.Data;
using LibraryLab.Api.Models;

namespace LibraryLab.Api.Services;

/// <summary>A rule of the library was broken. The API answers 400 with the message.</summary>
public class BusinessRuleException(string message) : Exception(message);

/// <summary>
/// Library operations. Each method opens one unit of work. Methods that touch several repositories
/// commit only when every step succeeds; if a step throws, the unit of work is disposed without
/// a commit and the database rolls back all steps of that method.
/// </summary>
public class LibraryService(IUnitOfWorkFactory unitOfWorkFactory)
{
    // Reads (views and functions)

    public async Task<IEnumerable<BookCatalogItem>> GetCatalogAsync()
    {
        await using var uow = await unitOfWorkFactory.BeginAsync();
        return await uow.Books.GetCatalogAsync();
    }

    public async Task<BookCatalogItem?> GetBookAsync(int id)
    {
        await using var uow = await unitOfWorkFactory.BeginAsync();
        return await uow.Books.GetByIdAsync(id);
    }

    public async Task<IEnumerable<BookSearchResult>> SearchBooksAsync(string query)
    {
        await using var uow = await unitOfWorkFactory.BeginAsync();
        return await uow.Books.SearchAsync(query);
    }

    public async Task<IEnumerable<AvailableCopy>> GetAvailableCopiesAsync(int bookId)
    {
        await using var uow = await unitOfWorkFactory.BeginAsync();
        return await uow.Copies.GetAvailableAsync(bookId);
    }

    public async Task<IEnumerable<ReaderBalance>> GetReadersAsync()
    {
        await using var uow = await unitOfWorkFactory.BeginAsync();
        return await uow.Readers.GetAllAsync();
    }

    public async Task<ReaderBalance?> GetReaderAsync(int id)
    {
        await using var uow = await unitOfWorkFactory.BeginAsync();
        return await uow.Readers.GetByIdAsync(id);
    }

    public async Task<IEnumerable<ActiveLoan>> GetActiveLoansAsync(int? readerId)
    {
        await using var uow = await unitOfWorkFactory.BeginAsync();
        return await uow.Loans.GetActiveAsync(readerId);
    }

    public async Task<IEnumerable<OverdueLoan>> GetOverdueLoansAsync()
    {
        await using var uow = await unitOfWorkFactory.BeginAsync();
        return await uow.Loans.GetOverdueAsync();
    }

    public async Task<IEnumerable<ServiceCatalogItem>> GetServiceCatalogAsync()
    {
        await using var uow = await unitOfWorkFactory.BeginAsync();
        return await uow.ServiceOrders.GetCatalogAsync();
    }

    public async Task<IEnumerable<ServiceOrderItem>> GetServiceOrdersAsync(int? readerId)
    {
        await using var uow = await unitOfWorkFactory.BeginAsync();
        return await uow.ServiceOrders.GetOrdersAsync(readerId);
    }

    // Scenarios over several repositories in one transaction

    /// <summary>
    /// Creates a book and puts its copies on the shelf (Books + Copies).
    /// If one inventory number is taken, the book is not created either.
    /// </summary>
    public async Task<BookCatalogItem> CreateBookAsync(int staffId, CreateBookRequest request)
    {
        await using var uow = await unitOfWorkFactory.BeginAsync(staffId);

        var bookId = await uow.Books.CreateAsync(request);
        foreach (var inventoryNumber in request.InventoryNumbers)
        {
            await uow.Copies.AddAsync(bookId, inventoryNumber);
        }

        var book = await uow.Books.GetByIdAsync(bookId);
        await uow.CommitAsync();
        return book!;
    }

    /// <summary>
    /// Issues a book (Readers + Copies + Loans + Reservations): checks the reader,
    /// picks a free copy, creates the loan and closes the reader's reservation of this book.
    /// </summary>
    public async Task<ActiveLoan> IssueBookAsync(int staffId, IssueLoanRequest request)
    {
        await using var uow = await unitOfWorkFactory.BeginAsync(staffId);

        if (!await uow.Readers.CanBorrowAsync(request.ReaderId))
        {
            throw new BusinessRuleException(
                $"Reader {request.ReaderId} cannot borrow: needs a valid membership, a free slot under the plan limit, no overdue books and no unpaid fines");
        }

        var copy = await uow.Copies.FindFirstAvailableAsync(request.BookId)
            ?? throw new BusinessRuleException($"Book {request.BookId} has no copies on the shelf");

        var loanId = await uow.Loans.IssueAsync(request.ReaderId, copy.CopyId);
        await uow.Reservations.FulfillAsync(request.ReaderId, request.BookId);

        var loan = await uow.Loans.GetActiveByIdAsync(loanId);
        await uow.CommitAsync();
        return loan!;
    }

    /// <summary>
    /// Returns a book and, if asked, takes payment for the fine at once (Loans + Payments).
    /// If the payment fails (for example, a wrong payment method), the return is rolled back too.
    /// </summary>
    public async Task<ReturnLoanResult> ReturnBookAsync(int staffId, int loanId, ReturnLoanRequest request)
    {
        await using var uow = await unitOfWorkFactory.BeginAsync(staffId);

        var fineId = await uow.Loans.ReturnAsync(loanId);
        var fineAmount = await uow.Loans.CalculateFineAsync(loanId);

        int? paymentId = null;
        if (fineId is not null && request.PayFineNow)
        {
            paymentId = await uow.Payments.PayFineAsync(fineId.Value, request.PaymentMethod);
        }

        await uow.CommitAsync();
        return new ReturnLoanResult(loanId, fineId, fineAmount, paymentId);
    }

    /// <summary>Orders an additional service and, if asked, takes payment at once (ServiceOrders + Payments).</summary>
    public async Task<ServiceOrderItem> OrderServiceAsync(int staffId, OrderServiceRequest request)
    {
        await using var uow = await unitOfWorkFactory.BeginAsync(staffId);

        var orderId = await uow.ServiceOrders.CreateAsync(request.ReaderId, request.ServiceId, request.Quantity, request.ScheduledAt);
        if (request.PayNow)
        {
            await uow.Payments.PayServiceOrderAsync(orderId, request.PaymentMethod);
        }

        var order = await uow.ServiceOrders.GetOrderAsync(orderId);
        await uow.CommitAsync();
        return order!;
    }

    // Single-step changes

    public async Task<BookCatalogItem> UpdateBookAsync(int staffId, int id, UpdateBookRequest request)
    {
        await using var uow = await unitOfWorkFactory.BeginAsync(staffId);
        await uow.Books.UpdateAsync(id, request);
        var book = await uow.Books.GetByIdAsync(id);
        await uow.CommitAsync();
        return book!;
    }

    public async Task DeleteBookAsync(int staffId, int id)
    {
        await using var uow = await unitOfWorkFactory.BeginAsync(staffId);
        await uow.Books.SoftDeleteAsync(id);
        await uow.CommitAsync();
    }

    public async Task<int> AddCopyAsync(int staffId, int bookId, AddCopyRequest request)
    {
        await using var uow = await unitOfWorkFactory.BeginAsync(staffId);
        var copyId = await uow.Copies.AddAsync(bookId, request.InventoryNumber);
        await uow.CommitAsync();
        return copyId;
    }

    public async Task<ReaderBalance> CreateReaderAsync(int staffId, CreateReaderRequest request)
    {
        await using var uow = await unitOfWorkFactory.BeginAsync(staffId);
        var readerId = await uow.Readers.CreateAsync(request);
        var reader = await uow.Readers.GetByIdAsync(readerId);
        await uow.CommitAsync();
        return reader!;
    }

    public async Task DeleteReaderAsync(int staffId, int id)
    {
        await using var uow = await unitOfWorkFactory.BeginAsync(staffId);
        await uow.Readers.SoftDeleteAsync(id);
        await uow.CommitAsync();
    }

    public async Task<ReaderBalance> BuyMembershipAsync(int staffId, int readerId, BuyMembershipRequest request)
    {
        await using var uow = await unitOfWorkFactory.BeginAsync(staffId);
        await uow.Readers.BuyMembershipAsync(readerId, request.PlanId, request.PaymentMethod);
        var reader = await uow.Readers.GetByIdAsync(readerId);
        await uow.CommitAsync();
        return reader!;
    }

    public async Task<int> ReserveBookAsync(int staffId, int readerId, ReserveBookRequest request)
    {
        await using var uow = await unitOfWorkFactory.BeginAsync(staffId);
        var reservationId = await uow.Reservations.ReserveAsync(readerId, request.BookId);
        await uow.CommitAsync();
        return reservationId;
    }

    public async Task<ServiceOrderItem> PayServiceOrderAsync(int staffId, int orderId, PayRequest request)
    {
        await using var uow = await unitOfWorkFactory.BeginAsync(staffId);
        await uow.Payments.PayServiceOrderAsync(orderId, request.PaymentMethod);
        var order = await uow.ServiceOrders.GetOrderAsync(orderId);
        await uow.CommitAsync();
        return order!;
    }
}
