function Receive-RunspaceJob {
    <#
        .SYNOPSIS
            Receive data back from a runspace job.
        .DESCRIPTION
            This function checks for completed runspace jobs, and retrieves the return data.
        .EXAMPLE
            Receive-RunspaceJob -Wait
            Description
            -----------
            Will wait until all runspace jobs are complete and retrieve data back from all of them.
        .EXAMPLE
            Receive-RunspaceJob -JobName 'Inventory'
            Description
            -----------
            Will get data from all completed jobs with the JobName 'Inventory'.
        .NOTES
            Name: Receive-RunspaceJob
            Author: Ryan Whitlock, inspired by Øyvind Kallstad, RamblingCookieMonster and Mjolinor  
            Date: 01.11.2024
            Version: 1.0
    #>
    [CmdletBinding()]
    param(
        # Only get results from named job.
        [Parameter()]
        [string]$JobName,

        # Only get the results from job with this ID.
        [Parameter()]
        [int] $ID,
 
        # Wait for all jobs to finish.
        [Parameter(HelpMessage='Using this switch will wait until all jobs are finished')]
        [switch]$Wait,

        # Timeout in seconds until breaking free of the wait loop.
        [Parameter()]
        [int] $TimeOut = 60,
 
        # Not implemented yet!
        [Parameter(HelpMessage='Not implemented yet!')]
        [switch]$ShowProgress,

        [Parameter()]
        [System.IO.FileInfo]$LogFile = 'C:\temp\Test1.log'
    )

    $startTime = Get-Date
 
    do{
        $more = $false
 
        # handle filtering of runspaces
        $filteredRunspaces = $global:runspaces.Clone()
        		
        if($JobName){
            $filteredRunspaces = $filteredRunspaces | Where-Object {$_.JobName -eq $JobName}
        }

        if ($ID) {
            $filteredRunspaces = $filteredRunspaces | Where-Object {$_.ID -eq $ID}
        }

        # need to get vars
        if ($ShowProgress) {
            Write-Progress -Id $ID -Activity "Running Query" -Status "Starting threads"`
                -CurrentOperation "$startedCount threads defined - $totalCount input objects - $script:completedCount input objects processed"`
                -PercentComplete $( Try { $script:completedCount / $totalCount * 100 } Catch {0} )
        }
 
        # iterate through the runspaces
        foreach ($runspace in $filteredRunspaces){
            if ($null -ne $Matches){
                $Matches.Clear()
            }
            if (($null -eq $runspace.startTime) -and ($runspace.Runspace.Streams.Information[0] -match 'Start\(Ticks\) = (?<TicksStart>\d+)')){ 
                $runspace.startTime =  [DateTime]([Int64]$Matches.TicksStart)
            }

            $log = "" | Select-Object -Property Status, Duration, Error, Warning, startTime, EndTime
            $log.StartTime = $runspace.startTime                        
            $log.status = $runspace.powershell.InvocationStateInfo.State


            # If job is finished, write the result to the pipeline and dispose of the runspace.
            if ($runspace.InvokeHandle.isCompleted){
                #Data is not cleared from previous cycle run       
                $caughtErrors = $null   
                Try {           
                    Write-Output $runspace.Runspace.EndInvoke($runspace.InvokeHandle)
                } Catch {
                    $caughtErrors = $Error  
                } 
                $script:completedCount++

                If ($runspace.Runspace.Streams.Error -OR $caughtErrors) {
                    $log.status = "CompletedWithErrors"                        
                    $ErrorList = New-Object System.Management.Automation.PSDataCollection[System.Management.Automation.ErrorRecord]
                    If ($runspace.Runspace.Streams.Error) {
                        ForEach ($e in $runspace.Runspace.Streams.Error) {                                
                            [void]$ErrorList.Add($e)
                        }
                    }
                    If ($CaughtErrors) {
                        ForEach ($e in $CaughtErrors) {                                
                            [void]$ErrorList.Add($e)
                        }                    
                    }
                    $log.Error = $ErrorList
                    Write-Verbose ($log | ConvertTo-Csv -Delimiter ";" -NoTypeInformation)[1]                      
                }else {
                    #add logging details and cleanup
                    $log.status = "Completed"
                    Write-Verbose ($log | ConvertTo-Csv -Delimiter ";" -NoTypeInformation)[1]
                }

                If ($runspace.Runspace.Streams.Warning){
                    $WarningList = New-Object System.Management.Automation.PSDataCollection[System.Management.Automation.WarningRecord]
                    foreach ($w in $($runspace.Runspace.Streams.Warning)) {
                        [void]$WarningList.Add($w)                    
                    }
                        $log.Warning = $WarningList                         
                }

                foreach ($v in $($runspace.Runspace.Streams.Verbose)) {
                    Write-Verbose -Message $v
                } 

                if ($null -ne $Matches){
                    $Matches.Clear()
                }
                if ($runspace.Runspace.Streams.Information[-1] -match 'End\(Ticks\) = (?<TicksEnd>\d+)'){  
                    $log.EndTime = [DateTime]([Int64]$Matches.TicksEnd)
                }

                If ($null -ne $runspace.startTime -and $Null -ne $Log.EndTime){
                    $log.Duration = '{0:f2} ms' -f ($Log.EndTime - $runspace.startTime).totalmilliseconds
                }else{
                    $log.Duration = $null
                }
                
                # Clean up the runspace 
                $runspace.Runspace.Dispose()
                $runspace.Runspace = $null
                $runspace.InvokeHandle = $null
                $runspaces.Remove($runspace)
                Write-Verbose 'Job received'
            }
 
            # If invoke handle is still in place, the job is not finished.
            elseif ($runspace.InvokeHandle -ne $null){
                $log = $null
                $more = $true
            }

            #log the results if a log file was indicated
            if($logFile -and $log) {
                ($log | ConvertTo-Csv -Delimiter ";" -NoTypeInformation)[1] | out-file $LogFile -append
            }
        }

        # break free of wait loop if timeout is exceeded
        if ((New-TimeSpan -Start $startTime).TotalSeconds -ge $TimeOut) {
            Write-Verbose 'Timeout exceeded - breaking out of loop'
            $more = $false
        }
 
    }
    while ($more -and $PSBoundParameters['Wait'])
}
