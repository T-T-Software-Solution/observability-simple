using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Extensions.Configuration;
using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using Xunit;

namespace ObservabilityTests;

public class DownstreamApiTests : IClassFixture<WebApplicationFactory<Program>>
{
    private readonly WebApplicationFactory<Program> _factory;
    private readonly HttpClient _client;

    public DownstreamApiTests(WebApplicationFactory<Program> factory)
    {
        _factory = factory.WithWebHostBuilder(builder =>
        {
            builder.ConfigureAppConfiguration((context, config) =>
            {
                config.AddInMemoryCollection(new Dictionary<string, string?>
                {
                    ["ApplicationInsights:ConnectionString"] = "",
                    ["Logging:LogLevel:Microsoft.ApplicationInsights"] = "None"
                });
            });
        });
        _client = _factory.CreateClient();
    }

    [Fact]
    public async Task HealthCheck_ReturnsHealthy()
    {
        // Act
        var response = await _client.GetAsync("/health");
        var content = await response.Content.ReadAsStringAsync();

        // Assert
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        Assert.Equal("Healthy", content);
    }

    [Fact]
    public async Task GetProduct_WithValidId_ReturnsProduct()
    {
        // Arrange
        var productId = 123;

        // Act
        var response = await _client.GetAsync($"/products/{productId}");
        var content = await response.Content.ReadAsStringAsync();

        // Assert
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        
        var product = JsonSerializer.Deserialize<JsonElement>(content);
        Assert.Equal(productId, product.GetProperty("productId").GetInt32());
        Assert.Equal($"Product {productId}", product.GetProperty("name").GetString());
    }

    [Fact]
    public async Task GetProduct_WithDelay_TakesExpectedTime()
    {
        // Arrange
        var productId = 456;
        var delayMs = 500;
        var startTime = DateTime.UtcNow;

        // Act
        var response = await _client.GetAsync($"/products/{productId}?delayMs={delayMs}");
        var endTime = DateTime.UtcNow;
        var actualDelay = (endTime - startTime).TotalMilliseconds;

        // Assert
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        Assert.True(actualDelay >= delayMs, $"Expected delay >= {delayMs}ms, actual: {actualDelay}ms");
    }

    [Fact]
    public async Task CreateOrder_WithNoFailure_ReturnsCreated()
    {
        // Act
        var response = await _client.PostAsync("/orders", null);
        var content = await response.Content.ReadAsStringAsync();

        // Assert
        Assert.Equal(HttpStatusCode.Created, response.StatusCode);
        
        var order = JsonSerializer.Deserialize<JsonElement>(content);
        Assert.True(order.TryGetProperty("orderId", out var orderIdProperty));
        Assert.True(Guid.TryParse(orderIdProperty.GetString(), out _));
        Assert.Equal("Created", order.GetProperty("status").GetString());
    }

    [Fact]
    public async Task CreateOrder_WithPersistentFailure_ReturnsInternalServerError()
    {
        // Act
        var response = await _client.PostAsync("/orders?failureMode=persistent", null);

        // Assert
        Assert.Equal(HttpStatusCode.InternalServerError, response.StatusCode);
    }

    [Theory]
    [InlineData(10)]
    [InlineData(50)]
    public async Task CreateOrder_WithTransientFailure_ReturnsVariedResults(int attempts)
    {
        // Arrange
        var successCount = 0;
        var failureCount = 0;

        // Act
        for (int i = 0; i < attempts; i++)
        {
            var response = await _client.PostAsync("/orders?failureMode=transient", null);
            
            if (response.StatusCode == HttpStatusCode.Created)
                successCount++;
            else if (response.StatusCode == HttpStatusCode.ServiceUnavailable)
                failureCount++;
        }

        // Assert
        Assert.True(successCount > 0, "Expected some successes with transient failure mode");
        Assert.True(failureCount > 0, "Expected some failures with transient failure mode");
        Assert.Equal(attempts, successCount + failureCount);
    }

    [Fact]
    public async Task CpuPressure_WithIterations_ReturnsResult()
    {
        // Arrange
        var iterations = 100000;

        // Act
        var response = await _client.GetAsync($"/pressure/cpu?iterations={iterations}");
        var content = await response.Content.ReadAsStringAsync();

        // Assert
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        
        var result = JsonSerializer.Deserialize<JsonElement>(content);
        Assert.Equal("CPU pressure simulation completed", result.GetProperty("message").GetString());
        Assert.Equal(iterations, result.GetProperty("iterations").GetInt32());
        Assert.True(result.GetProperty("durationMs").GetDouble() > 0);
    }

    [Fact]
    public async Task MemoryPressure_WithMbToAllocate_ReturnsResult()
    {
        // Arrange
        var mbToAllocate = 10;

        // Act
        var response = await _client.GetAsync($"/pressure/memory?mbToAllocate={mbToAllocate}");
        var content = await response.Content.ReadAsStringAsync();

        // Assert
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        
        var result = JsonSerializer.Deserialize<JsonElement>(content);
        Assert.Equal("Memory pressure simulation completed", result.GetProperty("message").GetString());
        Assert.Equal(mbToAllocate, result.GetProperty("mbAllocated").GetInt32());
    }

    [Fact]
    public async Task CorrelationId_IsPreservedInResponse()
    {
        // Arrange
        var correlationId = "test-correlation-123";
        var request = new HttpRequestMessage(HttpMethod.Get, "/products/777");
        request.Headers.Add("X-Correlation-ID", correlationId);

        // Act
        var response = await _client.SendAsync(request);

        // Assert
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        Assert.True(response.Headers.Contains("X-Correlation-ID"));
        Assert.Equal(correlationId, response.Headers.GetValues("X-Correlation-ID").First());
    }
}