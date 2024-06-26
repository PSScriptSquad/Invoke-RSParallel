function Convert-ScriptBlock {
    <#
        .SYNOPSIS
            Converts a ScriptBlock.
        .DESCRIPTION
            This function Converts a ScriptBlock to allow Using: based on Boe Prox and applies Parameters.
        .EXAMPLE
            Convert-ScriptBlock -ScriptBlock $code -Parameters $parameters
            Description
            -----------
            Converts code in $code with parameters from $parameters to be used in a runspace (thread).
        .NOTES
            Name: Convert-ScriptBlock
            Author: Ryan Whitlock
            Date: 01.11.2024
            Version: 1.0
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

    #Start building parameter names for the param block
    #Add existing parameter(s) to $ParamsToAdd array
    if ($scriptBlock.Ast.ParamBlock){
        [string[]]$ParamsToAdd = $scriptBlock.Ast.ParamBlock.Parameters.Name | ForEach-Object {$_.ToString()}
    }else{
        [string[]]$ParamsToAdd = '$_'
    }
                
    if( $PSBoundParameters.ContainsKey('Parameter') ) {
        $ParamsToAdd += '$Parameter'
    }

    $UsingVariableData = $Null

    # This code enables $Using support through the AST.
    # This is entirely from  Boe Prox, and his https://github.com/proxb/PoshRSJob module; all credit to Boe!

    if($PSVersionTable.PSVersion.Major -gt 2) {
        #Extract using references
        $UsingVariables = $ScriptBlock.ast.FindAll({$args[0] -is [System.Management.Automation.Language.UsingExpressionAst]},$True)

        If ($UsingVariables) {
            $List = New-Object 'System.Collections.Generic.List`1[System.Management.Automation.Language.VariableExpressionAst]'
            ForEach ($Ast in $UsingVariables) {
                [void]$list.Add($Ast.SubExpression)
            }

            $UsingVar = $UsingVariables | Group-Object -Property SubExpression | ForEach-Object {$_.Group | Select-Object -First 1}

            #Extract the name, value, and create replacements for each
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
            $GetWithInputHandlingForInvokeCommandImpl = ($ScriptBlock.ast.gettype().GetMethod('GetWithInputHandlingForInvokeCommandImpl',$bindingFlags))

            $StringScriptBlock = $GetWithInputHandlingForInvokeCommandImpl.Invoke($ScriptBlock.ast,@($Tuple))

            $ScriptBlock = [scriptblock]::Create($StringScriptBlock)

            Write-Verbose $StringScriptBlock
        }
    }

    #Get Script Body to exclude existing ParamBlock.
    $ScriptBlockBody = ($scriptBlock.Ast.FindAll({$args[0] -is [System.Management.Automation.Language.NamedBlockAst]},$false)).Statements | 
        ForEach-Object {"$($_.ToString())`r`n"}

    #Adding start and ending times to script block. This is to accurately get the start and end times of each thread.
    $ScriptBegin = [string]('
        Write-Information "Start(Ticks) = $((get-date).Ticks)"
    ')
    $ScriptEnding = [string]('
        Write-Information "End(Ticks) = $((get-date).Ticks)"
    ')

    Write-Output $([PSCustomObject]@{
        scriptblock = $ExecutionContext.InvokeCommand.NewScriptBlock("param($($ParamsToAdd -Join ", "))`r`n" +  $ScriptBegin + $ScriptBlockBody + $ScriptEnding)
        usingVariableData = $UsingVariableData
        parameters = $ParamsToAdd
    })
}
