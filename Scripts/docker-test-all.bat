@echo off
setlocal

rem -== CONFIG ==-
for %%d in (%~dp0..) do set ParentDirectory=%%~fd
set BASEPATH=%ParentDirectory%
set TEST_IMAGES=swift:4.2 swift:5.0 swift:5.1 swift:5.2 swift:5.3 swift:5.4 swift:5.5

if not [%1] == [] (
   set TEST_IMAGES=%1
)

rem -== START ==-
set TEST_RESULTS=
for	%%x in (%TEST_IMAGES%) do call :TASK %%x
rem call :TASK swift:4.2
call :SUMMARY
goto END

rem -== FUNCTIONS ==-
:TASK
set IMAGE=%1
echo ============================================================
echo  -. -. -. -. -. -. -. -. -. -. -. -. -. -. -.  %IMAGE%

set COMMAND="swift test"
if exist %BASEPATH%\.build (
   rmdir /s /q %BASEPATH%\.build
)
docker run --rm -t -v %BASEPATH%:/workspace -w /workspace %IMAGE% /bin/bash -c %COMMAND%
set RET=%ERRORLEVEL%
set TEST_RESULTS=%TEST_RESULTS% "%IMAGE% = %RET%"
echo - ERRORLEVEL: %RET%
echo ====================================================== END =
goto :eof

:SUMMARY
echo All Result:
for	%%x in (%TEST_RESULTS%) do call :print-x %%x
goto :eof

:print-x
rem https://ss64.com/nt/syntax-dequote.html
set content=%1
set content=###%content%###
set content=%content:"###=%
set content=%content:###"=%
set content=%content:###=%
echo - %content%
goto :eof


:END
