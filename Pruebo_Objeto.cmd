set objeto_path=C:\KBs\18\LUCIA_20260115\ProtDotNet\Web\bin
set objeto_prueba=%objeto_path%\declaraciones.cargas.aws_menscourierlogica_core_performance.exe



cd /d %objeto_path%
if exist log.console.config.test  copy log.console.config.test log.console.config
del c:\basura\logs\*.log
%objeto_prueba%
pause

