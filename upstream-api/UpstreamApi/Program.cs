using Microsoft.ApplicationInsights.AspNetCore.Extensions;
using Microsoft.Extensions.Diagnostics.HealthChecks;
using System.Text.Json;

var builder = WebApplication.CreateBuilder(args);

// Add services to the container.
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();

// Add Application Insights (automatically picks up APPLICATIONINSIGHTS_CONNECTION_STRING)
builder.Services.AddApplicationInsightsTelemetry();

// Add logging
builder.Services.AddLogging(logging =>
{
    logging.AddConsole();
    logging.AddApplicationInsights();
});

// Add HttpClient for downstream API calls
builder.Services.AddHttpClient("DownstreamApi", client =>
{
    var baseUrl = builder.Configuration["DownstreamApi:BaseUrl"] ?? "http://localhost:5001";
    client.BaseAddress = new Uri(baseUrl);
    client.DefaultRequestHeaders.Add("Accept", "application/json");
});

// Add health checks with downstream API check
builder.Services.AddHealthChecks()
    .AddTypeActivatedCheck<DownstreamHealthCheck>("downstream_api");

var app = builder.Build();

// Add correlation ID middleware
app.Use(async (context, next) =>
{
    var correlationId = context.Request.Headers["X-Correlation-ID"].FirstOrDefault();
    if (string.IsNullOrEmpty(correlationId))
    {
        correlationId = Guid.NewGuid().ToString();
    }
    
    context.Items["CorrelationId"] = correlationId;
    context.Response.Headers.Append("X-Correlation-ID", correlationId);
    
    using (var scope = app.Services.CreateScope())
    {
        var logger = scope.ServiceProvider.GetRequiredService<ILogger<Program>>();
        using (logger.BeginScope(new Dictionary<string, object> { ["CorrelationId"] = correlationId }))
        {
            await next();
        }
    }
});

// Configure the HTTP request pipeline.
if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

// Map health check endpoints
app.MapHealthChecks("/health");
app.MapHealthChecks("/health/ready");
app.MapHealthChecks("/health/live");

// Gateway Product Endpoint
app.MapGet("/gateway/products/{id}", async (int id, int? delayMs, HttpContext httpContext, IHttpClientFactory httpClientFactory, ILogger<Program> logger) =>
{
    var correlationId = httpContext.Items["CorrelationId"]?.ToString();
    logger.LogInformation("Gateway product endpoint called with id: {ProductId}, delayMs: {DelayMs}, correlationId: {CorrelationId}", 
        id, delayMs ?? 0, correlationId);
    
    try
    {
        var client = httpClientFactory.CreateClient("DownstreamApi");
        
        // Add correlation ID header for downstream call
        if (!string.IsNullOrEmpty(correlationId))
        {
            client.DefaultRequestHeaders.Remove("X-Correlation-ID");
            client.DefaultRequestHeaders.Add("X-Correlation-ID", correlationId);
        }
        
        // Build query string
        var queryString = delayMs.HasValue ? $"?delayMs={delayMs}" : "";
        var requestUri = $"/products/{id}{queryString}";
        
        logger.LogInformation("Calling downstream API at: {RequestUri} with correlationId: {CorrelationId}", requestUri, correlationId);
        
        var response = await client.GetAsync(requestUri);
        
        if (response.IsSuccessStatusCode)
        {
            var content = await response.Content.ReadAsStringAsync();
            logger.LogInformation("Successfully retrieved product {ProductId} from downstream API", id);
            
            // Parse and return the JSON
            var product = JsonSerializer.Deserialize<JsonElement>(content);
            return Results.Ok(product);
        }
        else
        {
            logger.LogError("Downstream API returned error status: {StatusCode} for product {ProductId}", response.StatusCode, id);
            return Results.StatusCode(StatusCodes.Status502BadGateway);
        }
    }
    catch (HttpRequestException ex)
    {
        logger.LogError(ex, "Network error calling downstream API for product {ProductId}", id);
        return Results.StatusCode(StatusCodes.Status502BadGateway);
    }
    catch (TaskCanceledException ex)
    {
        logger.LogError(ex, "Timeout calling downstream API for product {ProductId}", id);
        return Results.StatusCode(StatusCodes.Status502BadGateway);
    }
    catch (Exception ex)
    {
        logger.LogError(ex, "Unexpected error calling downstream API for product {ProductId}", id);
        return Results.StatusCode(StatusCodes.Status502BadGateway);
    }
})
.WithName("GetGatewayProduct")
.WithOpenApi()
.Produces(StatusCodes.Status200OK)
.Produces(StatusCodes.Status502BadGateway);

// Gateway Order Endpoint
app.MapPost("/gateway/orders", async (string? failureMode, HttpContext httpContext, IHttpClientFactory httpClientFactory, ILogger<Program> logger) =>
{
    var correlationId = httpContext.Items["CorrelationId"]?.ToString();
    logger.LogInformation("Gateway order endpoint called with failureMode: {FailureMode}, correlationId: {CorrelationId}", 
        failureMode ?? "none", correlationId);
    
    try
    {
        var client = httpClientFactory.CreateClient("DownstreamApi");
        
        // Add correlation ID header for downstream call
        if (!string.IsNullOrEmpty(correlationId))
        {
            client.DefaultRequestHeaders.Remove("X-Correlation-ID");
            client.DefaultRequestHeaders.Add("X-Correlation-ID", correlationId);
        }
        
        // Build query string
        var queryString = !string.IsNullOrEmpty(failureMode) ? $"?failureMode={failureMode}" : "";
        var requestUri = $"/orders{queryString}";
        
        logger.LogInformation("Calling downstream API at: {RequestUri} with correlationId: {CorrelationId}", requestUri, correlationId);
        
        var response = await client.PostAsync(requestUri, null);
        
        if (response.IsSuccessStatusCode)
        {
            var content = await response.Content.ReadAsStringAsync();
            logger.LogInformation("Successfully created order via downstream API");
            
            // Parse and return the JSON
            var order = JsonSerializer.Deserialize<JsonElement>(content);
            return Results.Created($"/gateway/orders/{order.GetProperty("orderId")}", order);
        }
        else
        {
            logger.LogError("Downstream API returned error status: {StatusCode} for order creation with failureMode: {FailureMode}", 
                response.StatusCode, failureMode ?? "none");
            
            // Log structured context for the failure
            logger.LogError("Order creation failed - Status: {StatusCode}, FailureMode: {FailureMode}, Timestamp: {Timestamp}", 
                response.StatusCode, failureMode ?? "none", DateTime.UtcNow);
            
            return Results.StatusCode(StatusCodes.Status502BadGateway);
        }
    }
    catch (HttpRequestException ex)
    {
        logger.LogError(ex, "Network error calling downstream API for order creation with failureMode: {FailureMode}", failureMode ?? "none");
        return Results.StatusCode(StatusCodes.Status502BadGateway);
    }
    catch (TaskCanceledException ex)
    {
        logger.LogError(ex, "Timeout calling downstream API for order creation with failureMode: {FailureMode}", failureMode ?? "none");
        return Results.StatusCode(StatusCodes.Status502BadGateway);
    }
    catch (Exception ex)
    {
        logger.LogError(ex, "Unexpected error calling downstream API for order creation with failureMode: {FailureMode}", failureMode ?? "none");
        return Results.StatusCode(StatusCodes.Status502BadGateway);
    }
})
.WithName("CreateGatewayOrder")
.WithOpenApi()
.Produces(StatusCodes.Status201Created)
.Produces(StatusCodes.Status502BadGateway);

app.Run();

// Custom health check for downstream API
public class DownstreamHealthCheck : IHealthCheck
{
    private readonly IHttpClientFactory _httpClientFactory;
    private readonly ILogger<DownstreamHealthCheck> _logger;

    public DownstreamHealthCheck(IHttpClientFactory httpClientFactory, ILogger<DownstreamHealthCheck> logger)
    {
        _httpClientFactory = httpClientFactory;
        _logger = logger;
    }

    public async Task<HealthCheckResult> CheckHealthAsync(HealthCheckContext context, CancellationToken cancellationToken = default)
    {
        try
        {
            var client = _httpClientFactory.CreateClient("DownstreamApi");
            var response = await client.GetAsync("/health", cancellationToken);
            
            if (response.IsSuccessStatusCode)
            {
                _logger.LogInformation("Downstream API health check passed");
                return HealthCheckResult.Healthy("Downstream API is healthy");
            }
            
            _logger.LogWarning("Downstream API health check failed with status: {StatusCode}", response.StatusCode);
            return HealthCheckResult.Unhealthy($"Downstream API returned status code: {response.StatusCode}");
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Downstream API health check failed with exception");
            return HealthCheckResult.Unhealthy("Downstream API is not reachable", ex);
        }
    }
}

// Make Program class accessible for testing
public partial class Program { }