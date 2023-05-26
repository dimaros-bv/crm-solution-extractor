# D365 Solution Extractor task

Azure pipelines task that extracts a Dynamics 365 solution and creates a PR.


## Requirements

- Dataverse Connection string. 
[See specifications](https://learn.microsoft.com/en-us/powershell/module/microsoft.xrm.tooling.crmconnector.powershell/get-crmconnection?view=pa-ps-latest#-connectionstring).
[See examples](https://learn.microsoft.com/en-us/power-apps/developer/data-platform/xrm-tooling/use-connection-strings-xrm-tooling-connect).
- Personal Access Token which will be used to create a new branch, make a commit and create pull request:
  - If built-in service user is used (aka `<Project Name> Build Services (<organization name>)`),
  then it requires _Create branch, Contribute, Contribute to pull requests_ permissions to a repository / project (changed under Project settings => Repositories => Security).
  - If PAT of a user is used, then it requires _read/write_ access in the _code scope_.

## Usage

```yaml
- task: D365SolutionExtractor@1
  inputs:
    newBranchName: 'solution-extract-$(Build.BuildNumber)'
    connectionString: '$(dataverseConnectionString)'
    solutionName: 'MyAwesomeSolution'
  env:
    System_AccessToken: $(System.AccessToken) # PAT of a built-in service user
```

## Features

### Push to the same branch.
If a branch already exists it will push the changes to this branch and **PR won't be created** in this case.

### Access to extracted solution files.
`<solution>.zip` and `<solution>_managed.zip` could be published from `$(Build.ArtifactStagingDirectory)/<solution>`.

## Parameters
| Label                       | Name                       | Description                                                                                                                                                                         | Default Value                         |
|-----------------------------|----------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|---------------------------------------|
| Repository Path             | repositoryRoot             | Sources path to be used to create a PR.                                                                                                                                             | $(Build.SourcesDirectory)             |
| Git Email                   | gitEmail                   | Email to be used for a commit.                                                                                                                                                      | $(Build.RequestedForEmail)            |
| Git Name                    | gitName                    | Name to be used for a commit.                                                                                                                                                       | $(Build.RequestedFor)                 |
| Target Branch Name          | targetBranchName           | Branch name to create a PR against.                                                                                                                                                 | main                                  |
| New Branch Name             | newBranchName              | Branch name to create a PR from.                                                                                                                                                    | solution-extract-$(Build.BuildNumber) |
| Dataverse connection string | connectionString           | Dataverse connection string to be used. [See examples](https://learn.microsoft.com/en-us/power-apps/developer/data-platform/xrm-tooling/use-connection-strings-xrm-tooling-connect) |                                       |
| Operation timeout (minutes) | connectionTimeoutInMinutes | Maximum number in minutes to wait before quitting the operation.                                                                                                                    | 20                                    |
| Solution                    | solutionName               | Solution Name.                                                                                                                                                                      |                                       |
| Unpack Folder               | unpackFolder               | Folder within the repository to unpack solution to.                                                                                                                                 | Solution                              |
| CrmSdk version              | crmSdkPackageVersion       | Package version for [Microsoft.CrmSdk.CoreTools](https://www.nuget.org/packages/Microsoft.CrmSdk.CoreTools/).                                                                       | 9.1.0.115                             |

## Release notes
- 1.0.0 Initial publish.