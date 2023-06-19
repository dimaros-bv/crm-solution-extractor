function Get-VstsInput {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory = $true)]
    [string]$Name
  )

  # Define your mock input values here
  $mockInputs = @{
    repositoryRoot             = "$env:BUILD_SOURCESDIRECTORY"
    gitEmail                   = "tests@dimaros.nl"
    gitName                    = "Integration Test"
    targetBranchName           = "main"
    newBranchName              = "solution-extract-$env:BUILD_BUILDNUMBER"
    connectionString           = "$env:CRMCONNECTION"
    connectionTimeoutInMinutes = "20"
    solutionName               = "PRTestSln"
    unpackFolder               = "Solution"
    crmSdkPackageVersion       = "9.1.0.115"
  }

  # Return the mock input value based on the input name
  if ($mockInputs.ContainsKey($Name)) {
    return $mockInputs[$Name]
  }
  else {
    throw "Mock input '$Name' not found."
  }
}

. "$PSScriptRoot\..\functions\ExtractSolutionAndCreatePR.ps1"

ExtractSolutionAndCreatePR