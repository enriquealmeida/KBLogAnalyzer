param (
    [int]$threshold = 50,
    [string]$directoryPath = ".\",
    [string]$outputFile = "Delays.txt"
)

Import-Module "$PSScriptRoot\Write-OutputAndFile.psm1"

# Lista de LogTypes válidos
$validLogTypes = @("DEBUG", "TRACE", "INFO", "FATAL", "ERROR", "WARN")

# Regex: toma el timestamp ISO 8601 completo al inicio (con offset)
$tsRegex = '^(?<ts>\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}[+-]\d{2}:\d{2})\s+'

function TryParseTimestamp([string]$line, [ref]$dto) {
    $m = [regex]::Match($line, $tsRegex)
    if (-not $m.Success) { return $false }

    $ts = $m.Groups['ts'].Value
    try {
        # DateTimeOffset respeta el -03:00, +00:00, etc.
        $dto.Value = [DateTimeOffset]::Parse($ts)
        return $true
    }
    catch {
        return $false
    }
}

# Obtener todos los archivos en el directorio especificado
$logFiles = Get-ChildItem -Path "$directoryPath\*.*"

foreach ($logFile in $logFiles) {
    Write-OutputAndFile " ==> Procesando archivo: $($logFile.FullName)" $outputFile

    # Inicializar la línea y hora previas
    $prevLine = $null
    $prevTime = $null

    # Stream line-by-line
    Get-Content -LiteralPath $logFile.FullName -ReadCount 1 | ForEach-Object {
        $line = $_

        $currTimeRef = $null
        $hasCurr = TryParseTimestamp $line ([ref]$currTimeRef)

        if ($prevLine -ne $null -and $prevTime -ne $null -and $hasCurr) {
            $deltaMs = ($currTimeRef - $prevTime).TotalMilliseconds

            if ($deltaMs -gt $threshold) {
                # Imprime la línea previa y la demora
                Write-OutputAndFile ("{0,8:0} ms | {1}" -f $deltaMs, $prevLine) $outputFile
            }
        }

        # Actualiza "prev" solo si la línea actual tiene timestamp parseable
        if ($hasCurr) {
            $prevLine = $line
            $prevTime = $currTimeRef
        }
    }
}






