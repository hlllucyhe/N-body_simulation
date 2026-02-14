# N-body Simulation

## Python Scripts for Golden Output Generation
- random_frame0_gen.py: to generate N particles with random parameters(pos, vel, mass) and store in txt file.
- golden_acc_output.py: to calculate 1 next frame from input file; store 3 txt files for:
    - (1)golden_acc_output.txt(may used to be compared with RTL results) 
    - (2)golden_out_full.txt(all paras)
    - (3)one frame txt(same structure as input frame)(may not compared to RTL result)

## Verilog Code for N-body Simulation
- src/pe_core.v: processing element core module
- src/lut.v : look-up table module for inverse square root calculation
- src/fifo.v: Input/Output FIFO (stream interface)
- src/in_buffer.v: Particle data buffer (3N × 16-bit)
- src/out_buffer.v: Accumulation result buffer (2N × 16-bit)

## Testbench
- test/pe_core_tb.v: testbench for pe_core.v


