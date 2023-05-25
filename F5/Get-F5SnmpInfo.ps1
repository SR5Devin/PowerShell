Function Get-F5SnmpInfo {

<#
.SYNOPSIS
Determine SNMP info for specified F5(s).

.DESCRIPTION
Determine SNMP info for specified F5(s).

.NOTES
Author: 
    Devin S
Notes:
    Revision 1
Revision:
    V01: 2023.04.24 by DS :: First revision
Call From:
    PowerShell v4 or higher

.PARAMETER F5
The name(s) of F5(s) for which hardware and version info will be retrieved.

.PARAMETER Credential
Credentials for connecting to F5(s).

.EXAMPLE
Get-F5SnmpInfo -F5 'f5-ext-01.contoso.com'
Will retrieve SNMP info from 'f5-ext-01.contoso.com'.

.EXAMPLE
$F5Creds = Get-Credential; Get-F5SslProfiles -F5 'f5-ext-01.contoso.com' -Credential $F5Creds
Will prompt for and store credentials in variable $F5Creds. Will retrieve SNMP info from 'f5-ext-01.contoso.com' using the credentials stored in $F5Creds.
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

# Subfunction to retrieve snmp info
Function SnmpInfo {
    
    # Variable to hold individual results
    $res = "" | Select F5,Name,Gateway,Network
    $res.F5 = $f

    # TMSH command: show SNMP info
    $cmd = $null
    $cmd = "tmsh list sys snmp sys-contact sys-location allowed-addresses communities snmpv1 snmpv2c agent-trap"

    # Invoke TMSH command via SSH
    $ssh = $null
    $ssh = (Invoke-SSHCommand -SSHSession (Get-SSHSession -ComputerName $f) -Command "$cmd")

    # Populate $res based on each line of SSH output
    foreach ($line in $ssh.Output) {
        switch ($line) {
            {$_ -eq "sys snmp {"} {
                $res = "" | Select F5,AgentTrap,AllowedAddresses,CommunityNames,SnmpV1,SnmpV2c,SysContact,SysLocation
                $res.F5 = $f
            }
            {$_ -like "    agent-trap *"} {
                $res.AgentTrap = $line.Replace('    agent-trap ','')
            }
            {$_ -like "    allowed-addresses { *"} {
                $res.AllowedAddresses= $line.Replace('    allowed-addresses { ','').TrimEnd(' }')
            }
            {$_ -like "            community-name *"} {
                If ($res.CommunityNames) {
                    $res.CommunityNames += " $($line.Replace('            community-name ',''))"
                }
                Else {
                    $res.CommunityNames = $line.Replace('            community-name ','')
                }
            }
            {$_ -like "    snmpv1 *"} {
                $res.SnmpV1 = $line.Replace('    snmpv1 ','')
            }
            {$_ -like "    snmpv2c *"} {
                $res.SnmpV2c = $line.Replace('    snmpv2c ','')
            }
            {$_ -like "    sys-contact *"} {
                $res.SysContact = $line.Replace('    sys-contact ','').Replace('"','')
            }
            {$_ -like "    sys-location *"} {
                $res.SysLocation = $line.Replace('    sys-location ','').Replace('"','')
            }
            {$_ -eq "}"} {
                $Results.Add($res) | Out-Null
            }
            Default {}
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
        Write-Progress "Gathering SNMP info from '$f'" -PercentComplete $($i / $F5.Count * 100)
    }
    Catch {}

    SSHSession
    SnmpInfo
}

# Output results
$Results


}
