. "$PSScriptRoot\CreatePullRequest.ps1"

function Get-Tree($Path, $Include = '*') { 
    @(Get-Item $Path -Include $Include -Force) + 
    (Get-ChildItem $Path -Recurse -Include $Include -Force) | 
    Sort-Object pspath -Descending -unique
} 

function Remove-Tree($Path, $Include = '*') { 
    Get-Tree $Path $Include | Remove-Item -force -recurse
}

function Log($message){
    Write-Host "$(Get-Date -Format u) $message";
}

function ExtractSolutionAndCreatePR {
    [CmdletBinding()]
    param()

    $repositoryRoot = Get-VstsInput -Name 'repositoryRoot'
    $gitEmail = Get-VstsInput -Name 'gitEmail'
    $gitName = Get-VstsInput -Name 'gitName'
    $targetBranchName = Get-VstsInput -Name 'targetBranchName'
    $newBranchName = Get-VstsInput -Name 'newBranchName'
    $connectionString = Get-VstsInput -Name 'connectionString'
    $connectionTimeoutInMinutes = Get-VstsInput -Name 'connectionTimeoutInMinutes'
    $solutionName = Get-VstsInput -Name 'solutionName'
    $unpackFolder = Get-VstsInput -Name 'unpackFolder'
    $crmSdkPackageVersion = Get-VstsInput -Name 'crmSdkPackageVersion'
    Log "Input parameters:"
    Log "repositoryRoot: $repositoryRoot"
    Log "gitEmail: $gitEmail"
    Log "gitName: $gitName"
    Log "targetBranchName: $targetBranchName"
    Log "newBranchName: $newBranchName"
    Log "connectionString: ***"
    Log "connectionTimeoutInMinutes: $connectionTimeoutInMinutes"
    Log "solutionName: $solutionName"
    Log "unpackFolder: $unpackFolder"
    Log "crmSdkPackageVersion: $crmSdkPackageVersion"
    Log ""
    
    $solutionFolder = "$env:BUILD_ARTIFACTSTAGINGDIRECTORY/$solutionName"
    Log "Solution extract folder: $solutionFolder"

    # Checkout
    Log 'Checking out a branch'
    Set-Location -Path $repositoryRoot
    $isExistingBranch = $False
    git switch $newBranchName
    if ($?) {
        Log "Using existing branch origin/$newBranchName"
        $isExistingBranch = $True
    } else {
        Log "Creating a new branch $newBranchName"
        git checkout -b $newBranchName
    }

    # Install
    Log 'Installing PS module Microsoft.Xrm.Data.Powershell'
    Install-Module -Name Microsoft.Xrm.Data.Powershell -Force
    Import-Module Microsoft.Xrm.Data.Powershell
    Log 'Installing nuget package Microsoft.CrmSdk.CoreTools'
    Install-Package Microsoft.CrmSdk.CoreTools -RequiredVersion $crmSdkPackageVersion -Destination $env:TEMP -Force
    $solutionPackager = "$env:TEMP\Microsoft.CrmSdk.CoreTools.$crmSdkPackageVersion\content\bin\coretools\SolutionPackager.exe"


    # Connect to CRM
    Log 'Getting crm connection'
    $crmTimeout = New-TimeSpan -Minutes $connectionTimeoutInMinutes
    $conn = Get-CrmConnection -ConnectionString $connectionString -MaxCrmConnectionTimeOutMinutes $crmTimeout.TotalMinutes
    Log "IsReady: $($conn.IsReady)"
    Log "CrmConnectOrgUriActual: $($conn.CrmConnectOrgUriActual)"
    Log "ConnectedOrgFriendlyName: $($conn.ConnectedOrgFriendlyName)"
    Log "ConnectedOrgVersion: $($conn.ConnectedOrgVersion)"

    Log "OrganizationServiceProxy Timeout in Minutes: $($conn.OrganizationServiceProxy.Timeout.TotalMinutes)"
    Log "OrganizationWebProxyClient Timeout in Minutes: $($conn.OrganizationWebProxyClient.Endpoint.Binding.SendTimeout.TotalMinutes)"


    # Publish customizations
    Log 'Publishing all customizations'
    Publish-CrmAllCustomization -conn $conn


    # Export
    if (!(test-path $solutionFolder)) {
        New-Item -ItemType Directory -Force -Path $solutionFolder
    }

    Log 'Exporting unmanaged solution'
    Export-CrmSolution -conn $conn -SolutionName $solutionName -SolutionFilePath $solutionFolder -SolutionZipFileName "$solutionName.zip"

    Log 'Exporting managed solution'
    Export-CrmSolution -conn $conn -SolutionName $solutionName -SolutionFilePath $solutionFolder -SolutionZipFileName "$($solutionName)_managed.zip" -Managed


    # Unpack
    Log 'Unpacking solution'
    & "$solutionPackager" /action:Extract /zipfile:"$solutionFolder\$solutionName.zip" /folder:"$unpackFolder\$solutionName" /packagetype:Both /allowWrite:Yes /allowDelete:Yes

    # Commit & push
    Log "Pushing changes to remote"
    git config --global user.email $gitEmail
    git config --global user.name $gitName

    git add $unpackFolder
    git commit -m "$solutionName solution extract"
    git push --set-upstream origin $newBranchName


    # Create PR
    if ($isExistingBranch) {
        Log "Skipping PR creation because branch already exists"
    } else {
        Log "Creating Pull Request"
        CreatePullRequestRoot `
            -sourceBranch $newBranchName `
            -targetBranch $targetBranchName `
            -title "$solutionName solution extract"
    }
        
}