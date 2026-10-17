# 06 - Relay results

## Tunnel health (Oracle Riyadh, port pinned)

| Check | Result |
|---|---|
| Tunnel service | running, handshake every <2 min |
| Riot traffic route | `riot-relay` interface |
| Other traffic | Ethernet (unchanged) |
| Ping through tunnel to relay | 53 ms min/median, 54 max, 40/40 |

## VALORANT's own measurements (from the logs)

| Time (UTC) | Relay | Riyadh | Mumbai |
|---|---|---|---|
| before | off | 61 | 66-67 |
| 22:13 | on | 71 | 117 |
| 22:47 | on | 150 | 128 |
| 22:50 | on | 150 | 156 |
| 22:53 | on | 229 | 274 |
| 22:56 | on | 71 | 117 |

Mumbai got worse too, because *all* Riot traffic hairpins through Riyadh.

## Why it lost

Path from the relay toward Riot's Riyadh exchange address:

```
1  Oracle Riyadh                0.2 ms
2  87.109.x (Saudi carrier)     0.4 ms
3  87.101.x (Saudi carrier)     1.8 ms
4  10.0.28.x                   13.6 ms   <- already left Riyadh
5+ no replies
```

Oracle isn't connected at SAIX, where Riot meets Saudi networks, so it hands Riot-bound traffic to a carrier
whose route leaves the city first. A VM can't choose its upstream; only Oracle's routing decides. Port
pinning can't help on this leg either: Riot's addresses give nothing to measure per port, and the in-game
spikes point to congestion rather than a stable second path.

**Verdict:** relay turned off. The direct route (61 ms) is better.
