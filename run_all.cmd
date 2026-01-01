@echo off
setlocal ENABLEDELAYEDEXPANSION
REM Run end-to-end: full encrypt/decrypt, image conversions, compare (pipeline_package-local)

REM Root and subpaths (package-local)
set ROOT=%~dp0
set RTL=%ROOT%rtl
set TB=%ROOT%tb
set SIM=%ROOT%sim
set TOOLS=%ROOT%tools
set DATA=%ROOT%data

if not exist "%SIM%" mkdir "%SIM%"
if not exist "%TB%\sim" mkdir "%TB%\sim"

echo [1/4] Full pipeline ENCRYPT (compile)
echo Checking for PNG source image in %DATA%
if exist "%DATA%\input.png" (
  echo Found input.png - generating input_second assets into data...
  pushd "%DATA%"
  python "%TOOLS%\png_to_input_assets.py" input.png 512 input_second
  popd
) else (
  echo No input.png found, using existing input_second.hex/coe.
)

iverilog -g2012 -o "%SIM%\tb_image_encryption_system.vvp" ^
  "%RTL%\aes_sbox.v" "%RTL%\aes_subbytes.v" "%RTL%\aes_shiftrows.v" "%RTL%\aes_mixcolumns.v" ^
  "%RTL%\aes_round.v" "%RTL%\key_expander.v" "%RTL%\aes_core.v" "%RTL%\aes_ctr_core.v" ^
  "%RTL%\axis_fifo.v" "%RTL%\axis_to_aes_if.v" "%RTL%\aes_to_axis_if.v" ^
  "%RTL%\axi_lite_ctrl.v" "%RTL%\aes_axil_config.v" "%RTL%\aes_ctr_axis_top.v" ^
  "%RTL%\image_reader.v" "%RTL%\encrypted_writer.v" "%RTL%\encryption_controller.v" ^
  "%TB%\tb_image_encryption_system.sv"
if errorlevel 1 goto :fail

echo [2/4] Full pipeline ENCRYPT (run)
pushd "%TB%"
vvp "..\sim\tb_image_encryption_system.vvp"
popd
if errorlevel 1 goto :fail

echo [3/4] Full pipeline DECRYPT (compile)
iverilog -g2012 -DDECRYPT -o "%SIM%\tb_image_encryption_system_decrypt.vvp" ^
  "%RTL%\aes_sbox.v" "%RTL%\aes_subbytes.v" "%RTL%\aes_shiftrows.v" "%RTL%\aes_mixcolumns.v" ^
  "%RTL%\aes_round.v" "%RTL%\key_expander.v" "%RTL%\aes_core.v" "%RTL%\aes_ctr_core.v" ^
  "%RTL%\axis_fifo.v" "%RTL%\axis_to_aes_if.v" "%RTL%\aes_to_axis_if.v" ^
  "%RTL%\axi_lite_ctrl.v" "%RTL%\aes_axil_config.v" "%RTL%\aes_ctr_axis_top.v" ^
  "%RTL%\image_reader.v" "%RTL%\encrypted_writer.v" "%RTL%\encryption_controller.v" ^
  "%TB%\tb_image_encryption_system.sv"
if errorlevel 1 goto :fail

echo [4/4] Full pipeline DECRYPT (run)
pushd "%TB%"
vvp "..\sim\tb_image_encryption_system_decrypt.vvp"
popd
if errorlevel 1 goto :fail

echo [Post] Conversions to images (PGM + PNG) and compare
REM Generate HEX from COE (redundant for ENCRYPT since TB already wrote HEX, but idempotent)
python "%TOOLS%\coe_to_hex.py" "%DATA%\encrypted_output.coe" "%DATA%\encrypted_output.hex"
python "%TOOLS%\hex_to_image.py" "%DATA%\encrypted_output.hex" 512 512 "%DATA%\encrypted_output.pgm"
python "%TOOLS%\coe_to_hex.py" "%DATA%\decrypted_output.coe" "%DATA%\decrypted_output.hex"
python "%TOOLS%\hex_to_image.py" "%DATA%\decrypted_output.hex" 512 512 "%DATA%\decrypted_output.pgm"
python "%TOOLS%\pgm_to_png.py" "%DATA%\input_second.pgm" "%DATA%\original_input_second.png"
python "%TOOLS%\pgm_to_png.py" "%DATA%\encrypted_output.pgm" "%DATA%\encrypted_output.png"
python "%TOOLS%\pgm_to_png.py" "%DATA%\decrypted_output.pgm" "%DATA%\decrypted_output.png"
python "%TOOLS%\compare_hex.py" "%DATA%\decrypted_output.hex" "%DATA%\input_second.hex"

echo All done.
echo Outputs are in: %DATA%
exit /b 0

:fail
echo Failed with errorlevel %errorlevel%
exit /b %errorlevel%
