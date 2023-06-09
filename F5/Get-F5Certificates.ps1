Function Get-F5Certificates {

#Requires -Module Posh-SSH
<#
.SYNOPSIS
Retrieves SSL traffic certificates from specified F5(s).

.DESCRIPTION
Retrieves SSL traffic certificates from specified F5(s).

.NOTES
Author: 
    Devin S
Notes:
    First Revision
Revision:
    V01: 2023.06.27 by DS :: First revision
Call From:
    PowerShell v4 or higher

.PARAMETER F5
The name(s) of F5(s) for which hardware and version info will be retrieved.

.PARAMETER Credential
Credentials for connecting to F5(s).

.EXAMPLE
Get-F5Certificates -F5 'f5-ext-01.contoso.com'
Will retrieve F5 SSL traffic certificates from 'f5-ext-01.contoso.com'.

.EXAMPLE
$F5Creds = Get-Credential; Get-F5Certificates -F5 'f5-ext-01.contoso.com' -Credential $F5Creds
Will prompt for and store credentials in variable $F5Creds. Will retrieve F5 SSL traffic certificates from 'f5-ext-01.contoso.com' using the credentials stored in $F5Creds.
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory=$True,ValueFromPipeline=$True,Position=0)]
    [string[]]$F5,
    [Parameter(Mandatory=$False,Position=1)]
    [AllowNull()]
    [pscredential]$Credential = $null
)

# Date variable to determining status of certificates
$Date = Get-Date

# Subfunction to create SSH session if it does not already exist
Function SSHSession {
    If (!(Get-SSHSession -ComputerName $f)) {
        If ($Credential -eq $null) {
            $Credential = Get-Credential -Message "Enter SSH credentials for $f"
        }
        New-SSHSession -ComputerName $f -Port 22 -Credential $Credential -AcceptKey -Force -WarningAction SilentlyContinue | Out-Null
    }
}

# Subfunction to retrieve cert info
Function CertInfo {
    
    # TMSH command: list traffic certificates
    $cmd = $null
    $cmd = "tmsh list sys file ssl-cert"

    # Invoke TMSH command via SSH
    $ssh = $null
    $ssh = (Invoke-SSHCommand -SSHSession (Get-SSHSession -ComputerName $f) -Command "$cmd")

    # Output from SSH command above
    $Output = $ssh.Output | ? {$_ -like "sys file ssl-cert *" -or $_ -like "    subject *" -or $_ -like "    issuer *" -or $_ -like "    expiration-date *"}

    foreach ($o in $Output) {
        switch ($o) {
            {$_ -like "sys file ssl-cert *"} {
                $res = "" | Select F5,Certificate,Subject,Issuer,Expiration,Status
                $res.F5 = $f
                $res.Certificate = $_.Replace('sys file ssl-cert ','').Replace(' {','')
            }
            {$_ -like "    subject *"} {
                $res.Subject = $_.Replace('    subject ','').TrimStart('"').TrimEnd('"')
            }
            {$_ -like "    issuer *"} {
                $res.Issuer = $_.Replace('    issuer ','').TrimStart('"').TrimEnd('"')
            }
            {$_ -like "    expiration-date *"} {
                $res.Expiration = (([System.DateTimeOffset]::FromUnixTimeSeconds($($_.Replace('    expiration-date ','')))).DateTime)
                switch ($res) {
                    {$res.Expiration -gt $Date.AddDays(60)} {
                        $res.Status = "SUCCESS"
                    }
                    {($res.Expiration -lt $Date.AddDays(60)) -and ($res.Expiration -gt $Date.AddDays(14))} {
                        $res.Status = "WARNING"
                    }
                    {$res.Expiration -lt $Date.AddDays(14)} {
                        $res.Status = "CRITICAL"
                    }
                    {$res.Expiration -lt $Date} {
                        $res.Status = "EXPIRED"
                    }
                }
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
        Write-Progress "Gathering traffic certificates from '$f'" -PercentComplete $($i / $F5.Count * 100)
    }
    Catch {}

    SSHSession
    CertInfo
}

# Output results
$Results


}
