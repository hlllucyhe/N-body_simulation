# run_golden_from_txt.py
from __future__ import annotations
import numpy as np

# =========================
# User-configurable params
# =========================
INPUT_FILE        = "input_frame0.txt"
ACC_OUT_FILE      = "golden_acc.txt"
FULL_OUT_FILE     = "golden_out_full.txt"
NEXT_FRAME_FILE   = "input_frame1.txt"   # new: next frame output (same format as frame0)

DT  = 1e-2   # used for stepping to next frame
EPS = 1e-3   # softening term added to r^2
G0  = 1.0    # optional global scaling (keep if you want)

PRINT_DEBUG = True  # print particle-0 info like your log


# =========================
# Distance-dependent force law g(r2)
# (Put it up front so it's easy to swap formulas)
# =========================
def g_of_r2(r2: float, eps: float, G: float) -> float:
    """
    Default: g(r2) = G * 1/(r2+eps)^(3/2)
    Note: r2 passed in here is typically (dx^2 + dy^2). We add eps inside.
    """
    r2e = r2 + eps
    return G * (1.0 / (r2e ** 1.5))


def load_particles_txt(path: str):
    """
    Read input txt:
      i  pos_x  pos_y  vel_x  vel_y  mass
    Returns:
      pos (N,2), vel (N,2), mass (N,)
    """
    pos_list, vel_list, mass_list = [], [], []
    with open(path, "r") as f:
        for line in f:
            line = line.strip()
            if (not line) or line.startswith("#"):
                continue
            parts = line.split()
            if len(parts) < 6:
                raise ValueError(f"Bad line (need 6 columns): {line}")

            _i = int(parts[0])  # index in file (not required, assumes in-order)
            x = float(parts[1]); y = float(parts[2])
            vx = float(parts[3]); vy = float(parts[4])
            m = float(parts[5])

            pos_list.append([x, y])
            vel_list.append([vx, vy])
            mass_list.append(m)

    pos = np.asarray(pos_list, dtype=np.float64)
    vel = np.asarray(vel_list, dtype=np.float64)
    mass = np.asarray(mass_list, dtype=np.float64)
    return pos, vel, mass


def write_frame_txt(path: str, pos: np.ndarray, vel: np.ndarray, mass: np.ndarray):
    """
    Write frame txt in the SAME format as input_frame0.txt:
      i  pos_x  pos_y  vel_x  vel_y  mass
    """
    with open(path, "w") as f:
        f.write("# i   pos_x        pos_y        vel_x        vel_y        mass\n")
        for i in range(pos.shape[0]):
            f.write(
                f"{i:2d}  "
                f"{pos[i,0]: .8f}  {pos[i,1]: .8f}  "
                f"{vel[i,0]: .8f}  {vel[i,1]: .8f}  "
                f"{mass[i]: .8f}\n"
            )


def compute_acc_2d(pos: np.ndarray, mass: np.ndarray, eps: float, G: float) -> np.ndarray:
    """
    a_i = sum_{j!=i} mass[j] * g(r2_ij) * (r_j - r_i)
    where r2_ij = dx^2 + dy^2
    """
    pos = np.asarray(pos, dtype=np.float64)
    mass = np.asarray(mass, dtype=np.float64)
    N = pos.shape[0]
    acc = np.zeros((N, 2), dtype=np.float64)

    for i in range(N):
        ai = np.zeros(2, dtype=np.float64)
        pi = pos[i]
        for j in range(N):
            if j == i:
                continue
            d = pos[j] - pi                 # (dx, dy)
            r2 = float(d @ d)               # dx^2 + dy^2
            g = g_of_r2(r2, eps=eps, G=G)   # distance-dependent coefficient
            ai += (mass[j] * g) * d
        acc[i] = ai
    return acc


def write_acc_txt(path: str, acc: np.ndarray):
    with open(path, "w") as f:
        f.write("# i   acc_x        acc_y\n")
        for i in range(acc.shape[0]):
            f.write(f"{i:2d}  {acc[i,0]: .10f}  {acc[i,1]: .10f}\n")


def write_full_txt(path: str, pos: np.ndarray, vel: np.ndarray, mass: np.ndarray, acc: np.ndarray):
    with open(path, "w") as f:
        f.write("# i   pos_x        pos_y        vel_x        vel_y        mass        acc_x        acc_y\n")
        for i in range(pos.shape[0]):
            f.write(
                f"{i:2d}  "
                f"{pos[i,0]: .8f}  {pos[i,1]: .8f}  "
                f"{vel[i,0]: .8f}  {vel[i,1]: .8f}  "
                f"{mass[i]: .8f}  "
                f"{acc[i,0]: .10f}  {acc[i,1]: .10f}\n"
            )


def step_frame(pos: np.ndarray, vel: np.ndarray, acc: np.ndarray, dt: float):
    """
    Semi-implicit Euler (stable-ish):
      vel_next = vel + acc*dt
      pos_next = pos + vel_next*dt
    """
    vel_next = vel + acc * dt
    pos_next = pos + vel_next * dt
    return pos_next, vel_next


def main():
    pos, vel, mass = load_particles_txt(INPUT_FILE)
    acc = compute_acc_2d(pos, mass, eps=EPS, G=G0)

    write_acc_txt(ACC_OUT_FILE, acc)
    write_full_txt(FULL_OUT_FILE, pos, vel, mass, acc)

    # new: compute next frame and write it in the SAME format as input_frame0.txt
    pos_next, vel_next = step_frame(pos, vel, acc, dt=DT)
    write_frame_txt(NEXT_FRAME_FILE, pos_next, vel_next, mass)

    if PRINT_DEBUG and pos.shape[0] > 0:
        print(f"Read N={pos.shape[0]} from {INPUT_FILE}")
        print(f"pos[0]={pos[0]}  vel[0]={vel[0]}  acc[0]={acc[0]}")
        print(f"pos_next[0]={pos_next[0]}  vel_next[0]={vel_next[0]}")
        print(f"[OK] Wrote {ACC_OUT_FILE}, {FULL_OUT_FILE}, and {NEXT_FRAME_FILE}")


if __name__ == "__main__":
    main()
