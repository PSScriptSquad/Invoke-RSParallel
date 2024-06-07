function Get-TimeSpanString {
    <#
      .SYNOPSIS
          Converts a TimeSpan object into a human-readable string.    
      .DESCRIPTION
          This function takes a TimeSpan object and converts it into a human-readable string format, showing days, hours, minutes, and seconds.    
      .PARAMETER TimeSpan
          The TimeSpan object to convert into a string.
      .PARAMETER RoundTo
          The unit to round the TimeSpan to. Can be 'Day', 'Hour', 'Minute', or 'Second'. Default is no rounding.  
      .EXAMPLE
          Get-TimeSpanString -TimeSpan "5.12:30:15" -RoundTo Hour
          Converts the TimeSpan "5 days, 13 hours" into a string.    
      .NOTES
          Name: Get-TimeSpanString
          Author: Ryan Whitlock
          Date: 01.11.2024
          Version: 2.0
          Changes: Ensured no trailing commas in the output string
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$True, Position=0, ValueFromPipeline=$true)]
        [ValidateNotNullOrEmpty()]
        [TimeSpan]$TimeSpan,

        [ValidateSet('Day', 'Hour', 'Minute', 'Second')]
        [string]$RoundTo
    )

    # Round the TimeSpan to the specified unit
    switch ($RoundTo) {
        'Day' {
            $TimeSpan = [timespan]::FromDays([math]::Round($TimeSpan.TotalDays))
            break
        }
        'Hour' {
            $TimeSpan = [timespan]::FromHours([math]::Round($TimeSpan.TotalHours))
            break
        }
        'Minute' {
            $TimeSpan = [timespan]::FromMinutes([math]::Round($TimeSpan.TotalMinutes))
            break
        }
        'Second' {
            $TimeSpan = [timespan]::FromSeconds([math]::Round($TimeSpan.TotalSeconds))
            break
        }
    }

    # Format each component of TimeSpan
    $Day = if ($TimeSpan.Days -eq 1) { "1 Day" } elseif ($TimeSpan.Days -gt 1) { "$($TimeSpan.Days) Days" } else { $null }
    $Hour = if ($TimeSpan.Hours -eq 1) { "1 Hour" } elseif ($TimeSpan.Hours -gt 1) { "$($TimeSpan.Hours) Hours" } else { $null }
    $Minute = if ($TimeSpan.Minutes -eq 1) { "1 Minute" } elseif ($TimeSpan.Minutes -gt 1) { "$($TimeSpan.Minutes) Minutes" } else { $null }
    $Second = if ($TimeSpan.Seconds -eq 1) { "1 Second" } elseif ($TimeSpan.Seconds -gt 1) { "$($TimeSpan.Seconds) Seconds" } else { $null }

    # Construct the final string
    $TimeComponents = @($Day, $Hour, $Minute, $Second) | Where-Object { $_ -ne $null }
    return "$($TimeComponents -join ', ')".Trim()
}
