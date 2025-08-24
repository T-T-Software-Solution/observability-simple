# Create Azure Resources for Observability Learning Platform
# This script creates all required Azure resources but does NOT deploy the applications
# Usage: .\create-azure-resources.ps1 [-ResourceGroup "name"] [-Location "location"] [-AppInsightsName "name"]

param(
    [string]$ResourceGroup = "observability-rg-west",
    [string]$Location = "westus2",
    [string]$AppInsightsName = "observability-insights",
    [string]$AppServicePlan = "observability-plan",
    [string]$DownstreamAppName = "observability-downstream",
    [string]$UpstreamAppName = "observability-upstream"
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
Write-Host "Creating Azure Resources" -ForegroundColor Blue
Write-Host "========================================" -ForegroundColor Blue
Write-Host "Resource Group: $ResourceGroup" -ForegroundColor Yellow
Write-Host "Location: $Location" -ForegroundColor Yellow
Write-Host "App Insights: $AppInsightsName" -ForegroundColor Yellow
Write-Host "App Service Plan: $AppServicePlan" -ForegroundColor Yellow
Write-Host "Downstream App: $DownstreamAppName" -ForegroundColor Yellow
Write-Host "Upstream App: $UpstreamAppName" -ForegroundColor Yellow
Write-Host ""

# Check if Azure CLI is installed
try {
    $azVersion = az version 2>$null | ConvertFrom-Json
    if (-not $azVersion) {
        throw
    }
    Write-Host "Azure CLI Version: $($azVersion.'azure-cli')" -ForegroundColor Green
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
        $account = az account show | ConvertFrom-Json
    }
    Write-Host "✓ Logged in to Azure" -ForegroundColor Green
    Write-Host "  Subscription: $($account.name)" -ForegroundColor Cyan
    Write-Host "  Account: $($account.user.name)" -ForegroundColor Cyan
} catch {
    Write-Host "Error: Failed to authenticate with Azure" -ForegroundColor Red
    exit 1
}

Write-Host ""

# Step 1: Create Resource Group
Write-Host "========================================" -ForegroundColor Blue
Write-Host "Step 1: Creating Resource Group" -ForegroundColor Blue
Write-Host "========================================" -ForegroundColor Blue

# Check if resource group already exists
$existingRg = az group show --name $ResourceGroup 2>$null
if ($existingRg) {
    Write-Host "✓ Resource group '$ResourceGroup' already exists" -ForegroundColor Green
} else {
    Write-Host "Creating resource group '$ResourceGroup' in '$Location'..." -ForegroundColor Yellow
    az group create --name $ResourceGroup --location $Location --output table
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✓ Resource group created successfully" -ForegroundColor Green
    } else {
        Write-Host "✗ Failed to create resource group" -ForegroundColor Red
        exit 1
    }
}

# Step 2: Create Application Insights
Write-Host ""
Write-Host "========================================" -ForegroundColor Blue
Write-Host "Step 2: Creating Application Insights" -ForegroundColor Blue
Write-Host "========================================" -ForegroundColor Blue

# Check if Application Insights already exists
$existingAppInsights = az monitor app-insights component show --app $AppInsightsName --resource-group $ResourceGroup 2>$null
if ($existingAppInsights) {
    Write-Host "✓ Application Insights '$AppInsightsName' already exists" -ForegroundColor Green
} else {
    Write-Host "Creating Application Insights '$AppInsightsName'..." -ForegroundColor Yellow
    az monitor app-insights component create `
        --app $AppInsightsName `
        --location $Location `
        --resource-group $ResourceGroup `
        --application-type web `
        --output table
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✓ Application Insights created successfully" -ForegroundColor Green
    } else {
        Write-Host "✗ Failed to create Application Insights" -ForegroundColor Red
        exit 1
    }
}

# Get Application Insights connection string
Write-Host "Getting Application Insights connection string..." -ForegroundColor Yellow
$connectionString = az monitor app-insights component show `
    --app $AppInsightsName `
    --resource-group $ResourceGroup `
    --query connectionString -o tsv

if (-not $connectionString) {
    Write-Host "✗ Failed to get Application Insights connection string" -ForegroundColor Red
    exit 1
}

Write-Host "✓ Application Insights connection string retrieved" -ForegroundColor Green

# Step 3: Create App Service Plan
Write-Host ""
Write-Host "========================================" -ForegroundColor Blue
Write-Host "Step 3: Creating App Service Plan" -ForegroundColor Blue
Write-Host "========================================" -ForegroundColor Blue

# Check if App Service Plan already exists
$existingPlan = az appservice plan show --name $AppServicePlan --resource-group $ResourceGroup 2>$null
if ($existingPlan) {
    Write-Host "✓ App Service Plan '$AppServicePlan' already exists" -ForegroundColor Green
} else {
    Write-Host "Creating App Service Plan '$AppServicePlan'..." -ForegroundColor Yellow
    
    # Try F1 (Free) tier first
    Write-Host "Attempting to create with F1 (Free) tier..." -ForegroundColor Cyan
    az appservice plan create `
        --name $AppServicePlan `
        --resource-group $ResourceGroup `
        --location $Location `
        --sku F1 `
        --output table 2>$null
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "F1 tier failed (likely quota exceeded), trying B1 tier..." -ForegroundColor Yellow
        az appservice plan create `
            --name $AppServicePlan `
            --resource-group $ResourceGroup `
            --location $Location `
            --sku B1 `
            --output table
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✓ App Service Plan created with B1 tier" -ForegroundColor Green
        } else {
            Write-Host "✗ Failed to create App Service Plan" -ForegroundColor Red
            exit 1
        }
    } else {
        Write-Host "✓ App Service Plan created with F1 (Free) tier" -ForegroundColor Green
    }
}

# Step 4: Create Web Apps
Write-Host ""
Write-Host "========================================" -ForegroundColor Blue
Write-Host "Step 4: Creating Web Applications" -ForegroundColor Blue
Write-Host "========================================" -ForegroundColor Blue

# Create Downstream API
Write-Host "Creating Downstream API '$DownstreamAppName'..." -ForegroundColor Yellow
$existingDownstream = az webapp show --name $DownstreamAppName --resource-group $ResourceGroup 2>$null
if ($existingDownstream) {
    Write-Host "✓ Downstream API '$DownstreamAppName' already exists" -ForegroundColor Green
} else {
    az webapp create `
        --name $DownstreamAppName `
        --resource-group $ResourceGroup `
        --plan $AppServicePlan `
        --runtime "dotnet:8" `
        --output table
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✓ Downstream API created successfully" -ForegroundColor Green
    } else {
        Write-Host "✗ Failed to create Downstream API" -ForegroundColor Red
        exit 1
    }
}

# Create Upstream API
Write-Host "Creating Upstream API '$UpstreamAppName'..." -ForegroundColor Yellow
$existingUpstream = az webapp show --name $UpstreamAppName --resource-group $ResourceGroup 2>$null
if ($existingUpstream) {
    Write-Host "✓ Upstream API '$UpstreamAppName' already exists" -ForegroundColor Green
} else {
    az webapp create `
        --name $UpstreamAppName `
        --resource-group $ResourceGroup `
        --plan $AppServicePlan `
        --runtime "dotnet:8" `
        --output table
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✓ Upstream API created successfully" -ForegroundColor Green
    } else {
        Write-Host "✗ Failed to create Upstream API" -ForegroundColor Red
        exit 1
    }
}

# Step 5: Configure Application Settings
Write-Host ""
Write-Host "========================================" -ForegroundColor Blue
Write-Host "Step 5: Configuring Application Settings" -ForegroundColor Blue
Write-Host "========================================" -ForegroundColor Blue

# Configure Downstream API settings
Write-Host "Configuring Downstream API settings..." -ForegroundColor Yellow
az webapp config appsettings set `
    --name $DownstreamAppName `
    --resource-group $ResourceGroup `
    --settings "APPLICATIONINSIGHTS_CONNECTION_STRING=$connectionString" `
               "ADVANCED_BUG_HARDCODED_ID=true" `
               "ADVANCED_BUG_ORDER_RANGE=true" `
               "ADVANCED_BUG_MEMORY_LEAK=true" `
               "ADVANCED_BUG_THREAD_POOL=true" `
               "ADVANCED_BUG_CACHE_POISON=true" `
               "ADVANCED_BUG_CPU_SPIKE=true" `
    --output table

if ($LASTEXITCODE -eq 0) {
    Write-Host "✓ Downstream API settings configured" -ForegroundColor Green
} else {
    Write-Host "✗ Failed to configure Downstream API settings" -ForegroundColor Red
}

# Configure Upstream API settings
Write-Host "Configuring Upstream API settings..." -ForegroundColor Yellow
$downstreamUrl = "https://$DownstreamAppName.azurewebsites.net"
az webapp config appsettings set `
    --name $UpstreamAppName `
    --resource-group $ResourceGroup `
    --settings "APPLICATIONINSIGHTS_CONNECTION_STRING=$connectionString" `
               "DownstreamApi__BaseUrl=$downstreamUrl" `
    --output table

if ($LASTEXITCODE -eq 0) {
    Write-Host "✓ Upstream API settings configured" -ForegroundColor Green
} else {
    Write-Host "✗ Failed to configure Upstream API settings" -ForegroundColor Red
}

# Get Application Insights URL for Azure Portal
$subscriptionId = $account.id
$appInsightsUrl = "https://portal.azure.com/#@/resource/subscriptions/$subscriptionId/resourceGroups/$ResourceGroup/providers/Microsoft.Insights/components/$AppInsightsName/overview"

# Display summary
Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "Azure Resources Created Successfully!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Created Resources:" -ForegroundColor Yellow
Write-Host "✓ Resource Group: $ResourceGroup" -ForegroundColor Cyan
Write-Host "✓ App Service Plan: $AppServicePlan" -ForegroundColor Cyan
Write-Host "✓ Application Insights: $AppInsightsName" -ForegroundColor Cyan
Write-Host "✓ Downstream API: $DownstreamAppName" -ForegroundColor Cyan
Write-Host "✓ Upstream API: $UpstreamAppName" -ForegroundColor Cyan
Write-Host ""
Write-Host "Application URLs (will be available after deployment):" -ForegroundColor Yellow
Write-Host "Downstream API: https://$DownstreamAppName.azurewebsites.net" -ForegroundColor Cyan
Write-Host "Upstream API: https://$UpstreamAppName.azurewebsites.net" -ForegroundColor Cyan
Write-Host ""
Write-Host "Monitoring:" -ForegroundColor Yellow
Write-Host "Application Insights: $appInsightsUrl" -ForegroundColor Cyan
Write-Host ""
Write-Host "Next Steps:" -ForegroundColor Yellow
Write-Host "1. Deploy applications using:" -ForegroundColor White
Write-Host "   .\deploy-apps-only.ps1 -ResourceGroup `"$ResourceGroup`" -DownstreamApp `"$DownstreamAppName`" -UpstreamApp `"$UpstreamAppName`"" -ForegroundColor Cyan
Write-Host ""
Write-Host "2. Test with advanced bug exercises:" -ForegroundColor White
Write-Host "   cd test-data-generator" -ForegroundColor Cyan
Write-Host "   dotnet run -- https://$UpstreamAppName.azurewebsites.net all" -ForegroundColor Cyan
Write-Host ""
Write-Host "✓ Ready for application deployment!" -ForegroundColor Green