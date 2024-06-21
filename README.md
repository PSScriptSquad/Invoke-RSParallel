# Invoke-RSParallel

$ModuleManifestParam = @{
    path = ".\Invoke-RSParallel\Source\Invoke-RSParallel.psd1"
    ModuleVersion = "1.0"
    Author = "Ryan Whitlock"
    RootModule = "Invoke-RSParallel.psm1"
    FunctionsToExport = @('New-RunspacePool','New-RunspaceJob','Receive-RunspaceJob','Clear-RunspaceJobs')
}

New-ModuleManifest @ModuleManifestParam
