function New-RunspacePool {
    <#
        .SYNOPSIS
            Create a new runspace pool
        .DESCRIPTION
            This function creates a new runspace pool. This is needed to be able to run code multi-threaded.
        .EXAMPLE
            $pool = New-RunspacePool
            Description
            -----------
            Create a new runspace pool with default settings, and store it in the pool variable.
        .NOTES
            Name: New-RunspacePool
            Author: Ryan Whitlock, inspired by Øyvind Kallstad, RamblingCookieMonster and Mjolinor
            Date: 01.11.2024
            Version: 1.1
            Changes: Added comments, improved variable naming, and removed unnecessary checks.
    #>
    [CmdletBinding()]
    param(
        # The minimum number of concurrent threads to be handled by the runspace pool. The default is 1.
        [Parameter(HelpMessage='Minimum number of concurrent threads')]
        [ValidateRange(1,65535)]
        [int]$MinimumRunspaces = 1,
 
        # The maximum number of concurrent threads to be handled by the runspace pool. The default is 20.
        [Parameter(HelpMessage='Maximum number of concurrent threads')]
        [ValidateRange(1,65535)]
        [int]$MaximumRunspaces = 20,
 
        # Using this switch will set the apartment state to MTA.
        [Parameter()]
        [switch]$MTA,
 
        # Array of snap-ins to be added to the initial session state of the runspace object.
        [Parameter(HelpMessage='Array of SnapIns you want available for the runspace pool')]
        [switch]$ImportSnapins,
 
        # Array of modules to be added to the initial session state of the runspace object.
        [Parameter(HelpMessage='Array of Modules you want available for the runspace pool')]
        [switch]$ImportModules,
 
        # Array of functions to be added to the initial session state of the runspace object.
        [Parameter(HelpMessage='Array of Functions that you want available for the runspace pool')]
        [switch]$ImportFunctions,
 
        # Gets variables from the global scope to be added to the initial session state of the runspace object.
        [Parameter(HelpMessage='Gets Variables from global scope to be added to the initial session state of the runspace object')]
        [switch]$ImportVariables,

        # The maximum number of PowerShell instances to be created at one time. Helps with memory management.
        [Parameter(HelpMessage='Maximum number of concurrent PowerShell instances')]
        [int]$MaxQueue
    )
    # If global runspace array is not present, create it
    if (-not $global:runspaces) {
        $global:runspaces = New-Object System.Collections.ArrayList
    }
    # If global runspace counter is not present, create it
    if (-not $global:runspaceCounter) {
        $global:runspaceCounter = 0
    }
    
    # Initialize the max queue if not specified
    if (-not $PSBoundParameters.ContainsKey('MaxQueue')) {
        $MaxQueue = $MaximumRunspaces * 3 
    }

    # Create the initial session state
    $initialSessionState = [System.Management.Automation.Runspaces.InitialSessionState]::CreateDefault()
    
    # Get system-created default items to filter against
    $standardUserEnv = Get-SystemDefaults

    # Add any snap-ins to the session state object
    if ($ImportSnapins) {
        $userSnapins = @(Get-PSSnapin | Select-Object -ExpandProperty Name | Where-Object { $standardUserEnv.Snapins -notcontains $_ })
        Write-Verbose "Found Snapins to import: $(($userSnapins | Sort-Object) -join ', ')"
        if ($userSnapins.Count -gt 0) {
            foreach ($snapin in $userSnapins) {
                try {
                    [void]$initialSessionState.ImportPSSnapIn($snapin,[ref]$null)
                    Write-Verbose "Imported $snapin to Initial Session State"
                }
                catch {
                    Write-Warning $_.Exception.Message
                }
            }
        }
    }
 
    # Add any modules to the session state object
    if ($ImportModules) {
        $userModules = @(Get-Module | Where-Object { $standardUserEnv.Modules -notcontains $_.Name -and (Test-Path $_.Path -ErrorAction SilentlyContinue) } | Select-Object -ExpandProperty Path )
        Write-Verbose "Found Modules to import: $(($userModules | Sort-Object) -join ', ')"
        if ($userModules.Count -gt 0) {
            foreach ($module in $userModules) {
                try {
                    [void]$initialSessionState.ImportPSModule($module)
                    Write-Verbose "Imported $module to Initial Session State"
                }
                catch {
                    Write-Warning $_.Exception.Message
                }
            }
        }
    }
 
    # Add any functions to the session state object
    if ($ImportFunctions) {
        $userFunctions = @(Get-ChildItem function:\ | Where-Object { $standardUserEnv.Functions -notcontains $_.Name })
        Write-Verbose "Found Functions to import: $(($userFunctions | Sort-Object) -join ', ')"
        if ($userFunctions.Count -gt 0) {
            foreach ($function in $userFunctions) {
                try {
                    $initialSessionState.Commands.Add((New-Object System.Management.Automation.Runspaces.SessionStateFunctionEntry -ArgumentList $function.Name,$function.ScriptBlock))
                    Write-Verbose "Imported $function to Initial Session State"                    
                }
                catch {
                    Write-Warning $_.Exception.Message
                }
            }
        }
    }
 
    # Add any variables to the session state object
    if ($ImportVariables) {
        $userVariables = @(Get-Variable | Where-Object { -not ($standardUserEnv.Variables -contains $_.Name) })
        Write-Verbose "Found Variables to import: $(($userVariables | Sort-Object) -join ', ')"
        if ($userVariables.Count -gt 0) {
            foreach ($variable in $userVariables) {
                try {
                    $initialSessionState.Variables.Add((New-Object -TypeName System.Management.Automation.Runspaces.SessionStateVariableEntry -ArgumentList $variable.Name, $variable.Value, $null))
                    Write-Verbose "Imported $variable to Initial Session State"
                }
                catch {
                    Write-Warning $_.Exception.Message
                }
            }
        }
    }
 
    # Create the runspace pool
    $runspacePool = [System.Management.Automation.Runspaces.RunspaceFactory]::CreateRunspacePool($initialSessionState)
    [void]$runspacePool.SetMinRunspaces($MinimumRunspaces)
    [void]$runspacePool.SetMaxRunspaces($MaximumRunspaces)
    Write-Verbose 'Created runspace pool'
 
    # Set apartment state to MTA if MTA switch is used
    if ($MTA) {
        $runspacePool.ApartmentState = 'MTA'
        Write-Verbose 'ApartmentState: MTA'
    }
    else {
        Write-Verbose 'ApartmentState: STA'
    }
 
    # Open the runspace pool
    $runspacePool.Open()
    Write-Verbose 'Runspace Pool Open'
 
    # Return the runspace pool object
    Write-Output $runspacePool
}
