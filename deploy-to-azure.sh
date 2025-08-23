#!/bin/bash

# Deploy Observability Learning Platform to Azure
# Usage: ./deploy-to-azure.sh [resource-group] [location] [deployment-type]
# deployment-type: appservice (default) or containerapp

set -e  # Exit on any error

# Configuration
RESOURCE_GROUP=${1:-"observability-rg"}
LOCATION=${2:-"eastus"}
DEPLOYMENT_TYPE=${3:-"appservice"}
APP_INSIGHTS_NAME="observability-insights"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Deploying Observability Platform to Azure${NC}"
echo -e "${BLUE}========================================${NC}"
echo -e "${YELLOW}Resource Group: $RESOURCE_GROUP${NC}"
echo -e "${YELLOW}Location: $LOCATION${NC}"
echo -e "${YELLOW}Deployment Type: $DEPLOYMENT_TYPE${NC}"
echo ""

# Check if Azure CLI is installed
if ! command -v az &> /dev/null; then
    echo -e "${RED}Error: Azure CLI is not installed. Please install it first.${NC}"
    exit 1
fi

# Check if logged in to Azure
if ! az account show &> /dev/null; then
    echo -e "${YELLOW}Not logged in to Azure. Please log in...${NC}"
    az login
fi

echo -e "${GREEN}✓ Azure CLI ready${NC}"

# Create Resource Group
echo -e "${BLUE}Creating resource group...${NC}"
az group create --name $RESOURCE_GROUP --location $LOCATION --output table

# Create Application Insights
echo -e "${BLUE}Creating Application Insights...${NC}"
az monitor app-insights component create \
    --app $APP_INSIGHTS_NAME \
    --location $LOCATION \
    --resource-group $RESOURCE_GROUP \
    --application-type web \
    --output table

# Get Application Insights connection string
echo -e "${BLUE}Getting Application Insights connection string...${NC}"
CONNECTION_STRING=$(az monitor app-insights component show \
    --app $APP_INSIGHTS_NAME \
    --resource-group $RESOURCE_GROUP \
    --query connectionString -o tsv)

if [ -z "$CONNECTION_STRING" ]; then
    echo -e "${RED}Error: Failed to get Application Insights connection string${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Application Insights created${NC}"

if [ "$DEPLOYMENT_TYPE" = "appservice" ]; then
    echo -e "${BLUE}Deploying to Azure App Service...${NC}"
    
    # Create App Service Plan
    echo -e "${BLUE}Creating App Service Plan...${NC}"
    az appservice plan create \
        --name "observability-plan" \
        --resource-group $RESOURCE_GROUP \
        --sku B1 \
        --is-linux \
        --output table
    
    # Create Web Apps
    echo -e "${BLUE}Creating Web Apps...${NC}"
    az webapp create \
        --name "downstream-api-$(date +%s)" \
        --resource-group $RESOURCE_GROUP \
        --plan "observability-plan" \
        --runtime "DOTNETCORE:8.0" \
        --output table
    
    DOWNSTREAM_APP_NAME=$(az webapp list --resource-group $RESOURCE_GROUP --query "[?contains(name, 'downstream-api')].name" -o tsv)
    
    az webapp create \
        --name "upstream-api-$(date +%s)" \
        --resource-group $RESOURCE_GROUP \
        --plan "observability-plan" \
        --runtime "DOTNETCORE:8.0" \
        --output table
    
    UPSTREAM_APP_NAME=$(az webapp list --resource-group $RESOURCE_GROUP --query "[?contains(name, 'upstream-api')].name" -o tsv)
    
    # Configure App Settings
    echo -e "${BLUE}Configuring application settings...${NC}"
    az webapp config appsettings set \
        --name $DOWNSTREAM_APP_NAME \
        --resource-group $RESOURCE_GROUP \
        --settings "ApplicationInsights__ConnectionString=$CONNECTION_STRING" \
        --output table
    
    az webapp config appsettings set \
        --name $UPSTREAM_APP_NAME \
        --resource-group $RESOURCE_GROUP \
        --settings "ApplicationInsights__ConnectionString=$CONNECTION_STRING" \
                   "DownstreamApi__BaseUrl=https://$DOWNSTREAM_APP_NAME.azurewebsites.net" \
        --output table
    
    # Build and deploy applications
    echo -e "${BLUE}Building and deploying applications...${NC}"
    
    # Deploy Downstream API
    echo -e "${YELLOW}Deploying Downstream API...${NC}"
    cd downstream-api/DownstreamApi
    dotnet publish -c Release -o ./publish
    cd publish
    zip -r ../downstream-api.zip . > /dev/null 2>&1
    cd ..
    az webapp deployment source config-zip \
        --name $DOWNSTREAM_APP_NAME \
        --resource-group $RESOURCE_GROUP \
        --src downstream-api.zip \
        --output table
    cd ../..
    
    # Deploy Upstream API
    echo -e "${YELLOW}Deploying Upstream API...${NC}"
    cd upstream-api/UpstreamApi
    dotnet publish -c Release -o ./publish
    cd publish
    zip -r ../upstream-api.zip . > /dev/null 2>&1
    cd ..
    az webapp deployment source config-zip \
        --name $UPSTREAM_APP_NAME \
        --resource-group $RESOURCE_GROUP \
        --src upstream-api.zip \
        --output table
    cd ../..
    
    # Get URLs
    DOWNSTREAM_URL="https://$DOWNSTREAM_APP_NAME.azurewebsites.net"
    UPSTREAM_URL="https://$UPSTREAM_APP_NAME.azurewebsites.net"
    
    echo -e "${GREEN}✓ App Service deployment completed${NC}"

elif [ "$DEPLOYMENT_TYPE" = "containerapp" ]; then
    echo -e "${BLUE}Deploying to Azure Container Apps...${NC}"
    
    # Create Container Apps Environment
    echo -e "${BLUE}Creating Container Apps environment...${NC}"
    az containerapp env create \
        --name "observability-env" \
        --resource-group $RESOURCE_GROUP \
        --location $LOCATION \
        --output table
    
    # Create Azure Container Registry
    echo -e "${BLUE}Creating Azure Container Registry...${NC}"
    ACR_NAME="observabilityacr$(date +%s)"
    az acr create \
        --name $ACR_NAME \
        --resource-group $RESOURCE_GROUP \
        --sku Basic \
        --admin-enabled true \
        --output table
    
    # Get ACR login server
    ACR_SERVER=$(az acr show --name $ACR_NAME --resource-group $RESOURCE_GROUP --query loginServer -o tsv)
    
    # Build and push images
    echo -e "${BLUE}Building and pushing container images...${NC}"
    az acr build --registry $ACR_NAME --image downstream-api:latest ./downstream-api/DownstreamApi --output table
    az acr build --registry $ACR_NAME --image upstream-api:latest ./upstream-api/UpstreamApi --output table
    
    # Deploy Container Apps
    echo -e "${BLUE}Deploying Container Apps...${NC}"
    
    # Deploy Downstream API
    az containerapp create \
        --name "downstream-api" \
        --resource-group $RESOURCE_GROUP \
        --environment "observability-env" \
        --image "$ACR_SERVER/downstream-api:latest" \
        --target-port 8080 \
        --ingress external \
        --registry-server $ACR_SERVER \
        --env-vars "ApplicationInsights__ConnectionString=$CONNECTION_STRING" \
        --cpu 0.25 \
        --memory 0.5Gi \
        --output table
    
    # Get Downstream API URL
    DOWNSTREAM_FQDN=$(az containerapp show \
        --name "downstream-api" \
        --resource-group $RESOURCE_GROUP \
        --query properties.configuration.ingress.fqdn -o tsv)
    
    # Deploy Upstream API
    az containerapp create \
        --name "upstream-api" \
        --resource-group $RESOURCE_GROUP \
        --environment "observability-env" \
        --image "$ACR_SERVER/upstream-api:latest" \
        --target-port 8080 \
        --ingress external \
        --registry-server $ACR_SERVER \
        --env-vars "ApplicationInsights__ConnectionString=$CONNECTION_STRING" \
                   "DownstreamApi__BaseUrl=https://$DOWNSTREAM_FQDN" \
        --cpu 0.25 \
        --memory 0.5Gi \
        --output table
    
    # Get URLs
    DOWNSTREAM_URL="https://$DOWNSTREAM_FQDN"
    UPSTREAM_URL="https://$(az containerapp show --name "upstream-api" --resource-group $RESOURCE_GROUP --query properties.configuration.ingress.fqdn -o tsv)"
    
    echo -e "${GREEN}✓ Container Apps deployment completed${NC}"
    
else
    echo -e "${RED}Error: Invalid deployment type. Use 'appservice' or 'containerapp'${NC}"
    exit 1
fi

# Get Application Insights URL
APP_INSIGHTS_URL="https://portal.azure.com/#@/resource/subscriptions/$(az account show --query id -o tsv)/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Insights/components/$APP_INSIGHTS_NAME/overview"

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Deployment Successful!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${YELLOW}Application URLs:${NC}"
echo -e "${WHITE}Downstream API: $DOWNSTREAM_URL${NC}"
echo -e "${WHITE}Upstream API: $UPSTREAM_URL${NC}"
echo ""
echo -e "${YELLOW}Test endpoints:${NC}"
echo -e "${WHITE}Health Check: $UPSTREAM_URL/health${NC}"
echo -e "${WHITE}Product API: $UPSTREAM_URL/gateway/products/123${NC}"
echo -e "${WHITE}Order API: $UPSTREAM_URL/gateway/orders${NC}"
echo -e "${WHITE}Swagger UI: $UPSTREAM_URL/swagger${NC}"
echo ""
echo -e "${YELLOW}Monitoring:${NC}"
echo -e "${WHITE}Application Insights: $APP_INSIGHTS_URL${NC}"
echo ""
echo -e "${BLUE}Run performance tests:${NC}"
echo -e "${WHITE}./performance-test.sh 10 2 $UPSTREAM_URL${NC}"
echo ""
echo -e "${GREEN}✓ Ready for observability learning exercises!${NC}"