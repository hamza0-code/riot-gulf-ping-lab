# Measures round-trip time from this PC to cloud regions and game-adjacent endpoints using TCP handshakes
# (works where ICMP ping is blocked). Min is the path's true floor; a large gap between min and median
# usually means the path is split across a fast and a slow route.
#   .\Measure-Targets.ps1                 # default Gulf / South Asia list
#   .\Measure-Targets.ps1 -Samples 60
param([int]$Samples = 40)

$targets = [ordered]@{
    'AWS Riyadh (me-west-1, not public yet)' = 'dynamodb.me-west-1.amazonaws.com'
    'AWS UAE (me-central-1)'                 = 'dynamodb.me-central-1.amazonaws.com'
    'AWS Bahrain (me-south-1)'               = 'dynamodb.me-south-1.amazonaws.com'
    'AWS Mumbai (ap-south-1)'                = 'dynamodb.ap-south-1.amazonaws.com'
    'Oracle Riyadh'                          = 'objectstorage.me-riyadh-1.oraclecloud.com'
    'Oracle Jeddah'                          = 'objectstorage.me-jeddah-1.oraclecloud.com'
    'Oracle Dubai'                           = 'objectstorage.me-dubai-1.oraclecloud.com'
    'Oracle Abu Dhabi'                       = 'objectstorage.me-abudhabi-1.oraclecloud.com'
    'Oracle Mumbai'                          = 'objectstorage.ap-mumbai-1.oraclecloud.com'
    'Huawei Riyadh'                          = 'obs.me-east-1.myhuaweicloud.com'
    'Alibaba Riyadh'                         = 'oss-me-central-1.aliyuncs.com'
    'Alibaba Dubai'                          = 'oss-me-east-1.aliyuncs.com'
}

$jobs = foreach ($name in $targets.Keys) {
    Start-Job -ArgumentList $name, $targets[$name], $Samples {
        param($name, $target, $n)
        $h, $port = $target -split ':'; if (-not $port) { $port = 443 }
        try { $ip = [System.Net.Dns]::GetHostAddresses($h) | Where-Object AddressFamily -eq 'InterNetwork' | Select-Object -First 1 } catch {}
        if (-not $ip) { return [pscustomobject]@{ Target = $name; IP = 'no DNS' } }
        $rt = @()
        for ($i = 0; $i -lt $n; $i++) {
            $c = New-Object System.Net.Sockets.TcpClient
            $sw = [Diagnostics.Stopwatch]::StartNew()
            $a = $c.BeginConnect($ip, [int]$port, $null, $null)
            if ($a.AsyncWaitHandle.WaitOne(1500)) { try { $c.EndConnect($a); $rt += $sw.Elapsed.TotalMilliseconds } catch {} }
            $c.Close(); Start-Sleep -Milliseconds 150
        }
        if (-not $rt) { return [pscustomobject]@{ Target = $name; IP = "$ip"; OK = 0 } }
        $s = $rt | Sort-Object
        [pscustomobject]@{
            Target = $name; IP = "$ip"
            Min    = [math]::Round($s[0], 1)
            Median = [math]::Round($s[[int]($s.Count / 2)], 1)
            P90    = [math]::Round($s[[int]($s.Count * 0.9)], 1)
            OK     = "$($s.Count)/$n"
        }
    }
}
$jobs | Wait-Job -Timeout 300 | Out-Null
$jobs | Receive-Job | Select-Object Target, IP, Min, Median, P90, OK |
    Sort-Object { if ($_.Min) { $_.Min } else { 9999 } } | Format-Table -AutoSize
$jobs | Remove-Job -Force
