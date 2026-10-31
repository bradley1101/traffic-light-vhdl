"""Render the lamp signals of traffic_light.vcd as a PNG timing diagram.

Usage:  python plot_wave.py traffic_light.vcd ../docs/waveform.png
"""
import sys
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

SIGNALS = [
    ("main_green", "#2e9e44"), ("main_yellow", "#e0a800"), ("main_red", "#d64545"),
    ("side_green", "#2e9e44"), ("side_yellow", "#e0a800"), ("side_red", "#d64545"),
    ("ped_walk", "#3b7dd8"), ("side_sensor", "#777777"), ("ped_request", "#777777"),
    ("night_mode", "#555555"),
]


def parse_vcd(path, wanted):
    ids, data, t = {}, {name: [] for name in wanted}, 0
    scope_dut = False
    with open(path) as f:
        for line in f:
            tok = line.split()
            if not tok:
                continue
            if tok[0] == "$scope":
                scope_dut = tok[2] == "tb_traffic_light"
            elif tok[0] == "$var" and scope_dut:
                code, name = tok[3], tok[4]
                aliases = {"m_g": "main_green", "m_y": "main_yellow", "m_r": "main_red",
                           "s_g": "side_green", "s_y": "side_yellow", "s_r": "side_red",
                           "walk": "ped_walk", "night": "night_mode"}
                name = aliases.get(name, name)
                if name in wanted:
                    ids[code] = name
            elif line[0] == "#":
                t = int(line[1:])
            elif line[0] in "01" and line[1:].strip() in ids:
                data[ids[line[1:].strip()]].append((t, int(line[0])))
    return data, t


def main(vcd, out):
    names = [n for n, _ in SIGNALS]
    data, t_end = parse_vcd(vcd, names)
    fs_per_s = 100_000_000  # 1 controller second = 100 ns = 1e8 fs (GHDL VCD unit: fs)
    fig, ax = plt.subplots(figsize=(12, 5.2))
    for i, (name, color) in enumerate(SIGNALS):
        y0 = (len(SIGNALS) - 1 - i) * 1.4
        pts = data[name] or [(0, 0)]
        xs, ys = [], []
        for j, (t, v) in enumerate(pts):
            t2 = pts[j + 1][0] if j + 1 < len(pts) else t_end
            xs += [t / fs_per_s, t2 / fs_per_s]
            ys += [y0 + v, y0 + v]
        ax.fill_between(xs, y0, ys, step=None, color=color, alpha=0.35, linewidth=0)
        ax.plot(xs, ys, color=color, linewidth=1.4)
        ax.text(-0.6, y0 + 0.4, name, ha="right", va="center", fontsize=9, family="monospace")
    ax.set_xlim(0, t_end / fs_per_s)
    ax.set_yticks([])
    ax.set_xlabel("time (controller seconds — 1 s = 10 clock cycles in simulation)")
    ax.set_title("traffic_light — GHDL simulation of tb_traffic_light")
    for s in ("top", "right", "left"):
        ax.spines[s].set_visible(False)
    fig.tight_layout()
    fig.savefig(out, dpi=130)
    print("saved", out)


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
