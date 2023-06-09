Function Get-ADReplicationLastStats {

#Requires -Version 4.0
#Requires -Module ActiveDirectory
<#
.SYNOPSIS
Retrieves last AD replication attempt, result, and success for domain controllers.

.DESCRIPTION
Retrieves last Active Directory replication attempt, result, and success for domain controllers for domain controllers in the forest, or domain.

.NOTES
Author: 
    Devin S
Notes:
    Revision 2
Revision:
    V01: 2022.03.23 by DS :: First revision
    V02: 2023.06.09 by DS :: Minor overhaul. Changed $Object parameter to $Scope, added $EnumerationServer parameter. 
Call From:
    PowerShell v4 or higher

.PARAMETER Object
The object for which to retrieve last AD replication stats, either 'Forest' (default) or 'Domain'.

.PARAMETER EnumerationServer
The server (domain controller) or domain name to query replication stats from. The default value is the DNS root of the currently logged on user's domain.

.EXAMPLE
Get-ADReplicationLastStats -Object Forest -EnumerationServer contoso.com
Retrieves last AD replication attempt, result, and success for global catalogs in the AD forest 'contoso.com'.
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory=$False,Position=0)]
	[ValidateSet("Forest", "Domain")]
    $Scope = "Forest",
    [Parameter(Mandatory=$False,Position=1)]
    [Alias('DomainName')]
    $EnumerationServer = "$((Get-ADDomain).DNSRoot)"
)

switch ($Scope) {
    {$_ -eq "Forest"} {$ScopeObj = Get-ADForest -Identity $EnumerationServer}
    {$_ -eq "Domain"} {$ScopeObj = Get-ADDomain -Identity $EnumerationServer}
}

# Splat table for Select-Object (Results)
$ResSelect = @{
    'Property' = @(
        @{N="Server";E={$gc}},`
        @{N="Partner";E={$($GlobalCatalogs | ? {$r.Partner -like "*$($_.Hostname)*"}).GlobalCatalog}},`
        'PartnerType',`
        @{N="LastAttempt";E={$_.LastReplicationAttempt}},`
        @{N="LastResult";E={$_.LastReplicationResult}},`
        @{N="LastSuccess";E={$_.LastReplicationSuccess}}
    )
}

# Splat table for Select-Object (No results)
$NonSelect = @{
    'Property' = @(
        @{N="Server";E={$gc}},`
        @{N="Partner";E={[string]::new('None')}},`
        @{N="PartnerType";E={[string]::new('None')}},`
        @{N="LastAttempt";E={[string]::new('None')}},`
        @{N="LastResult";E={[string]::new('None')}},`
        @{N="LastSuccess";E={[string]::new('None')}}
    )
}

# Splat table for Select-Object (Error)
$ErrSelect = @{
    'Property' = @(
        @{N="Server";E={$gc}},`
        @{N="Partner";E={[string]::new('Error')}},`
        @{N="PartnerType";E={[string]::new('Error')}},`
        @{N="LastAttempt";E={[string]::new('Error')}},`
        @{N="LastResult";E={[string]::new('Error')}},`
        @{N="LastSuccess";E={[string]::new('Error')}}
    )
}

# Global catalogs (FQDNs and hostnames)
$GlobalCatalogs = $ScopeObj.GlobalCatalogs | Select @{N="GlobalCatalog";E={$_}},@{N="Hostname";E={$_.Replace(".$($ScopeObj.Name)",'')}}

# 'Main' foreach loop to gather AD replication partner metadata from each global catalog
$i = 0
$Replication = foreach ($gc in $GlobalCatalogs.GlobalCatalog) {
    $i++
    Write-Progress "Retrieving AD replication partner metadata from $gc" -PercentComplete ($i / $GlobalCatalogs.Count * 100)

    Try {
        $rep = $null
        $rep = Get-ADReplicationPartnerMetadata -Scope Server -Target $gc -ErrorAction Stop

        If ($rep) {
            foreach ($r in $rep) {
                $r | Select-Object @ResSelect
            }
        }
        Else {
            Write-Warning "'$gc' has no AD replication partner metadata"
            $gc | Select-Object @NonSelect
        }
    }
    Catch {
        Write-Host "FAILURE: '$gc' connection not successful!" -ForegroundColor Red
        $gc | Select-Object @ErrSelect
    }
}

# Output results
$Replication


}
