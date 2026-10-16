using LibraryLab.Api.Models;
using LibraryLab.Api.Services;
using Microsoft.AspNetCore.Mvc;

namespace LibraryLab.Api.Controllers;

[Route("api/readers")]
public class ReadersController(LibraryService library) : ApiControllerBase
{
    /// <summary>Readers with membership, books on hand and debt (vw_reader_balance).</summary>
    [HttpGet]
    public Task<IEnumerable<ReaderBalance>> GetAll() => library.GetReadersAsync();

    [HttpGet("{id:int}")]
    public async Task<ActionResult<ReaderBalance>> Get(int id) =>
        await library.GetReaderAsync(id) is { } reader ? reader : NotFound();

    /// <summary>sp_create_reader</summary>
    [HttpPost]
    public async Task<ActionResult<ReaderBalance>> Create(CreateReaderRequest request)
    {
        var reader = await library.CreateReaderAsync(StaffId, request);
        return CreatedAtAction(nameof(Get), new { id = reader.ReaderId }, reader);
    }

    /// <summary>Soft delete (sp_soft_delete_reader). Refused while the reader holds books or owes fines.</summary>
    [HttpDelete("{id:int}")]
    public async Task<IActionResult> Delete(int id)
    {
        await library.DeleteReaderAsync(StaffId, id);
        return NoContent();
    }

    /// <summary>Sells a membership and records the payment (sp_buy_membership). Plans: 1 student, 2 standard, 3 premium.</summary>
    [HttpPost("{id:int}/memberships")]
    public Task<ReaderBalance> BuyMembership(int id, BuyMembershipRequest request) =>
        library.BuyMembershipAsync(StaffId, id, request);

    /// <summary>Reserves a book for 3 days (sp_reserve_book).</summary>
    [HttpPost("{id:int}/reservations")]
    public async Task<ActionResult<object>> Reserve(int id, ReserveBookRequest request) =>
        new { reservationId = await library.ReserveBookAsync(StaffId, id, request) };
}
