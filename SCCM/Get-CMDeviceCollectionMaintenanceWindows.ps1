Function Get-CMDeviceCollectionMaintenanceWindows {

#Requires -Module ConfigurationManager
<#
.SYNOPSIS
Retrieves specified SCCM device collection(s) and associated maintenance window(s).

.DESCRIPTION
Retrieves specified SCCM device collection(s) and associated maintenance window(s).

.NOTES
Author: 
    Devin S
Notes:
    Revision 1
Revision:
    V01: 2023.05.23 by DS :: First revision
Call From:
    PowerShell v4 or higher

.PARAMETER Name
Name(s) of SCCM device collections. Default value is '*' (all SCCM device collections).

.PARAMETER AllCollections
Switched parameter that specifies all SCCM device collections should be returned including those without maintenance windows.

.PARAMETER ExcludePast
Switched parameter that specifies non-reoccurring maintenance windows with dates in the past be excluded.

.EXAMPLE
Get-CMDeviceCollectionMaintenanceWindows
Will retrieve all SCCM device collections and associated maintenance windows if they exist.

.EXAMPLE
Get-CMDeviceCollectionMaintenanceWindows -Name "Windows Servers - Testing"
Will retrieve the 'Windows Servers - Testing' SCCM device collection and associated maintenance windows if they exist.

.EXAMPLE
Get-CMDeviceCollectionMaintenanceWindows -Name "Windows Servers - *"
Will retrieve SCCM device collections matching the name 'Windows Servers - *' and associated maintenance windows if they exist.
#>

[CmdletBinding(SupportsShouldProcess=$True)]
param (
    [Parameter(Mandatory=$False,ValueFromPipeline=$true,Position=0)]
    [string]$Name = "*",
    [Parameter(Mandatory=$False)]
    [switch]$AllCollections = $False,
    [Parameter(Mandatory=$False)]
    [switch]$ExcludePast = $False
)

Begin {

# Not connected to a configuration manager site via PowerShell
If (!(Get-PSDrive -PSProvider CMSite -ErrorAction SilentlyContinue)) {
    Write-Host "FAILURE: Not currently connected to CMSite!" -ForegroundColor Red
    Write-Warning "See 'https://learn.microsoft.com/en-us/powershell/sccm/overview?view=sccm-ps' for help connecting to SCCM via PowerShell." -ForegroundColor Gray
    Break
}

} # Begin

Process {

# Splat table for 'Get-CMCollection' parameters
$CcmParams = @{
    'CollectionType' = 'Device'
    'Name' = $Name
}

# Splat table for 'Select-Object' (success w/ data)
$CcmSelect = @{ 
    'Property' = @(
        @{N="CollectionID";E={$dc.CollectionID}},`
        @{N="CollectionName";E={$dc.Name}},`
        'Name',`
        'IsEnabled',`
        'Description',`
        @{N="Recurrence";E={
            switch ($_.RecurrenceType) {
                1 {[String]::new("None")}
                2 {[String]::new("Daily")}
                3 {[String]::new("Weekly")}
                4 {[String]::new("MonthlyByWeekDay")}
                5 {[String]::new("MonthlyByDate")}
            }
        }},`
        'StartTime',`
        @{N="InPast";E={If ($(($_.StartTime).AddMinutes($_.Duration) -lt $Date) -and $_.RecurrenceType -eq 1) {$True} Else {$False} }},`
        'Duration'
    )
}

# Splat table for 'Select-Object' (success w/o data)
$NonSelect = @{
    'Property' = @(
        @{N="CollectionID";E={$dc.CollectionID}},`
        @{N="CollectionName";E={$dc.Name}},`
        @{N="Name";E={[string]::new("None")}},`
        @{N="IsEnabled";E={[string]::new("None")}},`
        @{N="Description";E={[string]::new("None")}},`
        @{N="RecurrenceType";E={[string]::new("None")}},`
        @{N="StartTime";E={[string]::new("None")}},`
        @{N="InPast";E={[string]::new("None")}},`
        @{N="Duration";E={[string]::new("None")}}
    )
}

# Retrieve SCCM device collection(s)
Write-Verbose "Retrieving SCCM device collections matching name '$Name'"
$DeviceCollections = Get-CMCollection @CcmParams

# Retreive SCCM maintenance windows (if they exist) for specified device collection(s)
$i = 0
If ($DeviceCollections) {
    $Date = Get-Date
    $MaintenanceWindows = foreach ($dc in $DeviceCollections) {
        $i++
        Write-Progress "Retrieving maintenance windows for $($dc.Name)" -PercentComplete ($i / $DeviceCollections.Count * 100)

        $mw = $null
        $mw = $dc | Get-CMMaintenanceWindow
    
        If ($mw) {
            foreach ($_ in $mw) {
                $_ | Select-Object @CcmSelect
            }
        }
        Else {
            "" | Select-Object @NonSelect
        }
    }
}

# No SCCM device collection(s) match $Name
Else {
    Write-Warning "'$Name' does not match any SCCM device collection names"
}

} # Process

End {
    If ($AllCollections -eq $False) {
        $MaintenanceWindows = $MaintenanceWindows | Where-Object {$_.Name -ne "None"}
    }
    If ($ExcludePast -eq $True) {
        $MaintenanceWindows = $MaintenanceWindows | Where-Object {$_.InPast -ne $True}
    }
    
    If ($MaintenanceWindows) {
        $MaintenanceWindows
    }
    Else {
        Write-Warning "No SCCM device collections match specified criteria"
    }
}


}
