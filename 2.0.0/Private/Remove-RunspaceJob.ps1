function Remove-RunspaceJob {
    <#
        .SYNOPSIS
            Removes completed runspace jobs from the global runspace pool.

        .DESCRIPTION
            The Remove-RunspaceJob function checks for completed jobs in the global runspace pool, logs data if logging is enabled, 
            disposes of the completed jobs, and removes them from the global runspace pool. The function can optionally wait until 
            all jobs are finished if the -Wait switch is used.

        .PARAMETER Wait
            Using this switch will wait until all jobs are finished before removing them.

        .EXAMPLE
            # Remove completed jobs from the runspace pool.
            Remove-RunspaceJob

            # Remove completed jobs and wait for all jobs to finish before removing them.
            Remove-RunspaceJob -Wait

        .NOTES
            Name: Remove-RunspaceJob
            Author: Ryan Whitlock
            Date: 06.25.2024
            Version: 1.0
            Changes: Initial release
    #>
    [CmdletBinding()]
    param(
        # Wait for all jobs to finish.
        [Parameter(HelpMessage = 'Using this switch will wait until all jobs are finished')]
        [switch]$Wait
    )

    do {
        $more = $false

        $CompletedJobs = $global:Runspaces | Where-Object { $_.InvokeHandle.IsCompleted }
        if ($null -ne $CompletedJobs) {
            foreach ($job in $CompletedJobs) {
                try {
                    $job.State = $job.Instance.InvocationStateInfo.State

                    if ($Global:LoggingEnabled) {
                        .$SaveJobData
                    }

                    $script:completedCount++
                    $job.Instance.Dispose()
                    $job.Instance = $null
                    $job.InvokeHandle = $null
                    $global:Runspaces.Remove($job)
                } catch {
                    Write-Error "Error processing job: $($_.Exception.Message)"
                }
            }
        } elseif ($global:Runspaces | Where-Object { $_.InvokeHandle -ne $null }) {
            $more = $true
        }
    } while ($more -and $PSBoundParameters['Wait'])
}
