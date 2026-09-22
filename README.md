# System Load — an Omarchy bar widget

One dial in the bar for how hard the machine is working. Hover it for the
summary, click it for the numbers, right-click it for btop.

## Install

```bash
omarchy plugin add https://github.com/jonspinks/omarchy-sysload --enable
```

`--enable` places it in the bar; `omarchy plugin enable blacksheep.sysload --before omarchy.network`
puts it somewhere specific, and you can always drag it along the bar afterwards.

## What the dial actually means

The headline figure is **strain**: how hard the machine is working to keep up,
on a 0–100% scale. It is deliberately *not* an average of CPU, memory and I/O.

A machine with an idle CPU that is swapping itself to death feels broken, and
averaging would report it as half-busy. What you feel is whichever resource ran
out first, so strain is the **maximum** of four sub-scores — and the widget
names the one that won.

| Sub-score | What it is | 100% means |
|---|---|---|
| CPU | busy fraction from `/proc/stat`, iowait counted as idle | no idle time left |
| Memory | `MemAvailable` shortfall, or memory PSI, whichever is worse | allocations are stalling |
| Disk I/O | I/O pressure (PSI `full`, 10s window) | everything is waiting on the disk |
| Heat | package temperature against the throttle point, floored at 50°C | the governor is clawing back clocks |

The memory and I/O scores lean on [PSI](https://docs.kernel.org/accounting/psi.html),
which is the kernel's own answer to "is anything actually waiting". `full`
avg10 is the share of the last ten seconds in which *every* task was stalled on
that resource, so single digits already mean real, felt stalling and 20% is a
machine in trouble — that's the point the score reads as maxed.

Colour ramps from your theme's `foreground` through `accent` to `urgent`, so it
stays calm-looking until it isn't, in whatever theme you're running.

## Interactions

| Gesture | What happens |
|---|---|
| hover | strain, its driver, CPU/memory/temperature, network rates, busiest process |
| left click | panel: four meters, rates, load, uptime, top processes by CPU and by memory |
| right click | launches (or focuses) btop |
| `r` in the panel | resample now |
| `b` in the panel | btop |

## Settings

Set these inline on the widget's entry in `~/.config/omarchy/shell.json`:

```json
{ "id": "blacksheep.sysload", "style": "bar", "interval": 2, "idleInterval": 4 }
```

| Key | Default | Meaning |
|---|---|---|
| `style` | `arc` | `arc` for a 270° dial, `bar` for a flat fill |
| `interval` | `2` | seconds between samples while the panel is open |
| `idleInterval` | `4` | seconds between samples while only the dial is visible |

Both gauge styles work in a vertical bar; the flat fill turns and grows upward.

## Cost

`bin/sysload-sample` is one fork per tick and reads only `/proc` and `/sys` —
about 19ms of CPU, so roughly 0.5% of one core at the default 4s idle interval.
The per-process walk (~500 small reads, another 25ms) runs *only* while the
panel is open, because nobody needs a process table behind a closed popup.

Everything it reads is a counter or an instantaneous value; the widget keeps the
previous sample and does the delta arithmetic itself, so a dropped sample costs
one tick rather than a wrong number.

The one piece of state is per-process CPU, cached under `$XDG_RUNTIME_DIR`.
`ps %cpu` reports an average over each process's whole lifetime, which is the
wrong question when you're asking what is hammering the machine *right now*, so
the process pass diffs its own tick counters instead.

## What it doesn't show

**GPU.** Intel's i915/xe drivers expose no busy percentage in sysfs — it needs
perf counters and usually privileges. Rather than show a field that reads zero
on half the machines it runs on, there isn't one. AMD cards do expose
`gpu_busy_percent`, so this is a gap worth closing later, not a decision.

**Fan speed.** Read where `hwmon` offers it and skipped where it doesn't; plenty
of desktop boards register an `acpi_fan` that never reports RPM.

## Requirements

A Linux kernel with PSI enabled (`CONFIG_PSI=y`, the default on Arch). Without
it the memory and I/O sub-scores fall back to 0 and the dial runs on CPU,
memory headroom and temperature alone.

## License

MIT
