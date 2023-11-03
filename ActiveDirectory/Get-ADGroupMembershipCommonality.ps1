Function Get-ADGroupMembershipCommonality {

<#
.SYNOPSIS
Determines AD group membership commonality for all users in the specified organizational unit.

.DESCRIPTION
Determines AD group membership commonality for all users in the specified organizational unit.

.NOTES
Author: 
    Devin S
Notes:
    Revision 01
Revision:
    V01: 2023.11.03 by DS :: First revision
Call From:
    PowerShell v4 or higher w/ ActiveDirectory module

.PARAMETER OrganizationalUnit
The name of the targeted organizational unit.

.PARAMETER Server
Optional paramater which, if specified, defines the domain or domain controller from which to retrieve AD group membership commonality.

.PARAMETER MinimumPercentage
Optional parameter which, if specified, dictates the minimum commonality percentage an AD group must meet for users in the organizational unit in order to be returned in the results. The default value is 0.

.EXAMPLE
Get-ADGroupMembershipCommonality -OrganizationalUnit 'OU=Users,OU=Finance,DC=contoso,DC=local'
Will return the group membership commonality percentages for all groups which users in the 'OU=Users,OU=Finance,DC=contoso,DC=local' organizational unit are a member of.

.EXAMPLE
Get-ADGroupMembershipCommonality -OrganizationalUnit 'OU=Users,OU=Finance,DC=contoso,DC=local' -MinimumPercentage 75
Will return the group membership commonality percentages for all groups which users in the 'OU=Users,OU=Finance,DC=contoso,DC=local' organizational unit are a member of, but only if at least 75% of users are members of the group.
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory=$True,Position=0)]
    [Alias('OU')]
    [Microsoft.ActiveDirectory.Management.ADOrganizationalUnit]$OrganizationalUnit,
    [Parameter(Mandatory=$false,Position=1)]
    [string]$Server = $env:USERDNSDOMAIN,
    [Parameter(Mandatory=$false,Position=2)]
    [ValidateScript({$_ -le 100})]
    [int]$MinimumPercentage = 0
)

# Define and import required modules
$RequiredModules = "ActiveDirectory"
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

# Ensure that OU exists
Try {
    $ou = Get-ADOrganizationalUnit -Server $Server -Identity $OrganizationalUnit -ErrorAction Stop
    $Users = Get-ADUser -Filter * -SearchBase $ou -Server $Server
}
Catch {
    Write-Host "FAILURE: AD organizational unit '$OrganizationalUnit' could not be found on '$Server'" -ForegroundColor Red
    Break
}

If ($Users) {

    # Determine group membership for each user
    $i = 0
    $Groups = foreach ($u in $Users) {
        $i++
        Write-Progress "Determining group membership for '$($u.SamAccountName)'" -PercentComplete ($i / $Users.Count * 100)
        Get-ADPrincipalGroupMembership -Identity $u -Server $Server | Select @{N="User";E={$u.SamAccountName}},@{N="Group";E={$_.DistinguishedName}}
    }
    
    # Determine list of unique groups
    $UniqueGroups = $Groups.Group | Select -Unique
    
    # Determine the percentage of users in the OU which are members of each group
    $i = 0
    $GroupPercentages = foreach ($ug in $UniqueGroups) {
        $i++
        Write-Progress "Determining group membership percentage of '$($ug)'" -PercentComplete ($i / $UniqueGroups.Count * 100)
        "" | Select @{N="Group";E={$ug}},@{N="Percentage";E={ [int]([math]::Round( ($Groups | ? {$_.Group -eq $ug}).Count / $Users.Count * 100 ))}}
    }

    # Return results based upon $MinimumPercentage
    If ($GroupPercentages | Where-Object {$_.Percentage -ge $MinimumPercentage}) {
        Write-Verbose "$($Users.Count) users exist in $($ou.DistinguishedName)"
        $GroupPercentages | Where-Object {$_.Percentage -ge $MinimumPercentage}
    }
    Else {
        Write-Warning "There are no AD groups where at least $MinimumPercentage% of users in '$($ou.DistinguishedName)' are a member."
    }
}

# No AD users exist in the OU
Else {
    Write-Warning "No AD users exist in '$($ou.DistinguishedName)'"
}

}
