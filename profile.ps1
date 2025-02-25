#Put workarounds/hacks here.../Adjust to your own needs. It goes into c:\\Program Files\\Powershell\\7\\profile.ps1

#Remove ~/Documents/Powershell/Modules from modulepath; it becomes a mess because it`s not removed when one deletes the wineprefix... 
$path = $env:PSModulePath -split ';' ; $env:PSModulePath  = ( $path | Select-Object -Skip 1 | Sort-Object -Unique) -join ';'

#Register-WMIEvent not available in PS Core, so for now just change into noop
function Register-WMIEvent
{
    exit 0
}

#Prerequisite: Stuff below requires native dotnet (winetricks -q dotnet48) to be installed, otherwise it will just fail!
#
#Based on Get-WmiCustom by Daniele Muscetta, so credits to aforementioned author;
#See https://www.powershellgallery.com/packages/Traverse/0.6/Content/Private%5CGet-WMICustom.ps1
#
#Only works as of wine-6.20, see https://bugs.winehq.org/show_bug.cgi?id=51871
#
#Examples of usage:
#
#Get-WmiObject win32_operatingsystem version
#$(Get-WmiObject win32_videocontroller).name
Function Get-WmiObject([parameter(mandatory)] [string]$class, [string[]]$property="*", `
                       [string]$computername = "localhost", [string]$namespace = "root\cimv2", `
                       [string]$filter<#not used yet, but otherwise chocolatey starts complaining#>)
{
    if (!(Test-Path  "HKLM:\Software\Microsoft\.NETFramework\v4.0.30319"))
    {  Add-Type -AssemblyName PresentationCore,PresentationFramework; [System.Windows.MessageBox]::Show('This function requires native .NET48 to be installed!   Do "winetricks -q dotnet48" and try again ','Warning','ok','exclamation'); return}

    $ConnectionOptions = new-object System.Management.ConnectionOptions
    $assembledpath = "\\" + $computername + "\" + $namespace
    
    $Scope = new-object System.Management.ManagementScope $assembledpath, $ConnectionOptions
    $Scope.Connect() 
    
    $querystring = "SELECT " +  $property + " FROM " + $class
    $query = new-object System.Management.ObjectQuery $querystring
    $searcher = new-object System.Management.ManagementObjectSearcher
    $searcher.Query = $querystring
    $searcher.Scope = $Scope 
    
    return $searcher.get()
}

Set-Alias Get-CIMInstance Get-WMIObject

#Example (works on windows,requires admin rights): Set-WmiInstance -class win32_operatingsystem -arguments @{"description" = "MyDescription"}
#Based on https://devblogs.microsoft.com/scripting/use-the-set-wmiinstance-powershell-cmdlet-to-ease-configuration/
Function Set-WmiInstance( [string]$class, [hashtable]$arguments, [string]$computername = "localhost", `
                          [string]$namespace = "root\cimv2" <#, [string]$path #>)
{
    $assembledpath = "\\" + $computername + "\" + $namespace + ":" + $class
    $obj = ([wmiclass]"$assembledpath").CreateInstance()

    foreach ($h in $arguments.GetEnumerator()) {
        $obj.$($h.Name) = $($h.Value)
    }
    $result = $obj.put()

    return $result.Path
}

#Note: Following obviously overrides wine (-staging)`s tasklist(.exe) so just remove stuff below if you don`t want that 
New-Alias tasklist.exe tasklist

function tasklist
{
     Get-WmiObject win32_process "processid,name" | Format-Table -Property Name, processid -autosize
}
