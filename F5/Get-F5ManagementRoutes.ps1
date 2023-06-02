Function Get-F5ManagementRoutes {

#Requires -Module Posh-SSH
<#
.SYNOPSIS
Determine management route info for specified F5(s).

.DESCRIPTION
Determine management route info for specified F5(s).

.NOTES
Author: 
    Devin S
Notes:
    Revision 2
Revision:
    V01: 2023.04.24 by DS :: First revision
    V02: 2023.06.01 by DS :: Added '#Requires -Module Posh-SSH'
Call From:
    PowerShell v4 or higher

.PARAMETER F5
The name(s) of F5(s) for which hardware and version info will be retrieved.

.PARAMETER Credential
Credentials for connecting to F5(s).

.EXAMPLE
Get-F5ManagementRoutes -F5 'f5-ext-01.contoso.com'
Will retrieve F5 management route info for 'f5-ext-01.contoso.com'.

.EXAMPLE
$F5Creds = Get-Credential; Get-F5ManagementRoutes -F5 'f5-ext-01.contoso.com' -Credential $F5Creds
Will prompt for and store credentials in variable $F5Creds. Will retrieve F5 management route info for 'f5-ext-01.contoso.com' using the credentials stored in $F5Creds.
#>
[CmdletBinding()]
param (
    [Parameter(Mandatory=$True,ValueFromPipeline=$True,Position=0)]
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

# Subfunction to retrieve management route info
Function MgmtRoute {
    
    # Variable to hold individual results
    $res = "" | Select F5,Name,Gateway,Network
    $res.F5 = $f

    # TMSH command: show management routes
    $cmd = $null
    $cmd = "tmsh list sys management-route gateway network"

    # Invoke TMSH command via SSH
    $ssh = $null
    $ssh = (Invoke-SSHCommand -SSHSession (Get-SSHSession -ComputerName $f) -Command "$cmd")

    # Populate $res based on each line of SSH output
    foreach ($line in $ssh.Output) {
        switch ($line) {
            {$_ -like "sys management-route *"} {
                $res = "" | Select F5,Name,Gateway,Network
                $res.F5 = $f
                $res.Name = $line.Replace('sys management-route ','').TrimEnd(' {')
            }
            {$_ -like "    gateway *"} {
                $res.Gateway = $line.Replace('gateway','').Replace(' ','')
            }
            {$_ -like "    network *"} {
                $res.Network= $line.Replace('network','').Replace(' ','')
            }
            {$_ -eq "}"} {
                $Results.Add($res) | Out-Null
            }
        }
    }
}

# Results array
$Results = New-Object -TypeName System.Collections.ArrayList

# Main foreach loop to run subfunctions on F5(s)
$i = 0
foreach ($f in $F5) {
    
    $i++
    Try {
        Write-Progress "Gathering management route info from '$f'" -PercentComplete $($i / $F5.Count * 100)
    }
    Catch {}

    SSHSession
    MgmtRoute
}

# Output results
$Results


}
