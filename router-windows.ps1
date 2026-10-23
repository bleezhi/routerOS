#Requires -RunAsAdministrator
# Turns a Windows 10/11 PC into a router using Internet Connection Sharing (NAT + DHCP).
# Windows itself must be installed from Microsoft media (can't be redistributed/modified here).
# Multiple LAN ports: bridge them first in ncpa.cpl (select NICs > right-click > Bridge Connections) and pick the bridge.
$ErrorActionPreference = 'Stop'
$name = Read-Host "Computer name (blank = keep current)"
if ($name) { Rename-Computer -NewName $name -Force }

Get-NetAdapter | Format-Table Name, InterfaceDescription, Status, MacAddress -AutoSize
$wan = Read-Host "WAN adapter name (internet side)"
$lan = Read-Host "LAN adapter name (clients side)"
$lanIp = Read-Host "LAN router IP [192.168.10.1]"; if (-not $lanIp) { $lanIp = '192.168.10.1' }
$base = $lanIp.Substring(0, $lanIp.LastIndexOf('.'))

# Custom ICS subnet (/24)
$k = 'HKLM:\SYSTEM\CurrentControlSet\Services\SharedAccess\Parameters'
Set-ItemProperty $k ScopeAddress $lanIp
Set-ItemProperty $k ScopeAddressBackup $lanIp
Set-ItemProperty $k StartAddress "$base.100"
Set-ItemProperty $k EndAddress "$base.250"

Set-Service SharedAccess -StartupType Automatic
Start-Service SharedAccess

$m = New-Object -ComObject HNetCfg.HNetShare
function Get-Conn($n) { foreach ($c in $m.EnumEveryConnection) { if ($m.NetConnectionProps.Invoke($c).Name -eq $n) { return $c } } throw "Adapter '$n' not found" }
foreach ($c in $m.EnumEveryConnection) { $cfg = $m.INetSharingConfigurationForINetConnection.Invoke($c); if ($cfg.SharingEnabled) { $cfg.DisableSharing() } }
$m.INetSharingConfigurationForINetConnection.Invoke((Get-Conn $wan)).EnableSharing(0)  # public
$m.INetSharingConfigurationForINetConnection.Invoke((Get-Conn $lan)).EnableSharing(1)  # private
Get-NetIPInterface | Where-Object AddressFamily -eq IPv4 | Set-NetIPInterface -Forwarding Enabled
Write-Host "Router ready. LAN $lanIp, DHCP $base.100-$base.250. Reboot recommended."
