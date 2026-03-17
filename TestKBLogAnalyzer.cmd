@echo off
echo ==========================================
echo   Test KBLogAnalyzer v1.0
echo ==========================================

setlocal enabledelayedexpansion

:: Configuración de directorios para testing
set "testLogDir=.\TestLogs"
set "testOutputDir=.\TestOutput"

:: Crear directorios de test si no existen
if not exist "%testLogDir%\" (
    echo Creando directorio de logs de prueba: %testLogDir%
    mkdir "%testLogDir%"
)

if exist "%testOutputDir%\" (
    echo Limpiando directorio de salida: %testOutputDir%
    rmdir /s /q "%testOutputDir%"
)
mkdir "%testOutputDir%"

:: Generar logs de prueba
echo.
echo Generando logs de prueba...
call :GenerateTestLogs

:: Ejecutar todas las funcionalidades
echo.
echo ==========================================
echo   Ejecutando pruebas...
echo ==========================================

echo.
echo [1/5] Probando detectDelays.ps1...
powershell.exe -File "pscode\detectDelays.ps1" -threshold 100 -directoryPath "%testLogDir%" -outputFile "%testOutputDir%\detectDelays.txt"
if exist "%testOutputDir%\detectDelays.txt" (
    echo    [OK] Archivo generado: detectDelays.txt
) else (
    echo    [ERROR] No se genero detectDelays.txt
)

echo.
echo [2/5] Probando filterErrorWarningAndUnknown.ps1...
powershell.exe -File "pscode\filterErrorWarningAndUnknown.ps1" -directoryPath "%testLogDir%" -outputDir "%testOutputDir%"
if exist "%testOutputDir%\ErrorWarning.txt" (
    echo    [OK] Archivo generado: ErrorWarning.txt
) else (
    echo    [ERROR] No se genero ErrorWarning.txt
)

echo.
echo [3/5] Probando totalByProgram.ps1...
set WorkDir=%testOutputDir%\Programas
mkdir "%WorkDir%"
for %%i in (%testLogDir%\*.*) do findstr "gxObject" "%%i" > "%WorkDir%\%%~nxi"
call :CombinarYOrdenar "%WorkDir%\*.*" "%WorkDir%\Salida_ordenada.txt"
powershell -File "psCode\totalByProgram.ps1" -inputFile "%WorkDir%\Salida_ordenada.txt" -prefix "gxObject:GeneXus.Programs." -postfix "__default" -outputFile "%testOutputDir%\totalByPrograms.txt"
if exist "%testOutputDir%\totalByPrograms.txt" (
    echo    [OK] Archivo generado: totalByPrograms.txt
) else (
    echo    [ERROR] No se genero totalByPrograms.txt
)
rmdir /s /q "%WorkDir%"

echo.
echo [4/5] Probando totalByStmt.ps1...
set WorkDir=%testOutputDir%\Stmt
mkdir "%WorkDir%"
for %%i in (%testLogDir%\*.*) do findstr "GeneXus.Data.GxConnectionCache" "%%i" > "%WorkDir%\%%~nxi"
call :CombinarYOrdenar "%WorkDir%\*.*" "%WorkDir%\Salida_ordenada.txt"
powershell -File "psCode\totalByStmt.ps1" -inputFile "%WorkDir%\Salida_ordenada.txt" -searchText "stmt:" -outputFile "%testOutputDir%\totalByStmt.txt"
if exist "%testOutputDir%\totalByStmt.txt" (
    echo    [OK] Archivo generado: totalByStmt.txt
) else (
    echo    [ERROR] No se genero totalByStmt.txt
)
rmdir /s /q "%WorkDir%"

echo.
echo [5/6] Probando delaysByProgram.ps1...
powershell.exe -File "pscode\delaysByProgram.ps1" -directoryPath "%testLogDir%" -outputFileDetail "%testOutputDir%\DelaysByProgramDetail.txt" -outputFileSummary "%testOutputDir%\DelaysByProgramSummary.txt"
if exist "%testOutputDir%\DelaysByProgramDetail.txt" (
    echo    [OK] Archivo generado: DelaysByProgramDetail.txt
) else (
    echo    [ERROR] No se genero DelaysByProgramDetail.txt
)
if exist "%testOutputDir%\DelaysByProgramSummary.txt" (
    echo    [OK] Archivo generado: DelaysByProgramSummary.txt
) else (
    echo    [ERROR] No se genero DelaysByProgramSummary.txt
)

echo.
echo [6/7] Probando logDuration.ps1...
powershell.exe -File "pscode\logDuration.ps1" -directoryPath "%testLogDir%" -outputFile "%testOutputDir%\LogDuration.txt"
if exist "%testOutputDir%\LogDuration.txt" (
    echo    [OK] Archivo generado: LogDuration.txt
) else (
    echo    [ERROR] No se genero LogDuration.txt
)

echo.
echo [7/8] Probando connectionAnalysis.ps1...
powershell.exe -File "pscode\connectionAnalysis.ps1" -directoryPath "%testLogDir%" -outputFile "%testOutputDir%\ConnectionAnalysis.txt" -slowConnectionThreshold 100
if exist "%testOutputDir%\ConnectionAnalysis.txt" (
    echo    [OK] Archivo generado: ConnectionAnalysis.txt
) else (
    echo    [ERROR] No se genero ConnectionAnalysis.txt
)

echo [8/8] Probando callTree.ps1...
powershell.exe -File "pscode\callTree.ps1" -directoryPath "%testLogDir%" -outputFile "%testOutputDir%\CallTree.txt"
if exist "%testOutputDir%\CallTree.txt" (
    echo    [OK] Archivo generado: CallTree.txt
) else (
    echo    [ERROR] No se genero CallTree.txt
)

echo.
echo ==========================================
echo   Pruebas completadas
echo ==========================================
echo.
echo Resultados en: %testOutputDir%
echo Logs de prueba en: %testLogDir%
echo.
start explorer "%testOutputDir%"

exit /b 0

:GenerateTestLogs
powershell -Command "Set-Content -Path '%testLogDir%\test_log_1.log' -Value @('2026-03-17T10:00:00.000-03:00 INFO  GeneXus.Programs.CustomerList Starting process','2026-03-17T10:00:00.050-03:00 DEBUG gxObject:GeneXus.Programs.CustomerList__default Process started','2026-03-17T10:00:00.100-03:00 DEBUG GeneXus.Data.ADO.GxConnection - Start GxConnection.Open, autoCommit=False handle ''1'' datastore:Default','2026-03-17T10:00:00.150-03:00 TRACE GeneXus.Data.GxConnectionCache Opening connection','2026-03-17T10:00:00.250-03:00 DEBUG stmt: SELECT * FROM Customer WHERE Active = 1','2026-03-17T10:00:00.350-03:00 DEBUG gxObject:GeneXus.Programs.HelperProgram__default Called from CustomerList','2026-03-17T10:00:00.400-03:00 DEBUG GeneXus.Data.ADO.GxConnection - Start GxConnection.Open, autoCommit=False handle ''2'' datastore:Default','2026-03-17T10:00:00.450-03:00 DEBUG stmt: SELECT * FROM Config','2026-03-17T10:00:00.550-03:00 DEBUG GeneXus.Data.ADO.GxConnection - GxConnection.Close Id connection State ''Open'' handle ''2'' datastore:Default','2026-03-17T10:00:00.600-03:00 DEBUG GeneXus.Data.GxConnectionCache - Disconnect, handle ''2''','2026-03-17T10:00:00.800-03:00 DEBUG GeneXus.Data.ADO.GxConnection - GxConnection.Close Id connection State ''Open'' handle ''1'' datastore:Default','2026-03-17T10:00:00.850-03:00 DEBUG GeneXus.Data.GxConnectionCache - Disconnect, handle ''1''','2026-03-17T10:00:01.000-03:00 ERROR GeneXus.Programs.OrderProcessor Null reference exception','2026-03-17T10:00:01.050-03:00 DEBUG gxObject:GeneXus.Programs.OrderProcessor__default Starting','2026-03-17T10:00:01.100-03:00 DEBUG GeneXus.Data.ADO.GxConnection - Start GxConnection.Open, autoCommit=False handle ''1'' datastore:Default','2026-03-17T10:00:01.200-03:00 DEBUG stmt: INSERT INTO Orders (CustomerID, Date) VALUES (123, ''2026-03-17'')','2026-03-17T10:00:01.450-03:00 WARN  GeneXus.Programs.OrderProcessor Duplicate key detected','2026-03-17T10:00:01.500-03:00 DEBUG GeneXus.Data.ADO.GxConnection - GxConnection.Close Id connection State ''Open'' handle ''1'' datastore:Default','2026-03-17T10:00:01.550-03:00 DEBUG GeneXus.Data.GxConnectionCache - Disconnect, handle ''1''','2026-03-17T10:00:02.000-03:00 DEBUG gxObject:GeneXus.Programs.ReportGenerator__default Starting report','2026-03-17T10:00:02.050-03:00 DEBUG GeneXus.Data.ADO.GxConnection - Start GxConnection.Open, autoCommit=False handle ''1'' datastore:Default','2026-03-17T10:00:02.100-03:00 DEBUG stmt: SELECT * FROM Customer WHERE Active = 1','2026-03-17T10:00:02.700-03:00 DEBUG GeneXus.Data.ADO.GxConnection - GxConnection.Close Id connection State ''Open'' handle ''1'' datastore:Default','2026-03-17T10:00:02.750-03:00 DEBUG GeneXus.Data.GxConnectionCache - Disconnect, handle ''1''','2026-03-17T10:00:03.000-03:00 INVALID Invalid log entry without proper format','2026-03-17T10:00:03.100-03:00 DEBUG gxObject:GeneXus.Programs.CustomerList__default Second execution','2026-03-17T10:00:03.200-03:00 DEBUG stmt: SELECT * FROM Customer WHERE Active = 1')"

powershell -Command "Set-Content -Path '%testLogDir%\test_log_2.log' -Value @('2026-03-17T10:05:00.000-03:00 INFO  GeneXus.Programs.InvoiceProcessor Starting','2026-03-17T10:05:00.100-03:00 DEBUG gxObject:GeneXus.Programs.InvoiceProcessor__default Starting invoice processing','2026-03-17T10:05:00.200-03:00 DEBUG GeneXus.Data.ADO.GxConnection - Start GxConnection.Open, autoCommit=False handle ''1'' datastore:Default','2026-03-17T10:05:00.300-03:00 DEBUG stmt: SELECT * FROM Invoice WHERE Status = ''Pending''','2026-03-17T10:05:00.900-03:00 DEBUG GeneXus.Data.GxConnectionCache stmt: UPDATE Invoice SET Status = ''Processed'', ((GxItemStmt)o).opened: 0','2026-03-17T10:05:01.100-03:00 DEBUG GeneXus.Data.ADO.GxConnection - GxConnection.Close Id connection State ''Open'' handle ''1'' datastore:Default','2026-03-17T10:05:01.150-03:00 DEBUG GeneXus.Data.GxConnectionCache - Disconnect, handle ''1''','2026-03-17T10:05:01.200-03:00 FATAL GeneXus.Programs.PaymentGateway Connection timeout','2026-03-17T10:05:01.250-03:00 DEBUG gxObject:GeneXus.Programs.OrderProcessor__default Retry attempt','2026-03-17T10:05:01.300-03:00 DEBUG GeneXus.Data.ADO.GxConnection - Start GxConnection.Open, autoCommit=False handle ''1'' datastore:Default','2026-03-17T10:05:01.400-03:00 DEBUG stmt: INSERT INTO Orders (CustomerID, Date) VALUES (123, ''2026-03-17'')','2026-03-17T10:05:01.500-03:00 DEBUG GeneXus.Data.ADO.GxConnection - GxConnection.Close Id connection State ''Open'' handle ''1'' datastore:Default','2026-03-17T10:05:01.550-03:00 DEBUG GeneXus.Data.GxConnectionCache - Disconnect, handle ''1''')"

echo    Logs de prueba generados en %testLogDir%
goto :eof

:CombinarYOrdenar
setlocal enabledelayedexpansion
set "archivoSalida=%~2"

if exist "%archivoSalida%" del "%archivoSalida%"

for %%F in (%~1) do (
    type "%%F" >> "%archivoSalida%"
)

sort "%archivoSalida%" /o "%archivoSalida%_sorted.txt"
move /y "%archivoSalida%_sorted.txt" "%archivoSalida%" >nul
goto :eof
