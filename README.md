# Observability Learning Platform

A microservices-based learning platform designed to demonstrate modern observability practices using Azure Application Insights. This system consists of two .NET 8 Web APIs that simulate real-world performance issues for learning and diagnostics purposes.

## Overview

The platform simulates a distributed system with intentional performance issues to help developers learn:
- **Latency Analysis**: Identify which service causes slowness in a distributed call chain
- **Root Cause Analysis**: Trace errors from user-facing APIs to backend services
- **Resource Monitoring**: Observe CPU and memory usage impacts in real-time
- **Distributed Tracing**: Correlate requests across service boundaries

## Architecture

```
┌─────────────┐         ┌─────────────┐         ┌──────────────────┐
│   Client    │ ──────> │ Upstream API│ ──────> │ Downstream API   │
│             │         │  (Port 5000)│         │   (Port 5001)    │
└─────────────┘         └─────────────┘         └──────────────────┘
                               │                          │
                               └──────────┬───────────────┘
                                          │
                                 ┌────────▼────────┐
                                 │ Azure Application│
                                 │    Insights      │
                                 └─────────────────┘
```

## Prerequisites

### Local Development
- [.NET 8 SDK](https://dotnet.microsoft.com/download/dotnet/8.0)
- Visual Studio 2022 or VS Code (optional)

### Azure Deployment
- Azure subscription
- [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli) installed
- Azure Application Insights resource
- Azure App Service or Azure Container Apps

## Quick Start

1. **Clone the repository**
   ```powershell
   git clone <repository-url>
   cd observability-simple
   ```

2. **Build the solution**
   ```powershell
   dotnet build
   ```

3. **Azure Setup** (For Azure deployment)
   
   Ensure you have Azure CLI installed and login:
   ```powershell
   # Check if Azure CLI is installed
   az --version
   
   # If not installed, install from: https://aka.ms/installazurecliwindows
   
   # Login to Azure
   az login
   ```
   
   This will open a browser window for authentication. After successful login:
   ```powershell
   # Verify you're logged in and check your subscription
   az account show
   
   # If you have multiple subscriptions, list them
   az account list --output table
   
   # Set the correct subscription if needed
   az account set --subscription "your-subscription-name-or-id"
   ```

4. **Deploy to Azure** (Recommended)
   
   Use the PowerShell scripts to deploy to Azure:
   ```powershell
   # Create all Azure resources (one time)
   .\create-azure-resources.ps1
   
   # Deploy applications
   .\deploy-apps-only.ps1
   ```
   
   The scripts will automatically configure Application Insights and all settings.
   
   Update both APIs' `appsettings.json`:
   ```json
   "ApplicationInsights": {
     "ConnectionString": "InstrumentationKey=YOUR_KEY;IngestionEndpoint=https://eastus-8.in.applicationinsights.azure.com/;LiveEndpoint=https://eastus.livediagnostics.monitor.azure.com/"
   }
   ```

5. **Run Locally** (Alternative to Azure deployment)
   
   For local development, run both APIs:
   ```powershell
   # In first PowerShell window - start downstream API
   cd downstream-api/DownstreamApi
   dotnet run
   # API starts on http://localhost:5001
   
   # In second PowerShell window - start upstream API
   cd upstream-api/UpstreamApi  
   dotnet run
   # API starts on http://localhost:5000
   ```

6. **Access Swagger UI**
   - Local Downstream API: http://localhost:5001/swagger
   - Local Upstream API: http://localhost:5000/swagger
   - Azure Upstream API: https://your-upstream-app.azurewebsites.net/swagger

## API Endpoints

### Downstream API (Port 5001)

| Endpoint | Method | Description | Parameters |
|----------|--------|-------------|------------|
| `/products/{id}` | GET | Get product information with optional latency | `id` (path), `delayMs` (query, optional) |
| `/orders` | POST | Create order with failure simulation | `failureMode` (query: none/transient/persistent) |
| `/pressure/cpu` | GET | Simulate CPU-intensive operation | `iterations` (query, optional) |
| `/pressure/memory` | GET | Simulate memory allocation | `mbToAllocate` (query, optional) |

### Upstream API (Port 5000)

| Endpoint | Method | Description | Parameters |
|----------|--------|-------------|------------|
| `/gateway/products/{id}` | GET | Gateway to downstream products endpoint | `id` (path), `delayMs` (query, optional) |
| `/gateway/orders` | POST | Gateway to downstream orders endpoint | `failureMode` (query, optional) |

## Testing Scenarios

### 1. Latency Simulation
Test slow response times:
```powershell
# Normal response
Invoke-RestMethod http://localhost:5001/products/123

# With 2-second delay
Invoke-RestMethod "http://localhost:5001/products/123?delayMs=2000"

# Through gateway with delay
Invoke-RestMethod "http://localhost:5000/gateway/products/456?delayMs=1500"
```

### 2. Error Simulation
Test different failure modes:
```powershell
# Success scenario
Invoke-RestMethod -Uri http://localhost:5001/orders -Method Post

# Transient failure (50% chance)
Invoke-RestMethod -Uri "http://localhost:5001/orders?failureMode=transient" -Method Post

# Persistent failure (100% failure)
Invoke-RestMethod -Uri "http://localhost:5001/orders?failureMode=persistent" -Method Post

# Through gateway
Invoke-RestMethod -Uri "http://localhost:5000/gateway/orders?failureMode=transient" -Method Post
```

### 3. CPU Pressure
Simulate high CPU usage:
```powershell
# Light load
Invoke-RestMethod "http://localhost:5001/pressure/cpu?iterations=100000"

# Heavy load
Invoke-RestMethod "http://localhost:5001/pressure/cpu?iterations=10000000"
```

### 4. Memory Pressure
Simulate memory allocation:
```powershell
# Allocate 50MB
Invoke-RestMethod "http://localhost:5001/pressure/memory?mbToAllocate=50"

# Allocate 200MB
Invoke-RestMethod "http://localhost:5001/pressure/memory?mbToAllocate=200"
```

## Observability Features

### Structured Logging
All endpoints use structured logging with key-value pairs:
- Product operations log: `ProductId`, `DelayMs`
- Order operations log: `FailureMode`, `OrderId`
- CPU pressure logs: `Iterations`, `Duration`
- Memory pressure logs: `MbToAllocate`

### Distributed Tracing
The system supports distributed tracing through:
- Automatic correlation ID propagation between Upstream and Downstream APIs
- Request tracing across service boundaries
- Error correlation from gateway to backend services

### Application Insights Integration
When configured with Azure Application Insights, you can:
- View end-to-end transaction details
- Analyze performance metrics and bottlenecks
- Set up alerts for failures and performance degradation
- Create custom dashboards for monitoring

## Learning Exercises

### Basic Exercises

#### Exercise 1: Identify Latency Source
1. Call `/gateway/products/100?delayMs=3000`
2. Use Application Insights to identify where the delay occurs
3. Verify the delay is in the downstream service

#### Exercise 2: Trace Transient Failures
1. Call `/gateway/orders?failureMode=transient` multiple times
2. Observe the 50% failure rate
3. Trace failed requests through both services
4. Identify the exact failure point and error details

#### Exercise 3: Monitor Resource Usage
1. Generate CPU pressure: `/pressure/cpu?iterations=50000000`
2. Generate memory pressure: `/pressure/memory?mbToAllocate=500`
3. Monitor the impact on service performance
4. Set up alerts for high resource usage

#### Exercise 4: Correlate Distributed Errors
1. Stop the Downstream API
2. Call gateway endpoints
3. Observe 502 Bad Gateway errors
4. Trace the correlation between gateway errors and downstream unavailability

### Advanced Exercises 🔍

**[View Advanced Observability Exercises](./ADVANCED-EXERCISES.md)**

The advanced exercises include hidden production-like bugs that require detective work to identify:
- **The Mysterious Slow Products** - Some products consistently take 3+ seconds to load
- **The Order Processing Anomaly** - Specific order ranges have 90% failure rates
- **The Memory Leak Mystery** - Certain requests cause memory that never gets released
- **The Periodic Performance Problem** - Every few requests freeze for 5 seconds
- **The Cache Corruption Catastrophe** - Invalid inputs corrupt all subsequent responses
- **The CPU Spike Syndrome** - Palindrome IDs cause extreme CPU spikes

Use the cross-platform test data generator to trigger bugs:
```powershell
# Build the test data generator
cd test-data-generator
dotnet build

# Run all tests
dotnet run -- http://localhost:5000 all

# Run specific test type (random, range, prime, load, palindrome, edge)
dotnet run -- http://localhost:5000 palindrome
```

## Configuration

### Application Settings
Both APIs can be configured through `appsettings.json`:

**Downstream API:**
```json
{
  "ApplicationInsights": {
    "ConnectionString": "YOUR_CONNECTION_STRING"
  },
  "Kestrel": {
    "Endpoints": {
      "Http": {
        "Url": "http://localhost:5001"
      }
    }
  }
}
```

**Upstream API:**
```json
{
  "ApplicationInsights": {
    "ConnectionString": "YOUR_CONNECTION_STRING"
  },
  "DownstreamApi": {
    "BaseUrl": "http://localhost:5001"
  },
  "Kestrel": {
    "Endpoints": {
      "Http": {
        "Url": "http://localhost:5000"
      }
    }
  }
}
```

## Troubleshooting

### APIs won't start
- Ensure ports 5000 and 5001 are not in use
- Check that .NET 8 SDK is installed: `dotnet --version`

### Connection refused between services
- Ensure Downstream API is running before testing Upstream API
- Verify the `DownstreamApi:BaseUrl` in Upstream API configuration

### No telemetry in Application Insights
- Verify the connection string is correct
- Check that the Application Insights resource is active
- Allow a few minutes for telemetry to appear

## Project Structure

```
observability-simple/
├── downstream-api/
│   └── DownstreamApi/
│       ├── Program.cs          # All endpoints and configuration
│       ├── appsettings.json    # Configuration
│       └── DownstreamApi.csproj
├── upstream-api/
│   └── UpstreamApi/
│       ├── Program.cs          # Gateway endpoints
│       ├── appsettings.json    # Configuration
│       └── UpstreamApi.csproj
├── test-data-generator/
│   ├── Program.cs              # Cross-platform test data generator
│   └── TestDataGenerator.csproj
├── tests/
│   ├── ObservabilityTests/    # Shared test utilities
│   └── DownstreamApiTests/    # Downstream API unit tests
├── create-azure-resources.ps1  # Create Azure resources script
├── deploy-apps-only.ps1        # Deploy applications script
├── ObservabilitySimple.sln     # Solution file
├── CLAUDE.md                   # Implementation plan
├── README.md                   # This file
└── ADVANCED-EXERCISES.md       # Advanced bug hunting exercises
```

## Azure Deployment

### PowerShell Deployment Scripts

**Step 1: Create Azure Resources (One Time)**
First, create all required Azure resources:

```powershell
# Create all Azure resources (Resource Group, App Service Plan, Web Apps, Application Insights)
.\create-azure-resources.ps1

# Or with custom parameters
.\create-azure-resources.ps1 -ResourceGroup "my-rg" -Location "eastus" -DownstreamAppName "my-downstream" -UpstreamAppName "my-upstream"
```

**Step 2: Deploy Applications (For Updates)**
Deploy the latest code to existing Azure resources:

```powershell
# Deploy apps to existing resources
.\deploy-apps-only.ps1

# Or with custom parameters
.\deploy-apps-only.ps1 -ResourceGroup "observability-rg-west" -DownstreamApp "observability-downstream" -UpstreamApp "observability-upstream"
```

**Complete Workflow:**
```powershell
# 1. Create resources (one time)
.\create-azure-resources.ps1

# 2. Deploy applications
.\deploy-apps-only.ps1

# 3. Test with advanced bugs
cd test-data-generator
dotnet run -- https://observability-upstream.azurewebsites.net all
```

### Manual Azure App Service Deployment

If you prefer to deploy manually, follow these PowerShell steps:

#### Prerequisites
- Azure CLI installed and logged in (`az login`)
- PowerShell 5.1 or PowerShell Core 7+
- Proper Azure subscription permissions

#### Step-by-Step Deployment

1. **Create Resource Group and Application Insights**
   ```powershell
   # Choose a region that supports your subscription quotas
   # Common alternatives: westus2, eastus2, centralus, westeurope
   az group create --name observability-rg-west --location westus2
   
   # Create Application Insights
   az monitor app-insights component create `
     --app observability-insights `
     --location westus2 `
     --resource-group observability-rg-west `
     --application-type web
   ```

2. **Create App Service Plan**
   ```powershell
   # Try F1 (Free) tier first, fallback to B1 if needed
   az appservice plan create `
     --name observability-plan `
     --resource-group observability-rg-west `
     --location westus2 `
     --sku F1
   
   # If F1 fails due to quota, try B1 (requires subscription with compute quota)
   # az appservice plan create `
   #   --name observability-plan `
   #   --resource-group observability-rg-west `
   #   --location westus2 `
   #   --sku B1
   ```

3. **Create Web Apps**
   ```powershell
   # Create downstream API app
   az webapp create `
     --name observability-downstream `
     --resource-group observability-rg-west `
     --plan observability-plan `
     --runtime "dotnet:8"
   
   # Create upstream API app
   az webapp create `
     --name observability-upstream `
     --resource-group observability-rg-west `
     --plan observability-plan `
     --runtime "dotnet:8"
   ```

4. **Configure Application Settings**
   ```powershell
   # Get Application Insights connection string
   $connectionString = az monitor app-insights component show `
     --app observability-insights `
     --resource-group observability-rg-west `
     --query connectionString -o tsv
   
   # Configure Downstream API
   az webapp config appsettings set `
     --name observability-downstream `
     --resource-group observability-rg-west `
     --settings "APPLICATIONINSIGHTS_CONNECTION_STRING=$connectionString"
   
   # Configure Upstream API with downstream URL
   az webapp config appsettings set `
     --name observability-upstream `
     --resource-group observability-rg-west `
     --settings "APPLICATIONINSIGHTS_CONNECTION_STRING=$connectionString" `
                "DownstreamApi__BaseUrl=https://observability-downstream.azurewebsites.net"
   ```

5. **Build and Deploy Applications**
   ```powershell
   # Build downstream API
   dotnet publish downstream-api/DownstreamApi/DownstreamApi.csproj `
     --configuration Release `
     --output ./publish/downstream
   
   # Build upstream API  
   dotnet publish upstream-api/UpstreamApi/UpstreamApi.csproj `
     --configuration Release `
     --output ./publish/upstream
   
   # Create deployment packages
   Compress-Archive -Path 'publish/downstream/*' -DestinationPath 'publish/downstream-api.zip' -Force
   Compress-Archive -Path 'publish/upstream/*' -DestinationPath 'publish/upstream-api.zip' -Force
   
   # Deploy to Azure
   az webapp deploy `
     --name observability-downstream `
     --resource-group observability-rg-west `
     --src-path publish/downstream-api.zip `
     --type zip
   
   az webapp deploy `
     --name observability-upstream `
     --resource-group observability-rg-west `
     --src-path publish/upstream-api.zip `
     --type zip
   ```

6. **Verify Deployment**
   ```powershell
   # Test health endpoints
   Invoke-RestMethod https://observability-downstream.azurewebsites.net/health
   Invoke-RestMethod https://observability-upstream.azurewebsites.net/health
   
   # Test application endpoints
   Invoke-RestMethod "https://observability-upstream.azurewebsites.net/gateway/products/123?delayMs=100"
   
   # Access Swagger UI
   # Navigate to: https://observability-upstream.azurewebsites.net/swagger
   ```

### Testing Azure Deployment

After deploying to Azure, test your endpoints:

```powershell
# Health checks
Invoke-RestMethod https://your-downstream-app.azurewebsites.net/health
Invoke-RestMethod https://your-upstream-app.azurewebsites.net/health

# Product endpoint with latency simulation
Invoke-RestMethod "https://your-upstream-app.azurewebsites.net/gateway/products/123?delayMs=500"

# Order endpoint with failure simulation
Invoke-RestMethod -Uri "https://your-upstream-app.azurewebsites.net/gateway/orders?failureMode=transient" -Method Post

# CPU pressure test
Invoke-RestMethod "https://your-downstream-app.azurewebsites.net/pressure/cpu?iterations=100000"

# Memory pressure test
Invoke-RestMethod "https://your-downstream-app.azurewebsites.net/pressure/memory?mbToAllocate=50"

# Test advanced bugs (if enabled)
cd test-data-generator
dotnet run -- https://your-upstream-app.azurewebsites.net all
```

## Monitoring in Azure

### Application Insights Queries

Access Application Insights in Azure Portal and try these KQL queries:

1. **View All Requests**
   ```kusto
   requests
   | where timestamp > ago(1h)
   | summarize count() by name, resultCode
   | order by count_ desc
   ```

2. **Trace Request Flow**
   ```kusto
   requests
   | where name contains "gateway"
   | join kind=inner (dependencies | where name contains "products" or name contains "orders") on operation_Id
   | project timestamp, request_name = name, dependency_name = name1, duration, resultCode
   ```

3. **Performance Analysis**
   ```kusto
   requests
   | where timestamp > ago(1h)
   | summarize avg(duration), max(duration), min(duration) by name
   | order by avg_duration desc
   ```

4. **Error Analysis**
   ```kusto
   requests
   | where success == false
   | summarize count() by name, resultCode, problemId
   | order by count_ desc
   ```

### Setting Up Alerts

1. **Create Alert for High Error Rate**
   ```powershell
   az monitor metrics alert create `
     --name "High Error Rate" `
     --resource-group observability-rg-west `
     --scopes /subscriptions/{subscription-id}/resourceGroups/observability-rg-west/providers/Microsoft.Insights/components/observability-insights `
     --condition "count requests/failed > 10" `
     --window-size 5m `
     --evaluation-frequency 1m
   ```

2. **Create Alert for High Response Time**
   ```powershell
   az monitor metrics alert create `
     --name "High Response Time" `
     --resource-group observability-rg-west `
     --scopes /subscriptions/{subscription-id}/resourceGroups/observability-rg-west/providers/Microsoft.Insights/components/observability-insights `
     --condition "avg requests/duration > 2000" `
     --window-size 5m `
     --evaluation-frequency 1m
   ```

## Cost Management

- **App Service**: B1 tier (~$13/month)  
- **Application Insights**: First 5GB free, then $2.30/GB

To minimize costs:
1. Use F1 (Free) or B1 App Service tier for learning
2. Delete resources when not in use: `az group delete --name observability-rg-west`
3. Monitor Application Insights data ingestion

## Next Steps

1. **Deploy to Azure** using one of the options above
2. **Run load tests** against Azure endpoints to generate telemetry
3. **Create custom dashboards** in Application Insights
4. **Set up alerts** for various failure conditions
5. **Practice incident response** using Azure monitoring tools
6. **Explore Log Analytics** for advanced querying

## License

This is a learning platform for educational purposes.