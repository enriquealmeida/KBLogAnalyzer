@echo off
echo ==========================================
echo   KBLogAnalyzer v1.3 (2026.03)
echo ==========================================

setlocal enabledelayedexpansion

:: Preguntar al usuario los valores, si se dejan en blanco, se usarán los valores predeterminados

:askDirectoryLogInput
set /p "directoryLogInput=Directorio de los logs: "

:: Normalizar directoryLogInput - asegurar que NO termine con barra
:normalizeInput
if "!directoryLogInput:~-1!"=="\" (
    set "directoryLogInput=!directoryLogInput:~0,-1!"
    goto :normalizeInput
)

:: Verificar si el directorio de entrada existe
if not exist "!directoryLogInput!\" (
    echo El directorio de entrada no existe. Por favor, ingrese un directorio válido.
    goto :askDirectoryLogInput
)

:: Generar timestamp para nombre de directorio usando PowerShell
for /f "delims=" %%i in ('powershell -Command "Get-Date -Format 'yyyyMMdd_HHmmss'"') do set timestamp=%%i

:askDirectoryLogOutput
set "defaultDirectoryLogOutput=!directoryLogInput!\KBLogAnalyzer_!timestamp!\"
set /p "directoryLogOutput=Directorio de resultados: (default !defaultDirectoryLogOutput!) "

:: Usar el directorio predeterminado si la entrada está vacía
if "!directoryLogOutput!"=="" (
    set "directoryLogOutput=!defaultDirectoryLogOutput!"
)

:: Normalizar directoryLogOutput - remover dobles barras repetidamente
:normalizeOutputLoop
set "tempDir=!directoryLogOutput!"
set "directoryLogOutput=!directoryLogOutput:\\=\!"
if not "!tempDir!"=="!directoryLogOutput!" goto :normalizeOutputLoop

:: Remover barra final para evitar problemas de escape en comillas
if "!directoryLogOutput:~-1!"=="\" (
    set "directoryLogOutput=!directoryLogOutput:~0,-1!"
)

:: Verificar si el directorio de salida existe, de lo contrario crearlo
if not exist "!directoryLogOutput!\" (
    echo Creando directorio de salida...
    mkdir "!directoryLogOutput!"
) else (
    echo ADVERTENCIA: El directorio ya existe. El contenido existente podría mezclarse con los resultados.
)

:: Validar la entrada
:askDetectDelays
set detectDelays=N
set /p "detectDelays=Desea detectar demoras? (Y/N): "

if /i "%detectDelays%"=="Y" (
    goto :askThreshold
) else if /i "%detectDelays%"=="N" (
    goto :continue1
) else (
    echo Entrada no válida. Por favor, ingrese Y o N.
    goto :askDetectDelays
)
pause

:askThreshold
set threshold=500
set /p "threshold=Mostrar logs que demoran mas que (default %threshold% ms): "

:: Intentar evaluar la variable
set /a "test=threshold" 2>nul

:: Verificar si threshold es cero
if %test%==0 (
    echo Ingrese un valor entero mayor que 0
    goto :askThreshold
)

:continue1


:askFilterErrorWarningAndUnknown
set filterErrorWarningAndUnknown=N
set /p "filterErrorWarningAndUnknown=Separa Errores, Warnings y no conocidos? (Y/N): "

:: Convertir a mayúsculas
for %%i in ("!filterErrorWarningAndUnknown!") do set filterErrorWarningAndUnknown=%%~i

:: Validar la entrada
if /i "%filterErrorWarningAndUnknown%"=="Y" (
    goto :continue2
) else if /i "%filterErrorWarningAndUnknown%"=="N" (
    goto :continue2
) else (
    echo Entrada no válida. Por favor, ingrese Y o N.
    goto :askFilterErrorWarningAndUnknown
)
:continue2

:askTotalByProgram
set totalByProgram=N
set /p "totalByProgram=Agrupa y totaliza por programa? (Y/N): "

:: Convertir a mayúsculas
for %%i in ("!totalByProgram!") do set totalByProgram=%%~i

:: Validar la entrada
if /i "%totalByProgram%"=="Y" (
    goto :continue3
) else if /i "%totalByProgram%"=="N" (
    goto :continue3
) else (
    echo Entrada no válida. Por favor, ingrese Y o N.
    goto :askTotalByProgram
)
:continue3

:askTotalByStmt
set totalByStmt=N
set /p "totalByStmt=Agrupa y totaliza por SENTENCIA SQL? (Y/N): "

:: Convertir a mayúsculas
for %%i in ("!totalByStmt!") do set totalByStmt=%%~i

:: Validar la entrada
if /i "%totalByStmt%"=="Y" (
    goto :continue4
) else if /i "%totalByStmt%"=="N" (
    goto :continue4
) else (
    echo Entrada no válida. Por favor, ingrese Y o N.
    goto :asktotalByStmt
)
:continue4

:askDelaysByProgram
set delaysByProgram=N
set /p "delaysByProgram=Mide demoras por programa? (Y/N): "

:: Convertir a mayúsculas
for %%i in ("!delaysByProgram!") do set delaysByProgram=%%~i

:: Validar la entrada
if /i "%delaysByProgram%"=="Y" (
    goto :continue5
) else if /i "%delaysByProgram%"=="N" (
    goto :continue5
) else (
    echo Entrada no válida. Por favor, ingrese Y o N.
    goto :askDelaysByProgram
)
:continue5

:askLogDuration
set logDuration=N
set /p "logDuration=Calcula duración de archivos de log? (Y/N): "

:: Convertir a mayúsculas
for %%i in ("!logDuration!") do set logDuration=%%~i

:: Validar la entrada
if /i "%logDuration%"=="Y" (
    goto :continue6
) else if /i "%logDuration%"=="N" (
    goto :continue6
) else (
    echo Entrada no válida. Por favor, ingrese Y o N.
    goto :askLogDuration
)
:continue6

:askConnectionAnalysis
set connectionAnalysis=N
set /p "connectionAnalysis=Analiza conexiones a BD (lentas/no cerradas)? (Y/N): "

:: Convertir a mayúsculas
for %%i in ("!connectionAnalysis!") do set connectionAnalysis=%%~i

:: Validar la entrada
if /i "%connectionAnalysis%"=="Y" (
    goto :askConnectionThreshold
) else if /i "%connectionAnalysis%"=="N" (
    goto :continue7
) else (
    echo Entrada no válida. Por favor, ingrese Y o N.
    goto :askConnectionAnalysis
)

:askConnectionThreshold
set connectionThreshold=5000
set /p "connectionThreshold=Umbral para conexiones lentas (default %connectionThreshold% ms): "

:: Intentar evaluar la variable
set /a "test=connectionThreshold" 2>nul

:: Verificar si connectionThreshold es cero
if %test%==0 (
    echo Ingrese un valor entero mayor que 0
    goto :askConnectionThreshold
)
:continue7

:askCallTree
set callTree=N
set /p "callTree=Genera arbol de llamadas entre programas? (Y/N): "

:: Convertir a mayúsculas
for %%i in ("!callTree!") do set callTree=%%~i

:: Validar la entrada
if /i "%callTree%"=="Y" (
    goto :continue8
) else if /i "%callTree%"=="N" (
    goto :continue8
) else (
    echo Entrada no válida. Por favor, ingrese Y o N.
    goto :askCallTree
)
:continue8

:execute


if /i "!detectDelays!"=="Y" (
        set "outFile=!directoryLogOutput!\detectDelays.txt"
        powershell.exe -NoProfile -ExecutionPolicy Bypass -File "pscode\detectDelays.ps1" -threshold %threshold% -directoryPath "!directoryLogInput!" -outputFile "!outFile!"
)

if /i "%filterErrorWarningAndUnknown%"=="Y" (
        powershell.exe -NoProfile -ExecutionPolicy Bypass -File "pscode\filterErrorWarningAndUnknown.ps1" -directoryPath "!directoryLogInput!" -outputDir "!directoryLogOutput!"
)

if /i "%totalByProgram%"=="Y" (
        set WorkDir=!directoryLogOutput!\Programas
        rmdir !WorkDir! /s /q > nul
        md  !WorkDir!
        echo ">>Proceso Programas en !WorkDir!"
        for %%i in (!directoryLogInput!\*.*) do findstr "gxObject" "%%i" > "!WorkDir!\%%~nxi"
        call :CombinarYOrdenar "!WorkDir!\*.*"  !WorkDir!\Salida_ordenada.txt
        set "outFile=!directoryLogOutput!\totalByPrograms.txt"
        powershell -File "pscode\totalByProgram.ps1" -inputFile "!WorkDir!\Salida_ordenada.txt" -prefix "gxObject:GeneXus.Programs." -postfix "__default"  -outputFile "!outFile!"
    rmdir !WorkDir! /s /q > nul 
)

if /i "%totalByStmt%"=="Y" (
        set WorkDir=!directoryLogOutput!\Stmt
        rmdir !WorkDir! /s /q > nul
        md  !WorkDir!
        echo ">>Proceso Stmt en !WorkDir!"
        for %%i in (!directoryLogInput!\*.*) do findstr "GeneXus.Data.GxConnectionCache" "%%i" > "!WorkDir!\%%~nxi"
        call :CombinarYOrdenar "!WorkDir!\*.*"  !WorkDir!\Salida_ordenada.txt
        set "outFile=!directoryLogOutput!\totalByStmt.txt"
    powershell -File "pscode\totalByStmt.ps1" -inputFile "!WorkDir!\Salida_ordenada.txt" -searchText "stmt:" -outputFile "!outFile!"
        rmdir !WorkDir! /s /q > nul
)

if /i "%delaysByProgram%"=="Y" (
        set "outDetail=!directoryLogOutput!\DelaysByProgramDetail.txt"
        set "outSummary=!directoryLogOutput!\DelaysByProgramSummary.txt"
        powershell.exe -NoProfile -ExecutionPolicy Bypass -File "pscode\delaysByProgram.ps1" -directoryPath "!directoryLogInput!" -outputFileDetail "!outDetail!" -outputFileSummary "!outSummary!"
)

if /i "!logDuration!"=="Y" (
        powershell.exe -NoProfile -ExecutionPolicy Bypass -File "pscode\logDuration.ps1" -directoryPath "!directoryLogInput!" -outputFile "!directoryLogOutput!\LogDuration.txt"
)

if /i "!connectionAnalysis!"=="Y" (
        powershell.exe -NoProfile -ExecutionPolicy Bypass -File "pscode\connectionAnalysis.ps1" -directoryPath "!directoryLogInput!" -outputFile "!directoryLogOutput!\ConnectionAnalysis.txt" -slowConnectionThreshold !connectionThreshold!
)

if /i "!callTree!"=="Y" (
        powershell.exe -NoProfile -ExecutionPolicy Bypass -File "pscode\callTree.ps1" -directoryPath "!directoryLogInput!" -outputFile "!directoryLogOutput!\CallTree.txt"
)

echo.
echo Copiando logs procesados al directorio de salida...
xcopy "!directoryLogInput!\*.log" "!directoryLogOutput!" /Y /Q 2>nul
if errorlevel 1 (
    echo ADVERTENCIA: No se encontraron archivos .log para copiar o hubo un error en la copia.
) else (
    echo Logs copiados a: !directoryLogOutput!
)
echo.
echo Proceso completado.
echo.
echo Abriendo directorio de salida...
explorer "!directoryLogOutput!"

exit

:CombinarYOrdenar
@echo off
:: recibe los parametros
:: % 1 DIRECTORIO con archivo
:: % 2 ARCHIVO DE SALIDA
:: Lo que hace es concatenar todos los archivos en un solo y ordenarlo y ponerlo en archivo de SALIDA

setlocal enabledelayedexpansion

set "archivoSalida=%~2"

if exist "%archivoSalida%" del "%archivoSalida%"

for %%F in (%~1) do (
    type "%%F" >> "%archivoSalida%"
)

sort "%archivoSalida%" /o "%archivoSalida%_sorted.txt"
move /y "%archivoSalida%_sorted.txt" "%archivoSalida%" >nul
