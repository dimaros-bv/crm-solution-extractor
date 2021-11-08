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

    $repositoryUrl = Get-VstsInput -Name 'repositoryUrl'
    $gitEmail = Get-VstsInput -Name 'gitEmail'
    $gitName = Get-VstsInput -Name 'gitName'
    $mainBranchName = Get-VstsInput -Name 'mainBranchName'
    $branchName = Get-VstsInput -Name 'branchName'
    $connectionString = Get-VstsInput -Name 'connectionString'
    $solutionName = Get-VstsInput -Name 'solutionName'
    $solutionFolder = Get-VstsInput -Name 'solutionFolder'
    $unpackFolder = Get-VstsInput -Name 'unpackFolder'

    # Checkout
    Write-Host 'Project Checkout'
    git init
    git remote add origin $repositoryUrl
    git pull origin $mainBranchName
    git checkout -b $branchName


    # Install
    Write-Host 'Installing necessary tooling'
    Install-Module -Name Microsoft.Xrm.Data.Powershell
    Install-Package Microsoft.CrmSdk.CoreTools -RequiredVersion 9.1.0.92 -Destination $env:TEMP
    $solutionPackager = "$env:TEMP\Microsoft.CrmSdk.CoreTools.9.1.0.92\content\bin\coretools\SolutionPackager.exe"


    # Connect to CRM
    Write-Host 'Getting crm connection'
    $conn = Get-CrmConnection -ConnectionString $connectionString

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

    git add .
    git commit -m "$solutionName solution extract $branchName"
    git push --set-upstream origin $branchName


    # Create PR
    Write-Host "Creating PR"
    az repos pr create --delete-source-branch --source-branch $branchName --target-branch $mainBranchName --title $branchName
}

ExtractSolutionAndCreatePR