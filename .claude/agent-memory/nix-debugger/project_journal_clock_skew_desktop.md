---
name: journal-clock-skew-desktop
description: On nixos-desktop the journal has non-monotonic timestamps (RTC read +2h at boot, then NTP corrects), so journalctl --since/--until and -b -N windows silently return "No entries"
metadata:
  type: project
---

`journalctl --since/--until` is unreliable on **nixos-desktop**: every boot's first
entries are stamped ~2h in the future (firmware/CMOS reads local time as UTC), then
NTP corrects mid-boot. Result: `journalctl --list-boots` shows "last entry" *earlier*
than "first entry", and time-range filters return `-- No entries --` for windows that
clearly contain events.

**Why:** same RTC quirk as the "GRUB shows 1970" symptom - firmware-side, not fixable
in Nix config.

**How to apply:** when correlating events across a long journal on this host, dump once
with `journalctl --no-pager -o short-iso > <scratchpad>/j.log` and work by **line number**
(`grep -n` + `sed -n 'A,Bp'`), not by timestamp. Do not trust `-b -1` boundaries either.
Also note `rtk` compresses/mangles multi-line journal output - use `rtk proxy journalctl ...`
when exact line ordering matters.
