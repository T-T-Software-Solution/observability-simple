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
   ```bash
   git clone <repository-url>
   cd observability-simple
   ```

2. **Build the solution**
   ```bash
   dotnet build
   ```

3. **Login to Azure CLI** (Required for Azure resources)
   
   First, ensure you have Azure CLI installed and login:
   ```bash
   # Check if Azure CLI is installed
   az --version
   
   # If not installed, install it from: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli
   
   # Login to Azure
   az login
   ```
   
   This will open a browser window for authentication. After successful login:
   ```bash
   # Verify you're logged in and check your subscription
   az account show
   
   # If you have multiple subscriptions, list them
   az account list --output table
   
   # Set the correct subscription if needed
   az account set --subscription "your-subscription-name-or-id"
   ```

4. **Configure Application Insights**
   
   Create an Application Insights resource in Azure:
   ```bash
   az monitor app-insights component create \
     --app observability-learning \
     --location eastus \
     --resource-group your-resource-group \
     --application-type web
   ```
   
   Get the connection string:
   ```bash
   az monitor app-insights component show \
     --app observability-learning \
     --resource-group your-resource-group \
     --query connectionString -o tsv
   ```
   
   Update both APIs' `appsettings.json`:
   ```json
   "ApplicationInsights": {
     "ConnectionString": "InstrumentationKey=YOUR_KEY;IngestionEndpoint=https://eastus-8.in.applicationinsights.azure.com/;LiveEndpoint=https://eastus.livediagnostics.monitor.azure.com/"
   }
   ```

5. **Run the Downstream API**
   ```bash
   cd downstream-api/DownstreamApi
   dotnet run
   ```
   The API will start on http://localhost:5001

6. **Run the Upstream API** (in a new terminal)
   ```bash
   cd upstream-api/UpstreamApi
   dotnet run
   ```
   The API will start on http://localhost:5000

7. **Access Swagger UI**
   - Downstream API: http://localhost:5001/swagger
   - Upstream API: http://localhost:5000/swagger

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
```bash
# Normal response
curl http://localhost:5001/products/123

# With 2-second delay
curl "http://localhost:5001/products/123?delayMs=2000"

# Through gateway with delay
curl "http://localhost:5000/gateway/products/456?delayMs=1500"
```

### 2. Error Simulation
Test different failure modes:
```bash
# Success scenario
curl -X POST http://localhost:5001/orders

# Transient failure (50% chance)
curl -X POST "http://localhost:5001/orders?failureMode=transient"

# Persistent failure (100% failure)
curl -X POST "http://localhost:5001/orders?failureMode=persistent"

# Through gateway
curl -X POST "http://localhost:5000/gateway/orders?failureMode=transient"
```

### 3. CPU Pressure
Simulate high CPU usage:
```bash
# Light load
curl "http://localhost:5001/pressure/cpu?iterations=100000"

# Heavy load
curl "http://localhost:5001/pressure/cpu?iterations=10000000"
```

### 4. Memory Pressure
Simulate memory allocation:
```bash
# Allocate 50MB
curl "http://localhost:5001/pressure/memory?mbToAllocate=50"

# Allocate 200MB
curl "http://localhost:5001/pressure/memory?mbToAllocate=200"
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

### Exercise 1: Identify Latency Source
1. Call `/gateway/products/100?delayMs=3000`
2. Use Application Insights to identify where the delay occurs
3. Verify the delay is in the downstream service

### Exercise 2: Trace Transient Failures
1. Call `/gateway/orders?failureMode=transient` multiple times
2. Observe the 50% failure rate
3. Trace failed requests through both services
4. Identify the exact failure point and error details

### Exercise 3: Monitor Resource Usage
1. Generate CPU pressure: `/pressure/cpu?iterations=50000000`
2. Generate memory pressure: `/pressure/memory?mbToAllocate=500`
3. Monitor the impact on service performance
4. Set up alerts for high resource usage

### Exercise 4: Correlate Distributed Errors
1. Stop the Downstream API
2. Call gateway endpoints
3. Observe 502 Bad Gateway errors
4. Trace the correlation between gateway errors and downstream unavailability

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
├── ObservabilitySimple.sln     # Solution file
├── CLAUDE.md                   # Implementation plan
└── README.md                   # This file
```

## Azure Deployment

### Automated Deployment Script

The project includes an automated deployment script that handles the complete Azure deployment process:

```bash
# Make script executable and run deployment
chmod +x deploy-to-azure.sh
./deploy-to-azure.sh
```

### Manual Azure App Service Deployment

If you prefer to deploy manually or the automated script fails, follow these steps:

#### Prerequisites
- Azure CLI installed and logged in (`az login`)
- Proper Azure subscription permissions

#### Step-by-Step Deployment

1. **Create Resource Group and Application Insights**
   ```bash
   # Choose a region that supports your subscription quotas
   # Common alternatives: westus2, eastus2, centralus, westeurope
   az group create --name observability-rg-west --location westus2
   
   # Create Application Insights
   az monitor app-insights component create \
     --app observability-insights \
     --location westus2 \
     --resource-group observability-rg-west \
     --application-type web
   ```

2. **Create App Service Plan**
   ```bash
   # Try F1 (Free) tier first, fallback to B1 if needed
   az appservice plan create \
     --name observability-plan \
     --resource-group observability-rg-west \
     --location westus2 \
     --sku F1
   
   # If F1 fails due to quota, try B1 (requires subscription with compute quota)
   # az appservice plan create \
   #   --name observability-plan \
   #   --resource-group observability-rg-west \
   #   --location westus2 \
   #   --sku B1
   ```

3. **Create Web Apps**
   ```bash
   # Create downstream API app
   az webapp create \
     --name observability-downstream \
     --resource-group observability-rg-west \
     --plan observability-plan \
     --runtime "dotnet:8"
   
   # Create upstream API app
   az webapp create \
     --name observability-upstream \
     --resource-group observability-rg-west \
     --plan observability-plan \
     --runtime "dotnet:8"
   ```

4. **Configure Application Settings**
   ```bash
   # Get Application Insights connection string
   CONNECTION_STRING=$(az monitor app-insights component show \
     --app observability-insights \
     --resource-group observability-rg-west \
     --query connectionString -o tsv)
   
   # Configure Downstream API
   az webapp config appsettings set \
     --name observability-downstream \
     --resource-group observability-rg-west \
     --settings "APPLICATIONINSIGHTS_CONNECTION_STRING=$CONNECTION_STRING"
   
   # Configure Upstream API with downstream URL
   az webapp config appsettings set \
     --name observability-upstream \
     --resource-group observability-rg-west \
     --settings "APPLICATIONINSIGHTS_CONNECTION_STRING=$CONNECTION_STRING" \
                "DownstreamApi__BaseUrl=https://observability-downstream.azurewebsites.net"
   ```

5. **Build and Deploy Applications**
   ```bash
   # Build downstream API
   dotnet publish downstream-api/DownstreamApi/DownstreamApi.csproj \
     --configuration Release \
     --output ./publish/downstream
   
   # Build upstream API  
   dotnet publish upstream-api/UpstreamApi/UpstreamApi.csproj \
     --configuration Release \
     --output ./publish/upstream
   
   # Create deployment packages (Windows PowerShell)
   powershell "Compress-Archive -Path 'publish/downstream/*' -DestinationPath 'publish/downstream-api.zip' -Force"
   powershell "Compress-Archive -Path 'publish/upstream/*' -DestinationPath 'publish/upstream-api.zip' -Force"
   
   # Create deployment packages (Linux/Mac with zip)
   # cd publish/downstream && zip -r ../downstream-api.zip . && cd ../upstream && zip -r ../upstream-api.zip . && cd ../..
   
   # Deploy to Azure
   az webapp deploy \
     --name observability-downstream \
     --resource-group observability-rg-west \
     --src-path publish/downstream-api.zip \
     --type zip
   
   az webapp deploy \
     --name observability-upstream \
     --resource-group observability-rg-west \
     --src-path publish/upstream-api.zip \
     --type zip
   ```

6. **Verify Deployment**
   ```bash
   # Test health endpoints
   curl https://observability-downstream.azurewebsites.net/health
   curl https://observability-upstream.azurewebsites.net/health
   
   # Test application endpoints
   curl "https://observability-upstream.azurewebsites.net/gateway/products/123?delayMs=100"
   
   # Access Swagger UI
   # Navigate to: https://observability-upstream.azurewebsites.net/swagger
   ```

### Current Deployment Status

✅ **Successfully Deployed**
- **Resource Group**: observability-rg-west (West US 2 region)
- **Upstream API**: https://observability-upstream.azurewebsites.net
- **Downstream API**: https://observability-downstream.azurewebsites.net  
- **Application Insights**: observability-insights (configured for both services)
- **Status**: Both services are healthy and responding

### Testing the Live Deployment

```bash
# Health checks
curl https://observability-downstream.azurewebsites.net/health
curl https://observability-upstream.azurewebsites.net/health

# Product endpoint with latency simulation
curl "https://observability-upstream.azurewebsites.net/gateway/products/123?delayMs=500"

# Order endpoint with failure simulation
curl -X POST "https://observability-upstream.azurewebsites.net/gateway/orders?failureMode=transient"

# CPU pressure test
curl "https://observability-downstream.azurewebsites.net/pressure/cpu?iterations=100000"

# Memory pressure test
curl "https://observability-downstream.azurewebsites.net/pressure/memory?mbToAllocate=50"
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
   ```bash
   az monitor metrics alert create \
     --name "High Error Rate" \
     --resource-group observability-rg \
     --scopes /subscriptions/{subscription-id}/resourceGroups/observability-rg/providers/Microsoft.Insights/components/observability-insights \
     --condition "count requests/failed > 10" \
     --window-size 5m \
     --evaluation-frequency 1m
   ```

2. **Create Alert for High Response Time**
   ```bash
   az monitor metrics alert create \
     --name "High Response Time" \
     --resource-group observability-rg \
     --scopes /subscriptions/{subscription-id}/resourceGroups/observability-rg/providers/Microsoft.Insights/components/observability-insights \
     --condition "avg requests/duration > 2000" \
     --window-size 5m \
     --evaluation-frequency 1m
   ```

## Cost Management

- **App Service**: B1 tier (~$13/month)  
- **Application Insights**: First 5GB free, then $2.30/GB

To minimize costs:
1. Use B1 App Service tier for learning
2. Delete resources when not in use: `az group delete --name observability-rg`
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