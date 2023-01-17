. ".\createPullRequest.ps1"

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
    $mainBranchName = Get-VstsInput -Name 'mainBranchName'
    $branchName = Get-VstsInput -Name 'branchName'
    $connectionString = Get-VstsInput -Name 'connectionString'
    $connectionTimeoutInMinutes = Get-VstsInput -Name 'connectionTimeoutInMinutes'
    $solutionName = Get-VstsInput -Name 'solutionName'
    $solutionFolder = Get-VstsInput -Name 'solutionFolder'
    $unpackFolder = Get-VstsInput -Name 'unpackFolder'
    $crmSdkPackageVersion = Get-VstsInput -Name 'crmSdkPackageVersion'
    Log "Input parameters:"
    Log "repositoryRoot: $repositoryRoot"
    Log "gitEmail: $gitEmail"
    Log "gitName: $gitName"
    Log "mainBranchName: $mainBranchName"
    Log "branchName: $branchName"
    Log "connectionString: ***"
    Log "connectionTimeoutInMinutes: $connectionTimeoutInMinutes"
    Log "solutionName: $solutionName"
    Log "solutionFolder: $solutionFolder"
    Log "unpackFolder: $unpackFolder"
    Log "crmSdkPackageVersion: $crmSdkPackageVersion"
    Log ""

    # Checkout
    Log 'Creating separate branch'
    Set-Location -Path $repositoryRoot
    $isExisingBranch = $False
    git checkout -b $branchName origin/$branchName
    if ($?) {
        Log "Using exising branch origin/$branchName"
        $isExisingBranch = $True
    } else {
        Log "Creating a new branch $branchName"
    git checkout -b $branchName
        git branch $branchName -u origin/$branchName
    }

    # Install
    Log 'Installing necessary tooling'
    Install-Module -Name Microsoft.Xrm.Data.Powershell -Force
    Import-Module Microsoft.Xrm.Data.Powershell
    # Install-Module -Name Microsoft.Xrm.Tooling.CrmConnector.PowerShell -Force -AllowClobber
    Install-Package Microsoft.CrmSdk.CoreTools -RequiredVersion $crmSdkPackageVersion -Destination $env:TEMP -Force
    $solutionPackager = "$env:TEMP\Microsoft.CrmSdk.CoreTools.$crmSdkPackageVersion\content\bin\coretools\SolutionPackager.exe"


    # Connect to CRM
    Log 'Getting crm connection'
    $crmTimeout = New-TimeSpan -Minutes $connectionTimeoutInMinutes
    Set-CrmConnectionTimeout -TimeoutInSeconds $crmTimeout.TotalSeconds
    $conn = Get-CrmConnection -ConnectionString $connectionString -MaxCrmConnectionTimeOutMinutes $crmTimeout.TotalMinutes
    $conn

    Log "OrganizationServiceProxy Timeout in Minutes: $($conn.OrganizationServiceProxy.Timeout.TotalMinutes)"
    Log "OrganizationWebProxyClient Timeout in Minutes: $($conn.OrganizationWebProxyClient.Endpoint.Binding.SendTimeout.TotalMinutes)"

    # Publish customizations
    Log 'Publishing all customizations'
    Publish-CrmAllCustomization -conn $conn


    # Export
    If (!(test-path $solutionFolder)) {
        New-Item -ItemType Directory -Force -Path $solutionFolder
    }
    Log 'Exporting unmanaged solution'
    Export-CrmSolution -conn $conn -SolutionName $solutionName -SolutionFilePath $solutionFolder -SolutionZipFileName "$solutionName.zip"

    Log 'Exporting managed solution'
    Export-CrmSolution -conn $conn -SolutionName $solutionName -SolutionFilePath $solutionFolder -SolutionZipFileName "$($solutionName)_managed.zip" -Managed


    # Unpack
    Log 'Unpacking solution'
    & "$solutionPackager" /action:Extract /zipfile:"$solutionFolder\$solutionName.zip" /folder:"$unpackFolder\$solutionName" /packagetype:Both /allowWrite:Yes /allowDelete:Yes


    # Cleanup
    Log "Cleanup"
    Remove-Tree $solutionFolder
    New-Item -ItemType directory -Path $solutionFolder
    New-Item -ItemType file -Path "$solutionFolder\.placeholder"


    # Commit & push
    Log "Pushing changes to remote"
    git config --global user.email $gitEmail
    git config --global user.name $gitName

    git add $unpackFolder
    git commit -m "$solutionName solution extract $branchName"
    git push


    # Create PR
    if ($isExisingBranch) {
        Log "Skipping PR creation because branch already exists"
    } else {
    Log "Creating Pull Request"
    CreatePullRequestRoot `
        -sourceBranch $branchName `
        -targetBranch $mainBranchName `
            -title "$solutionName solution extract"
    }
        
}

ExtractSolutionAndCreatePR