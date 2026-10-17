# Finds which local UDP source ports land on the fast path to your relay.
# Some links (e.g. Dubai -> Riyadh on Oracle) balance flows across two routes by hashing the port numbers,
# so the same relay can be ~53 ms on one port and ~77 ms on another. WireGuard keeps one source port for
# the whole session, so pinning a fast port (ListenPort in the tunnel config) keeps you on the fast route.
#
# Temporarily stops WireGuard on the relay, runs a tiny UDP echo on port 51820, scans, then restores it.
#   .\Find-FastPort.ps1 -RelayIP 203.0.113.10 -SshKey C:\path\key.key
param(
    [Parameter(Mandatory)][string]$RelayIP,
    [Parameter(Mandatory)][string]$SshKey,
    [string]$User = 'ubuntu',
    [int]$FirstPort = 40000,
    [int]$Count = 40,
    [int]$Probes = 12
)
$ssh = @('-i', $SshKey, '-o', 'StrictHostKeyChecking=accept-new', '-o', 'BatchMode=yes', "$User@$RelayIP")

$py = "import socket`ns=socket.socket(socket.AF_INET,socket.SOCK_DGRAM)`ns.bind(('0.0.0.0',51820))`nwhile True:`n d,a=s.recvfrom(256)`n s.sendto(d,a)"
$b64 = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes($py))
# The echo stops itself after 240 s and WireGuard comes back even if this script is interrupted.
ssh @ssh "echo $b64 | base64 -d > /tmp/echo.py; sudo systemd-run --unit=udpecho --collect bash -c 'systemctl stop wg-quick@wg0; iptables -I INPUT -p udp --dport 51820 -j ACCEPT; timeout 240 python3 /tmp/echo.py; iptables -D INPUT -p udp --dport 51820 -j ACCEPT; systemctl start wg-quick@wg0'"
Start-Sleep 3

try {
    $res = foreach ($port in $FirstPort..($FirstPort + $Count - 1)) {
        $u = New-Object System.Net.Sockets.UdpClient($port)
        $u.Client.ReceiveTimeout = 400
        $u.Connect($RelayIP, 51820)
        $rt = @()
        for ($i = 0; $i -lt $Probes; $i++) {
            $sw = [Diagnostics.Stopwatch]::StartNew()
            [void]$u.Send([byte[]](1..32), 32)
            try { $ep = $null; [void]$u.Receive([ref]$ep); $rt += $sw.Elapsed.TotalMilliseconds } catch {}
            Start-Sleep -Milliseconds 40
        }
        $u.Close()
        $s = $rt | Sort-Object
        [pscustomobject]@{ Port = $port; Min = [math]::Round($s[0], 1); Median = [math]::Round($s[[int]($s.Count / 2)], 1); OK = $s.Count }
    }
} finally {
    # Stop the echo early and bring WireGuard back (the iptables rule is removed by the unit's own cleanup
    # only on timeout, so remove it here when stopping early).
    ssh @ssh "sudo systemctl stop udpecho 2>/dev/null; sudo iptables -D INPUT -p udp --dport 51820 -j ACCEPT 2>/dev/null; sudo systemctl start wg-quick@wg0; rm -f /tmp/echo.py"
}

$res | Sort-Object Median | Format-Table -AutoSize
$best = $res | Sort-Object Median | Select-Object -First 1
"Best port: $($best.Port) ($($best.Median) ms). Use it with: .\Connect-RiotRelay.ps1 ... -ListenPort $($best.Port)"
