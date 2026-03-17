param (
    [string]$directoryPath = ".\",
        [string]$outputDir = "Demoras.txt"  
)

Import-Module "$PSScriptRoot\Write-OutputAndFile.psm1"

# Normalizar paths - remover barra final si existe
$directoryPath = $directoryPath.TrimEnd('\')
$outputDir = $outputDir.TrimEnd('\')

$errorFile = "$outputDir\ErrorWarning.txt"
$unknownTypeFile = "$outputDir\unknounLogType.txt"

#Lista de LogTypes Validos
$validLogTypes = @("DEBUG", "TRACE", "INFO", "FATAL", "ERROR", "WARN")

# Obtener todos los archivos .log en el directorio especificado
$logFiles = Get-ChildItem -Path "$directoryPath\*.*"

foreach ($logFile in $logFiles) {
    Write-OutputAndFile ">>Procesando archivo: $($logFile.FullName)" $errorFile
    Write-OutputAndFile ">>Procesando archivo: $($logFile.FullName)" $unknownTypeFile
    
    # Leer el archivo de log línea por línea
    Get-Content $logFile.FullName | ForEach-Object {
        $currentLine = $_
        
        # Dividir la línea en un array basado en espacios en blanco
        $splitLine = $currentLine -split '\s+', 5
        
        # Obtener el tipo de log de la línea actual
        $logType = $splitLine[2]
                
                if ($logType -in $validLogTypes) {
                        if ($logType -in @("FATAL", "ERROR", "WARN")) {
               Write-OutputAndFile "$currentLine" $errorFile
                        }
        } else {
                        #$logType
            Write-OutputAndFile "$currentLine" $unknownTypeFile
        }
    }
}
