# 05 - Oracle Cloud relay guide (free tier)

Builds a WireGuard relay that carries **only Riot Games traffic**, like a self-hosted ExitLag. Read
[04](04-cloud-comparison.md) first: measure whether a relay location can actually beat your direct route.

## 1. Account

1. Go to oracle.com/cloud/free and click **Start for free**.
2. **Home region:** pick the region you want the relay in. **This can't be changed later**, and Always Free
   only works there.
3. Card verification places a temporary charge, which is reversed. Pakistani cards: enable international/online
   transactions in your bank app first. Prepaid and virtual cards are often refused.
4. Two-factor sign-in: Oracle's first-time QR code is in Oracle's own format, which Google Authenticator
   rejects ("not a valid authenticator QR code"). Use **Oracle Mobile Authenticator** for the first setup.
5. New accounts show *"provisioning in progress"* on some pages for up to an hour.

Staying free: never click **Upgrade to Pay As You Go**, only create *Always Free-eligible* shapes, and set
**Billing -> Budgets** to alert at $1.

## 2. Network (VCN)

Creating a public subnet inside the instance wizard may leave **"Assign public IPv4"** greyed out. Use the
wizard instead:

1. Menu -> **Networking -> Virtual cloud networks -> Start VCN Wizard**.
2. **Create VCN with Internet Connectivity**, name `riot-vcn`, defaults -> **Create**.
3. In the VCN, open **Security -> Default Security List -> Add Ingress Rules**: source `0.0.0.0/0`,
   **UDP**, destination port `51820`.

## 3. Instance

Menu -> **Compute -> Instances -> Create instance**

| Setting | Value |
|---|---|
| Image | Canonical Ubuntu 24.04 (aarch64 for Ampere) |
| Shape | `VM.Standard.A1.Flex`, 1 OCPU / 6 GB (or `VM.Standard.E2.1.Micro` if offered) |
| Capacity type | On-demand |
| Networking | existing `riot-vcn`, **public** subnet, tick *Automatically assign public IPv4* |
| SSH keys | Generate, and **download the private key** |
| Management -> Initialization script | paste `scripts/relay/server-setup.sh` |

`server-setup.sh` installs WireGuard, enables forwarding and NAT, opens UDP 51820 above Oracle's default
iptables REJECT rules, and writes the PC-side config to `/etc/wireguard/client.conf` with
`AllowedIPs` = Riot Games prefixes only. It runs once; re-runs exit early so the keys never change.

## 4. Connect the PC

1. Edit `scripts/relay/RUN-CONNECT-RELAY.cmd`: set `RELAY_IP` and `SSH_KEY`.
2. Double-click it and click Yes. It:
   - installs WireGuard (winget, or the official signed installer),
   - copies your key with locked-down permissions (Windows ssh rejects keys other accounts can read),
   - waits for the relay to report ready and fetches the config with `sudo cat` (the folder is root-only),
   - adds `ListenPort` (see below) and installs the tunnel as a Windows service,
   - pings through the tunnel.
3. Turn it off with `RUN-DISCONNECT-RELAY.cmd`.

Check from Windows: `Find-NetRoute -RemoteIPAddress 162.249.75.1` should show the `riot-relay` interface,
and `8.8.8.8` should still go via Ethernet.

## 5. Pin the fast path

If PC -> relay is bimodal (e.g. 53 vs 77 ms), run `scripts/tools/Find-FastPort.ps1 -RelayIP ... -SshKey ...`
and pass the best port as `-ListenPort` to `Connect-RiotRelay.ps1`. After pinning, the test tunnel held a
steady **53 ms (40/40)**.

## 6. Verify in-game

Restart VALORANT, sit in the menu for a few minutes or play a match, then run
`scripts/pc/Check-ValorantPing.ps1`. That's the only trustworthy number, because Riot's servers can't be pinged.

## Clean-up

Compute -> Instances -> your instance -> **Terminate** (tick *permanently delete boot volume*).
