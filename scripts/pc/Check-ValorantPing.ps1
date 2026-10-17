# Reads the ping VALORANT itself measured to every server (logged each time the party refreshes)
# and prints it per log session, newest last. Run after playing to compare before/after any change.
# No admin needed.

$Logs = "$env:LOCALAPPDATA\VALORANT\Saved\Logs"
$rows = foreach ($f in Get-ChildItem $Logs -Filter 'ShooterGame*.log' | Sort-Object LastWriteTime) {
    $hits = Select-String -Path $f.FullName -Pattern '\[(\d{4}\.\d\d\.\d\d-\d\d\.\d\d)[^\]]*\].*Party_(?:FetchPlayer|RefreshPings)\], URL \[(?:GET|POST) [^?]+\?([^ \]]+)'
    foreach ($h in $hits) {
        $ping = @{}
        foreach ($kv in $h.Matches[0].Groups[2].Value -split '&') {
            $k, $v = $kv -split '=', 2
            if ($v -match '^\d+$' -and $k -match 'gp-(\w+)-\d') { $ping[$Matches[1]] = [int]$v }
        }
        [pscustomobject]@{ Time = $h.Matches[0].Groups[1].Value; Riyadh = $ping.riyadh; Mumbai = $ping.mumbai; Bahrain = $ping.bahrain; Dubai = $ping.dubai }
    }
}
if (-not $rows) { Write-Host "No ping samples found in $Logs"; exit }
$rows | Group-Object { $_.Time.Substring(0, 13) } | ForEach-Object {
    $r = $_.Group | Where-Object Riyadh | ForEach-Object Riyadh | Sort-Object
    $m = $_.Group | Where-Object Mumbai | ForEach-Object Mumbai | Sort-Object
    [pscustomobject]@{
        Hour          = $_.Name
        Samples       = $_.Count
        'Riyadh min'  = $r | Select-Object -First 1
        'Riyadh med'  = $(if ($r) { @($r)[[int](@($r).Count / 2)] })
        'Mumbai med'  = $(if ($m) { @($m)[[int](@($m).Count / 2)] })
    }
} | Format-Table -AutoSize

