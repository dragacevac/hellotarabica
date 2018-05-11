param(
    [Parameter(Mandatory = $True)] [string] $ServicePrincipalCertThumbprint,
    [Parameter(Mandatory = $True)] [string] $ServicePrincipalId,
    [Parameter(Mandatory = $True)] [string] $TenantId,
    [Parameter(Mandatory = $True)] [string] $SubscriptionId
)

function New-LoginToAzure {
    Write-Host "Login to Azure"

    Add-AzureRmAccount -ServicePrincipal `
        -CertificateThumbprint $ServicePrincipalCertThumbprint `
        -ApplicationId $ServicePrincipalId `
        -TenantId $TenantId `
        -SubscriptionId $SubscriptionId `
        -ErrorAction Stop | Out-Null

    Write-Host "Login successful"
}
function New-ResourceGroup {
    $ResourceGroup = Get-AzureRmResourceGroup -Name $ResourceGroupName -ErrorAction SilentlyContinue

    if (!$ResourceGroup) {
        Write-Host "Creating resource group '$ResourceGroupName' in location '$ResourceGroupLocation'"
        New-AzureRmResourceGroup -Name $ResourceGroupName -Location $ResourceGroupLocation -ErrorAction Stop
        Write-Host "Resource group created"
    }
    else {
        Write-Host "Resource group '$ResourceGroupName' already exists"
    }
}

function Set-Resources {
    $params = @{
        ResourceGroupName     = $ResourceGroupName
        TemplateFile          = $TemplateFile
        TemplateParameterFile = $TemplateParameters
    
        Name                  = $DeploymentName
        ErrorAction           = "Stop"
    }
    
    # Update or create resources in resource group
    Write-Host "Updating resources"
    
    New-AzureRmResourceGroupDeployment @params
    
    Write-Host "Resources updated"
}

function Get-DeploymentCredentials {
    Write-Host "Getting Deploy credentials"

    $PublishProfile = [xml](Get-AzureRmWebAppPublishingProfile -ResourceGroupName $ResourceGroupName -Name $FunctionAppName)
    $WebDeployNode = $PublishProfile.SelectSingleNode("//*[@publishMethod='MSDeploy']")
    $Username = $WebDeployNode.userName
    $Password = $WebDeployNode.userPWD
    
    return @($Username, $Password)
}
function New-LocalRepositoryAndAddRemoteRepo ($Credentials) {
    $RepoName = $FunctionAppName

    New-Item $TempRepository -ItemType Directory -Force | Out-Null

    Push-Location $TempRepository

    $Username = $Credentials[0]
    $Password = $Credentials[1]

    git init
    git remote add azure "https://${Username}:${Password}@${RepoName}.scm.azurewebsites.net:443/${RepoName}.git"
    git checkout -b master
    git pull azure master
    git rm *
    git commit -am "Reset working dir"    
}

function Invoke-GitPush {
    git add .
    git commit -m "$DeploymentName"
    git push -uf azure master
    
}

function Invoke-RepositoryCleanup {
    Pop-Location
    Remove-Item $TempRepository -Force -Recurse
}

function Invoke-CopyArtifacts {
    # Copy build artifacts to working dir
    Get-ChildItem -Path $ArtifactsFolder | ForEach-Object { 
        Copy-Item $_.FullName $TempRepository -Force -Recurse
    }
}

$ResourceGroupName = "HelloTarabica"
$ResourceGroupLocation = "westeurope"
$FunctionAppName = "hellotarabica"

$TemplateFile = Resolve-Path "$PSScriptRoot/resources.json"
$TemplateParameters = Resolve-Path "$PSScriptRoot/parameters.json"

$ArtifactsFolder = "c:/repos/HelloTarabica/src/HelloTarabica/bin/Release/net461/"
$TempRepository = "C:/Deployment"

$DeploymentName = "Deployment-$(Get-Date -Format "yyyyMMdd-HHmmssffff")"

############################################################

New-LoginToAzure

# Create resource group, if not exist
New-ResourceGroup

# Create or update resources
Set-Resources

$Credentials = Get-DeploymentCredentials

# Deploy App
New-LocalRepositoryAndAddRemoteRepo $Credentials
Invoke-CopyArtifacts
Invoke-GitPush

# Cleanup
Invoke-RepositoryCleanup
