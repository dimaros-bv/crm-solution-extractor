. ".\createPullRequest.ps1"

function Get-Tree($Path, $Include = '*') { 
    @(Get-Item $Path -Include $Include -Force) + 
    (Get-ChildItem $Path -Recurse -Include $Include -Force) | 
    Sort-Object pspath -Descending -unique
} 

function Remove-Tree($Path, $Include = '*') { 
    Get-Tree $Path $Include | Remove-Item -force -recurse
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

    # Checkout
    Write-Host 'Creating separate branch'
    Set-Location -Path $repositoryRoot
    git checkout -b $branchName


    # Install
    Write-Host 'Installing necessary tooling'
    Install-Module -Name Microsoft.Xrm.Data.Powershell -Force
    Install-Package Microsoft.CrmSdk.CoreTools -RequiredVersion 9.1.0.92 -Destination $env:TEMP -Force
    $solutionPackager = "$env:TEMP\Microsoft.CrmSdk.CoreTools.9.1.0.92\content\bin\coretools\SolutionPackager.exe"


    # Connect to CRM
    Write-Host 'Getting crm connection'
    $conn = Get-CrmConnection -ConnectionString $connectionString -MaxCrmConnectionTimeOutMinutes [int]$connectionTimeoutInMinutes
    Write-Host "Connection Timeout in Minutes:" $conn.OrganizationWebProxyClient.Endpoint.Binding.SendTimeout.TotalMinutes

    # Publish customizations
    Write-Host 'Publishing all customizations'
    Publish-CrmAllCustomization -conn $conn


    # Export
    If (!(test-path $solutionFolder)) {
        New-Item -ItemType Directory -Force -Path $solutionFolder
    }
    Write-Host 'Exporting unmanaged solution'
    Export-CrmSolution -conn $conn -SolutionName $solutionName -SolutionFilePath $solutionFolder -SolutionZipFileName "$solutionName.zip"

    Write-Host 'Exporting managed solution'
    Export-CrmSolution -conn $conn -SolutionName $solutionName -SolutionFilePath $solutionFolder -SolutionZipFileName "$($solutionName)_managed.zip" -Managed


    # Unpack
    Write-Host 'Unpacking solution'
    & "$solutionPackager" /action:Extract /zipfile:"$solutionFolder\$solutionName.zip" /folder:"$unpackFolder\$solutionName" /packagetype:Both /allowWrite:Yes /allowDelete:Yes


    # Cleanup
    Write-Host "Cleanup"
    Remove-Tree $solutionFolder
    New-Item -ItemType directory -Path $solutionFolder
    New-Item -ItemType file -Path "$solutionFolder\.placeholder"


    # Commit & push
    Write-Host "Pushing changes to remote"
    git config --global user.email $gitEmail
    git config --global user.name $gitName

    git add $unpackFolder
    git commit -m "$solutionName solution extract $branchName"
    git push --set-upstream origin $branchName


    # Create PR
    Write-Host "Creating PR"
    CreatePullRequestRoot `
        -sourceBranch $branchName `
        -targetBranch $mainBranchName `
        -title $branchName 
        
}

ExtractSolutionAndCreatePR