# 07 - Asking the ISP to fix the route

Since the slow part is the ISP's choice of exit, the ISP is the one party that can fix it.

## Nayatel Optimus (example ISP gaming-route service)

Optimus re-routes selected destinations and offers two profiles, **Western** and **Eastern**. When the
profile changes, your **public IP changes** (a different address pool with different routing). That's
how you confirm it applied.

Portal test values at the time:

| Test server | Eastern | Western |
|---|---|---|
| AWS Dubai edge `75.2.105.73` | 39.0 | 39.6 |
| Valve EU `185.25.182.1` | 145.0 | 144.6 |
| AWS Singapore `54.255.0.2` | 102.9 | 95.5 |

Results for VALORANT Riyadh (`35.71.92.128`):

| Profile | Public IP changed? | Riyadh ping | Exit |
|---|---|---|---|
| (default) | n/a | 60 | Transworld |
| Western | yes | 60 | Transworld, identical hops |
| Eastern | yes | 60 | Transworld, identical hops |

Neither profile covers Riyadh. The ISP's own help page asks for a **traceroute to the game server** by
email or WhatsApp before a ticket.

## What to send

1. Traceroutes:
   ```
   tracert -d 162.249.75.1      (VALORANT game server; hops stop at the carrier, which is expected)
   tracert -d 35.71.92.128      (AWS Riyadh; reachable)
   ping -n 20 35.71.92.128
   ```
2. A short explanation with the evidence. Template:

> **Subject:** OPTIMUS - VALORANT Riyadh latency not optimized (traceroute attached)
>
> I'm an OPTIMUS subscriber on a wired connection. Since VALORANT's Bahrain and Dubai servers went offline,
> Middle East players are placed on Riyadh. My ping there is 60-61 ms on both the Western and Eastern profiles.
> My public IP changes when I switch, but the route is identical: it always exits via Transworld.
>
> Your UAE-IX exit reaches Riyadh in about 53 ms, and Riot Games also connects at UAE-IX.
>
> Please add these to OPTIMUS via the UAE-IX path, or the fastest upstream to Riyadh:
> - 162.249.72.0/21: Riot Games (AS6507), VALORANT game server observed 162.249.75.1
> - 35.71.92.0/24: AWS Saudi Arabia (VALORANT Riyadh hosting); 35.71.92.128 answers ping
>
> Traceroutes and a ping test are attached.

The ISP's line is the one change that can realistically bring Riyadh from ~60 back toward ~53.
