using LibraryLab.Api.Services;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Filters;
using Npgsql;

namespace LibraryLab.Api;

/// <summary>
/// Expected errors become 400 with a readable message: library rules from <see cref="LibraryService"/>
/// and errors raised in PostgreSQL (RAISE EXCEPTION in procedures, CHECK, UNIQUE, foreign keys).
/// </summary>
public class ApiExceptionFilter : IExceptionFilter
{
    public void OnException(ExceptionContext context)
    {
        var message = context.Exception switch
        {
            BusinessRuleException rule => rule.Message,
            PostgresException pg => pg.MessageText,
            _ => null
        };

        if (message is null)
        {
            return;
        }

        context.Result = new BadRequestObjectResult(new { error = message });
        context.ExceptionHandled = true;
    }
}
