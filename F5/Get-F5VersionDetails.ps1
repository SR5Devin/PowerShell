Function Get-F5VersionDetails {

#Requires -Module Posh-SSH
<#
.SYNOPSIS
Determine hardware and version info for specified F5(s).

.DESCRIPTION
Determine hardware and version info for specified F5(s).

.NOTES
Author: 
    Devin S
Notes:
    Revision 3
Revision:
    V01: 2023.04.24 by DS :: First revision.
    V02: 2023.06.01 by DS :: Added '#Requires -Module Posh-SSH'.
    V03: 2023.07.03 by DS :: Removed 'ValueFromPipeline=$True' from $F5 parameter. Cleaned up spacing.
Call From:
    PowerShell v4 or higher

.PARAMETER F5
The name(s) of F5(s) for which hardware and version info will be retrieved.

.PARAMETER Credential
Credentials for connecting to F5(s).

.EXAMPLE
Get-F5VersionDetails -F5 'f5-ext-01.contoso.com'
Will retrieve F5 hardware and version info for 'f5-ext-01.contoso.com'.

.EXAMPLE
$F5Creds = Get-Credential; Get-F5VersionDetails -F5 'f5-ext-01.contoso.com' -Credential $F5Creds
Will prompt for and store credentials in variable $F5Creds. Will retrieve F5 hardware and version info for 'f5-ext-01.contoso.com' using the credentials stored in $F5Creds.
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory=$True,Position=0)]
    [string[]]$F5,
    [Parameter(Mandatory=$False,Position=1)]
    [AllowNull()]
    [pscredential]$Credential = $null
)

# Subfunction to create SSH session if it does not already exist
Function SSHSession {
    If (!(Get-SSHSession -ComputerName $f)) {
        If ($Credential -eq $null) {
            $Credential = Get-Credential -Message "Enter SSH credentials for $f"
        }
        New-SSHSession -ComputerName $f -Port 22 -Credential $Credential -AcceptKey -Force -WarningAction SilentlyContinue | Out-Null
    }
}

# Subfunction to retrieve hardware & software version info
Function VersionInfo {
    
    # Variable to hold individual results
    $res = "" | Select F5,Hardware,Platform,Version,Build,Edition
    $res.F5 = $f

    # TMSH command: show hardware name and platform
    $cmd = $null
    $cmd = "tmsh show /sys hardware field-fmt | grep -e platform -e marketing"

    # Invoke TMSH command via SSH
    $ssh = $null
    $ssh = (Invoke-SSHCommand -SSHSession (Get-SSHSession -ComputerName $f) -Command "$cmd")

    # Determine hardware and platform from SSH output
    $res.Hardware = ($ssh.Output | ? {$_ -like "*marketing-name *"}).TrimStart(' ').Replace('marketing-name ','')
    $res.Platform = ($ssh.Output | ? {$_ -like "*platform *" -and $_ -notlike "*platform {*" -and $_ -notlike "*versions.1.name*"}).TrimStart(' ').Replace('platform ','')

    # TMSH command: show version
    $cmd = $null
    $cmd = "tmsh show /sys version"

    # Invoke TMSH command via SSH
    $ssh = $null
    $ssh = (Invoke-SSHCommand -SSHSession (Get-SSHSession -ComputerName $f) -Command "$cmd")

    # Determine version, build, and edition from SSH output
    $res.Version = ($ssh.Output | ? {$_ -like "* Version *"}).Replace('Version','').TrimStart(' ')
    $res.Build = ($ssh.Output | ? {$_ -like "* Build *"}).Replace('Build','').TrimStart(' ')
    $res.Edition = ($ssh.Output | ? {$_ -like "* Edition *"}).Replace('Edition','').TrimStart(' ')

    # Add $res to $Results
    $Results.Add($res) | Out-Null
}

# Results array
$Results = New-Object -TypeName System.Collections.ArrayList

# Main foreach loop to run subfunctions on F5(s)
$i = 0
foreach ($f in $F5) {
    
    $i++
    Try {
        Write-Progress "Gathering hardware and version info from '$f'" -PercentComplete $($i / $F5.Count * 100)
    }
    Catch {}

    SSHSession
    VersionInfo
}

# Output results
$Results

}
