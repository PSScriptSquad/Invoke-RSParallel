function Invoke-Runspace {
    <#
        .SYNOPSIS
            Executes a script block in parallel across multiple runspaces.

        .DESCRIPTION
            This function leverages runspaces to execute a script block in parallel for each input object. It supports logging and dynamic import of necessary modules, functions, and variables into each runspace.

        .PARAMETER RunspacePool
            The runspace pool to use for executing the script block.

        .PARAMETER ScriptBlock
            The script block to execute in each runspace.

        .PARAMETER InputObject
            The input object to pass to the script block.

        .PARAMETER LogPath
            Optional path to a directory where logs will be saved.

        .EXAMPLE
            $pool = New-RunspacePool
            $scriptBlock = { param($input) Start-Sleep -Seconds $input }
            1..10 | Invoke-Runspace -RunspacePool $pool -ScriptBlock $scriptBlock

        .EXAMPLE
            $pool = New-RunspacePool
            $scriptBlock = { param($input) Start-Sleep -Seconds $input }
            1..10 | Invoke-Runspace -RunspacePool $pool -ScriptBlock $scriptBlock -LogPath "C:\Logs"

        .NOTES
            Name: Manage-Runspace
            Author: Ryan Whitlock
            Date: 06.25.2024
            Version: 1.0
            Changes: Initial release
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [System.Management.Automation.Runspaces.RunspacePool]$RunspacePool,

        [Parameter(Mandatory = $true)]
        [System.Management.Automation.ScriptBlock]$ScriptBlock,

        [Parameter(Mandatory=$true,ValueFromPipeline=$true)]
        [PSObject]$InputObject,

        [Parameter(Mandatory = $false)]
        [ValidateScript({ Test-Path -Path $_ -PathType Container })]
        [System.IO.Fileinfo]$LogPath
    )
    begin {
        if ($PSBoundParameters.ContainsKey('LogPath')) {
            $Global:LoggingEnabled = $true
            $LogFilePath = Join-Path -Path $LogPath -ChildPath "RunspaceLog.csv"
        }

        $allObjects = [System.Collections.ArrayList]@()
        $ScriptBlockAttributes = Convert-ScriptBlock -ScriptBlock $ScriptBlock -Parameters $Parameters
        $Bound = $PSBoundParameters.keys -contains "InputObject"
        $Inputs = New-Object 'System.Management.Automation.PSDataCollection[PSObject]'
        $Results = New-Object 'System.Management.Automation.PSDataCollection[PSObject]'

        $SaveJobData = {
            $EndDate = Get-Date
            $JobData = [PSCustomObject]@{
                ID = $Job.ID
                State = $Job.State
                StartTime = $Job.StartTime
                EndTime = $EndDate
                Duration = New-TimeSpan -Start $Job.StartTime -End $EndDate            
                HadErrors = $Job.Instance.HadErrors
                Verbose = $Job.Instance.Streams.Verbose.ReadAll() | Out-String
                Error = $Job.Instance.Streams.Error | ForEach-Object { $_.Exception.Message }
                Warning = $Job.Instance.Streams.Warning.ReadAll() | Out-String
                Debug = $Job.Instance.Streams.Debug[1..($Job.Instance.Streams.Debug.Count - 2)] | Out-String
            }

            $JobData | Export-Csv -Path $LogFilePath -Append -NoTypeInformation
        }
    }

    process {
        if ($Bound) {
            $allObjects = $InputObject
        } else {
            [void]$allObjects.Add($_)
        }
    }

    end {
        foreach ($Object in $allObjects) {            
            $global:runspaceCounter++
            Write-ProgressHelper -i $global:runspaceCounter -TotalCount $allObjects.count -Activity 'Running Scripts'

            $PSInstance = [System.Management.Automation.PowerShell]::Create()
            $PSInstance.RunspacePool = $RunspacePool

            [void]$PSInstance.AddScript($ScriptBlockAttributes.ScriptBlock)

            if ($ScriptBlockAttributes.UsingVariableData) {
                foreach ($UsingVariable in $ScriptBlockAttributes.UsingVariableData) {
                    Write-Verbose "Adding $($UsingVariable.Name) with value: $($UsingVariable.Value)"
                    [void]$PSInstance.AddArgument($UsingVariable.Value)
                }
            }

            [void]$PSInstance.AddArgument($Object)

            $job = @{
                InvokeHandle = $PSInstance.BeginInvoke($Inputs, $Results)
                Instance = $PSInstance
                StartTime = Get-Date
                ID = $global:runspaceCounter
            }

            [void]$global:runspaces.Add($job)

            Remove-RunspaceJob

            while ($global:runspaces.Count -ge $global:MaxQueue) {
                Remove-RunspaceJob
                Start-Sleep -Milliseconds 200
            }
        }

        Remove-RunspaceJob -Wait
        $RunspacePool.Close()
        $global:runspaceCounter = $null
        [gc]::Collect()
        return $Results
    }
}
