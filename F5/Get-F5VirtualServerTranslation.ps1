Function Get-F5VirtualServerTranslation {

<#
.SYNOPSIS
Retrieves all virtual servers and related network translation settings from the specified F5(s).

.DESCRIPTION
Retrieves all virtual servers and related network translation settings from the specified F5(s).

.NOTES
Author: 
    Devin S
Notes:
    Revision 2
Revision:
    V01: 2023.09.11 by DS :: First revision.
    V02: 2023.09.29 by DS :: Updated comments.
Call From:
    PowerShell v5.1 or higher w/ Posh-SSH module

.PARAMETER F5
The name(s) of F5(s) for which virtual server and related network translation settings will be retrieved.

.PARAMETER Credential
Credentials for connecting to F5(s).

.EXAMPLE
Get-F5VirtualServerTranslation -F5 'f5-ext-01.contoso.com'
Will retrieve virtual servers and related network translation settings from 'f5-ext-01.contoso.com'.

.EXAMPLE
$F5Creds = Get-Credential; Get-F5SslProfiles -F5 'f5-ext-01.contoso.com' -Credential $F5Creds
Will prompt for and store credentials in variable $F5Creds. Will retrieve virtual servers and related network translation settings from 'f5-ext-01.contoso.com' using the credentials stored in $F5Creds.
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory=$True,Position=0)]
    [string[]]$F5,
    [Parameter(Mandatory=$False,Position=1)]
    [AllowNull()]
    [pscredential]$Credential = $null
)

# Define and import required modules
$RequiredModules = "Posh-SSH"
foreach ($rm in $RequiredModules) {
    Try {
        If (!(Get-Module -Name $rm)) {
            Import-Module -Name $rm -ErrorAction Stop
        }
    }
    Catch {
        Write-Host "FAILURE: Required module '$rm' could not be imported!" -ForegroundColor Red
        Break
    }
}

# Subfunction to create SSH session if it does not already exist
Function SSHSession {
    If (!(Get-SSHSession -ComputerName $f)) {
        If ($Credential -eq $null) {
            $Credential = Get-Credential -Message "Enter SSH credentials for $f"
        }
        New-SSHSession -ComputerName $f -Port 22 -Credential $Credential -AcceptKey -Force -WarningAction SilentlyContinue | Out-Null
    }
}

# Subfunction for virtual servers
Function VirtualServers {
    
    # TMSH cmd: Retrieve list of all virtual servers
    $cmd = $null
    $cmd = "tmsh -q list ltm virtual recursive destination mask source source-address-translation { pool type } source-port translate-address translate-port"
    $ssh = Invoke-SSHCommand -SSHSession (Get-SSHSession -ComputerName $f) -Command "$cmd"

    # Populate $Results based on $ssh.output
    foreach ($line in $ssh.Output) {
        switch ($line) {
            {$_ -like "ltm virtual * {"} {
                $vs = "" | Select F5,VS,Destination,Mask,Source,Source-Address-Translation-Pool,Source-Address-Translation-Type,Source-Port,Translate-Address,Translate-Port
                $vs.F5 = $f
                $vs.VS = ($_).Replace('ltm virtual ','').Replace(' {','')
            }
            {$_ -like "    destination *"} {
                $vs.Destination = ($_).TrimStart(' ').Replace('destination ','')
            }
            {$_ -like "    mask *"} {
                $vs.Mask = ($_).TrimStart(' ').Replace('mask ','')
            }
            {$_ -like "    source *"} {
                $vs.Source = ($_).TrimStart(' ').Replace('source ','')
            }
            {$_ -like "        pool *"} {
                $vs.'Source-Address-Translation-Pool' = ($_).TrimStart(' ').Replace('pool ','')
            }
            {$_ -like "        type *"} {
                $vs.'Source-Address-Translation-Type' = ($_).TrimStart(' ').Replace('type ','')
            }
            {$_ -like "    source-port *"} {
                $vs.'Source-Port' = ($_).TrimStart(' ').Replace('source-port ','')
            }
            {$_ -like "    translate-address *"} {
                $vs.'Translate-Address' = ($_).TrimStart(' ').Replace('translate-address ','')
            }
            {$_ -like "    translate-port *"} {
                $vs.'Translate-Port' = ($_).TrimStart(' ').Replace('translate-port ','')
            }
            {$_ -eq "}"} {
                $Results.Add($vs) | Out-Null
            }
        }
    }
}

# Results array populated by the 'VirtualServers' subfunction
$script:Results = New-Object -TypeName System.Collections.ArrayList

# Main foreach loop to run subfunctions on F5(s)
$i = 0
foreach ($f in $F5) {
    $i++
    Write-Progress "Retrieving virtual server translation export from '$f'" -PercentComplete ($i / $F5.Count * 100) -Id 1
    SSHSession
    VirtualServers
}

# Return results
$Results

}
