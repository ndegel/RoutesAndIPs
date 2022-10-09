#Requires -RunAs
#Requires -Version 5.1

function Get-InterfaceConfiguration {
    param (
        # alias of chosen interface
        [Parameter(Mandatory)]
        [string] $IfAlias,

        # index of chosen interface
        [Parameter(Mandatory)]
        [int] $IfIndex
    )

    Write-Host "`n`nAktuelle Konfiguration des Interfaces `"$IfAlias`" (ifIndex: $IfIndex)"

    $ConfiguredIPAddresses = @()
    $NetIPAddress = Get-NetIPAddress -InterfaceIndex $IfIndex -AddressFamily IPv4
    $NetIPAddress | ForEach-Object {$ConfiguredIPAddresses += "$($_.IPAddress)/$($_.PrefixLength)"}

    $ConfiguredDefaultGateway = (Get-NetIPConfiguration -ifIndex $IfIndex).IPv4DefaultGateway.NextHop

    $ConfiguredDNSServers = (Get-DnsClientServerAddress -InterfaceIndex $IfIndex -AddressFamily IPv4).ServerAddresses -join ", "

    [PSCustomObject] @{
        IPAddress = $ConfiguredIPAddresses -join ", ";
        DefaultGateway = $ConfiguredDefaultGateway
        DNSServers = $ConfiguredDNSServers
    } | Format-Table -AutoSize -Wrap
}

function Get-RoutePrefix {
    param (
        [Parameter(Mandatory)]
        [string] $NetMask,
        [Parameter(Mandatory)]
        [string] $Network
    )
    
    return "$Network/$Netmask"
}

function Get-Routes {
    param (
        $RoutesFromXML
    )
    
    $RetRoutes = @()
    $RoutesFromXML | ForEach-Object {
        $RetRoutes += [PSCustomObject]@{
           DestPrefix = Get-RoutePrefix -Network $_.Network -NetMask $_.NetMask
           NextHop = $_.Gateway
        }
    }

    return $RetRoutes
}
function Get-RoutesString {
    param (
        [array]$XmlRoutes
    )

    $Routes = @()
    foreach ($Route in $XmlRoutes) {

        # $Routes += "$($Route.Network)/$($Route.Netmask) ($($Route.Name)) via $($Route.Gateway)"
        $Routes += "$(Get-RoutePrefix -Network $Route.Network -NetMask $Route.Netmask) ($($Route.Name)) via $($Route.Gateway)"
    }
    
    return ($Routes -join "`n")
}

$UsbNICAlias = "USB-NIC"

if ("Connected" -eq ($IfUsbNIC = Get-NetIPInterface -AddressFamily IPv4 -InterfaceAlias $UsbNICAlias -ErrorAction SilentlyContinue).ConnectionState) {
    Write-Host "Interface $UsbNICAlias wird verwendet."

    $SelectedInterface = $IfUsbNIC

    Get-InterfaceConfiguration -IfAlias $UsbNICAlias -IfIndex $IfUsbNIC.ifIndex
}

($Interfaces = Get-NetIPInterface -AddressFamily IPv4 | ForEach-Object {$Index = 1} {
    [PSCustomObject] @{
        Index = $Index;
        ifIndex = $_.ifIndex;
        InterfaceAlias = $_.InterfaceAlias;
        ConnectionState = $_.ConnectionState
    };

    $Index++
}) | Select-Object Index, ifIndex, InterfaceAlias, ConnectionState | Format-Table -AutoSize

do {
    [int]$SelectedIndex = Read-Host "Index des Interfaces eingeben, das verwendet werden soll"
} while ($SelectedIndex -le 0 -or $SelectedIndex -gt $Index)

$SelectedInterface = $Interfaces[$SelectedIndex-1]

Get-InterfaceConfiguration -IfAlias $SelectedInterface.InterfaceAlias -IfIndex $SelectedInterface.ifIndex

do {
    $Answer = Read-Host "`nAktuelle Konfiguration ueberschreiben? [Y/n]"

    if ($Answer -eq 'n') {
        exit
    }
} while ('y','' -notcontains $Answer)


# XML Verarbeitung
[xml]$XMLIPConfigurations = Get-Content -Path .\test.xml

$IPConfigurations = @()

$XMLIPConfigurations.Anlagen.Anlage | ForEach-Object {$Index = 1} {

    if ($_.Unteranlage) {
        foreach ($Unteranlage in $_.Unteranlage) {
            $Name = $_.Name
            $UaName = $Unteranlage.Name
            # $IPString = "$($Unteranlage.IP)/$($Unteranlage.Netmask)"
            $IPString = "$(Get-RoutePrefix -Network $Unteranlage.IP -NetMask $Unteranlage.Netmask)"
            $DNS = $Unteranlage.DNS
            $RoutesString = Get-RoutesString -XmlRoutes $Unteranlage.Route
            $RoutesInfo = $Unteranlage.Route

            $IPConfigurations += [PSCustomObject]@{
                Index = $Index
                Anlage = $Name
                Unteranlage = $UaName
                InterfaceIP = $IPString
                DNSServer = $DNS
                Routen = $RoutesString
                RoutenInfos = $RoutesInfo
            }

            $Index++
        }

        # $Name = $_.Name
        # $UaName = $_.Unteranlage.Name
        # # $IPString = "$($_.Unteranlage.IP)/$($_.Unteranlage.Netmask)"
        # $IPString = "$(Get-RoutePrefix -Network $_.Unteranlage.IP -NetMask $_.Unteranlage.Netmask)"
        # $DNS = $_.Unteranlage.DNS
        # $RoutesString = Get-RoutesString -XmlRoutes $_.Unteranlage.Route
        # $RoutesInfo = $_.Unteranlage.Route
    } else {
        $Name = $_.Name
        $UaName = ""
        # $IPString = "$($_.IP)/$($_.Netmask)"
        $IPString = "$(Get-RoutePrefix -Network $_.IP -NetMask $_.Netmask)"
        $DNS = $_.DNS
        $RoutesString = Get-RoutesString -XmlRoutes $_.Route
        $RoutesInfo = $_.Route

        $IPConfigurations += [PSCustomObject]@{
            Index = $Index
            Anlage = $Name
            Unteranlage = $UaName
            InterfaceIP = $IPString
            DNSServer = $DNS
            Routen = $RoutesString
            RoutenInfos = $RoutesInfo
        }

        $Index++
    }
} 

$IPConfigurations | Format-Table -AutoSize -Wrap

do {
    [int]$SelectedIndex = Read-Host "Index der IP-Konfiguration eingeben, die verwendet werden soll"
} while ($SelectedIndex -le 0 -or $SelectedIndex -gt $Index)

$SelectedIPConfiguration = $IPConfigurations[$SelectedIndex-1]

# $SelectedIPConfiguration

$Anlage = $XMLIPConfigurations.Anlagen.Anlage | Where-Object {$_.Name -eq $SelectedIPConfiguration.Anlage}

$Unteranlage = $XMLIPConfigurations.Anlagen.Anlage.Unteranlage | Where-Object {$_.Name -eq $SelectedIPConfiguration.Unteranlage}

function Get-RoutePrefix {
    param (
        [Parameter(Mandatory)]
        [string] $NetMask,
        [Parameter(Mandatory)]
        [string] $Network
    )
    
    return "$Network/$Netmask"
}

function Get-Routes {
    param (
        $RoutesFromXML
    )
    
    $RetRoutes = @()
    $RoutesFromXML | ForEach-Object {
        $RetRoutes += [PSCustomObject]@{
           DestPrefix = Get-RoutePrefix -Network $_.Network -NetMask $_.NetMask
           NextHop = $_.Gateway
        }
    }

    return $RetRoutes
}

$Routes = @()
if ($Unteranlage) {
    
    $IPAddress = $Unteranlage.IP
    $NetMask = $Unteranlage.Netmask
    $DNS = $Unteranlage.DNS

    $Routes = Get-Routes -RoutesFromXML $Unteranlage.Route
} else {
    $IPAddress = $Anlage.IP
    $NetMask = $Anlage.Netmask
    $DNS = $Anlage.DNS
    $Routes = Get-Routes -RoutesFromXML $Anlage.Route
}


# Remove any existing IP, gateway from our ipv4 adapter
if (($SelectedInterface | Get-NetIPConfiguration).IPv4Address.IPAddress) {
    $SelectedInterface | Remove-NetIPAddress -AddressFamily IPv4 -Confirm:$false
}

if (($SelectedInterface | Get-NetIPConfiguration).Ipv4DefaultGateway) {
    $SelectedInterface | Remove-NetRoute -AddressFamily IPv4 -Confirm:$false
}

$SelectedInterface | New-NetIPAddress -IPAddress $IPAddress -AddressFamily IPv4 -PrefixLength $NetMask -Confirm:$true

$SelectedInterface | Set-DnsClientServerAddress -ServerAddresses $DNS

foreach ($Route in $Routes) {
    New-NetRoute -DestinationPrefix $Route.DestPrefix -InterfaceIndex $SelectedInterface.ifIndex -NextHop $Route.NextHop
}