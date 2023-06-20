param (
  [string]$repositoryRoot,
  [string]$newBranchName,
  [string]$connectionString
)

# Mock Azure task specific functions
function Get-VstsInput {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory = $true)]
    [string]$Name
  )

  # Define your mock input values here
  $mockInputs = @{
    repositoryRoot             = "$repositoryRoot"
    gitEmail                   = "tests@dimaros.nl"
    gitName                    = "Integration Test"
    targetBranchName           = "main"
    newBranchName              = "$newBranchName"
    connectionString           = "$connectionString"
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

function Trace-VstsEnteringInvocation { }
function Trace-VstsLeavingInvocation { }

. "$PSScriptRoot\..\functions\ExtractSolutionAndCreatePR.ps1"

ExtractSolutionAndCreatePR