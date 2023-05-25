Function Get-Uptime {

<#
.SYNOPSIS
Retrieves system uptime for specified computer(s).

.DESCRIPTION
Retrieves system uptime for specified computer(s).

.NOTES
Author: 
    Devin S
Notes:
    Revision 3
Revision:
    V01: 2017.11.02 by DS :: First working itteration.
    V02: 2018.12.28 by DS :: Added 'Credential' parameter and improved parameter block.
    V03: 2023.05.16 by DS :: Major script rewrite using template for 'Get-WmiObject' based cmdlets.
Call From:
    PowerShell v4 or higher

.PARAMETER ComputerName
The computer(s) for which uptime information will be retrieved.

.PARAMETER Credential
Optional parameter to specify alternate credentials for running the cmdlet.

.EXAMPLE
Get-Uptime -ComputerName FileServer01
Will return uptime information for computer FileServer01.

.EXAMPLE
Get-Uptime -ComputerName FileServer01,FileServer02
Will return uptime information for computers FileServer01 and FileServer02.

.EXAMPLE
Get-Uptime -ComputerName FileServer01 -Credential (Get-Credential)
Will prompt for alternate credentials to run the cmdlet and retrieve uptime information for FileServer01.

#>

[CmdletBinding()]
param (
    [Parameter(Mandatory=$True,ValueFromPipeline=$true,Position=0)]
    [Alias('Identity')]
    [string[]]$ComputerName,
    [Parameter(Mandatory=$false,Position=1)]
    [AllowNull()]
    [pscredential]$Credential = $null
)

# Splat table for 'Get-WmiObject' parameters
switch ($Credential) {
    {$_ -ne $null} {
        $WmiParams = @{
	        'ComputerName' = ""
	        'Credential' = $Credential
            'Class' = 'win32_OperatingSystem'
            'ErrorAction' = 'Stop'
        }
    }
    {$_ -eq $null} {
        $WmiParams = @{
	        'ComputerName' = ""
            'Class' = 'win32_OperatingSystem'
            'ErrorAction' = 'Stop'
        }
    }
}

# Splat table for 'Select-Object' (success w/ data)
$WmiSelect = @{ 
    'Property'= @(`
        @{N="ComputerName";E={$cn}},`
        @{N="LastBootUp";E={$_.ConvertToDateTime($_.LastBootUpTime)}}
        @{N="Uptime";E={(Get-Date) - ($_.ConvertToDateTime($_.LastBootUpTime))}}
    )
}

# Splat table for 'Select-Object' (success w/o data)
$NonSelect = @{
    'Property'= @(`
        @{N="ComputerName";E={$cn}},`
        @{N="LastBootUp";E={[string]::new("None")}},`
        @{N="Uptime";E={[string]::new("None")}}
    )
}

# Splat table for 'Select-Object' (failure)
$ErrSelect = @{
    'Property'= @(`
        @{N="ComputerName";E={$cn}},`
        @{N="LastBootUp";E={[string]::new("Error")}},`
        @{N="Uptime";E={[string]::new("Error")}}
    )
}

# Foreach loop to get WMI object from each $cn in $ComputerName
$i = 0
$WmiResults = foreach ($cn in $ComputerName) {
    $i++
    Write-Progress "Retrieving information from $cn" -PercentComplete ($i / $ComputerName.Count * 100)

    $WmiParams.ComputerName = $cn
    Try {
        $wmi = Get-WmiObject @WmiParams
        If ($wmi) {
            $wmi | Select-Object @WmiSelect
        }
        Else {
            "" | Select-Object @NonSelect
        }
    }
    Catch {
        Write-Warning "'$cn' WMI connectivity failure"
        "" | Select-Object @ErrSelect
    }
}

# Output results
$WmiResults


}
