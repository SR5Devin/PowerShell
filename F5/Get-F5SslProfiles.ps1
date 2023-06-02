Function Get-F5SslProfiles {

#Requires -Module Posh-SSH
<#
.SYNOPSIS
Determine SSL profile and virtual server info for specified F5(s).

.DESCRIPTION
Determine SSL profile and virtual server info for specified F5(s).

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
Get-F5SslProfiles -F5 'f5-ext-01.contoso.com'
Will retrieve SSL profile and virtual server info from 'f5-ext-01.contoso.com'.

.EXAMPLE
$F5Creds = Get-Credential; Get-F5SslProfiles -F5 'f5-ext-01.contoso.com' -Credential $F5Creds
Will prompt for and store credentials in variable $F5Creds. Will retrieve SSL profile and virtual server info from 'f5-ext-01.contoso.com' using the credentials stored in $F5Creds.
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

# Subfunction to retrieve SSL (client and server) profiles
Function SslProfiles {

    # tmsh command: list client-ssl profiles
    $cmd = $null
    $cmd = "tmsh list ltm profile client-ssl defaults-from"

    # Invoke tmsh command
    $ssh = $null
    $ssh = (Invoke-SSHCommand -SSHSession (Get-SSHSession -ComputerName $f) -Command "$cmd")

    # Store client SSL profiles names in $clientssl
    $clientssl = ($ssh.Output | ? {$_ -like "* {"}).Replace('ltm profile client-ssl ','').TrimEnd(' {')

    # Store client SSL profiles names in $allssl adding the 'Context' attribute
    $allssl = foreach ($_ in $clientssl) {
        $_ | Select-Object @{N="F5";E={$f}},@{N="Profile";E={$_}},@{N="Context";E={'client-ssl'}}
    }

    # tmsh command: list server-ssl profiles
    $cmd = $null
    $cmd = "tmsh list ltm profile server-ssl defaults-from"

    # Invoke tmsh command
    $ssh = $null
    $ssh = (Invoke-SSHCommand -SSHSession (Get-SSHSession -ComputerName $f) -Command "$cmd")

    # Store client SSL profiles names in $clientssl
    $serverssl = ($ssh.Output | ? {$_ -like "* {"}).Replace('ltm profile server-ssl ','').TrimEnd(' {')

    # Store server SSL profiles names in $allssl adding the 'Context' attribute
    $allssl += foreach ($_ in $serverssl) {
        $_ | Select-Object @{N="F5";E={$f}},@{N="Profile";E={$_}},@{N="Context";E={'server-ssl'}}
    }

    $allssl
}

# Subfunction to retrieve virtual servers and profiles
Function VsProfiles {
    
    # tmsh command: list virtual servers
    $cmd = $null
    $cmd = "tmsh list ltm virtual"

    # Invoke tmsh command
    $ssh = $null
    $ssh = (Invoke-SSHCommand -SSHSession (Get-SSHSession -ComputerName $f) -Command "$cmd")

    # Create $virtualservers from ssh output
    $virtualservers = $null
    $virtualservers = ($ssh.Output | ? {$_ -like "ltm virtual *"}).Replace('ltm virtual ','').Replace(' {','')

    If ($virtualservers) {
        foreach ($vs in $virtualservers) {

            # tmsh command: list profiles for specifc virtual server
            $cmd = $null
            $cmd = "tmsh list ltm virtual $vs profiles"

            # Invoke tmsh command
            $ssh = $null
            $ssh = (Invoke-SSHCommand -SSHSession (Get-SSHSession -ComputerName $f) -Command "$cmd")

            # Create $profiles from ssh output
            $profiles = $null
            $profiles = ($ssh.Output | ? {$_ -like " *{" -and $_ -notlike "ltm virtual *" -and $_ -notlike "*profiles {"}).TrimStart(' ').TrimEnd(' {')
            
            # Profiles exist on the given virtual server
            If ($profiles) {

                foreach ($p in $profiles) {
                    $p | Select @{N="F5";E={$f}},@{N="VirtualServer";E={$vs}},@{N="Profile";E={$_}}
                }
            }
            Else {
                $vs | Select @{N="F5";E={$f}},@{N="VirtualServer";E={$_}},@{N="Profile";E={[string]::new("None")}}
            }
        }
    }
    Else {
        $f | Select @{N="F5";E={$_}},@{N="VirtualServer";E={[string]::new("None")}},@{N="Profile";E={[string]::new("None")}} 
    }
}

# Main foreach loop to run subfunctions on F5(s)
$i = 0
$Results = foreach ($f in $F5) {
    
    $i++
    Try {
        Write-Progress "Gathering SSL profile info from '$f'" -PercentComplete $($i / $F5.Count * 100)
    }
    Catch {}

    SSHSession

    Write-Verbose "'$f' gathering SSL profiles"
    $sslprofiles = SslProfiles
    
    Write-Verbose "'$f' gathering virtual servers"
    $vsprofiles = VsProfiles

    # Attempt to match each SSL profile with a virtual server using data stored in $sslprofiles and $vsprofiles
    foreach ($sp in $sslprofiles) {
        
        $match = $null
        $match = $vsprofiles | ? {$_.Profile -eq $sp.Profile}

        # The individual SSL profile ($sp) is used by a virtual server
        If ($match) {
            Write-Verbose "'$f' SSL profile '$($sp.Profile)' is used by VS '$($match.VirtualServer)'"
            $match | Select F5,VirtualServer,Profile,@{N="Context";E={$sp.Context}}
        }

        # The individual SSL profile ($sp) is *NOT* used by a virtual server
        Else {
            Write-Verbose "'$f' SSL profile '$($sp.Profile)' is *NOT* used by any VS"
            $sp | Select F5,@{N="VirtualServer";E={[string]::new("None")}},Profile,Context
        }
    }
}

# Output results
$Results


}
