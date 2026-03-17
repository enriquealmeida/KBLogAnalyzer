param (
    [string]$directoryPath = ".\",
    [string]$outputFileDetail = "DelaysByProgramDetail.txt",
    [string]$outputFileSummary = "DelaysByProgramSummary.txt"
)

Import-Module "$PSScriptRoot\Write-OutputAndFile.psm1"

$tsRegex = '^(?<ts>\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}[+-]\d{2}:\d{2})\s+'
$programPattern = "gxObject:GeneXus\.Programs\.(.*?)__default"

function TryParseTimestamp([string]$line, [ref]$dto) {
    $m = [regex]::Match($line, $tsRegex)
    if (-not $m.Success) { return $false }

    $ts = $m.Groups['ts'].Value
    try {
        $dto.Value = [DateTimeOffset]::Parse($ts)
        return $true
    }
    catch {
        return $false
    }
}

function ExtractProgramName([string]$line) {
    if ($line -match $programPattern) {
        return $matches[1]
    }
    return $null
}

$logFiles = Get-ChildItem -Path "$directoryPath\*.*"
$programTotals = @{}

foreach ($logFile in $logFiles) {
    Write-OutputAndFile " ==> Procesando archivo: $($logFile.FullName)" $outputFileDetail

    $prevLine = $null
    $prevTime = $null
    $prevProgram = $null

    Get-Content -LiteralPath $logFile.FullName -ReadCount 1 | ForEach-Object {
        $line = $_

        if ($line -match "gxObject") {
            $currTimeRef = $null
            $hasCurr = TryParseTimestamp $line ([ref]$currTimeRef)
            $currProgram = ExtractProgramName $line

            if ($prevLine -ne $null -and $prevTime -ne $null -and $hasCurr -and $currProgram -ne $null) {
                $deltaMs = ($currTimeRef - $prevTime).TotalMilliseconds

                Write-OutputAndFile ("{0,8:0} ms | {1} | {2}" -f $deltaMs, $currProgram, $line) $outputFileDetail

                if ($programTotals.ContainsKey($currProgram)) {
                    $programTotals[$currProgram].TotalTime += $deltaMs
                    $programTotals[$currProgram].Count++
                } else {
                    $programTotals[$currProgram] = @{
                        TotalTime = $deltaMs
                        Count = 1
                    }
                }
            }

            if ($hasCurr -and $currProgram -ne $null) {
                $prevLine = $line
                $prevTime = $currTimeRef
                $prevProgram = $currProgram
            }
        }
    }
}

"Programa;Tiempo_Total_ms;Cantidad_Ejecuciones;Tiempo_Promedio_ms" | Out-File "$outputFileSummary"
$programTotals.GetEnumerator() | Sort-Object { $_.Value.TotalTime } -Descending | ForEach-Object {
    $avgTime = [math]::Round($_.Value.TotalTime / $_.Value.Count, 2)
    "$($_.Key);$([math]::Round($_.Value.TotalTime, 2));$($_.Value.Count);$avgTime" | Out-File "$outputFileSummary" -Append
}

Write-Host "Proceso completado. Detalle en: $outputFileDetail, Resumen en: $outputFileSummary"
