using LibraryLab.Api.Controllers;
using Microsoft.OpenApi;
using Swashbuckle.AspNetCore.SwaggerGen;

namespace LibraryLab.Api;

/// <summary>Shows the X-Staff-Id header field in Swagger for requests that change data.</summary>
public class StaffHeaderOperationFilter : IOperationFilter
{
    public void Apply(OpenApiOperation operation, OperationFilterContext context)
    {
        if (context.ApiDescription.HttpMethod is "GET")
        {
            return;
        }

        operation.Parameters ??= [];
        operation.Parameters.Add(new OpenApiParameter
        {
            Name = ApiControllerBase.StaffHeader,
            In = ParameterLocation.Header,
            Required = false,
            Description = "Staff user who makes the change: 1 admin, 2 or 3 librarian. Default 2.",
            Schema = new OpenApiSchema { Type = JsonSchemaType.Integer }
        });
    }
}
