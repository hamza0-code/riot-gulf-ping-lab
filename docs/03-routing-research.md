# 03 - Routing research

## How VALORANT traffic travels

1. **Game servers:** AWS. Pod names in the logs map to AWS sites: `aws-ksa1` (Riyadh), `aws-aps1` (Mumbai),
   `aws-euc1` (Frankfurt), `aws-afs1` (Cape Town), and so on.
2. **Access network:** Riot Direct (AS6507). Players connect to a Riot-owned address (`162.249.75.1` for
   these Riyadh matches). Traffic enters Riot's backbone where Riot meets your ISP's upstream, then rides
   Riot's private network to the AWS-hosted server.

So the only part of the path that differs between players is **from their ISP to the point where Riot picks
the traffic up**.

## Where Riot connects in the region (PeeringDB)

`scripts/tools/Get-PeeringInfo.ps1` (AS6507, policy: *Selective*):

| Location | Type |
|---|---|
| **UAE-IX**, Dubai | public exchange (2 ports) |
| **Equinix DX1**, Dubai | facility |
| **SAIX**, Riyadh | public exchange (Saudi national IX) |
| **center3 RUH1**, Riyadh | facility |
| DE-CIX Mumbai, Extreme IX Mumbai/Delhi, DE-CIX Delhi | India |

No Pakistani exchange or facility. Every Pakistani ISP hands VALORANT traffic to an international carrier
first.

## AWS Riyadh region

AWS's public `ip-ranges.json` lists a region `me-west-1` (e.g. `35.71.92.0/24`) that the AWS SDKs don't yet
describe publicly. It answers from ~60 ms here, matching the VALORANT Riyadh pod, and is almost certainly the
Saudi region that VALORANT's `aws-ksa1` pods run in. It wasn't open for customer VMs at the time of testing.

AWS **Bahrain** (`me-south-1`) didn't answer from anywhere, including probes inside Bahrain, and AWS
**UAE** (`me-central-1`) showed *"currently unable to reliably support customer applications"* when launching
instances.

## The ISP has three exits out of Pakistan

Traceroutes from the test connection (an Islamabad fiber ISP) show different exits per destination:

| Exit | Used for | Gulf arrival |
|---|---|---|
| Transworld (110.93.x) | AWS Riyadh / VALORANT, AWS UAE, AWS Singapore | last visible hop 34 ms; Riyadh at **59-60 ms** |
| Direct to UAE-IX (185.1.8.24) | Oracle Dubai / Riyadh | UAE-IX at **41 ms**; Oracle Riyadh at **53 ms** (fast path) |
| Zain Omantel | Valve EU servers | first hop 56 ms |

The UAE-IX exit is the most interesting: Riot also connects at UAE-IX. Routing Riot traffic through it is a
change only the ISP can make (see [07](07-isp-route-request.md)).

## Other Pakistani connections (Globalping public probes)

`Invoke-Globalping.ps1 -Target dynamodb.me-west-1.amazonaws.com -From Pakistan -Protocol TCP -Limit 20`

| City | Network | To AWS Riyadh (min) |
|---|---|---|
| Karachi | Sharp Telecom | 38 ms |
| Karachi | 2E Telekom | 38 ms |
| Faisalabad | Aero Cable | 53 ms |
| Islamabad | Virtury Cloud (data center) | 58-61 ms |
| Islamabad | Nayatel | 58.6 ms |
| Lahore | PTCL | 58-68 ms |
| Islamabad | BrainStorm | 61 ms |
| Islamabad | Cyber Internet Services (StormFiber) | 65 ms |

Takeaways:
- **Location dominates.** Karachi, where the submarine cables land, is ~20 ms closer to the Gulf than Islamabad.
- In Islamabad, the tested ISP was already among the best measured. Switching ISP isn't a guaranteed fix
  (one probe per network; treat as indicative).
- A relay in Karachi doesn't help an Islamabad player: about 22 ms to Karachi plus 38 ms to Riyadh is about 60,
  the same as direct.

## The ECMP discovery

Paths into Oracle Riyadh were **bimodal**: some connections ~53 ms, others ~77 ms. Testing 40 fixed UDP
source ports showed the split is per-flow (5-tuple hashing across two links): 23 ports landed on 52.7-55.6 ms,
17 on 74-78 ms. WireGuard keeps one source port per session, so pinning `ListenPort` to a fast port keeps
the tunnel on the fast link (`scripts/tools/Find-FastPort.ps1`).

The direct route to AWS Riyadh showed **no** such split: 40 random-port samples all fell in 58.6-61.2 ms.
