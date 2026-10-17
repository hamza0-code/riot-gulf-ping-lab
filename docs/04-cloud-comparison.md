# 04 - Cloud relay candidates

A relay only helps if **(PC -> relay) + (relay -> Riot)** beats the direct route (61 ms). All numbers are
from Islamabad on the test connection, using TCP handshake RTT (`scripts/tools/Measure-Targets.ps1`,
40 samples each), October 2026.

## PC -> relay location

| Cloud / region | Min | Median | Notes |
|---|---|---|---|
| Oracle Dubai | 40.1 | 41.8 | stable; not free outside your home region |
| AWS UAE (me-central-1) | 40.2 | 42.3 | AWS: region "unable to reliably support customer applications" |
| Oracle Abu Dhabi | 45.1 | 47.2 | |
| Oracle Riyadh | 52.4 | 62.8 | bimodal 53 / 77 (ECMP), pin a fast port |
| Google Cloud Doha | 53.9 | 56.1 | Cloud Run request RTT, includes 1-3 ms server time |
| Google Cloud Dammam | 55.9 | 61.3 | bimodal, p90 78 |
| AWS Riyadh (me-west-1) | 58.6 | 60.6 | not open to customers |
| Oracle Jeddah | 66.9 | 70.3 | |
| AWS Mumbai | 109 | 111 | |
| Huawei Riyadh | 128 | 130 | |
| Alibaba Riyadh | 159 | 163 | |
| Alibaba Dubai | 189 | 192 | |
| Oracle Mumbai | 208 | 225 | Pakistan -> India detours abroad |
| Google Tel Aviv | 209 | 213 | |
| AWS Bahrain | n/a | n/a | down |

## SAIX members (networks that meet Riot in Riyadh)

Pinging Saudi-geolocated addresses in each SAIX member network from the PC:

| Member | PC -> network |
|---|---|
| Sphera | 70 ms |
| STC | 103 ms |
| Sahara Net | 108 ms |
| Kalaam | 133 ms |
| Salam | 137 ms |
| DETASAD | 138 ms |
| WafaiCloud | 148 ms |
| Kaopu Cloud | 175 ms |

These meet Riot ~1 ms away in Riyadh, but reaching them from Pakistan costs 70+ ms.

## Relay -> Riot leg

Riot's game addresses don't answer probes, so this leg can only be measured by VALORANT itself, or inferred:

- **Oracle Riyadh -> Riot:** Oracle isn't a SAIX member. It hands traffic to a Saudi carrier, which is
  already 13.6 ms away at the next hop. Measured in-game: about +18 ms, with spikes.
- **Oracle UAE -> Riot / AWS Riyadh:** a probe inside Oracle Abu Dhabi hands traffic to **du** (EITC), not
  Riot; AWS Riyadh is 26 ms away from there.
- **Dubai probes (M247, BrainStorm, LightNode) -> AWS Riyadh:** 22-27 ms.
- **Bahrain probes -> AWS Riyadh:** about 30 ms minimum, very unstable.

## Estimated totals

| Relay | Estimate | Verdict |
|---|---|---|
| Oracle Riyadh | 53 + 18 = **71 (measured)** | worse |
| Oracle / AWS Dubai | 40 + 20-26 = 60-66 | same or worse, and paid |
| Google Dammam | 55-58 + 5-8 = 58-63 | coin flip, paid after trial, card checks strict |
| Karachi relay | 22 + 38 = 60 | same |
| Any SAIX member | 70+ | worse |

## Account notes from testing

- **Oracle Always Free** works only in the home region chosen at signup (permanent). Riyadh offers
  `VM.Standard.A1.Flex` (Ampere); the AMD Micro shape may not be listed.
- **Google Cloud** rejected a Pakistani card at the risk-check stage (`OR_BACR2_31`) after the verification
  charge succeeded. The verification charge is reversed automatically.
- **AWS** new-account Free plan blocks most instance types; check the region status first.
