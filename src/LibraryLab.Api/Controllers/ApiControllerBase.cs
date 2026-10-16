using Microsoft.AspNetCore.Mvc;

namespace LibraryLab.Api.Controllers;

[ApiController]
[Produces("application/json")]
public abstract class ApiControllerBase : ControllerBase
{
    public const string StaffHeader = "X-Staff-Id";

    // librarian Іван Мельник from the seed data
    private const int DefaultStaffId = 2;

    /// <summary>
    /// Staff user who makes the change, from the X-Staff-Id header.
    /// There is no login in this lab, so the header stands in for the signed-in librarian.
    /// </summary>
    protected int StaffId =>
        Request.Headers.TryGetValue(StaffHeader, out var value) && int.TryParse(value, out var id)
            ? id
            : DefaultStaffId;
}
