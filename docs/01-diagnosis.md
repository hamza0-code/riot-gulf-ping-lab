# 01 - Diagnosis

Goal: find out whether the extra ping comes from the PC, the home network, or the route.

## Line quality (wired Ethernet, Realtek 1 Gbps)

| Test | Result |
|---|---|
| Ping to router, 60 samples | 1 ms, 0 jitter, 0% loss |
| Ping to 1.1.1.1 (Cloudflare node in Islamabad), 60 samples | 2.5 ms avg, 0% loss |
| Ping to 8.8.8.8, 60 samples | 44.7 ms avg, 0.6 ms jitter, 0% loss |
| Ping to 1.1.1.1 during a 132 Mbps upload | 2-3 ms (no bufferbloat) |

The local network is clean. Nothing here explains a 6-8 ms gap to other players.

## VALORANT's own ping measurements

VALORANT logs the ping it measures to every server pod in
`%LOCALAPPDATA%\VALORANT\Saved\Logs\ShooterGame*.log`, both at login (`Party_FetchPlayer`) and every ~3
minutes while the client is open (`Party_RefreshPings`), as URL query parameters such as
`aresriot.aws-ksa1-prod.eu-gp-riyadh-1=61`. `scripts/pc/Check-ValorantPing.ps1` extracts them.

Across 45+ samples over two days:

| Pod | Min | Median | Max |
|---|---|---|---|
| Riyadh (aws-ksa1) | 61 | 61 | 74 |
| Mumbai (aws-aps1) | 66 | 68 | 82 |
| Paris | 128 | 129 | 143 |
| Frankfurt | 135 | 137 | 150 |
| London | 136 | 137 | 150 |
| Istanbul | 166 | 167 | 180 |
| Tokyo | 169 | 175 | 178 |
| Cape Town | 335 | 341 | 343 |

A ping that sits at **exactly 61 every time** is set by path length, not by congestion or the PC. A PC or
Wi-Fi problem shows up as variance, not a flat floor.

## Game server address

The log line `LogTravelManager: Beginning travel to <ip>:<port>` gives the match server. Every Riyadh match
went to `162.249.75.1` (port varies per match), which is **Riot Direct** (AS6507). It drops ICMP, TCP and
UDP probes, so it can't be pinged directly. Use AWS Riyadh (`35.71.92.128`, answers ping, ~60 ms here) as a
stand-in for the route.

## Traceroute from the PC

```
 1   <1 ms  home router
 2    2 ms  ISP access
 3-7  2 ms  ISP core (private addresses)
 8   22 ms  110.93.x.x   Transworld Associates (international carrier, Karachi)
 11  34 ms  110.93.x.x   Transworld, last visible hop
 ...         hidden, destination reached at ~60 ms
```

Roughly 20 ms is spent just getting from Islamabad to the cable landing in Karachi.
