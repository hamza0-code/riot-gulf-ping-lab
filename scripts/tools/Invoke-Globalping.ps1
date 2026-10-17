# Runs ping/traceroute from public Globalping probes (https://globalping.io) so you can measure paths you
# can't reach yourself: e.g. Dubai -> Riyadh, or other Pakistani ISPs -> Riyadh. No account needed.
#   .\Invoke-Globalping.ps1 -Target dynamodb.me-west-1.amazonaws.com -From Pakistan -Limit 20
#   .\Invoke-Globalping.ps1 -Target 35.71.92.128 -From 'AS31898+AE' -Type traceroute
#   .\Invoke-Globalping.ps1 -Target dynamodb.me-west-1.amazonaws.com -From Dubai -Protocol TCP
param(
    [Parameter(Mandatory)][string]$Target,
    [Parameter(Mandatory)][string]$From,          # city, country, network name, or ASN combos like 'AS31898+AE'
    [ValidateSet('ping', 'traceroute')][string]$Type = 'ping',
    [ValidateSet('ICMP', 'TCP')][string]$Protocol = 'ICMP',
    [int]$Limit = 4
)
$opts = @{ protocol = $Protocol }
if ($Type -eq 'ping') { $opts.packets = 8 }
if ($Protocol -eq 'TCP') { $opts.port = 443 }
$body = @{ type = $Type; target = $Target; limit = $Limit; locations = @(@{ magic = $From }); measurementOptions = $opts } | ConvertTo-Json -Depth 5
$m = Invoke-RestMethod -Method Post -Uri https://api.globalping.io/v1/measurements -ContentType 'application/json' -Body $body
do { Start-Sleep 2; $r = Invoke-RestMethod "https://api.globalping.io/v1/measurements/$($m.id)" } while ($r.status -eq 'in-progress')

foreach ($x in $r.results) {
    $probe = "$($x.probe.city), $($x.probe.country) | $($x.probe.network) AS$($x.probe.asn)"
    if ($Type -eq 'ping') {
        [pscustomobject]@{ Probe = $probe; Min = $x.result.stats.min; Avg = $x.result.stats.avg; Loss = $x.result.stats.loss }
    } else {
        "-- $probe"
        foreach ($h in $x.result.hops) { "   {0,-16} {1}" -f $h.resolvedAddress, (($h.timings | ForEach-Object { $_.rtt }) -join ' ') }
    }
}
