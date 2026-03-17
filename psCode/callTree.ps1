param(
    [string]$directoryPath,
    [string]$outputFile
)

Import-Module "$PSScriptRoot\Write-OutputAndFile.psm1" -Force

function Get-TimestampFromLine {
    param([string]$line)
    
    if ($line -match '^(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}[+-]\d{2}:\d{2})') {
        try {
            return [DateTime]::ParseExact($matches[1], 'yyyy-MM-ddTHH:mm:ss.fffzzz', $null)
        } catch {
            return $null
        }
    }
    return $null
}

function Get-ProgramName {
    param([string]$fullName)
    
    $fullName = $fullName -replace ',\s*$', ''
    
    $fullName = $fullName -replace '^GeneXus\.Programs\.', ''
    
    if ($fullName -match '([^.]+)__default') {
        return $matches[1]
    }
    
    $parts = $fullName -split '\.'
    return $parts[-1]
}

function Format-Duration {
    param([double]$seconds)
    
    if ($seconds -ge 1) {
        return "{0:N2}s" -f $seconds
    } else {
        return "{0:N0}ms" -f ($seconds * 1000)
    }
}

Write-OutputAndFile -message "" -filePath $outputFile
Write-OutputAndFile -message "==============================================" -filePath $outputFile
Write-OutputAndFile -message "  Arbol de Llamadas entre Programas" -filePath $outputFile
Write-OutputAndFile -message "==============================================" -filePath $outputFile
Write-OutputAndFile -message "" -filePath $outputFile

Get-ChildItem -Path $directoryPath -Filter *.log | ForEach-Object {
    $logFile = $_.FullName
    $fileName = $_.Name
    
    Write-OutputAndFile -message "Procesando: $fileName" -filePath $outputFile
    
    $programs = @()
    $currentProgram = $null
    
    Get-Content $logFile | ForEach-Object {
        $line = $_
        $timestamp = Get-TimestampFromLine $line
        
        if ($null -eq $timestamp) { return }
        
        # Detectar inicio de programa: "Start DataStoreProvider.Ctr, Parameters: handle 'X', dataStoreHelper:GeneXus.Programs..."
        if ($line -match "Start DataStoreProvider\.Ctr.*handle\s+'(\d+)'.*dataStoreHelper:(GeneXus\.Programs\.\S+)") {
            $handle = [int]$matches[1]
            $programFull = $matches[2]
            $programName = Get-ProgramName $programFull
            
            $prog = [PSCustomObject]@{
                Name = $programName
                Handle = $handle
                StartTime = $timestamp
                EndTime = $null
            }
            $programs += $prog
        }
        # Detectar gxObject con handle (patrón original por si existe)
        elseif ($line -match "gxObject:(\S+),?\s+handle\s+'(\d+)'") {
            $programFull = $matches[1]
            $handle = [int]$matches[2]
            $programName = Get-ProgramName $programFull
            
            $prog = [PSCustomObject]@{
                Name = $programName
                Handle = $handle
                StartTime = $timestamp
                EndTime = $null
            }
            $programs += $prog
        }
        # Detectar fin: "End DataStoreProvider" o patrones similares
        elseif ($line -match "(End|Finish|Cleanup|Dispose).*DataStoreProvider.*handle\s+'(\d+)'") {
            $handle = [int]$matches[2]
            
            foreach ($prog in $programs) {
                if ($prog.Handle -eq $handle -and $null -eq $prog.EndTime) {
                    $prog.EndTime = $timestamp
                    break
                }
            }
        }
        # Detectar Disconnect
        elseif ($line -match "Disconnect.*handle\s+'(\d+)'") {
            $handle = [int]$matches[1]
            
            foreach ($prog in $programs) {
                if ($prog.Handle -eq $handle -and $null -eq $prog.EndTime) {
                    $prog.EndTime = $timestamp
                    break
                }
            }
        }
    }
    
    # Calcular EndTime basándose en el siguiente programa del mismo handle
    $groupedByHandle = $programs | Group-Object -Property Handle
    
    foreach ($group in $groupedByHandle) {
        $handleProgs = $group.Group | Sort-Object StartTime
        
        for ($i = 0; $i -lt $handleProgs.Count; $i++) {
            $currentProg = $handleProgs[$i]
            
            # Si no tiene EndTime establecido
            if ($null -eq $currentProg.EndTime) {
                # Si hay un siguiente programa en el mismo handle, usar su StartTime como EndTime del actual
                if ($i -lt $handleProgs.Count - 1) {
                    $currentProg.EndTime = $handleProgs[$i + 1].StartTime
                }
                # Si es el último programa y no tiene EndTime, dejarlo en null (duración = 0)
            }
        }
    }
    
    Write-OutputAndFile -message "" -filePath $outputFile
    Write-OutputAndFile -message "=== ARBOL DE EJECUCION ===" -filePath $outputFile
    Write-OutputAndFile -message "" -filePath $outputFile
    
    $groupedByHandle = $programs | Group-Object -Property Handle | Sort-Object { [int]$_.Name }
    
    foreach ($group in $groupedByHandle) {
        $handle = [int]$group.Name
        $handleProgs = $group.Group | Sort-Object StartTime
        
        $level = $handle - 1
        if ($level -lt 0) { $level = 0 }
        
        $indent = "  " * $level
        $branch = if ($level -eq 0) { "" } else { "+- " }
        
        foreach ($prog in $handleProgs) {
            $duration = 0
            if ($prog.EndTime -and $prog.StartTime) {
                $duration = ($prog.EndTime - $prog.StartTime).TotalSeconds
            }
            
            $durationStr = Format-Duration $duration
            
            Write-OutputAndFile -message "$indent$branch$($prog.Name) ($durationStr)" -filePath $outputFile
        }
    }
    
    Write-OutputAndFile -message "" -filePath $outputFile
}

Write-OutputAndFile -message "Proceso completado. Resultados guardados." -filePath $outputFile
