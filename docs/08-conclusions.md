# 08 - Conclusions

## What the data says

1. **The PC was not the problem.** 1 ms to the router, 0% loss, no bufferbloat, and a flat 61 ms in
   VALORANT. Tuning is worth doing for consistency, but it doesn't move route time.
2. **The first leg decides everything.** From Islamabad every route reaches the Gulf at ~40 ms at best, and
   about 20 ms of that is just getting to Karachi.
3. **Relays add a stop, they don't remove one.** Every cloud relay must re-enter Riot's network from a
   cloud provider's upstream. None of the clouds tested hand traffic to Riot directly in the Gulf (Oracle ->
   Saudi carrier / du; SAIX members are 70+ ms away from Pakistan).
4. **Multipath / packet duplication** (ExitLag's "multipath") only smooths spikes and loss. It can't beat
   the fastest single path, and this line had no spikes to smooth.
5. **The ISP has a faster exit (UAE-IX, ~53 ms to Riyadh) that it isn't using for Riot traffic.** Getting
   Riot prefixes routed through it is the realistic path to a significant gain.

## Decision guide for others

| Your situation | Try |
|---|---|
| Ping varies a lot, or has loss | PC tuning, a wired connection, check bufferbloat; multipath GPNs can help |
| Flat ping, but higher than friends **in the same city on another ISP** | ask your ISP to re-route, or switch ISP |
| Flat ping, same as others in your city | that's the route floor; relays very unlikely to help |
| You can reach a cloud that peers with Riot near the server in under (direct - 5) ms | build the relay in 05 |

## Things that did not work (so you don't have to try them)

- Static routes on Windows "directly" to Riot IPs: the only next hop is your router; the ISP picks the path.
- Oracle Riyadh relay: 71 ms (vs 61) with spikes, even with the fast-path port pinned.
- Oracle Mumbai relay idea: 208 ms to the relay (Pakistan -> India traffic detours abroad).
- AWS Bahrain / UAE: unavailable at the time.
- Google Cloud: card rejected at the risk check, and the estimate was only 58-63 anyway.
- Nayatel Optimus Western/Eastern profiles: no effect on Riyadh (not on its list).
