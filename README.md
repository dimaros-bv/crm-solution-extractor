# D365 Solution Extractor task

Azure pipelines task that extracts a Dynamics 365 solution and creates a PR.


## Requirements

- Dataverse Connection string. 
[See specifications](https://learn.microsoft.com/en-us/powershell/module/microsoft.xrm.tooling.crmconnector.powershell/get-crmconnection?view=pa-ps-latest#-connectionstring).
[See examples](https://learn.microsoft.com/en-us/power-apps/developer/data-platform/xrm-tooling/use-connection-strings-xrm-tooling-connect).
- Personal Access Token which will be used to create a new branch, make a commit and create pull request:
  - If build-in service user is used (aka `<Project Name> Build Services (<organization name>)`),
  then it requires _Create branch, Contribute, Contribute to pull requests_ permissions to a repository / project (changed under Project settings => Repositories => Security).
  - If PAT of a user is used, then it requires _read/write_ access in the _code scope_.

## Usage

```yaml
- task: D365SolutionExtractor@1
  inputs:
    branchName: 'solution-extract-$(Build.BuildNumber)'
    connectionString: '$(crmConnection)'
    solutionName: 'MyAwesomeSolution'
  env:
    System_AccessToken: $(System.AccessToken) // PAT of a build-in service user
```

## Features

### Push to the same branch.
If a branch already exists it will push the changes to this branch and **PR won't be created** in this case.

## Release notes
- 1.0.0 Initial publish.