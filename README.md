# riot-gulf-ping-lab

Can a player in **Islamabad, Pakistan** lower their VALORANT ping to the **Riyadh** server with PC tuning, a
self-hosted ExitLag-style relay, or a different cloud route? This repo documents the full investigation
(October 2026), the scripts used, every measurement, and what actually worked.

**Short answer:** the PC was tuned as far as it goes, and every relay tested came out equal or worse.
On this connection ~60 ms to Riyadh is the floor of the ISP's current route. The only lever left is the
ISP's own routing (here: Nayatel's Optimus gaming-route service).

| Setup | VALORANT Riyadh ping |
|---|---|
| Direct (baseline) | **61 ms**, rock steady |
| Direct + PC tuning | 61 ms (tuning removes ~1-3 ms of local jitter, not route time) |
| Oracle Riyadh relay (WireGuard, Riot-only split tunnel) | **71 ms**, spikes to 150-229 |
| Best estimate for any other cloud relay | 58-66 ms |

## Background

- In March 2026 VALORANT's **Bahrain** and **Dubai** servers went offline; Middle East players were moved to
  **Riyadh** (and Mumbai). Pakistani players who used to get 33-42 ms now get ~60.
- VALORANT game servers run on **AWS** (pod names like `aws-ksa1-prod.eu-gp-riyadh-1`) but players connect
  through **Riot Direct** (AS6507), Riot's own backbone. The game server address (`162.249.75.1` here) is
  Riot Direct, not AWS, and it ignores ping/traceroute.

## Repo layout

```
docs/
  01-diagnosis.md            baseline: line quality, VALORANT's own ping logs, game server IPs
  02-pc-tuning.md            what the Windows tune-up changes and why (and what was skipped as placebo)
  03-routing-research.md     Riot Direct, PeeringDB, UAE-IX / SAIX, ISP exits, other Pakistani ISPs
  04-cloud-comparison.md     every cloud region measured, with numbers
  05-oracle-relay-guide.md   step-by-step: free Oracle Cloud VM in Riyadh as a WireGuard relay
  06-relay-results.md        what the relay did in-game and why it lost
  07-isp-route-request.md    ISP gaming-route service (Optimus), traceroute report, email template
  08-conclusions.md          what works, what doesn't, and what to try in your situation
scripts/
  pc/      Optimize-Network.ps1, Revert-Network.ps1, RUN-TUNE-UP.cmd, Check-ValorantPing.ps1
  relay/   server-setup.sh (cloud-init), Connect-RiotRelay.ps1, launchers, Disconnect-RiotRelay.ps1
  tools/   Measure-Targets.ps1, Find-FastPort.ps1, Invoke-Globalping.ps1, Get-PeeringInfo.ps1
```

## Quick start

1. **See your real VALORANT ping history** (no admin): `scripts\pc\Check-ValorantPing.ps1`.
   It reads the ping VALORANT itself measures to every server, from the game's log files.
2. **Tune the PC** (admin, reversible): double-click `scripts\pc\RUN-TUNE-UP.cmd`, click Yes, reboot.
   Undo with `Revert-Network.ps1`.
3. **Measure routes** before spending money on anything: `scripts\tools\Measure-Targets.ps1`.
4. **Only if a relay location is clearly faster than your direct route**, follow
   [docs/05-oracle-relay-guide.md](docs/05-oracle-relay-guide.md).

## Safety notes

- The relay only carries Riot Games address space (AS6507); all other traffic stays on your normal line.
- Never commit `*.key`, `*.pem`, `riot-relay.conf` or `network-backup.json`; `.gitignore` excludes them.
- Using a VPN/relay with VALORANT is not against Riot's rules as of writing, but check your local laws and
  your ISP's terms.

## License

MIT, see [LICENSE](LICENSE).
