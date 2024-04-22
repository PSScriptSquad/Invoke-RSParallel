function Convert-ScriptBlock {
    <#
        .SYNOPSIS
            The Convert-ScriptBlock function converts a script block with parameters into a format suitable 
            for execution in a runspace (thread).
        .DESCRIPTION
            This function takes a script block and a hashtable of parameters and prepares them to be used 
            in a runspace, which is useful for running code asynchronously or in parallel. It extracts the 
            parameters from the script block and adds them to a param block, along with any additional parameters 
            specified in the Parameters hashtable. It also handles the use of Using: variables based on Boe Prox's 
            method in the script block, and makes sure they are properly referenced. Additionally, the function 
            includes code to accurately track the start and end times of each thread. This allows for precise timing 
            measurements within the threads.
        .EXAMPLE
            Convert-ScriptBlock -ScriptBlock $code -Parameters $parameters
            Description
            -----------
            Converts code in $code with parameters from $parameters to be used in a runspace (thread).
        .NOTES
            Name: Convert-ScriptBlock
            Author: Ryan Whitlock
            Date: 01.11.2024
            Version: 1.1
            Changes: Added comments, improved clarity and readability.
    #>
    [CmdletBinding()]
    param(
        # The code you want to execute.
        [Parameter(Mandatory = $true)]
        [System.Management.Automation.ScriptBlock]$ScriptBlock,

        # Hashtable of parameters to add to the runspace scriptblock.
        [Parameter()]
        [HashTable]$Parameters
    )

    # Start building parameter names for the param block
    # Add existing parameter(s) to $ParamsToAdd array
    if ($scriptBlock.Ast.ParamBlock){
        [string[]]$ParamsToAdd = $scriptBlock.Ast.ParamBlock.Parameters.Name | ForEach-Object {$_.ToString()}
    } else {
        [string[]]$ParamsToAdd = '$_'
    }
                
    if ($PSBoundParameters.ContainsKey('Parameters')) {
        $ParamsToAdd += '$Parameters'
    }

    $UsingVariableData = $null

    # This code enables $Using support through the AST.
    # Credit to Boe Prox and his https://github.com/proxb/PoshRSJob module.

    if ($PSVersionTable.PSVersion.Major -gt 2) {
        # Extract using references
        $UsingVariables = $ScriptBlock.ast.FindAll({$args[0] -is [System.Management.Automation.Language.UsingExpressionAst]}, $true)

        If ($UsingVariables) {
            $List = New-Object 'System.Collections.Generic.List`1[System.Management.Automation.Language.VariableExpressionAst]'
            ForEach ($Ast in $UsingVariables) {
                [void]$list.Add($Ast.SubExpression)
            }

            $UsingVar = $UsingVariables | Group-Object -Property SubExpression | ForEach-Object {$_.Group | Select-Object -First 1}

            # Extract the name, value, and create replacements for each
            $UsingVariableData = ForEach ($Var in $UsingVar) {
                try {
                    $Value = Get-Variable -Name $Var.SubExpression.VariablePath.UserPath -ErrorAction Stop
                    [PSCustomObject]@{
                        Name = $Var.SubExpression.Extent.Text
                        Value = $Value.Value
                        NewName = ('$__using_{0}' -f $Var.SubExpression.VariablePath.UserPath)
                        NewVarName = ('__using_{0}' -f $Var.SubExpression.VariablePath.UserPath)
                    }
                }
                catch {
                    Write-Error "$($Var.SubExpression.Extent.Text) is not a valid Using: variable!"
                }
            }
            $ParamsToAdd += $UsingVariableData | Select-Object -ExpandProperty NewName -Unique

            $NewParams = $UsingVariableData.NewName -join ', '
            $Tuple = [Tuple]::Create($list, $NewParams)
            $bindingFlags = [Reflection.BindingFlags]"Default,NonPublic,Instance"
            $GetWithInputHandlingForInvokeCommandImpl = ($ScriptBlock.ast.gettype().GetMethod('GetWithInputHandlingForInvokeCommandImpl', $bindingFlags))

            $StringScriptBlock = $GetWithInputHandlingForInvokeCommandImpl.Invoke($ScriptBlock.ast, @($Tuple))

            $ScriptBlock = [scriptblock]::Create($StringScriptBlock)

            Write-Verbose $StringScriptBlock
        }
    }

    # Get Script Body to exclude existing ParamBlock.
    $ScriptBlockBody = ($scriptBlock.Ast.FindAll({$args[0] -is [System.Management.Automation.Language.NamedBlockAst]}, $false)).Statements | 
        ForEach-Object {"$($_.ToString())`r`n"}

    # Adding start and ending times to script block.
    # This is to accurately get the start and end times of each thread.
    $ScriptBegin = [string]('
        Write-Information "Start(Ticks) = $((get-date).Ticks)"
    ')
    $ScriptEnding = [string]('
        Write-Information "End(Ticks) = $((get-date).Ticks)"
    ')

    Write-Output @{
        ScriptBlock = $ExecutionContext.InvokeCommand.NewScriptBlock("param($($ParamsToAdd -Join ", "))`r`n" +  $ScriptBegin + $ScriptBlockBody + $ScriptEnding)
        UsingVariableData = $UsingVariableData
        Parameters = $ParamsToAdd
    }
}
