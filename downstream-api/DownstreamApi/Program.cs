using Microsoft.ApplicationInsights.AspNetCore.Extensions;

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

// Add health checks
builder.Services.AddHealthChecks();

// Add configuration for advanced exercises
builder.Services.AddSingleton<BugSimulation>();

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
// Enable Swagger for all environments
app.UseSwagger();
app.UseSwaggerUI(c =>
{
    c.SwaggerEndpoint("/swagger/v1/swagger.json", "Downstream API V1");
    c.RoutePrefix = "swagger";
});

// Map health check endpoints
app.MapHealthChecks("/health");
app.MapHealthChecks("/health/ready");
app.MapHealthChecks("/health/live");

// Endpoint 1: Product Information Endpoint (Latency Simulation)
app.MapGet("/products/{id}", async (int id, int? delayMs, HttpContext httpContext, ILogger<Program> logger, BugSimulation bugSim) =>
{
    var correlationId = httpContext.Items["CorrelationId"]?.ToString();
    logger.LogInformation("Product endpoint called with id: {ProductId}, delayMs: {DelayMs}, correlationId: {CorrelationId}", 
        id, delayMs ?? 0, correlationId);
    
    // ADVANCED EXERCISE BUG 1: Hardcoded performance degradation for "unlucky" product IDs
    if (bugSim.IsHardcodedIdBugEnabled && bugSim.IsUnluckyProductId(id))
    {
        logger.LogInformation("Product {ProductId} triggering special processing path", id);
        await Task.Delay(3000); // Hidden 3-second delay for specific IDs
    }
    
    // ADVANCED EXERCISE BUG 3: Memory leak for prime number IDs
    if (bugSim.IsMemoryLeakBugEnabled && bugSim.IsPrime(id))
    {
        bugSim.LeakMemoryForId(id);
        logger.LogDebug("Processing prime product {ProductId}", id);
    }
    
    // ADVANCED EXERCISE BUG 6: CPU spike for palindrome IDs
    if (bugSim.IsCpuSpikeBugEnabled)
    {
        bugSim.ConsumeCpuForPalindrome(id, logger);
    }
    
    if (delayMs.HasValue && delayMs.Value > 0)
    {
        logger.LogInformation("Simulating delay of {DelayMs} milliseconds", delayMs.Value);
        await Task.Delay(delayMs.Value);
    }
    
    // ADVANCED EXERCISE BUG 5: Cache poisoning for ID 0 or negative
    if (bugSim.IsCachePoisoningBugEnabled && id <= 0)
    {
        bugSim.PoisonCache();
        logger.LogWarning("Processing special product ID: {ProductId}", id);
    }
    
    var product = new
    {
        productId = id,
        name = bugSim.IsCachePoisoned ? "CORRUPTED_DATA" : $"Product {id}",
        description = bugSim.IsCachePoisoned ? "CACHE_ERROR" : $"Description for product {id}",
        price = bugSim.IsCachePoisoned ? -1 : 99.99 + id,
        inStock = !bugSim.IsCachePoisoned
    };
    
    logger.LogInformation("Returning product: {ProductId}", id);
    return Results.Ok(product);
})
.WithName("GetProduct")
.WithOpenApi()
.Produces(StatusCodes.Status200OK);

// Endpoint 2: Order Creation Endpoint (Error Simulation)
app.MapPost("/orders", (string? failureMode, int? orderId, HttpContext httpContext, ILogger<Program> logger, BugSimulation bugSim) =>
{
    var correlationId = httpContext.Items["CorrelationId"]?.ToString();
    var actualOrderId = orderId ?? Random.Shared.Next(1, 10000);
    
    logger.LogInformation("Order endpoint called with failureMode: {FailureMode}, orderId: {OrderId}, correlationId: {CorrelationId}", 
        failureMode ?? "none", actualOrderId, correlationId);
    
    // ADVANCED EXERCISE BUG 2: Order range processing bug (1000-1099 fail 90% of the time)
    if (bugSim.IsOrderRangeBugEnabled && actualOrderId >= 1000 && actualOrderId <= 1099)
    {
        if (Random.Shared.Next(0, 10) < 9) // 90% failure rate
        {
            logger.LogError("Order processing failed for order {OrderId} - Database constraint violation", actualOrderId);
            throw new InvalidOperationException($"Order {actualOrderId} violates business rule BR-1099");
        }
    }
    
    // ADVANCED EXERCISE BUG 4: Thread pool exhaustion - every 10th request
    if (bugSim.IsThreadPoolBugEnabled)
    {
        bugSim.IncrementRequestCount();
        if (bugSim.ShouldExhaustThreadPool())
        {
            logger.LogDebug("Request {RequestNumber} triggering extended processing", bugSim.RequestCount);
            Thread.Sleep(5000); // Block thread for 5 seconds
        }
    }
    
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
        orderId = actualOrderId,
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

// Bug Simulation Service for Advanced Exercises
public class BugSimulation
{
    private readonly IConfiguration _configuration;
    private readonly Dictionary<int, byte[]> _memoryLeaks = new();
    private bool _cacheCorrupted = false;
    private int _requestCount = 0;
    private readonly object _lock = new();
    
    // Unlucky product IDs that trigger performance issues
    private readonly HashSet<int> _unluckyIds = new() { 13, 42, 99, 666, 1337, 2024, 9999 };
    
    public BugSimulation(IConfiguration configuration)
    {
        _configuration = configuration;
    }
    
    // Feature flags for different bugs (controlled via environment variables)
    public bool IsHardcodedIdBugEnabled => _configuration.GetValue<bool>("ADVANCED_BUG_HARDCODED_ID", false);
    public bool IsOrderRangeBugEnabled => _configuration.GetValue<bool>("ADVANCED_BUG_ORDER_RANGE", false);
    public bool IsMemoryLeakBugEnabled => _configuration.GetValue<bool>("ADVANCED_BUG_MEMORY_LEAK", false);
    public bool IsThreadPoolBugEnabled => _configuration.GetValue<bool>("ADVANCED_BUG_THREAD_POOL", false);
    public bool IsCachePoisoningBugEnabled => _configuration.GetValue<bool>("ADVANCED_BUG_CACHE_POISON", false);
    public bool IsCpuSpikeBugEnabled => _configuration.GetValue<bool>("ADVANCED_BUG_CPU_SPIKE", false);
    
    public int RequestCount => _requestCount;
    public bool IsCachePoisoned => _cacheCorrupted;
    
    public bool IsUnluckyProductId(int id)
    {
        return _unluckyIds.Contains(id);
    }
    
    public bool IsPrime(int n)
    {
        if (n <= 1) return false;
        if (n <= 3) return true;
        if (n % 2 == 0 || n % 3 == 0) return false;
        
        for (int i = 5; i * i <= n; i += 6)
        {
            if (n % i == 0 || n % (i + 2) == 0)
                return false;
        }
        return true;
    }
    
    public void LeakMemoryForId(int id)
    {
        lock (_lock)
        {
            if (!_memoryLeaks.ContainsKey(id))
            {
                // Leak 5MB per unique prime ID
                _memoryLeaks[id] = new byte[5 * 1024 * 1024];
                Random.Shared.NextBytes(_memoryLeaks[id].AsSpan(0, 1024));
            }
        }
    }
    
    public void IncrementRequestCount()
    {
        lock (_lock)
        {
            _requestCount++;
        }
    }
    
    public bool ShouldExhaustThreadPool()
    {
        return _requestCount % 10 == 0;
    }
    
    public void PoisonCache()
    {
        _cacheCorrupted = true;
        // Cache stays poisoned for 30 seconds
        Task.Delay(30000).ContinueWith(_ => 
        {
            lock (_lock)
            {
                _cacheCorrupted = false;
            }
        });
    }
    
    public bool IsPalindrome(int n)
    {
        string str = n.ToString();
        int left = 0;
        int right = str.Length - 1;
        
        while (left < right)
        {
            if (str[left] != str[right])
                return false;
            left++;
            right--;
        }
        return true;
    }
    
    public void ConsumeCpuForPalindrome(int id, ILogger logger)
    {
        if (IsPalindrome(id))
        {
            logger.LogWarning("CPU-intensive operation triggered for palindrome ID: {ProductId}", id);
            
            // Consume CPU with intensive calculation
            var startTime = DateTime.UtcNow;
            double result = 0;
            
            // Perform 50 million iterations of complex math
            for (int i = 0; i < 50_000_000; i++)
            {
                result += Math.Sqrt(i) * Math.Sin(i) * Math.Cos(i);
                
                // Add some string operations to stress CPU further
                if (i % 1000000 == 0)
                {
                    _ = $"Processing iteration {i} for palindrome {id}".GetHashCode();
                }
            }
            
            var duration = (DateTime.UtcNow - startTime).TotalMilliseconds;
            logger.LogWarning("CPU spike completed for palindrome {ProductId} in {Duration}ms", id, duration);
        }
    }
}