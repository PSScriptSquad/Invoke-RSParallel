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
        .EXAMPLE
            $pool = New-RunspacePool -Snapins 'vmware.vimautomation.core'
            Description
            -----------
            Create a new runspace pool with the VMWare PowerCli snapin added, and store it in the pool variable.
        .NOTES
            Name: New-RunspacePool
            Author: Ryan Whitlock, inspired by Øyvind Kallstad, RamblingCookieMonster and Mjolinor  
            Date: 10.02.2014
            Version: 1.0
    #>
    [CmdletBinding()]
    param(
        # The minimun number of concurrent threads to be handled by the runspace pool. The default is 1.
        [Parameter(HelpMessage='Minimum number of concurrent threads')]
        [ValidateRange(1,65535)]
        [int32]$minRunspaces = 1,
 
        # The maximum number of concurrent threads to be handled by the runspace pool. The default is 20.
        [Parameter(HelpMessage='Maximum number of concurrent threads')]
        [ValidateRange(1,65535)]
        [int32]$maxRunspaces = 20,
 
        # Using this switch will set the apartment state to MTA.
        [Parameter()]
        [switch]$MTA,
 
        # Array of snapins to be added to the initial session state of the runspace object.
        [Parameter(HelpMessage='Array of SnapIns you want available for the runspace pool')]
        [switch]$ImportSnapins,
 
        # Array of modules to be added to the initial session state of the runspace object.
        [Parameter(HelpMessage='Array of Modules you want available for the runspace pool')]
        [switch]$ImportModules,
 
        # Array of functions to be added to the initial session state of the runspace object.
        [Parameter(HelpMessage='Array of Functions that you want available for the runspace pool')]
        [switch]$ImportFunctions,
 
        # Gets Variables from global scope to be added to the initial session state of the runspace object.
        [Parameter(HelpMessage='Gets Variables from global scope to be added to the initial session state of the runspace object')]
        [switch]$ImportVariables,

        # The maximum number of Powershell instances to be created at one time. Helps with memory management.
        [Parameter(HelpMessage='Maximum number of concurrent Powershell instances')]
        [int]$MaxQueue
    )
 
    # if global runspace array is not present, create it
    if(-not $global:runspaces){
        $global:runspaces = New-Object System.Collections.ArrayList
    }
    # if global runspace counter is not present, create it
    if(-not $global:runspaceCounter){
        $global:runspaceCounter = 0
    }
    
    
    #No max queue specified?  Estimate one.
    if( -not $PSBoundParameters.ContainsKey('MaxQueue') ) {
        $script:MaxQueue = $maxRunspaces * 3 
    } else {
        $script:MaxQueue = $MaxQueue
    }   
    
    # create the initial session state
    $iss = [System.Management.Automation.Runspaces.InitialSessionState]::CreateDefault()
    
    # Get System-Created default items to filter against
    $StandardUserEnv = Get-SystemCreatedDefaults

    # add any snapins to the session state object
    if($ImportSnapins){
        $UserSnapins = @( Get-PSSnapin | Select-Object -ExpandProperty Name | Where-Object {$StandardUserEnv.Snapins -notcontains $_ })
        Write-Verbose "Found Snapins to import: $(($UserSnapins | Select-Object -expandproperty Name | Sort-Object ) -join ", " | Out-String).`n"
        if($UserSnapins.count -gt 0){
            foreach ($PSSnapin in $UserSnapins){
                try{
                    [void]$iss.ImportPSSnapIn($PSSnapin,[ref]$null)
                    Write-Verbose "Imported $snapName to Initial Session State"
                }
                catch{
                    Write-Warning $_.Exception.Message
                }
            }
        }
    }
 
    # add any modules to the session state object
    if($ImportModules){
        $UserModules = @( Get-Module | Where-Object {$StandardUserEnv.Modules -notcontains $_.Name -and (Test-Path $_.Path -ErrorAction SilentlyContinue)} | Select-Object -ExpandProperty Path )
        Write-Verbose "Found Modules to import: $(($UserModules | Select-Object -expandproperty Name | Sort-Object ) -join ", " | Out-String).`n"
        if($UserModules.count -gt 0){
            foreach($module in $UserModules){
                try{
                    [void]$iss.ImportPSModule($module)
                    Write-Verbose "Imported $module to Initial Session State"
                }
                catch{
                    Write-Warning $_.Exception.Message
                }
            }
        }
    }
 
    # add any functions to the session state object
    if($ImportFunctions){
        $UserFunctions = @( Get-ChildItem function:\ | Where-Object {$StandardUserEnv.Functions -notcontains $_.Name })
        Write-Verbose "Found Functions to import: $( ($UserFunctions | Select-Object -expandproperty Name | Sort-Object ) -join ", " | Out-String).`n"
        if($UserFunctions.count -gt 0){
            foreach($Function in  $UserFunctions){
                try{
                    $iss.Commands.Add((New-Object System.Management.Automation.Runspaces.SessionStateFunctionEntry -ArgumentList $Function.Name,$Function.ScriptBlock))
                    Write-Verbose "Imported $Function to Initial Session State"                    
                }
                catch{
                    Write-Warning $_.Exception.Message
                }
            }
        }
    }
 
    # add any variables to the session state object
    if($ImportVariables){
        $UserVariables = @( Get-Variable | Where-Object { -not ($StandardUserEnv.Variables -contains $_.Name) } )
        Write-Verbose "Found variables to import: $( ($UserVariables | Select-Object -expandproperty Name | Sort-Object ) -join ", " | Out-String).`n"
        if($UserVariables.count -gt 0){
            foreach($Variable in $UserVariables){
                try{
                    $iss.Variables.Add((New-Object -TypeName System.Management.Automation.Runspaces.SessionStateVariableEntry -ArgumentList $Variable.Name, $Variable.Value, $null))
                    Write-Verbose "Imported $var to Initial Session State"
                }
                catch{
                    Write-Warning $_.Exception.Message
                }
            }
        }
    }
 
    # create the runspace pool
    $runspacePool = [System.Management.Automation.Runspaces.RunspaceFactory]::CreateRunspacePool($iss)
    [void]$runspacePool.SetMinRunspaces($minRunspaces)
    [void]$runspacePool.SetMaxRunspaces($maxRunspaces)
    Write-Verbose 'Created runspace pool'
 
    # set apartmentstate to MTA if MTA switch is used
    if($MTA){
        $runspacePool.ApartmentState = 'MTA'
        Write-Verbose 'ApartmentState: MTA'
    }
    else {
        Write-Verbose 'ApartmentState: STA'
    }
 
    # open the runspace pool
    $runspacePool.Open()
    Write-Verbose 'Runspace Pool Open'
 
    # return the runspace pool object
    Write-Output $runspacePool
}
