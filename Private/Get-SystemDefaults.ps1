function Get-SystemDefaults {
    <#
    .SYNOPSIS
        Retrieves system-created default variables, modules, Snapins, and functions.
    .DESCRIPTION
        This function retrieves the system-created default variables, modules, Snapins, and functions. 
        These defaults can be used for comparison with user-defined items.
    .NOTES
        Name: Get-SystemDefaults
        Author: Ryan Whitlock
        Date: 01.11.2024
        Version: 1.0
    #>
    [CmdletBinding()]
    param()

    process {
        # Create a clean PowerShell instance to load system-created default items
        $StandardUserEnv = [powershell]::Create().addscript({
            # Define a temporary function to retrieve its parameters
            Function _temp {[cmdletbinding(SupportsShouldProcess=$True)] param() }

            # Gather system-created defaults
            [PSCustomObject]@{
                Modules     = Get-Module | Select-Object -ExpandProperty Name
                Snapins     = Get-PSSnapin | Select-Object -ExpandProperty Name
                Functions   = Get-ChildItem function:\ | Select-Object -ExpandProperty Name
                # Combine variable names and parameters of the temporary function to get all variables
                Variables   = @((Get-Variable | Select-Object -ExpandProperty Name) + (Get-Command _temp | Select-Object -ExpandProperty parameters).Keys)
            }
        }, $true).invoke()[0]
    }

    end {
        Write-Output $StandardUserEnv
    }
}
