Function Get-F5LTMObjectStatus {

<#
.SYNOPSIS
Retrieves status of F5 LTM objects.

.DESCRIPTION
Retrieves status of specified F5 LTM objects. Parameters can be used to filter the types of objects and states which are returned.

.NOTES
Author: 
    Devin S
Notes:
    Revision 1
Revision:
    V01: 2023.05.25 by DS :: First revision
Call From:
    PowerShell v4 or higher

.PARAMETER F5
The name(s) of F5(s) from which LTM object status info will be retrieved.

.PARAMETER Credential
Credentials for connecting to F5(s).

.PARAMETER Object
The LTM object(s) to return. Valid values are 'virtual', 'pool', and 'node'. All objects are returned by default.

.PARAMETER Availability
The LTM availability state to return. Valid values are 'available', 'offline', 'unknown', and '*' (all). All availability states are returned by default.

.PARAMETER State
The LTM object state to return. Valid values are 'enabled', 'disabled', and '*' (all). All states are returned by default.

.PARAMETER IncludePoolMemberCounts
Switched parameter which specifies that pool member counts be returned. This only matters if 'pool' is included when '-Object' is specified.

.EXAMPLE
Get-F5LTMObjectStatus -F5 'f5-ext-01.contoso.com'
Will retrieve F5 LTM object status for all virtual servers, pools, and nodes from 'f5-ext-01.contoso.com'.

.EXAMPLE
Get-F5LTMObjectStatus -F5 'f5-ext-01.contoso.com' -Availability available -Object virtual
Will retrieve F5 LTM object status for all virtual servers with an availability state of 'available' from 'f5-ext-01.contoso.com'.

Get-F5LTMObjectStatus -F5 'f5-ext-01.contoso.com' -Object pool -IncludePoolMemberCounts
Will retrieve F5 LTM object status for all pools from 'f5-ext-01.contoso.com'. Pool member counts, both total and available will be included in results.
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory=$True,ValueFromPipeline=$True,Position=0)]
    [string[]]$F5,
    [Parameter(Mandatory=$False,Position=1)]
    [AllowNull()]
    [pscredential]$Credential = $null,
    [Parameter(Mandatory=$False,Position=2)]
    [ValidateSet("Virtual", "Pool", "Node")]
    [string[]]$Object = @("Virtual", "Pool", "Node"),
    [Parameter(Mandatory=$False,Position=3)]
    [ValidateSet("available","offline","unknown","*")]
    [string]$Availability = "*",
    [Parameter(Mandatory=$False,Position=4)]
    [ValidateSet("enabled","disabled","*")]
    [string]$State = "*",
    [Parameter(Mandatory=$False)]
    [switch]$IncludePoolMemberCounts = $False
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

# Subfunctions for LTM objects. (This will be a single function at some point)
Function pool {
    
    $results = New-Object -TypeName System.Collections.ArrayList
    
    $cmd = "tmsh show ltm pool"
    
    $out = (Invoke-SSHCommand -SSHSession (Get-SSHSession -ComputerName $f) -Command $cmd).Output | Where-Object { `
        $_ -like "Ltm::*: *" -or `
        $_ -like "  Availability*: *" -or `
        $_ -like "  State*: *" -or `
        $_ -like "  Reason*: *" -or `
        $_ -like "  Available Members*: *" -or `
        $_ -like "  Total Members*: *"
    }

    foreach ($o in $out) {
    
        switch ($o) {
            {$_ -like "Ltm::*: *"} {
                $res = "" | Select F5,Object,Name,Availability,State,Reason,AvailableMembers,TotalMembers
                $res.F5 = $f
                $res.Object = $o.Replace('Ltm::','').Split(':')[0]
                $res.Name = $o.Replace('Ltm::','').Split(':')[1].TrimStart()
            }
            {$_ -like "  Availability*: *"} {
                $res.Availability = $o.Split(':')[1].TrimStart()
            }
            {$_ -like "  State*: *"} {
                $res.State = $o.Split(':')[1].TrimStart()
            }
            {$_ -like "  Reason*: *"} {
                $res.Reason = $o.Split(':')[1].TrimStart()
            }
            {$_ -like "  Available Members*: *"} {
                $res.AvailableMembers = $o.Split(':')[1].TrimStart()
            }
            {$_ -like "  Total Members*: *"} {
                $res.TotalMembers = $o.Split(':')[1].TrimStart()
                $results.Add($res) | Out-Null
            }
        }
    }

    $results
}
Function virtual {
    
    $results = New-Object -TypeName System.Collections.ArrayList
    
    $cmd = "tmsh show ltm virtual"
    
    $out = (Invoke-SSHCommand -SSHSession (Get-SSHSession -ComputerName $f) -Command $cmd).Output | Where-Object { `
        $_ -like "Ltm::*: *" -or `
        $_ -like "  Availability*: *" -or `
        $_ -like "  State*: *" -or `
        $_ -like "  Reason*: *" -or `
        $_ -like "  Available Members*: *" -or `
        $_ -like "  Total Members*: *"
    }

    foreach ($o in $out) {
    
        switch ($o) {
            {$_ -like "Ltm::*: *"} {
                $res = "" | Select F5,Object,Name,Availability,State,Reason,AvailableMembers,TotalMembers
                $res.F5 = $f
                $res.Object = $o.Replace('Ltm::','').Split(':')[0]
                $res.Name = $o.Replace('Ltm::','').Split(':')[1].TrimStart()
            }
            {$_ -like "  Availability*: *"} {
                $res.Availability = $o.Split(':')[1].TrimStart()
            }
            {$_ -like "  State*: *"} {
                $res.State = $o.Split(':')[1].TrimStart()
            }
            {$_ -like "  Reason*: *"} {
                $res.Reason = $o.Split(':')[1].TrimStart()
                $results.Add($res) | Out-Null
            }
        }
    }

    $results
}
Function node {
    
    $results = New-Object -TypeName System.Collections.ArrayList
    
    $cmd = "tmsh show ltm node"
    
    $out = (Invoke-SSHCommand -SSHSession (Get-SSHSession -ComputerName $f) -Command $cmd).Output | Where-Object { `
        $_ -like "Ltm::*: *" -or `
        $_ -like "  Availability*: *" -or `
        $_ -like "  State*: *" -or `
        $_ -like "  Reason*: *" -or `
        $_ -like "  Available Members*: *" -or `
        $_ -like "  Total Members*: *"
    }

    foreach ($o in $out) {
    
        switch ($o) {
            {$_ -like "Ltm::*: *"} {
                $res = "" | Select F5,Object,Name,Availability,State,Reason,AvailableMembers,TotalMembers
                $res.F5 = $f
                $res.Object = $o.Replace('Ltm::','').Split(':')[0]
                $res.Name = $o.Replace('Ltm::','').Split(':')[1].TrimStart()
            }
            {$_ -like "  Availability*: *"} {
                $res.Availability = $o.Split(':')[1].TrimStart()
            }
            {$_ -like "  State*: *"} {
                $res.State = $o.Split(':')[1].TrimStart()
            }
            {$_ -like "  Reason*: *"} {
                $res.Reason = $o.Split(':')[1].TrimStart()
                $results.Add($res) | Out-Null
            }
        }
    }

    $results
}

# Splat table for 'Select-Object' in the main foreach loop
switch ($IncludePoolMemberCounts) {
    {$_ -eq $True} {
        $DataSelect = @{
            'Property' = @('F5','Object','Name','Availability','State','Reason','AvailableMembers','TotalMembers')
        }
    }
    {$_ -eq $False} {
        $DataSelect = @{
            'Property' = @('F5','Object','Name','Availability','State','Reason')
        }
    }
}

# 'Main' foreach loop for retrieving F5 LTM objects from each F5
$i = 0
foreach ($f in $F5) {
    $i++
    Write-Progress "Retrieving LTM object(s) from $f" -PercentComplete ($i / $F5.Count * 100) -Id 1

    SSHSession
        
    $ii = 0
    foreach ($obj in $Object) {
        $ii++
        Write-Progress "Retrieving object type: '$obj'" -PercentComplete ($ii / $Object.Count * 100) -ParentId 1

        & $obj | Where-Object {$_.Availability -like $Availability -and $_.State -like $State} | Select-Object @DataSelect
    }
}


}
