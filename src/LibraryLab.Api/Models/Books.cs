using System.ComponentModel.DataAnnotations;

namespace LibraryLab.Api.Models;

/// <summary>Row of vw_book_catalog.</summary>
public class BookCatalogItem
{
    public int Id { get; set; }
    public string Isbn { get; set; } = "";
    public string Title { get; set; } = "";
    public int? PublishYear { get; set; }
    public int? PagesCount { get; set; }
    public int PublisherId { get; set; }
    public string Publisher { get; set; } = "";
    public int GenreId { get; set; }
    public string Genre { get; set; } = "";
    public string Authors { get; set; } = "";
    public int TotalCopies { get; set; }
    public int AvailableCopies { get; set; }
    public DateTime? UpdatedAt { get; set; }
    public int? UpdatedBy { get; set; }
}

/// <summary>Row of fn_search_books.</summary>
public class BookSearchResult
{
    public int BookId { get; set; }
    public string Isbn { get; set; } = "";
    public string Title { get; set; } = "";
    public string Authors { get; set; } = "";
    public int AvailableCopies { get; set; }
    public float Rank { get; set; }
}

/// <summary>Row of vw_available_copies.</summary>
public class AvailableCopy
{
    public int CopyId { get; set; }
    public string InventoryNumber { get; set; } = "";
    public int BookId { get; set; }
    public string Title { get; set; } = "";
    public string Isbn { get; set; } = "";
}

public class CreateBookRequest
{
    [Required, StringLength(17)] public string Isbn { get; init; } = "";
    [Required, StringLength(255)] public string Title { get; init; } = "";
    public int PublisherId { get; init; }
    public int GenreId { get; init; }
    public int? PublishYear { get; init; }
    public int? PagesCount { get; init; }
    [MinLength(1)] public int[] AuthorIds { get; init; } = [];

    /// <summary>Inventory numbers of copies to put on the shelf right away. Can be empty.</summary>
    public string[] InventoryNumbers { get; init; } = [];
}

public class UpdateBookRequest
{
    [Required, StringLength(255)] public string Title { get; init; } = "";
    public int PublisherId { get; init; }
    public int GenreId { get; init; }
    public int? PublishYear { get; init; }
    public int? PagesCount { get; init; }
}

public class AddCopyRequest
{
    [Required, StringLength(20)] public string InventoryNumber { get; init; } = "";
}
