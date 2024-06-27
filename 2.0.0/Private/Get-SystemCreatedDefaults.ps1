function Get-SystemCreatedDefaults {
    <#
        .SYNOPSIS
            Gets Default variables, modules, Snapins, and functions
        .DESCRIPTION
            This function gets the System-Created default variables, modules, Snapins, and functions. This is needed to be able to filter against to get user defined items.
        .NOTES
            Name: Get-SystemCreatedItems
            Author: Ryan Whitlock
            Date: 01.11.2024
            Version: 1.0
    #>
    [CmdletBinding()]
    param()
    process {
        try {
            # Create a clean PowerShell instance to load system-created default items
            $StandardUserEnv = [powershell]::Create().addscript({
                Function _temp {[cmdletbinding(SupportsShouldProcess=$True)] param() }
                [PSCustomObject]@{                    
                    Modules     = Get-Module | Select-Object -ExpandProperty Name
                    Snapins     = Get-PSSnapin | Select-Object -ExpandProperty Name
                    Functions   = Get-ChildItem function:\ | Select-Object -ExpandProperty Name
                    Variables   = @((Get-Variable | Select-Object -ExpandProperty Name) + (Get-Command _temp | Select-Object -ExpandProperty parameters).Keys)
                }
            },$true).invoke()[0]

            Write-Output $StandardUserEnv
        }
        catch {
            Write-Error "Failed to get system created defaults: $_"
        }
    }
}
