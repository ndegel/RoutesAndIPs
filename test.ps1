# XML Verarbeitung
[xml]$XMLIPConfigurations = Get-Content -Path .\test.xml

$IPConfigurations = @()

$XMLIPConfigurations.Anlagen.Anlage | ForEach-Object {$Index = 1} {

    if ($_.Unteranlage) {
        $Name = $_.Name
        $UaName = $_.Unteranlage.Name
        $IPString = "$($_.Unteranlage.IP)/$($_.Unteranlage.Netmask)"
        $DNS = $_.Unteranlage.DNS
        $RoutesString = Get-RoutesString -XmlRoutes $_.Unteranlage.Route
        $RoutesInfo = $_.Unteranlage.Route
    } else {
        $Name = $_.Name
        $UaName = ""
        $IPString = "$($_.IP)/$($_.Netmask)"
        $DNS = $_.DNS
        $RoutesString = Get-RoutesString -XmlRoutes $_.Route
        $RoutesInfo = $_.Route
    }

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