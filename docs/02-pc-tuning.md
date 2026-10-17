# 02 - PC tuning

`scripts/pc/Optimize-Network.ps1` (run via `RUN-TUNE-UP.cmd`, needs admin) changes only settings that trade
latency for power saving or throughput. It saves the original values to `network-backup.json` first and
writes a log to `tune-up-log.txt`. `Revert-Network.ps1` restores everything.

| Change | Why |
|---|---|
| Interrupt Moderation -> Disabled | NIC raises an interrupt per packet instead of batching them |
| Power Saving Mode, EEE, Green Ethernet, Gigabit Lite, Flow Control -> Disabled | stop the link napping between packets (only the options your driver exposes are touched) |
| `PnPCapabilities = 24` on the adapter's registry key | unticks "Allow the computer to turn off this device"; `Disable-NetAdapterPowerManagement` fails with error 31 on the Realtek inbox driver, so the registry is set directly (needs reboot) |
| Ultimate Performance power plan, PCIe Link State Power Management off | keep CPU/PCIe out of low-power states between packets |
| `NetworkThrottlingIndex = 0xFFFFFFFF`, `SystemResponsiveness = 10` | stop Windows' multimedia scheduler throttling network processing |

## Deliberately skipped

- **TCP tweaks** (`TcpAckFrequency`, `TCPNoDelay`, autotuning, congestion provider): VALORANT gameplay is UDP.
- **DNS changes:** DNS affects lookups, not in-match ping.
- **QoS/DSCP tagging:** home ISPs strip or ignore it.

## Result

All settings applied and survived a reboot (verified). Line ping stayed at 1-3 ms and VALORANT Riyadh stayed
at 61. Expected: tuning removes ~1-3 ms of jitter at most, not route distance.

## Gotchas found while testing

- Double-clicking the launcher and declining or missing the UAC prompt changes nothing. The launcher now says
  so, and the script writes a log so you can tell whether it ran.
- An old Realtek inbox driver (2022) exposes only a few advanced properties. Updating from realtek.com
  exposes EEE / Green Ethernet; re-run the script afterwards.
