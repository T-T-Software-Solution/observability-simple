# Deploy ONLY the App Services to Existing Azure Resources
# This script assumes all Azure resources already exist
# Usage: .\deploy-apps-only.ps1 [-ResourceGroup "name"] [-DownstreamApp "name"] [-UpstreamApp "name"]

param(
    [string]$ResourceGroup = "observability-rg-west",
    [string]$DownstreamApp = "observability-downstream",
    [string]$UpstreamApp = "observability-upstream"
)

# Colors for output
function Write-ColorOutput($ForegroundColor) {
    $fc = $host.UI.RawUI.ForegroundColor
    $host.UI.RawUI.ForegroundColor = $ForegroundColor
    if ($args) {
        Write-Output $args
    }
    $host.UI.RawUI.ForegroundColor = $fc
}

Write-Host "========================================" -ForegroundColor Blue
Write-Host "Deploying Apps to Existing Azure Resources" -ForegroundColor Blue
Write-Host "========================================" -ForegroundColor Blue
Write-Host "Resource Group: $ResourceGroup" -ForegroundColor Yellow
Write-Host "Downstream App: $DownstreamApp" -ForegroundColor Yellow
Write-Host "Upstream App: $UpstreamApp" -ForegroundColor Yellow
Write-Host ""

# Check if Azure CLI is installed
try {
    $azVersion = az version 2>$null
    if (-not $azVersion) {
        throw
    }
} catch {
    Write-Host "Error: Azure CLI is not installed. Please install it first." -ForegroundColor Red
    Write-Host "Download from: https://aka.ms/installazurecliwindows" -ForegroundColor Yellow
    exit 1
}

# Check if logged in to Azure
try {
    $account = az account show 2>$null | ConvertFrom-Json
    if (-not $account) {
        Write-Host "Not logged in to Azure. Please log in..." -ForegroundColor Yellow
        az login
    }
} catch {
    Write-Host "Not logged in to Azure. Please log in..." -ForegroundColor Yellow
    az login
}

Write-Host "[OK] Azure CLI ready" -ForegroundColor Green

# Check if .NET SDK is installed
try {
    $dotnetVersion = dotnet --version
    if (-not $dotnetVersion) {
        throw
    }
} catch {
    Write-Host "Error: .NET SDK is not installed. Please install it first." -ForegroundColor Red
    Write-Host "Download from: https://dotnet.microsoft.com/download" -ForegroundColor Yellow
    exit 1
}

Write-Host "[OK] .NET SDK ready" -ForegroundColor Green

# Verify resources exist
Write-Host "Verifying existing resources..." -ForegroundColor Blue

# Check resource group exists
$rgExists = az group show --name $ResourceGroup 2>$null
if (-not $rgExists) {
    Write-Host "Error: Resource group '$ResourceGroup' not found" -ForegroundColor Red
    Write-Host "Available resource groups:" -ForegroundColor Yellow
    az group list --query "[].name" -o tsv
    exit 1
}

# Check downstream app exists
$downstreamExists = az webapp show --name $DownstreamApp --resource-group $ResourceGroup 2>$null
if (-not $downstreamExists) {
    Write-Host "Error: Web app '$DownstreamApp' not found in resource group '$ResourceGroup'" -ForegroundColor Red
    Write-Host "Available web apps:" -ForegroundColor Yellow
    az webapp list --resource-group $ResourceGroup --query "[].name" -o tsv
    exit 1
}

# Check upstream app exists
$upstreamExists = az webapp show --name $UpstreamApp --resource-group $ResourceGroup 2>$null
if (-not $upstreamExists) {
    Write-Host "Error: Web app '$UpstreamApp' not found in resource group '$ResourceGroup'" -ForegroundColor Red
    Write-Host "Available web apps:" -ForegroundColor Yellow
    az webapp list --resource-group $ResourceGroup --query "[].name" -o tsv
    exit 1
}

Write-Host "[OK] All resources verified" -ForegroundColor Green

# Clean previous builds
Write-Host "Cleaning previous builds..." -ForegroundColor Blue
Remove-Item -Path "downstream-api\DownstreamApi\publish" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -Path "downstream-api\DownstreamApi\bin\Release" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -Path "downstream-api\DownstreamApi\obj\Release" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -Path "upstream-api\UpstreamApi\publish" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -Path "upstream-api\UpstreamApi\bin\Release" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -Path "upstream-api\UpstreamApi\obj\Release" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -Path "downstream-api\DownstreamApi\downstream-api.zip" -Force -ErrorAction SilentlyContinue
Remove-Item -Path "upstream-api\UpstreamApi\upstream-api.zip" -Force -ErrorAction SilentlyContinue

# Build and deploy Downstream API
Write-Host "========================================" -ForegroundColor Blue
Write-Host "Building and Deploying Downstream API" -ForegroundColor Blue
Write-Host "========================================" -ForegroundColor Blue

Push-Location downstream-api\DownstreamApi

# Build the project
Write-Host "Building Downstream API..." -ForegroundColor Yellow
dotnet publish -c Release -o .\publish --nologo --verbosity minimal

# Create deployment package
Write-Host "Creating deployment package..." -ForegroundColor Yellow
Compress-Archive -Path ".\publish\*" -DestinationPath ".\downstream-api.zip" -Force

# Deploy to Azure
Write-Host "Deploying to Azure..." -ForegroundColor Yellow
az webapp deploy `
    --name $DownstreamApp `
    --resource-group $ResourceGroup `
    --src-path downstream-api.zip `
    --type zip `
    --async false `
    --output table

Write-Host "[OK] Downstream API deployed successfully" -ForegroundColor Green

Pop-Location

# Build and deploy Upstream API
Write-Host "========================================" -ForegroundColor Blue
Write-Host "Building and Deploying Upstream API" -ForegroundColor Blue
Write-Host "========================================" -ForegroundColor Blue

Push-Location upstream-api\UpstreamApi

# Build the project
Write-Host "Building Upstream API..." -ForegroundColor Yellow
dotnet publish -c Release -o .\publish --nologo --verbosity minimal

# Create deployment package
Write-Host "Creating deployment package..." -ForegroundColor Yellow
Compress-Archive -Path ".\publish\*" -DestinationPath ".\upstream-api.zip" -Force

# Deploy to Azure
Write-Host "Deploying to Azure..." -ForegroundColor Yellow
az webapp deploy `
    --name $UpstreamApp `
    --resource-group $ResourceGroup `
    --src-path upstream-api.zip `
    --type zip `
    --async false `
    --output table

Write-Host "[OK] Upstream API deployed successfully" -ForegroundColor Green

Pop-Location

# Restart the apps to ensure they're running with the latest code
Write-Host "Restarting applications..." -ForegroundColor Blue
az webapp restart --name $DownstreamApp --resource-group $ResourceGroup
az webapp restart --name $UpstreamApp --resource-group $ResourceGroup

# Get URLs
$DownstreamUrl = "https://$DownstreamApp.azurewebsites.net"
$UpstreamUrl = "https://$UpstreamApp.azurewebsites.net"

# Wait for apps to be ready
Write-Host "Waiting for applications to be ready..." -ForegroundColor Blue
Start-Sleep -Seconds 10

# Test the deployments
Write-Host "Testing deployments..." -ForegroundColor Blue

# Test Downstream API
Write-Host "Testing Downstream API health..." -ForegroundColor Yellow
try {
    $response = Invoke-WebRequest -Uri "$DownstreamUrl/health" -UseBasicParsing -ErrorAction Stop
    if ($response.StatusCode -eq 200) {
        Write-Host "[OK] Downstream API is healthy" -ForegroundColor Green
    }
} catch {
    Write-Host "[WARNING] Downstream API health check failed" -ForegroundColor Red
}

# Test Upstream API
Write-Host "Testing Upstream API health..." -ForegroundColor Yellow
try {
    $response = Invoke-WebRequest -Uri "$UpstreamUrl/health" -UseBasicParsing -ErrorAction Stop
    if ($response.StatusCode -eq 200) {
        Write-Host "[OK] Upstream API is healthy" -ForegroundColor Green
    }
} catch {
    Write-Host "[WARNING] Upstream API health check failed" -ForegroundColor Red
}

# Display summary
Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "Deployment Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Deployed Applications:" -ForegroundColor Yellow
Write-Host "Downstream API: $DownstreamUrl" -ForegroundColor Cyan
Write-Host "Upstream API: $UpstreamUrl" -ForegroundColor Cyan
Write-Host ""
Write-Host "Test Endpoints:" -ForegroundColor Yellow
Write-Host "Health Check: $UpstreamUrl/health" -ForegroundColor Cyan
Write-Host "Swagger UI: $UpstreamUrl/swagger" -ForegroundColor Cyan
Write-Host "Product API: $UpstreamUrl/gateway/products/123" -ForegroundColor Cyan
Write-Host "Order API: $UpstreamUrl/gateway/orders" -ForegroundColor Cyan
Write-Host ""
Write-Host "Test with Advanced Bugs:" -ForegroundColor Yellow
Write-Host "1. Enable bugs in Azure Portal App Settings:" -ForegroundColor White
Write-Host "   ADVANCED_BUG_HARDCODED_ID=true" -ForegroundColor Cyan
Write-Host "   ADVANCED_BUG_ORDER_RANGE=true" -ForegroundColor Cyan
Write-Host "   ADVANCED_BUG_MEMORY_LEAK=true" -ForegroundColor Cyan
Write-Host "   ADVANCED_BUG_THREAD_POOL=true" -ForegroundColor Cyan
Write-Host "   ADVANCED_BUG_CACHE_POISON=true" -ForegroundColor Cyan
Write-Host "   ADVANCED_BUG_CPU_SPIKE=true" -ForegroundColor Cyan
Write-Host ""
Write-Host "2. Run test data generator:" -ForegroundColor White
Write-Host "   cd test-data-generator" -ForegroundColor Cyan
Write-Host "   dotnet run -- $UpstreamUrl all" -ForegroundColor Cyan
Write-Host ""
Write-Host "[OK] Ready for testing!" -ForegroundColor Green