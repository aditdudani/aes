Pipeline package
Contents: `rtl/`, `tb/`, `sim/`, `tools/`, `data/`, `run_all.cmd`, `run_small.cmd`, `run_unit.cmd`, `clean.cmd`

Quick start (PowerShell or CMD):
- Full pipeline (encrypt + decrypt + PNGs):
	.\run_all.cmd
- Small pipeline tests (inline round-trip, then small encrypt/decrypt):
	.\run_small.cmd
- AES unit testbenches (sbox, shiftrows, mixcolumns, round, key schedule, core, ctr core, axis top):
	.\run_unit.cmd

Inputs and outputs:
- Source image: place `data\input.png` (square) to auto-generate `input_second.*` assets.
- Main outputs in `data/`: `encrypted_output.*`, `decrypted_output.*`, and PNGs.
- Small TB outputs in `data/`: `small_encrypted_output.*`, `small_decrypted_output.hex`.

Cleanup:
- Remove build artifacts and generated images/hex/coe:
	.\clean.cmd

Notes:
- Requires Icarus Verilog (`iverilog`, `vvp`) on PATH; Python 3 with Pillow for PNG conversions.
- All testbenches and scripts are package-local; no external paths required.
