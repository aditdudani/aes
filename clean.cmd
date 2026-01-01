@echo off
setlocal
set ROOT=%~dp0
set SIM=%ROOT%sim
set TB=%ROOT%tb
set DATA=%ROOT%data

REM Clean compiled simulation outputs
if exist "%SIM%" del /Q "%SIM%\*.vvp" 2>nul
if exist "%SIM%" del /Q "%SIM%\*.vcd" 2>nul

REM Clean waveform in tb
if exist "%TB%\tb_image_encryption_system.vcd" del /Q "%TB%\tb_image_encryption_system.vcd" 2>nul
if exist "%TB%\sim\*.vcd" del /Q "%TB%\sim\*.vcd" 2>nul

REM Clean generated data artifacts (preserve inputs like input.png/jpg and input_second.*)
if exist "%DATA%\encrypted_output.hex" del /Q "%DATA%\encrypted_output.hex" 2>nul
if exist "%DATA%\encrypted_output.coe" del /Q "%DATA%\encrypted_output.coe" 2>nul
if exist "%DATA%\encrypted_output.pgm" del /Q "%DATA%\encrypted_output.pgm" 2>nul
if exist "%DATA%\encrypted_output.png" del /Q "%DATA%\encrypted_output.png" 2>nul

if exist "%DATA%\decrypted_output.hex" del /Q "%DATA%\decrypted_output.hex" 2>nul
if exist "%DATA%\decrypted_output.coe" del /Q "%DATA%\decrypted_output.coe" 2>nul
if exist "%DATA%\decrypted_output.pgm" del /Q "%DATA%\decrypted_output.pgm" 2>nul
if exist "%DATA%\decrypted_output.png" del /Q "%DATA%\decrypted_output.png" 2>nul

if exist "%DATA%\original_input_second.png" del /Q "%DATA%\original_input_second.png" 2>nul

REM Clean small TB artifacts
if exist "%DATA%\small_encrypted_output.hex" del /Q "%DATA%\small_encrypted_output.hex" 2>nul
if exist "%DATA%\small_encrypted_output.coe" del /Q "%DATA%\small_encrypted_output.coe" 2>nul
if exist "%DATA%\small_decrypted_output.hex" del /Q "%DATA%\small_decrypted_output.hex" 2>nul

echo Cleaned sim/data artifacts. Preserved inputs and tools.
