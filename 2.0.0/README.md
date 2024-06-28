## Module: Invoke-RSParallel

### Overview

The `Invoke-RSParallel` module provides a set of functions that enable efficient parallel execution of script blocks using PowerShell runspaces. This module is designed to maximize performance by leveraging multi-threading capabilities, making it ideal for tasks that require high concurrency and efficient resource management.

### Features

- **Parallel Execution**: Execute script blocks in parallel across multiple runspaces to improve performance and reduce execution time.
- **Runspace Management**: Create and manage runspace pools with configurable settings for optimal resource utilization.
- **Logging and Monitoring**: Optional logging of runspace execution details for monitoring and troubleshooting.
- **Dynamic Import**: Import necessary modules, functions, and variables into each runspace dynamically.
- **Progress Tracking**: Monitor the progress of parallel tasks with detailed progress reporting.

### Functions

1. **Convert-ScriptBlock**
    - **Description**: Converts a script block to support `$Using:` variables and applies parameters for execution in runspaces.
    - **Parameters**:
        - `ScriptBlock` (Mandatory): The script block to be converted.
        - `Parameters` (Optional): A hashtable of parameters to be added to the script block.

2. **Get-SystemCreatedDefaults**
    - **Description**: Retrieves system-created default variables, modules, snap-ins, and functions. This is useful for filtering out user-defined items.
    - **Parameters**: None.

3. **Remove-RunspaceJob**
    - **Description**: Removes completed runspace jobs from the global runspace pool. Optionally waits until all jobs are finished before removal.
    - **Parameters**:
        - `Wait` (Optional): Switch to wait until all jobs are finished before removing them.

4. **Write-ProgressHelper**
    - **Description**: Writes progress status to the console, displaying the current progress of tasks.
    - **Parameters**:
        - `i` (Mandatory): The current position in the progress.
        - `TotalCount` (Mandatory): The total count of items.
        - `Activity` (Mandatory): The activity description to display in the progress bar.
        - `CurrentOperation` (Optional): The description of the current operation to display in the progress bar.

5. **Invoke-Runspace**
    - **Description**: Executes a script block in parallel across multiple runspaces, supporting logging and dynamic import of necessary items.
    - **Parameters**:
        - `RunspacePool` (Mandatory): The runspace pool to use for executing the script block.
        - `ScriptBlock` (Mandatory): The script block to execute in each runspace.
        - `InputObject` (Mandatory, ValueFromPipeline): The input object to pass to the script block.
        - `LogPath` (Optional): Path to a directory where logs will be saved.

6. **New-RunspacePool**
    - **Description**: Creates a new runspace pool with configurable settings for concurrent threads and resource management.
    - **Parameters**:
        - `minRunspaces` (Optional): Minimum number of concurrent threads in the runspace pool (default: 1).
        - `maxRunspaces` (Optional): Maximum number of concurrent threads in the runspace pool (default: 20).
        - `MTA` (Optional): Switch to set the apartment state to MTA.
        - `ImportSnapins` (Optional): Switch to import snap-ins into the runspace pool.
        - `ImportModules` (Optional): Switch to import modules into the runspace pool.
        - `ImportFunctions` (Optional): Switch to import functions into the runspace pool.
        - `ImportVariables` (Optional): Switch to import variables into the runspace pool.
        - `MaxQueue` (Optional): Maximum number of PowerShell instances to be created at one time for memory management.

### Usage Examples

#### Example 1: Convert and Execute a Script Block in Parallel

```powershell
[System.Management.Automation.ScriptBlock]$ScriptBlock = { 
    param($IP)
     
    $CurrentWhoIs = $IP.clientIP | Get-WhoIs -ErrorAction SilentlyContinue
    [PSCustomObject]@{
        'clientIP' = $CurrentWhoIs.IP
        'reason' = $IP.reason
        'ymd' = $IP.ymd
        'RegisteredOrganization' = $CurrentWhoIs.RegisteredOrganization
        'CIDR' = $CurrentWhoIs.NetBlocks
        'City' = $CurrentWhoIs.City
        'State' = $CurrentWhoIs.State
        'Country' = $CurrentWhoIs.Country
    }       
}

$IPs = Import-Csv -Path "C:\Users\Ryan\Desktop\TorExit.csv" -Header clientIP
$RunspacePool = New-RunspacePool -ImportFunctions
$NewNewRuspaceCodeTime = Measure-Command  {
   $WhoIsNew = Invoke-Runspace –RunspacePool $RunspacePool –ScriptBlock $ScriptBlock -InputObject $IPs -LogPath C:\temp\
}
```
My Get-WhoIs function can be found [here](https://github.com/PSScriptSquad/GeneralUtilityScripts/blob/main/Get-WhoIs.ps1)


### Authors and Credits

- **Ryan Whitlock**: Primary author and maintainer.
- **Contributors**: Inspired by the work of Øyvind Kallstad, RamblingCookieMonster, Mjolinor, and Boe Prox.

### Version

- **Current Version**: 2.0.0
- **Release Date**: 2024-01-11

### Notes

- The module ensures efficient memory management and error handling throughout its functions.
- It is designed to work with PowerShell 5.1 and later versions, leveraging advanced features for parallel execution and runspace management.
