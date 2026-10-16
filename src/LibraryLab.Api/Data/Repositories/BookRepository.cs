using LibraryLab.Api.Models;
using Npgsql;

namespace LibraryLab.Api.Data.Repositories;

public interface IBookRepository
{
    Task<IEnumerable<BookCatalogItem>> GetCatalogAsync();
    Task<BookCatalogItem?> GetByIdAsync(int id);
    Task<IEnumerable<BookSearchResult>> SearchAsync(string query);
    Task<int> CreateAsync(CreateBookRequest book);
    Task UpdateAsync(int id, UpdateBookRequest book);
    Task SoftDeleteAsync(int id);
}

public sealed class BookRepository(NpgsqlConnection connection, NpgsqlTransaction transaction)
    : RepositoryBase(connection, transaction), IBookRepository
{
    public Task<IEnumerable<BookCatalogItem>> GetCatalogAsync() =>
        QueryAsync<BookCatalogItem>("SELECT * FROM vw_book_catalog ORDER BY title");

    public Task<BookCatalogItem?> GetByIdAsync(int id) =>
        QuerySingleOrDefaultAsync<BookCatalogItem>("SELECT * FROM vw_book_catalog WHERE id = @Id", new { Id = id });

    public Task<IEnumerable<BookSearchResult>> SearchAsync(string query) =>
        QueryAsync<BookSearchResult>("SELECT * FROM fn_search_books(@Query)", new { Query = query });

    public Task<int> CreateAsync(CreateBookRequest book) =>
        CallReturningIdAsync(
            "CALL sp_create_book(@Isbn, @Title, @PublisherId, @GenreId, @PublishYear, @PagesCount, @AuthorIds, NULL)",
            new { book.Isbn, book.Title, book.PublisherId, book.GenreId, book.PublishYear, book.PagesCount, book.AuthorIds });

    public Task UpdateAsync(int id, UpdateBookRequest book) =>
        ExecuteAsync(
            "CALL sp_update_book(@Id, @Title, @PublisherId, @GenreId, @PublishYear, @PagesCount)",
            new { Id = id, book.Title, book.PublisherId, book.GenreId, book.PublishYear, book.PagesCount });

    public Task SoftDeleteAsync(int id) =>
        ExecuteAsync("CALL sp_soft_delete_book(@Id)", new { Id = id });
}
