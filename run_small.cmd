@echo off
setlocal ENABLEDELAYEDEXPANSION
REM Small pipeline testbench runner: inline round-trip, encrypt-only, decrypt-only (package-local).

set ROOT=%~dp0
set RTL=%ROOT%rtl
set TBS=%ROOT%tb
set SIM=%ROOT%sim
set DATA=%ROOT%data

if not exist "%SIM%" mkdir "%SIM%"
if not exist "%TBS%\sim" mkdir "%TBS%\sim"

echo [1/6] Compile small inline round-trip TB
iverilog -g2012 -o "%SIM%\tb_roundtrip_small_inline.vvp" ^
  "%RTL%\aes_sbox.v" "%RTL%\aes_subbytes.v" "%RTL%\aes_shiftrows.v" "%RTL%\aes_mixcolumns.v" ^
  "%RTL%\aes_round.v" "%RTL%\key_expander.v" "%RTL%\aes_core.v" "%RTL%\aes_ctr_core.v" ^
  "%RTL%\axis_fifo.v" "%RTL%\axis_to_aes_if.v" "%RTL%\aes_to_axis_if.v" ^
  "%RTL%\axi_lite_ctrl.v" "%RTL%\aes_axil_config.v" "%RTL%\aes_ctr_axis_top.v" ^
  "%RTL%\image_reader.v" "%RTL%\encrypted_writer.v" ^
  "%TBS%\tb_roundtrip_small_inline.sv"
@echo off
setlocal ENABLEDELAYEDEXPANSION
REM Small pipeline testbench runner: inline round-trip, encrypt-only, decrypt-only.
REM Assumes input_small.hex exists in %ROOT%src (64 x 128-bit words).
REM Outputs small_encrypted.hex / small_decrypted.hex in that same src directory.
REM Uses compare_hex.py in tools for validation (optional).

set ROOT=%~dp0
set RTL=%ROOT%rtl
set TBS=%ROOT%tb
set SIM=%ROOT%sim
set SRC_SMALL=%ROOT%src
set UTIL=%ROOT%tools

if not exist "%SIM%" mkdir "%SIM%"

echo [1/6] Compile small inline round-trip TB
iverilog -g2012 -o "%SIM%\tb_roundtrip_small_inline.vvp" ^
  "%RTL%\aes_sbox.v" "%RTL%\aes_subbytes.v" "%RTL%\aes_shiftrows.v" "%RTL%\aes_mixcolumns.v" ^
  "%RTL%\aes_round.v" "%RTL%\key_expander.v" "%RTL%\aes_core.v" "%RTL%\aes_ctr_core.v" ^
  "%RTL%\axis_fifo.v" "%RTL%\axis_to_aes_if.v" "%RTL%\aes_to_axis_if.v" ^
  "%RTL%\axi_lite_ctrl.v" "%RTL%\aes_axil_config.v" "%RTL%\aes_ctr_axis_top.v" ^
  "%RTL%\image_reader.v" "%RTL%\encrypted_writer.v" ^
  "%TBS%\tb_roundtrip_small_inline.sv"
if errorlevel 1 goto :fail

echo [2/6] Run small inline round-trip TB
pushd "%TBS%"
vvp "..\sim\tb_roundtrip_small_inline.vvp"
popd
if errorlevel 1 goto :fail

echo [3/6] Compile small encrypt-only TB
iverilog -g2012 -o "%SIM%\tb_pipeline_small.vvp" ^
  "%RTL%\aes_sbox.v" "%RTL%\aes_subbytes.v" "%RTL%\aes_shiftrows.v" "%RTL%\aes_mixcolumns.v" ^
  "%RTL%\aes_round.v" "%RTL%\key_expander.v" "%RTL%\aes_core.v" "%RTL%\aes_ctr_core.v" ^
  "%RTL%\axis_fifo.v" "%RTL%\axis_to_aes_if.v" "%RTL%\aes_to_axis_if.v" ^
  "%RTL%\axi_lite_ctrl.v" "%RTL%\aes_axil_config.v" "%RTL%\aes_ctr_axis_top.v" ^
  "%RTL%\image_reader.v" "%RTL%\encrypted_writer.v" ^
  "%TBS%\tb_pipeline_small.sv"
if errorlevel 1 goto :fail

echo [4/6] Run small encrypt-only TB
pushd "%TBS%"
vvp "..\sim\tb_pipeline_small.vvp"
popd
if errorlevel 1 goto :fail

echo [5/6] Compile small decrypt-only TB
iverilog -g2012 -DDECRYPT -o "%SIM%\tb_pipeline_small_decrypt.vvp" ^
  "%RTL%\aes_sbox.v" "%RTL%\aes_subbytes.v" "%RTL%\aes_shiftrows.v" "%RTL%\aes_mixcolumns.v" ^
  "%RTL%\aes_round.v" "%RTL%\key_expander.v" "%RTL%\aes_core.v" "%RTL%\aes_ctr_core.v" ^
  "%RTL%\axis_fifo.v" "%RTL%\axis_to_aes_if.v" "%RTL%\aes_to_axis_if.v" ^
  "%RTL%\axi_lite_ctrl.v" "%RTL%\aes_axil_config.v" "%RTL%\aes_ctr_axis_top.v" ^
  "%RTL%\image_reader.v" "%RTL%\encrypted_writer.v" ^
  "%TBS%\tb_pipeline_small_decrypt.sv"
if errorlevel 1 goto :fail

echo [6/6] Run small decrypt-only TB
pushd "%TBS%"
vvp "..\sim\tb_pipeline_small_decrypt.vvp"
popd
if errorlevel 1 goto :fail

echo Small pipeline sequence complete.
exit /b 0

:fail
echo Failed with errorlevel %errorlevel%
exit /b %errorlevel%
