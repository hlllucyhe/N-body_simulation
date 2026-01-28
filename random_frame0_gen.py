# gen_input_frame0.py
import numpy as np

# =========================
# User-configurable params
# =========================
N_PARTICLE   = 8                 # number of particles (N-body N)
POS_MIN      = -1.0              # position range
POS_MAX      =  1.0
MASS_MIN     =  0.5              # mass range
MASS_MAX     =  2.0
VEL_INIT_ZERO = True             # initial velocity = 0 ?
RANDOM_SEED  = 0
OUTPUT_FILE  = "input_frame0.txt"

# =========================
# Generator
# =========================
def gen_input_txt():
    """
    Generate initial particle state for N-body golden / RTL test.

    Output format (per line):
    i  pos_x  pos_y  vel_x  vel_y  mass
    """
    np.random.seed(RANDOM_SEED)

    pos = np.random.uniform(POS_MIN, POS_MAX, size=(N_PARTICLE, 2))

    if VEL_INIT_ZERO:
        vel = np.zeros((N_PARTICLE, 2))
    else:
        vel = np.random.uniform(-0.1, 0.1, size=(N_PARTICLE, 2))

    mass = np.random.uniform(MASS_MIN, MASS_MAX, size=(N_PARTICLE,))

    with open(OUTPUT_FILE, "w") as f:
        f.write("# i   pos_x        pos_y        vel_x        vel_y        mass\n")
        for i in range(N_PARTICLE):
            f.write(
                f"{i:2d}  "
                f"{pos[i,0]: .8f}  {pos[i,1]: .8f}  "
                f"{vel[i,0]: .8f}  {vel[i,1]: .8f}  "
                f"{mass[i]: .8f}\n"
            )

    print(f"[OK] Generated {OUTPUT_FILE} with N={N_PARTICLE}")

# =========================
# Main
# =========================
if __name__ == "__main__":
    gen_input_txt()
