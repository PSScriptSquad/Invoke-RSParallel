# Invoke-RSParallel
```
$ModuleManifestParam = @{
    path = ".\Invoke-RSParallel\Source\Invoke-RSParallel.psd1"
    ModuleVersion = "1.0"
    Author = "Ryan Whitlock"
    RootModule = "Invoke-RSParallel.psm1"
    FunctionsToExport = @('New-RunspacePool','New-RunspaceJob','Receive-RunspaceJob','Clear-RunspaceJobs')
}

New-ModuleManifest @ModuleManifestParam
```


My goal is to create a high-performing runspace module capable of processing a large number of items (10,000+) quickly in parallel, while effectively managing memory without compromising performance. I aim to maintain a modular approach rather than developing a large, monolithic, and difficult-to-follow script. Additionally, I want to implement a timeout per thread and continue honing my PowerShell skills.

There are several existing repositories and approaches that nearly meet my objectives:

### PoshRSJob
[PoshRSJob on GitHub](https://github.com/proxb/PoshRSJob)
1. Easy to use.
2. Utilizes nested runspaces and synchronized objects, aiding in timeout tracking and memory management. However, these features add overhead, reducing performance.

### Invoke-Parallel by RamblingCookieMonster
[Invoke-Parallel on GitHub](https://github.com/RamblingCookieMonster/Invoke-Parallel/tree/master)
1. Excellent approach to memory management and timeout handling by preventing the creation of PowerShell instances (threads) until just before the runspace pool requires them.
2. The code is monolithic and not broken down into functional components, making it difficult to follow and maintain.

### Foreach-Parallel by scriptingstudio
[Foreach-Parallel on GitHub Gist](https://gist.github.com/scriptingstudio/a1ce247fd1d6a75996f98ed9f578c10a)
1. I appreciate the experimental approach of having the asynchronous process return data from a vobject defined in `$pspipe.BeginInvoke($inputs, $results)` instead of periodically calling `EndInvoke`.
2. The code is monolithic and not broken down into functional components, making it difficult to follow and maintain.

### Mark Wilkinson
[Mark Wilkinson's approach](https://markw.dev/runspaces-output/)
1. Similar to RamblingCookieMonster's approach in queuing instances to better manage memory, but Mark's instances are not disposed of upon completion, reducing effectiveness. I do appreciate his use of an actual queue.

### Øyvind Kallstad Runspace-Functions
[Runspace-Functions by Øyvind Kallstad](https://gist.github.com/gravejester/b16bab17b80619f2b964)
[Runspaces Made Simple](https://communary.net/2014/11/24/runspaces-made-simple/)
1. Highly modular, clean, and easy to maintain.
2. Does not use queues or manage memory efficiently, creating all PowerShell instances upfront for many objects.

### mjolinor Invoke-ScriptAsync
[mjolinor Invoke-ScriptAsync](https://mjolinor.wordpress.com/2014/06/03/invoke-scritptasync-v2/)
1. Innovative idea for tracking the actual begin and end time of each thread.
2. Does not allow the provision of the `$host` parameter to the runspace, requiring manual programming of all host features and forwarding streams to the original host. This approach is annoying, error-prone, and inconvenient.
3. Lacks a method to queue PowerShell instances.

### Microsoft's Foreach-Object -Parallel
[Microsoft's Foreach-Object -Parallel](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/foreach-object?view=powershell-7.4)
1. Only supports a global timeout.
