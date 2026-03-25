param(
    [string]$directoryPath,
    [string]$outputFile
)

Import-Module "$PSScriptRoot\Write-OutputAndFile.psm1" -Force

function Get-ProgramName {
    param([string]$line)
    
    # Extract program name from "dataStoreHelper:" or "gxObject:"
    $idx = $line.IndexOf("dataStoreHelper:")
    if ($idx -ge 0) {
        $after = $line.Substring($idx + 16).Trim()
    } else {
        $idx = $line.IndexOf("gxObject:")
        if ($idx -lt 0) { return $null }
        $after = $line.Substring($idx + 9).Trim()
    }
    # Take the first non-whitespace token
    $token = ($after -split '\s')[0]
    # Remove trailing comma if present
    $token = $token -replace ',\s*$', ''
    # Remove GeneXus.Programs. prefix
    $token = $token -replace '^GeneXus\.Programs\.', ''
    
    # Extract program name before __default
    if ($token -match '([^.]+)__default') {
        return $matches[1]
    }
    
    # Remove __default suffix if present
    $token = $token -replace '__default$', ''
    
    # Take last part after dots
    $parts = $token -split '\.'
    return $parts[-1]
}

function Get-StmtText {
    param([string]$line)
    
    $stmtText = ($line -split "stmt:")[1]
    if ($null -eq $stmtText) { return "" }
    $stmtText = $stmtText.Replace(",c.opened:0=0", "")
    $stmtText = $stmtText.Replace(", ((GxItemStmt)o).opened: 0", "")
    return $stmtText.Trim()
}

Write-OutputAndFile -message "" -filePath $outputFile
Write-OutputAndFile -message "==============================================" -filePath $outputFile
Write-OutputAndFile -message "  Sentencias SQL ejecutadas por Programa" -filePath $outputFile
Write-OutputAndFile -message "==============================================" -filePath $outputFile
Write-OutputAndFile -message "" -filePath $outputFile

$programStmtPairs = @{}

Get-ChildItem -Path $directoryPath -Filter *.log | ForEach-Object {
    $logFile = $_.FullName
    $fileName = $_.Name
    
    Write-OutputAndFile -message "Procesando: $fileName" -filePath $outputFile
    
    $currentProgram = $null
    
    Get-Content $logFile | ForEach-Object {
        $line = $_
        
        if ($line.Contains("dataStoreHelper:") -or $line.Contains("gxObject:")) {
            $currentProgram = Get-ProgramName $line
        }
        
        if ($line.Contains("stmt:") -and $null -ne $currentProgram) {
            $stmtText = Get-StmtText $line
            if ($stmtText.Length -gt 0) {
                if (-not $programStmtPairs.ContainsKey($currentProgram)) {
                    $programStmtPairs[$currentProgram] = @{}
                }
                $programStmtPairs[$currentProgram][$stmtText] = $true
            }
        }
    }
}

Write-OutputAndFile -message "" -filePath $outputFile

$programStmtPairs.GetEnumerator() | Sort-Object Name | ForEach-Object {
    $progName = $_.Key
    $stmts = $_.Value
    
    Write-OutputAndFile -message "$progName" -filePath $outputFile
    $stmts.GetEnumerator() | Sort-Object Name | ForEach-Object {
        Write-OutputAndFile -message "  $($_.Name)" -filePath $outputFile
    }
    Write-OutputAndFile -message "" -filePath $outputFile
}

Write-OutputAndFile -message "Proceso completado. Resultados guardados." -filePath $outputFile
