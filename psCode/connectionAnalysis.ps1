param(
    [Parameter(Mandatory=$true)]
    [string]$directoryPath,
    
    [Parameter(Mandatory=$true)]
    [string]$outputFile,
    
    [Parameter(Mandatory=$false)]
    [int]$slowConnectionThreshold = 5000
)

Import-Module "$PSScriptRoot\Write-OutputAndFile.psm1" -Force

$timestampPattern = '^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}[+-]\d{2}:\d{2}'

$connections = @{}
$slowConnections = @()
$unclosedConnections = @()
$connectionStats = @{
    TotalOpened = 0
    TotalClosed = 0
    MaxConcurrent = 0
    CurrentOpen = 0
}

Write-OutputAndFile -message "" -filePath $outputFile
Write-OutputAndFile -message "==============================================" -filePath $outputFile
Write-OutputAndFile -message "  Análisis de Conexiones a Base de Datos" -filePath $outputFile
Write-OutputAndFile -message "==============================================" -filePath $outputFile
Write-OutputAndFile -message "" -filePath $outputFile

Get-ChildItem -Path $directoryPath -File | ForEach-Object {
    $logFile = $_.FullName
    $fileName = $_.Name
    
    Write-OutputAndFile -message "Procesando: $fileName" -filePath $outputFile
    
    Get-Content -Path $logFile | ForEach-Object {
        $line = $_
        
        if ($line -match $timestampPattern) {
            $timestampStr = $line -replace '^(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}[+-]\d{2}:\d{2}).*', '$1'
            $timestamp = [DateTime]::ParseExact($timestampStr, "yyyy-MM-ddTHH:mm:ss.fffzzz", $null)
            
            if ($line -match 'GxConnection\.Open.*handle:(\d+)\s+datastore:(\w+)') {
                $handle = $matches[1]
                $datastore = $matches[2]
                $key = "$handle-$datastore"
                
                $connections[$key] = @{
                    Handle = $handle
                    Datastore = $datastore
                    OpenTime = $timestamp
                    OpenLine = $line
                    File = $fileName
                }
                
                $connectionStats.TotalOpened++
                $connectionStats.CurrentOpen++
                
                if ($connectionStats.CurrentOpen -gt $connectionStats.MaxConcurrent) {
                    $connectionStats.MaxConcurrent = $connectionStats.CurrentOpen
                }
            }
            
            if ($line -match 'GxConnection\.Close.*handle:(\d+)\s+datastore:(\w+)') {
                $handle = $matches[1]
                $datastore = $matches[2]
                $key = "$handle-$datastore"
                
                if ($connections.ContainsKey($key)) {
                    $conn = $connections[$key]
                    $duration = ($timestamp - $conn.OpenTime).TotalMilliseconds
                    
                    if ($duration -gt $slowConnectionThreshold) {
                        $slowConnections += @{
                            Handle = $handle
                            Datastore = $datastore
                            Duration = $duration
                            OpenTime = $conn.OpenTime
                            CloseTime = $timestamp
                            OpenLine = $conn.OpenLine
                            CloseLine = $line
                            File = $fileName
                        }
                    }
                    
                    $connections.Remove($key)
                    $connectionStats.TotalClosed++
                    $connectionStats.CurrentOpen--
                }
            }
        }
    }
}

foreach ($key in $connections.Keys) {
    $unclosedConnections += $connections[$key]
}

Write-OutputAndFile -message "" -filePath $outputFile
Write-OutputAndFile -message "=== ESTADÍSTICAS GENERALES ===" -filePath $outputFile
Write-OutputAndFile -message "Total conexiones abiertas: $($connectionStats.TotalOpened)" -filePath $outputFile
Write-OutputAndFile -message "Total conexiones cerradas: $($connectionStats.TotalClosed)" -filePath $outputFile
Write-OutputAndFile -message "Conexiones no cerradas: $($unclosedConnections.Count)" -filePath $outputFile
Write-OutputAndFile -message "Máximo conexiones concurrentes: $($connectionStats.MaxConcurrent)" -filePath $outputFile
Write-OutputAndFile -message "" -filePath $outputFile

if ($slowConnections.Count -gt 0) {
    Write-OutputAndFile -message "=== CONEXIONES LENTAS (> $slowConnectionThreshold ms) ===" -filePath $outputFile
    Write-OutputAndFile -message "" -filePath $outputFile
    
    $slowConnections | Sort-Object -Property Duration -Descending | ForEach-Object {
        $durationSec = [math]::Round($_.Duration / 1000, 2)
        Write-OutputAndFile -message "Duración: $durationSec seg | Handle: $($_.Handle) | Datastore: $($_.Datastore)" -filePath $outputFile
        Write-OutputAndFile -message "  Archivo: $($_.File)" -filePath $outputFile
        Write-OutputAndFile -message "  Abierta:  $($_.OpenTime.ToString('HH:mm:ss.fff'))" -filePath $outputFile
        Write-OutputAndFile -message "  Cerrada:  $($_.CloseTime.ToString('HH:mm:ss.fff'))" -filePath $outputFile
        Write-OutputAndFile -message "" -filePath $outputFile
    }
    
    Write-OutputAndFile -message "SUGERENCIA: Conexiones abiertas > $([math]::Round($slowConnectionThreshold/1000,1))s indican:" -filePath $outputFile
    Write-OutputAndFile -message "  - Transacciones muy largas que bloquean recursos" -filePath $outputFile
    Write-OutputAndFile -message "  - Posible falta de commit/rollback" -filePath $outputFile
    Write-OutputAndFile -message "  - Queries lentas dentro de la transacción" -filePath $outputFile
    Write-OutputAndFile -message "" -filePath $outputFile
} else {
    Write-OutputAndFile -message "=== CONEXIONES LENTAS ===" -filePath $outputFile
    Write-OutputAndFile -message "No se detectaron conexiones lentas (> $slowConnectionThreshold ms)" -filePath $outputFile
    Write-OutputAndFile -message "" -filePath $outputFile
}

if ($unclosedConnections.Count -gt 0) {
    Write-OutputAndFile -message "=== CONEXIONES NO CERRADAS (POSIBLE MEMORY LEAK) ===" -filePath $outputFile
    Write-OutputAndFile -message "" -filePath $outputFile
    
    $unclosedConnections | ForEach-Object {
        Write-OutputAndFile -message "Handle: $($_.Handle) | Datastore: $($_.Datastore)" -filePath $outputFile
        Write-OutputAndFile -message "  Archivo: $($_.File)" -filePath $outputFile
        Write-OutputAndFile -message "  Abierta: $($_.OpenTime.ToString('yyyy-MM-dd HH:mm:ss.fff'))" -filePath $outputFile
        Write-OutputAndFile -message "  Línea: $($_.OpenLine)" -filePath $outputFile
        Write-OutputAndFile -message "" -filePath $outputFile
    }
    
    Write-OutputAndFile -message "SUGERENCIA: Conexiones no cerradas indican:" -filePath $outputFile
    Write-OutputAndFile -message "  - Memory leak - las conexiones quedan abiertas indefinidamente" -filePath $outputFile
    Write-OutputAndFile -message "  - Falta de finally/dispose en el código" -filePath $outputFile
    Write-OutputAndFile -message "  - Pool de conexiones agotado eventualmente" -filePath $outputFile
    Write-OutputAndFile -message "" -filePath $outputFile
} else {
    Write-OutputAndFile -message "=== CONEXIONES NO CERRADAS ===" -filePath $outputFile
    Write-OutputAndFile -message "Todas las conexiones fueron cerradas correctamente" -filePath $outputFile
    Write-OutputAndFile -message "" -filePath $outputFile
}

Write-OutputAndFile -message "Proceso completado. Resultados guardados." -filePath $outputFile
