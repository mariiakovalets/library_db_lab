using LibraryLab.Api.Models;
using LibraryLab.Api.Services;
using Microsoft.AspNetCore.Mvc;

namespace LibraryLab.Api.Controllers;

[Route("api/books")]
public class BooksController(LibraryService library) : ApiControllerBase
{
    /// <summary>Catalog of books (vw_book_catalog).</summary>
    [HttpGet]
    public Task<IEnumerable<BookCatalogItem>> GetCatalog() => library.GetCatalogAsync();

    /// <summary>Full-text search by title (fn_search_books).</summary>
    [HttpGet("search")]
    public Task<IEnumerable<BookSearchResult>> Search([FromQuery] string q) => library.SearchBooksAsync(q);

    [HttpGet("{id:int}")]
    public async Task<ActionResult<BookCatalogItem>> Get(int id) =>
        await library.GetBookAsync(id) is { } book ? book : NotFound();

    /// <summary>Copies on the shelf (vw_available_copies).</summary>
    [HttpGet("{id:int}/available-copies")]
    public Task<IEnumerable<AvailableCopy>> GetAvailableCopies(int id) => library.GetAvailableCopiesAsync(id);

    /// <summary>Creates a book with its copies in one transaction (sp_create_book + sp_add_book_copy).</summary>
    [HttpPost]
    public async Task<ActionResult<BookCatalogItem>> Create(CreateBookRequest request)
    {
        var book = await library.CreateBookAsync(StaffId, request);
        return CreatedAtAction(nameof(Get), new { id = book.Id }, book);
    }

    /// <summary>sp_update_book</summary>
    [HttpPut("{id:int}")]
    public Task<BookCatalogItem> Update(int id, UpdateBookRequest request) => library.UpdateBookAsync(StaffId, id, request);

    /// <summary>Soft delete (sp_soft_delete_book). The row stays in the table with is_deleted = true.</summary>
    [HttpDelete("{id:int}")]
    public async Task<IActionResult> Delete(int id)
    {
        await library.DeleteBookAsync(StaffId, id);
        return NoContent();
    }

    /// <summary>sp_add_book_copy</summary>
    [HttpPost("{id:int}/copies")]
    public async Task<ActionResult<object>> AddCopy(int id, AddCopyRequest request) =>
        new { copyId = await library.AddCopyAsync(StaffId, id, request) };
}
