using Microsoft.ApplicationInsights.AspNetCore.Extensions;

var builder = WebApplication.CreateBuilder(args);

// Add services to the container.
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();

// Add Application Insights
builder.Services.AddApplicationInsightsTelemetry(new ApplicationInsightsServiceOptions
{
    ConnectionString = builder.Configuration["ApplicationInsights:ConnectionString"]
});

// Add logging
builder.Services.AddLogging(logging =>
{
    logging.AddConsole();
    logging.AddApplicationInsights();
});

// Add health checks
builder.Services.AddHealthChecks();

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

// Endpoint 1: Product Information Endpoint (Latency Simulation)
app.MapGet("/products/{id}", async (int id, int? delayMs, HttpContext httpContext, ILogger<Program> logger) =>
{
    var correlationId = httpContext.Items["CorrelationId"]?.ToString();
    logger.LogInformation("Product endpoint called with id: {ProductId}, delayMs: {DelayMs}, correlationId: {CorrelationId}", 
        id, delayMs ?? 0, correlationId);
    
    if (delayMs.HasValue && delayMs.Value > 0)
    {
        logger.LogInformation("Simulating delay of {DelayMs} milliseconds", delayMs.Value);
        await Task.Delay(delayMs.Value);
    }
    
    var product = new
    {
        productId = id,
        name = $"Product {id}",
        description = $"Description for product {id}",
        price = 99.99 + id,
        inStock = true
    };
    
    logger.LogInformation("Returning product: {ProductId}", id);
    return Results.Ok(product);
})
.WithName("GetProduct")
.WithOpenApi()
.Produces(StatusCodes.Status200OK);

// Endpoint 2: Order Creation Endpoint (Error Simulation)
app.MapPost("/orders", (string? failureMode, HttpContext httpContext, ILogger<Program> logger) =>
{
    var correlationId = httpContext.Items["CorrelationId"]?.ToString();
    logger.LogInformation("Order endpoint called with failureMode: {FailureMode}, correlationId: {CorrelationId}", 
        failureMode ?? "none", correlationId);
    
    failureMode = failureMode?.ToLower() ?? "none";
    
    switch (failureMode)
    {
        case "transient":
            // 50% chance of failure
            if (Random.Shared.Next(0, 2) == 0)
            {
                logger.LogWarning("Simulating transient failure for order creation");
                return Results.StatusCode(StatusCodes.Status503ServiceUnavailable);
            }
            break;
            
        case "persistent":
            logger.LogError("Simulating persistent failure for order creation");
            throw new InvalidOperationException("Persistent failure: Unable to process order due to system error");
            
        case "none":
        default:
            break;
    }
    
    var order = new
    {
        orderId = Guid.NewGuid(),
        status = "Created",
        createdAt = DateTime.UtcNow,
        totalAmount = 199.99
    };
    
    logger.LogInformation("Order created successfully: {OrderId}", order.orderId);
    return Results.Created($"/orders/{order.orderId}", order);
})
.WithName("CreateOrder")
.WithOpenApi()
.Produces(StatusCodes.Status201Created)
.Produces(StatusCodes.Status503ServiceUnavailable)
.Produces(StatusCodes.Status500InternalServerError);

// Endpoint 3: CPU Pressure Endpoint
app.MapGet("/pressure/cpu", (int? iterations, ILogger<Program> logger) =>
{
    var iterationCount = iterations ?? 1000000;
    logger.LogInformation("CPU pressure endpoint called with iterations: {Iterations}", iterationCount);
    
    var startTime = DateTime.UtcNow;
    double result = 0;
    
    // CPU-intensive computation
    for (int i = 0; i < iterationCount; i++)
    {
        result += Math.Sqrt(i) * Math.Sin(i) * Math.Cos(i);
    }
    
    var duration = DateTime.UtcNow - startTime;
    logger.LogInformation("CPU pressure completed in {Duration} ms", duration.TotalMilliseconds);
    
    return Results.Ok(new
    {
        message = "CPU pressure simulation completed",
        iterations = iterationCount,
        durationMs = duration.TotalMilliseconds,
        result = result
    });
})
.WithName("SimulateCPUPressure")
.WithOpenApi()
.Produces(StatusCodes.Status200OK);

// Endpoint 4: Memory Pressure Endpoint
app.MapGet("/pressure/memory", async (int? mbToAllocate, ILogger<Program> logger) =>
{
    var megabytes = mbToAllocate ?? 100;
    logger.LogInformation("Memory pressure endpoint called with mbToAllocate: {MbToAllocate}", megabytes);
    
    // Allocate memory
    var bytesToAllocate = megabytes * 1024 * 1024;
    var data = new byte[bytesToAllocate];
    
    // Fill with random data to ensure memory is actually allocated
    Random.Shared.NextBytes(data.AsSpan(0, Math.Min(1024, bytesToAllocate)));
    
    logger.LogInformation("Allocated {MbToAllocate} MB of memory, holding for 5 seconds", megabytes);
    
    // Hold memory for 5-10 seconds
    await Task.Delay(5000);
    
    // Clear reference to allow garbage collection
    data = null;
    GC.Collect();
    GC.WaitForPendingFinalizers();
    GC.Collect();
    
    logger.LogInformation("Released {MbToAllocate} MB of memory", megabytes);
    
    return Results.Ok(new
    {
        message = "Memory pressure simulation completed",
        mbAllocated = megabytes,
        status = "Memory allocated and released"
    });
})
.WithName("SimulateMemoryPressure")
.WithOpenApi()
.Produces(StatusCodes.Status200OK);

app.Run();

// Make Program class accessible for testing
public partial class Program { }