# Shows where a network (default: Riot Games, AS6507) connects to others, from PeeringDB, and optionally
# the member list of an internet exchange. A relay only helps if it hands traffic to Riot directly.
#   .\Get-PeeringInfo.ps1                       # Riot's exchanges + Middle East/South Asia facilities
#   .\Get-PeeringInfo.ps1 -Exchange 'SAIX'      # members of SAIX (Saudi Arabia)
param([int]$Asn = 6507, [string]$Exchange)

$net = (Invoke-RestMethod "https://www.peeringdb.com/api/net?asn=$Asn").data[0]
"$($net.name) (AS$Asn), peering policy: $($net.policy_general)"
"`nExchanges:"
(Invoke-RestMethod "https://www.peeringdb.com/api/netixlan?net_id=$($net.id)").data |
    Select-Object name, speed, ipaddr4 | Sort-Object name | Format-Table -AutoSize
"Facilities in the Middle East / South Asia:"
(Invoke-RestMethod "https://www.peeringdb.com/api/netfac?net_id=$($net.id)").data |
    Where-Object { $_.country -in 'AE', 'SA', 'BH', 'QA', 'OM', 'KW', 'PK', 'IN' } |
    Select-Object name, city, country | Format-Table -AutoSize

if ($Exchange) {
    foreach ($ix in (Invoke-RestMethod "https://www.peeringdb.com/api/ix?name__contains=$Exchange").data) {
        $members = (Invoke-RestMethod "https://www.peeringdb.com/api/netixlan?ix_id=$($ix.id)").data
        $ids = ($members.net_id | Sort-Object -Unique) -join ','
        "`n== $($ix.name) ($($ix.city))"
        (Invoke-RestMethod "https://www.peeringdb.com/api/net?id__in=$ids").data |
            Select-Object asn, name, info_type, policy_general | Sort-Object name | Format-Table -AutoSize
    }
}
