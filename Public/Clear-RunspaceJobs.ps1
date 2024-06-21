function Clear-RunspaceJobs {
    Remove-Variable -Name 'Runspaces' -Scope 'Global'
}
