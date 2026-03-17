param (
    [int]$threshold = 50,
    [string]$directoryPath = ".\",
    [string]$outputFile = "Delays.txt",
    [string]$outputSQLFile = "DelaysSQLStatements.sql"
)

Import-Module "$PSScriptRoot\Write-OutputAndFile.psm1"

$validLogTypes = @("DEBUG", "TRACE", "INFO", "FATAL", "ERROR", "WARN")

$tsRegex = '^(?<ts>\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}[+-]\d{2}:\d{2})\s+'

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

function ExtractSQL([string]$line) {
    if ($line -match "stmt:(.+)") {
        $sql = $matches[1]
        $sql = $sql.Replace(",c.opened:0=0", "")
        $sql = $sql.Replace(", ((GxItemStmt)o).opened: 0", "")
        $sql = $sql.Trim()
        if ($sql.Length -gt 0) {
            return $sql
        }
    }
    return $null
}

function ParseParameters([string]$line) {
    $params = @{}
    if ($line -match "Execute(?:Reader|NonQuery): Parameters\s+(.+)$") {
        $paramString = $matches[1]
        $paramMatches = [regex]::Matches($paramString, "(\w+)='([^']*)'")
        foreach ($m in $paramMatches) {
            $params[$m.Groups[1].Value] = $m.Groups[2].Value
        }
    }
    return $params
}

function FormatOracleValue([string]$value) {
    if ($value -match "^\d{1,2}/\d{1,2}/\d{4}\s+\d{1,2}:\d{1,2}:\d{1,2}:\d+$") {
        $parts = $value -split "\s+", 2
        $datePart = $parts[0]
        $timePart = ($parts[1] -replace ":\d+$", "")
        return "TO_DATE('$datePart $timePart', 'DD/MM/YYYY HH24:MI:SS')"
    }
    if ($value -match "^\d{1,2}/\d{1,2}/\d{4}$") {
        return "TO_DATE('$value', 'DD/MM/YYYY')"
    }
    return "'$value'"
}

function ReplaceBindVariables([string]$sql, [hashtable]$params) {
    if ($params.Count -eq 0) { return $sql }
    $result = $sql
    foreach ($key in $params.Keys) {
        $oracleValue = FormatOracleValue $params[$key]
        $result = $result -replace ":$key\b", $oracleValue
    }
    return $result
}

$logFiles = Get-ChildItem -Path "$directoryPath\*.*"
$sqlStatements = @()

foreach ($logFile in $logFiles) {
    Write-OutputAndFile " ==> Procesando archivo: $($logFile.FullName)" $outputFile

    $prevLine = $null
    $prevTime = $null
    $lastParams = @{}

    Get-Content -LiteralPath $logFile.FullName -ReadCount 1 | ForEach-Object {
        $line = $_

        if ($line -match "Execute(?:Reader|NonQuery): Parameters") {
            $lastParams = ParseParameters $line
        }

        $currTimeRef = $null
        $hasCurr = TryParseTimestamp $line ([ref]$currTimeRef)

        if ($prevLine -ne $null -and $prevTime -ne $null -and $hasCurr) {
            $deltaMs = ($currTimeRef - $prevTime).TotalMilliseconds

            if ($deltaMs -gt $threshold) {
                Write-OutputAndFile ("{0,8:0} ms | {1}" -f $deltaMs, $prevLine) $outputFile

                $sql = ExtractSQL $prevLine
                if ($sql -ne $null) {
                    $sqlWithValues = ReplaceBindVariables $sql $lastParams
                    $sqlStatements += [PSCustomObject]@{
                        DelayMs      = $deltaMs
                        SQL          = $sql
                        SQLWithValues = $sqlWithValues
                    }
                }
            }
        }

        if ($hasCurr) {
            $prevLine = $line
            $prevTime = $currTimeRef
        }
    }
}

if ($sqlStatements.Count -gt 0) {
    $lines = @()
    $lines += "-- Archivo generado por KBLogAnalyzer"
    $lines += "-- Sentencias SQL que presentaron demoras mayores a $threshold ms"
    $lines += "-- Fecha de generacion: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    $lines += "-- Cantidad de sentencias: $($sqlStatements.Count)"
    $lines += ""
    $lines += "SET TIMING ON;"
    $lines += "SET AUTOTRACE ON EXPLAIN;"
    $lines += ""

    foreach ($entry in ($sqlStatements | Sort-Object DelayMs -Descending)) {
        $sqlText = $entry.SQLWithValues
        if ($sqlText -match "(?i)^(SELECT|INSERT|UPDATE|DELETE|MERGE)\b") {
            $lines += "-- Demora detectada: $($entry.DelayMs) ms"
            $lines += "EXPLAIN PLAN FOR"
            $lines += "$sqlText"
            $lines += ";"
            $lines += "SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY);"
            $lines += ""
        }
    }

    $lines += "SET TIMING OFF;"
    $lines += "SET AUTOTRACE OFF;"
    $lines | Out-File $outputSQLFile -Encoding UTF8
    Write-Host "Archivo SQL generado: $outputSQLFile ($($sqlStatements.Count) sentencias)"
} else {
    Write-Host "No se encontraron sentencias SQL con demoras mayores a $threshold ms"
}
