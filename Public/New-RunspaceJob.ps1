function New-RunspaceJob{
    <#
        .SYNOPSIS
            Create a new runspace job.
        .DESCRIPTION
            This function creates a new runspace job, executed in it's own runspace (thread).
        .EXAMPLE
            New-RunspaceJob -JobName 'Inventory' -ScriptBlock $code -Parameters $parameters
            Description
            -----------
            Execute code in $code with parameters from $parameters in a new runspace (thread).
        .NOTES
            Name: New-RunspaceJob
            Author: Øyvind Kallstad, Ryan Whitlock
            Date: 01.11.2024
            Version: 1.0
    #>
    [CmdletBinding()]
    param(
        # Optionally give the job a name.
        [Parameter()]
        [string]$JobName,
 
        # The code you want to execute.
        [Parameter(Mandatory = $true)]
        [System.Management.Automation.ScriptBlock]$ScriptBlock,
 
        # A working runspace pool object to handle the runspace job.
        [Parameter(Mandatory = $true)]
        [System.Management.Automation.Runspaces.RunspacePool]$RunspacePool,
 
        [Parameter(Mandatory=$true,ValueFromPipeline=$true)]
        [Alias('CN','__Server','IPAddress','Server','ComputerName')]
        [PSObject]$InputObject
    )    

    begin {
        $ScriptBlockAttributes = Convert-ScriptBlock -ScriptBlock $ScriptBlock -Parameters $Parameters

         # Initialize an ArrayList to hold all objects
        $allObjects = [System.Collections.ArrayList]@()

        $Bound = $PSBoundParameters.keys -contains "InputObject"
    }
    process {
         # Add objects to $allObjects based on whether InputObject is bound
        if ($Bound) {
            # If InputObject is bound, set $allObjects to the value of InputObject
            $allObjects = $InputObject
        } else {
            # If InputObject is not bound, add the piped object to the ArrayList
            [void]$allObjects.Add($_)
        }
    }
    end {
        foreach($Object in $allObjects) {
            # increment the runspace counter
            $global:runspaceCounter++
    
            # create a new runspace and set it to use the runspace pool object
            $runspace = [System.Management.Automation.PowerShell]::Create()
            $runspace.RunspacePool = $RunspacePool

            if ($VerbosePreference -eq 'Continue') {
                [void]$PowerShell.AddScript({$VerbosePreference = 'Continue'})
            }
        

            # add the scriptblock to the runspace
            [void]$runspace.AddScript($ScriptBlockAttributes.scriptblock)

            # $Using support from Boe Prox
            # Does NOT work here yet, scoping issue
            if ($ScriptBlockAttributes.UsingVariableData) {
                Foreach($UsingVariable in $ScriptBlockAttributes.UsingVariableData) {
                    Write-Verbose "Adding $($UsingVariable.Name) with value: $($UsingVariable.Value)"
                    [void]$PowerShell.AddArgument($UsingVariable.Value)
                }
            }    
 
            [void]$runspace.AddArgument($Object)

            # invoke the runspace and store in the global runspaces variable
            [void]$runspaces.Add(@{
                JobName = $JobName
                InvokeHandle = $runspace.BeginInvoke()
                Runspace = $runspace
                ID = $global:runspaceCounter
            })

            while ($runspaces.count -ge $Script:MaxQueue) {

                #run get-runspace data and sleep for a short while
                Receive-RunspaceJob
                Start-Sleep -Milliseconds 200
            }
        }
        Receive-RunspaceJob -wait
<#      if (-not $quiet) {
            Write-Progress -Id $ProgressId -Activity "Running Query" -Status "Starting threads" -Completed
        }#>   
        Write-Verbose 'Code invoked in runspace' 
    }
}
