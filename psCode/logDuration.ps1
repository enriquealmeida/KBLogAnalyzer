param(
    [Parameter(Mandatory=$true)]
    [string]$directoryPath,
    
    [Parameter(Mandatory=$true)]
    [string]$outputFile
)

Import-Module "$PSScriptRoot\Write-OutputAndFile.psm1" -Force

$pattern = '^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}[+-]\d{2}:\d{2}'

Write-OutputAndFile -message "" -filePath $outputFile
Write-OutputAndFile -message "==============================================" -filePath $outputFile
Write-OutputAndFile -message "  Duración de archivos de log" -filePath $outputFile
Write-OutputAndFile -message "==============================================" -filePath $outputFile
Write-OutputAndFile -message "" -filePath $outputFile

Get-ChildItem -Path $directoryPath -File | ForEach-Object {
    $logFile = $_.FullName
    $fileName = $_.Name
    
    $allLines = Get-Content -Path $logFile
    
    if ($allLines.Count -eq 0) {
        Write-OutputAndFile -message "Archivo: $fileName" -filePath $outputFile
        Write-OutputAndFile -message "  [VACÍO - No contiene líneas]" -filePath $outputFile
        Write-OutputAndFile -message "" -filePath $outputFile
        return
    }
    
    $firstLine = $null
    $lastLine = $null
    $firstTimestamp = $null
    $lastTimestamp = $null
    
    foreach ($line in $allLines) {
        if ($line -match $pattern) {
            if ($null -eq $firstLine) {
                $firstLine = $line
                $timestampStr = $line -replace '^(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}[+-]\d{2}:\d{2}).*', '$1'
                $firstTimestamp = [DateTime]::ParseExact($timestampStr, "yyyy-MM-ddTHH:mm:ss.fffzzz", $null)
            }
            $lastLine = $line
            $timestampStr = $line -replace '^(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}[+-]\d{2}:\d{2}).*', '$1'
            $lastTimestamp = [DateTime]::ParseExact($timestampStr, "yyyy-MM-ddTHH:mm:ss.fffzzz", $null)
        }
    }
    
    Write-OutputAndFile -message "Archivo: $fileName" -filePath $outputFile
    
    if ($null -eq $firstLine -or $null -eq $lastLine) {
        Write-OutputAndFile -message "  [SIN TIMESTAMPS VÁLIDOS]" -filePath $outputFile
    } else {
        Write-OutputAndFile -message "  Primera línea: $firstLine" -filePath $outputFile
        Write-OutputAndFile -message "  Última línea:  $lastLine" -filePath $outputFile
        
        $duration = ($lastTimestamp - $firstTimestamp).TotalSeconds
        Write-OutputAndFile -message "  Duración: $([math]::Round($duration, 3)) segundos" -filePath $outputFile
    }
    
    Write-OutputAndFile -message "" -filePath $outputFile
}

Write-OutputAndFile -message "Proceso completado. Resultados en: $outputFile" -filePath $outputFile
