function Get-RoutesString {
    param (
        [array]$XmlRoutes
    )

    $Routes = @()
    foreach ($Route in $XmlRoutes) {
        $Routes += "$($Route.Network)/$($Route.Netmask) ($($Route.Name)) via $($Route.Gateway)"
    }
    
    return ($Routes -join "`n")
}

[xml]$IPCofigurations = Get-Content -Path .\test.xml

$IPCofigurations.Anlagen.Anlage | ForEach-Object {

    if ($_.Unteranlage) {
        $Name = $_.Unteranlage.Name
        $IPString = "$($_.Unteranlage.IP)/$($_.Unteranlage.Netmask)"
        $RoutesString = Get-RoutesString -XmlRoutes $_.Unteranlage.Route
    } else {
        $Name = $_.Name
        $IPString = "$($_.IP)/$($_.Netmask)"
        $RoutesString = Get-RoutesString -XmlRoutes $_.Route
    }

    [PSCustomObject]@{
        Anlage = $Name
        IP = $IPString
        Routen = $RoutesString
    }
} | Format-Table -AutoSize -Wrap