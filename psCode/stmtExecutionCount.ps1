param(
    [string]$directoryPath,
    [string]$outputFile
)

Import-Module "$PSScriptRoot\Write-OutputAndFile.psm1" -Force

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

Write-OutputAndFile -message "" -filePath $outputFile
Write-OutputAndFile -message "==============================================" -filePath $outputFile
Write-OutputAndFile -message "  Sentencias SQL con parametros (por cantidad)" -filePath $outputFile
Write-OutputAndFile -message "==============================================" -filePath $outputFile
Write-OutputAndFile -message "" -filePath $outputFile

$stmtCounts = @{}

Get-ChildItem -Path $directoryPath -Filter *.log | ForEach-Object {
    $logFile = $_.FullName
    $fileName = $_.Name

    Write-OutputAndFile -message "Procesando: $fileName" -filePath $outputFile

    $lastParams = @{}

    Get-Content $logFile | ForEach-Object {
        $line = $_

        if ($line -match "Execute(?:Reader|NonQuery): Parameters") {
            $lastParams = ParseParameters $line
        }

        if ($line.Contains("stmt:")) {
            $sql = ExtractSQL $line
            if ($null -ne $sql) {
                $sqlWithValues = ReplaceBindVariables $sql $lastParams
                if ($stmtCounts.ContainsKey($sqlWithValues)) {
                    $stmtCounts[$sqlWithValues]++
                } else {
                    $stmtCounts[$sqlWithValues] = 1
                }
            }
        }
    }
}

Write-OutputAndFile -message "" -filePath $outputFile

$stmtCounts.GetEnumerator() | Sort-Object Value -Descending | ForEach-Object {
    $count = $_.Value
    $stmt = $_.Key
    Write-OutputAndFile -message ("{0,6} | {1}" -f $count, $stmt) -filePath $outputFile
}

Write-OutputAndFile -message "" -filePath $outputFile
Write-OutputAndFile -message "Total sentencias distintas: $($stmtCounts.Count)" -filePath $outputFile
Write-OutputAndFile -message "Proceso completado. Resultados guardados." -filePath $outputFile
