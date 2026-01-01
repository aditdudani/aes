@echo off
setlocal ENABLEDELAYEDEXPANSION

set ROOT=%~dp0
set RTL=%ROOT%rtl
set TB=%ROOT%tb
set SIM=%ROOT%sim

if not exist "%SIM%" mkdir "%SIM%"

rem Common RTL list
set RTL_LIST=%RTL%\aes_core.v %RTL%\aes_round.v %RTL%\aes_sbox.v %RTL%\aes_shiftrows.v %RTL%\aes_mixcolumns.v %RTL%\aes_subbytes.v %RTL%\key_expander.v %RTL%\aes_ctr_core.v

echo [1/6] aes_core TB
iverilog -g2012 -o "%SIM%\tb_aes_core.vvp" %RTL_LIST% %TB%\tb_aes_core.sv || goto :err
vvp "%SIM%\tb_aes_core.vvp" || goto :err

echo [2/6] aes_round TB
iverilog -g2012 -o "%SIM%\tb_aes_round.vvp" %RTL%\aes_round.v %RTL%\aes_sbox.v %RTL%\aes_mixcolumns.v %RTL%\aes_shiftrows.v %RTL%\aes_subbytes.v %TB%\tb_aes_round.sv || goto :err
vvp "%SIM%\tb_aes_round.vvp" || goto :err

echo [3/6] aes_sbox TB
iverilog -g2012 -o "%SIM%\tb_aes_sbox.vvp" %RTL%\aes_sbox.v %TB%\tb_aes_sbox.sv || goto :err
vvp "%SIM%\tb_aes_sbox.vvp" || goto :err

echo [4/6] aes_shiftrows TB
iverilog -g2012 -o "%SIM%\tb_aes_shiftrows.vvp" %RTL%\aes_shiftrows.v %TB%\tb_aes_shiftrows.sv || goto :err
vvp "%SIM%\tb_aes_shiftrows.vvp" || goto :err

echo [5/6] aes_mixcolumns TB
iverilog -g2012 -o "%SIM%\tb_aes_mixcolumns.vvp" %RTL%\aes_mixcolumns.v %TB%\tb_aes_mixcolumns.sv || goto :err
vvp "%SIM%\tb_aes_mixcolumns.vvp" || goto :err

echo [6/6] key_expander TB
iverilog -g2012 -o "%SIM%\tb_key_expander.vvp" %RTL%\key_expander.v %RTL%\aes_sbox.v %TB%\tb_key_expander.sv || goto :err
vvp "%SIM%\tb_key_expander.vvp" || goto :err

echo Unit testbenches completed successfully.
goto :eof

:err
echo *** ERROR running unit testbenches ***
endlocal
exit /b 1
