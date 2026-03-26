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

function Get-OperationType([string]$sql) {
    $upper = $sql.TrimStart().ToUpper()
    if ($upper.StartsWith("INSERT"))  { return "INSERT" }
    if ($upper.StartsWith("UPDATE"))  { return "UPDATE" }
    if ($upper.StartsWith("DELETE"))  { return "DELETE" }
    if ($upper.StartsWith("SELECT"))  { return "SELECT" }
    return $null
}

function Get-TableNames([string]$sql, [string]$operation) {
    $tables = @()
    $upper = $sql.ToUpper()

    switch ($operation) {
        "INSERT" {
            # INSERT INTO tablename(... or INSERT INTO tablename (...
            if ($upper -match "INSERT\s+INTO\s+(\w+)") {
                $tables += $matches[1]
            }
        }
        "UPDATE" {
            # UPDATE tablename SET ...
            if ($upper -match "UPDATE\s+(\w+)") {
                $tables += $matches[1]
            }
        }
        "DELETE" {
            # DELETE FROM tablename ... or DELETE tablename ...
            if ($upper -match "DELETE\s+FROM\s+(\w+)") {
                $tables += $matches[1]
            } elseif ($upper -match "DELETE\s+(\w+)") {
                $tables += $matches[1]
            }
        }
        "SELECT" {
            # Extract the FROM clause content
            # Match FROM ... until WHERE, ORDER, GROUP, HAVING, UNION, or end of string
            if ($upper -match "FROM\s+(.+?)(?:\s+WHERE\s|\s+ORDER\s|\s+GROUP\s|\s+HAVING\s|\s+UNION\s|$)") {
                $fromClause = $matches[1].Trim()

                # Split by JOIN keywords to get table references
                $joinParts = $fromClause -split "\s+(?:INNER\s+JOIN|LEFT\s+(?:OUTER\s+)?JOIN|RIGHT\s+(?:OUTER\s+)?JOIN|FULL\s+(?:OUTER\s+)?JOIN|CROSS\s+JOIN|JOIN)\s+"

                foreach ($part in $joinParts) {
                    # Each part may have comma-separated tables
                    $commaParts = $part -split ","
                    foreach ($commaPart in $commaParts) {
                        $cleaned = $commaPart.Trim()
                        # Extract first word (table name), ignore alias and ON clause
                        $cleaned = $cleaned -replace "\s+ON\s+.*$", ""
                        if ($cleaned -match "^(\w+)") {
                            $tableName = $matches[1]
                            # Skip known non-table keywords
                            if ($tableName -notin @("SELECT", "DUAL", "TABLE", "SET", "AS", "ON", "AND", "OR", "NOT", "NULL", "IN", "EXISTS", "BETWEEN", "LIKE", "CASE")) {
                                $tables += $tableName
                            }
                        }
                    }
                }

                # If no tables found from FROM, check for DUAL
                if ($tables.Count -eq 0 -and $upper -match "FROM\s+DUAL") {
                    $tables += "DUAL"
                }
            }
        }
    }

    return $tables
}

Write-OutputAndFile -message "" -filePath $outputFile
Write-OutputAndFile -message "==============================================" -filePath $outputFile
Write-OutputAndFile -message "  Accesos a tablas por tipo de operacion SQL" -filePath $outputFile
Write-OutputAndFile -message "==============================================" -filePath $outputFile
Write-OutputAndFile -message "" -filePath $outputFile

# Hash: tableName -> @{ INSERT=0; UPDATE=0; DELETE=0; SELECT=0 }
$tableCounts = @{}

Get-ChildItem -Path $directoryPath -Filter *.log | ForEach-Object {
    $logFile = $_.FullName
    $fileName = $_.Name

    Write-OutputAndFile -message "Procesando: $fileName" -filePath $outputFile

    Get-Content $logFile | ForEach-Object {
        $line = $_

        if ($line.Contains("stmt:")) {
            $sql = ExtractSQL $line
            if ($null -ne $sql) {
                $operation = Get-OperationType $sql
                if ($null -ne $operation) {
                    $tableNames = Get-TableNames $sql $operation
                    foreach ($tableName in $tableNames) {
                        $tableUpper = $tableName.ToUpper()
                        if (-not $tableCounts.ContainsKey($tableUpper)) {
                            $tableCounts[$tableUpper] = @{ INSERT = 0; UPDATE = 0; DELETE = 0; SELECT = 0 }
                        }
                        $tableCounts[$tableUpper][$operation]++
                    }
                }
            }
        }
    }
}

Write-OutputAndFile -message "" -filePath $outputFile

# Header
$header = "{0,-30} | {1,8} | {2,8} | {3,8} | {4,8} | {5,8}" -f "TABLA", "#INSERT", "#UPDATE", "#DELETE", "#SELECT", "#TOTAL"
$separator = "{0,-30}-+-{1,8}-+-{2,8}-+-{3,8}-+-{4,8}-+-{5,8}" -f ("-" * 30), ("-" * 8), ("-" * 8), ("-" * 8), ("-" * 8), ("-" * 8)

Write-OutputAndFile -message $header -filePath $outputFile
Write-OutputAndFile -message $separator -filePath $outputFile

$tableCounts.GetEnumerator() | Sort-Object Name | ForEach-Object {
    $tableName = $_.Key
    $counts = $_.Value
    $total = $counts["INSERT"] + $counts["UPDATE"] + $counts["DELETE"] + $counts["SELECT"]
    $line = "{0,-30} | {1,8} | {2,8} | {3,8} | {4,8} | {5,8}" -f $tableName, $counts["INSERT"], $counts["UPDATE"], $counts["DELETE"], $counts["SELECT"], $total
    Write-OutputAndFile -message $line -filePath $outputFile
}

Write-OutputAndFile -message $separator -filePath $outputFile

# Totals row
$totalInsert = 0; $totalUpdate = 0; $totalDelete = 0; $totalSelect = 0
foreach ($counts in $tableCounts.Values) {
    $totalInsert += $counts["INSERT"]
    $totalUpdate += $counts["UPDATE"]
    $totalDelete += $counts["DELETE"]
    $totalSelect += $counts["SELECT"]
}
$grandTotal = $totalInsert + $totalUpdate + $totalDelete + $totalSelect
$totalLine = "{0,-30} | {1,8} | {2,8} | {3,8} | {4,8} | {5,8}" -f "TOTAL", $totalInsert, $totalUpdate, $totalDelete, $totalSelect, $grandTotal
Write-OutputAndFile -message $totalLine -filePath $outputFile

Write-OutputAndFile -message "" -filePath $outputFile
Write-OutputAndFile -message "Total tablas: $($tableCounts.Count)" -filePath $outputFile
Write-OutputAndFile -message "Proceso completado. Resultados guardados." -filePath $outputFile
