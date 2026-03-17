# KBLogAnalyzer - Guía Técnica

## Índice

1. [Arquitectura](#arquitectura)
2. [Scripts PowerShell](#scripts-powershell)
3. [Script Principal Batch](#script-principal-batch)
4. [Normalización de Paths](#normalización-de-paths)
5. [Patrones de Expresiones Regulares](#patrones-de-expresiones-regulares)
6. [Módulo Compartido](#módulo-compartido)
7. [Flujo de Ejecución](#flujo-de-ejecución)
8. [Consideraciones de Rendimiento](#consideraciones-de-rendimiento)
9. [Extensibilidad](#extensibilidad)

---

## Arquitectura

### Componentes Principales

```
┌─────────────────────────────────────┐
│   KBLogAnalyzer.cmd (Orchestrator)  │
│   - Interfaz de usuario             │
│   - Validación de inputs            │
│   - Normalización de paths          │
│   - Invocación de scripts PS        │
└──────────────┬──────────────────────┘
               │
               ├─► detectDelays.ps1
               ├─► filterErrorWarningAndUnknown.ps1
               ├─► delaysByProgram.ps1
               ├─► totalByProgram.ps1
               ├─► totalByStmt.ps1
               ├─► logDuration.ps1
               ├─► connectionAnalysis.ps1
               └─► callTree.ps1
                   │
                   └─► Write-OutputAndFile.psm1
```

### Tecnologías Utilizadas

- **Windows Batch**: Script principal y orquestación
- **PowerShell 5.1+**: Procesamiento de logs
- **Expresiones Regulares**: Parsing de patrones en logs
- **Comandos nativos Windows**: findstr, sort, xcopy

---

## Scripts PowerShell

### 1. detectDelays.ps1

**Propósito**: Detectar operaciones que exceden un umbral de tiempo

**Parámetros**:
```powershell
param(
    [int]$threshold,
    [string]$directoryPath,
    [string]$outputFile
)
```

**Lógica Principal**:
```powershell
# 1. Leer todas las líneas del log
Get-Content $logFile | ForEach-Object {
    # 2. Extraer timestamp y parsear a DateTime
    if ($line -match 'timestamp_pattern') {
        $currentTime = [DateTime]::Parse($matches[1])
        
        # 3. Calcular diferencia con línea anterior
        $diff = ($currentTime - $previousTime).TotalMilliseconds
        
        # 4. Si supera threshold, registrar
        if ($diff -gt $threshold) {
            Write-OutputAndFile -message "..." -filePath $outputFile
        }
    }
}
```

**Optimizaciones**:
- Lectura de archivo línea por línea (stream) para eficiencia de memoria
- Parseo de timestamps con formato específico
- Skip de líneas sin timestamp válido

---

### 2. filterErrorWarningAndUnknown.ps1

**Propósito**: Clasificar líneas de log en ERROR, WARNING o UNKNOWN

**Parámetros**:
```powershell
param(
    [string]$directoryPath,
    [string]$outputDir
)
```

**Lógica de Clasificación**:
```powershell
switch -Regex ($line) {
    '\b(ERROR|FATAL|CRITICAL)\b' {
        # Escribir a ErrorWarning.txt
    }
    '\b(WARN|WARNING)\b' {
        # Escribir a ErrorWarning.txt
    }
    '^(\d{4}-\d{2}-\d{2}T.*)' {
        # Línea válida (INFO, DEBUG, etc.) → ignorar
    }
    default {
        # Formato desconocido → escribir a unknownLogType.txt
    }
}
```

**Salidas**:
- `ErrorWarning.txt`: Acumula todos los errores y warnings de todos los archivos
- `unknownLogType.txt`: Líneas con formato inesperado

---

### 3. delaysByProgram.ps1

**Propósito**: Agrupar y totalizar demoras por programa GeneXus

**Parámetros**:
```powershell
param(
    [string]$directoryPath,
    [string]$outputFileDetail,
    [string]$outputFileSummary
)
```

**Estructura de Datos**:
```powershell
$delays = @{
    "ProgramaA" = @(
        [PSCustomObject]@{ Time = 1500; Context = "..." },
        [PSCustomObject]@{ Time = 2000; Context = "..." }
    )
    "ProgramaB" = @(...)
}
```

**Algoritmo**:
1. Procesar cada archivo de log
2. Para cada línea con delay detectado:
   - Extraer nombre de programa (pattern: `GeneXus.Programs.xxx`)
   - Normalizar nombre (remover prefijos/sufijos)
   - Agregar a hashtable agrupado por programa
3. Generar dos salidas:
   - **Detail**: Lista completa ordenada por programa
   - **Summary**: Totales, count y promedio por programa

**Cálculo de Estadísticas**:
```powershell
$totalTime = ($group.Group | Measure-Object -Property Time -Sum).Sum
$count = $group.Count
$average = $totalTime / $count
```

---

### 4. totalByProgram.ps1

**Propósito**: Contar ejecuciones de cada programa

**Proceso**:
```powershell
# 1. Leer archivo consolidado (ya ordenado)
Get-Content $inputFile | ForEach-Object {
    # 2. Extraer nombre de programa entre prefix y postfix
    if ($line -match "$prefix(.+?)$postfix") {
        $program = $matches[1]
        
        # 3. Acumular en hashtable
        if ($programCounts.ContainsKey($program)) {
            $programCounts[$program]++
        } else {
            $programCounts[$program] = 1
        }
    }
}

# 4. Ordenar por count descendente
$programCounts.GetEnumerator() | 
    Sort-Object Value -Descending |
    ForEach-Object { ... }
```

**Nota**: Depende de que el batch haya consolidado y ordenado los archivos previamente usando `:CombinarYOrdenar`

---

### 5. totalByStmt.ps1

**Propósito**: Contar ejecuciones de sentencias SQL

**Similar a totalByProgram.ps1** pero:
- Busca el patrón `stmt:` en lugar de `gxObject:`
- Extrae la sentencia SQL completa
- Agrupa sentencias idénticas

**Consideraciones**:
- Sentencias parametrizadas se cuentan juntas
- Puede generar output muy grande si hay muchas queries únicas
- Ordenado por frecuencia descendente

---

### 6. logDuration.ps1

**Propósito**: Calcular duración de cada archivo de log

**Algoritmo**:
```powershell
foreach ($logFile in Get-ChildItem -Path $directoryPath -Filter *.log) {
    # 1. Leer todas las líneas
    $allLines = Get-Content -Path $logFile
    
    # 2. Buscar primer timestamp válido (desde el inicio)
    $firstTimestamp = $null
    foreach ($line in $allLines) {
        if ($line -match $timestampPattern) {
            $firstTimestamp = [DateTime]::ParseExact($matches[1], $format, $null)
            break
        }
    }
    
    # 3. Buscar último timestamp válido (desde el final)
    $lastTimestamp = $null
    for ($i = $allLines.Count - 1; $i -ge 0; $i--) {
        if ($allLines[$i] -match $timestampPattern) {
            $lastTimestamp = [DateTime]::ParseExact($matches[1], $format, $null)
            break
        }
    }
    
    # 4. Calcular diferencia
    $duration = $lastTimestamp - $firstTimestamp
}
```

**Optimización**: Buscar desde el final para encontrar último timestamp más rápido

---

### 7. connectionAnalysis.ps1

**Propósito**: Analizar conexiones a base de datos

**Rastreo de Conexiones**:
```powershell
$connections = @{}  # Key: handle, Value: objeto con info

# Detectar apertura
if ($line -match "Start GxConnection.Open.*handle:(\d+)") {
    $handle = $matches[1]
    $connections[$handle] = [PSCustomObject]@{
        Handle = $handle
        OpenTime = $timestamp
        OpenDuration = $null
        Closed = $false
    }
}

# Detectar fin de apertura (para calcular tiempo de apertura)
if ($line -match "End GxConnection.Open.*handle:(\d+)") {
    $handle = $matches[1]
    if ($connections.ContainsKey($handle)) {
        $openDuration = ($timestamp - $connections[$handle].OpenTime).TotalMilliseconds
        $connections[$handle].OpenDuration = $openDuration
        
        # Si supera threshold, es "lenta"
        if ($openDuration -gt $slowConnectionThreshold) {
            # Registrar como conexión lenta
        }
    }
}

# Detectar cierre
if ($line -match "Close.*handle:(\d+)") {
    $handle = $matches[1]
    if ($connections.ContainsKey($handle)) {
        $connections[$handle].Closed = $true
    }
}
```

**Salidas**:
1. **Conexiones Lentas**: Aquellas cuya apertura supera el threshold
2. **Conexiones No Cerradas**: Aquellas que no tienen evento de cierre al final del log

---

### 8. callTree.ps1

**Propósito**: Generar árbol jerárquico de llamadas entre programas

**Estructura de Datos**:
```powershell
$programs = @(
    [PSCustomObject]@{
        Name = "ProgramaA"
        Handle = 1
        StartTime = DateTime
        EndTime = DateTime
    },
    ...
)
```

**Detección de Programas**:
```powershell
# Patrón 1: gxObject con handle
if ($line -match "gxObject:(\S+),?\s+handle\s+'(\d+)'") {
    $programFull = $matches[1]
    $handle = [int]$matches[2]
    # Crear entrada en $programs
}

# Patrón 2: DataStoreProvider con handle
if ($line -match "Start DataStoreProvider\.Ctr.*handle\s+'(\d+)'.*dataStoreHelper:(GeneXus\.Programs\.\S+)") {
    $handle = [int]$matches[1]
    $programFull = $matches[2]
    # Crear entrada en $programs
}
```

**Cálculo de EndTime**:
```powershell
# Para cada handle, ordenar programas por StartTime
$groupedByHandle = $programs | Group-Object -Property Handle

foreach ($group in $groupedByHandle) {
    $handleProgs = $group.Group | Sort-Object StartTime
    
    for ($i = 0; $i -lt $handleProgs.Count; $i++) {
        $currentProg = $handleProgs[$i]
        
        # Si no tiene EndTime (no se detectó cierre explícito)
        if ($null -eq $currentProg.EndTime) {
            # Usar StartTime del siguiente como EndTime del actual
            if ($i -lt $handleProgs.Count - 1) {
                $currentProg.EndTime = $handleProgs[$i + 1].StartTime
            }
        }
    }
}
```

**Formato de Salida**:
```powershell
# Agrupar por handle y crear indentación basada en nivel
$level = $handle - 1
$indent = "  " * $level
$branch = if ($level -eq 0) { "" } else { "+- " }

Write-OutputAndFile -message "$indent$branch$($prog.Name) ($durationStr)" -filePath $outputFile
```

**Limitaciones Conocidas**:
- El último programa de cada handle puede no tener EndTime → duración = 0 ms
- Asume que handles secuenciales indican niveles de anidamiento
- No detecta llamadas entre handles diferentes (cross-handle calls)

---

## Script Principal Batch

### KBLogAnalyzer.cmd

**Responsabilidades**:
1. Interfaz de usuario (prompts interactivos)
2. Validación de inputs
3. Normalización de paths
4. Invocación de scripts PowerShell
5. Gestión de directorios temporales
6. Copia de logs al directorio de salida
7. Apertura del directorio de resultados

**Estructura**:
```batch
@echo off
setlocal enabledelayedexpansion

:: 1. Solicitar directorio de logs (con validación)
:askDirectoryLogInput
set /p "directoryLogInput=..."
if not exist "!directoryLogInput!\" goto :askDirectoryLogInput

:: 2. Normalización de paths
:normalizeInput
if "!directoryLogInput:~-1!"=="\" (
    set "directoryLogInput=!directoryLogInput:~0,-1!"
    goto :normalizeInput
)

:: 3. Generar timestamp para directorio de salida
for /f "delims=" %%i in ('powershell -Command "Get-Date -Format 'yyyyMMdd_HHmmss'"') do set timestamp=%%i

:: 4. Solicitar configuraciones (Y/N para cada análisis)
:askDetectDelays
...

:: 5. Ejecutar análisis seleccionados
:execute
if /i "!detectDelays!"=="Y" (
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File "pscode\detectDelays.ps1" ...
)
...

:: 6. Copiar logs y abrir directorio
xcopy "!directoryLogInput!\*.log" "!directoryLogOutput!" /Y /Q
explorer "!directoryLogOutput!"
```

---

## Normalización de Paths

### Problema

Windows Batch tiene problemas con:
- **Trailing backslashes**: `C:\logs\` → `C:\logs\"`
- **Double backslashes**: `C:\logs\\data` → paths malformados
- **Expansión dentro de comillas**: `"!var!\"` → el `\` escapa la `"`

### Solución Implementada

#### 1. Remover Trailing Backslashes

```batch
:normalizeInput
if "!directoryLogInput:~-1!"=="\" (
    set "directoryLogInput=!directoryLogInput:~0,-1!"
    goto :normalizeInput
)
```

**Cómo funciona**:
- `!var:~-1!`: Obtiene último carácter
- `!var:~0,-1!`: Obtiene todos los caracteres excepto el último
- Loop hasta que no haya `\` al final

#### 2. Remover Double Backslashes

```batch
:normalizeOutputLoop
set "tempDir=!directoryLogOutput!"
set "directoryLogOutput=!directoryLogOutput:\\=\!"
if not "!tempDir!"=="!directoryLogOutput!" goto :normalizeOutputLoop
```

**Cómo funciona**:
- `!var:\\=\!`: Reemplaza `\\` con `\`
- Compara valor anterior con nuevo
- Repite hasta que no haya cambios (maneja `\\\` → `\\` → `\`)

#### 3. Construcción de Paths para PowerShell

```batch
:: INCORRECTO (trailing backslash puede escapar comilla)
powershell.exe ... -outputFile "!directoryLogOutput!\archivo.txt"

:: CORRECTO (path ya normalizado sin trailing backslash)
set "directoryLogOutput=C:\logs"  :: Sin \ al final
powershell.exe ... -outputFile "!directoryLogOutput!\archivo.txt"
:: Se expande a: "C:\logs\archivo.txt" (correcto)
```

#### 4. Uso de Variables Temporales vs Construcción Directa

**Enfoque A: Variable temporal (puede fallar)**
```batch
if /i "!logDuration!"=="Y" (
    set "outFile=!directoryLogOutput!\LogDuration.txt"
    powershell.exe ... -outputFile "!outFile!"
)
```
❌ Problema: `!outFile!` puede no expandirse correctamente dentro del bloque `if`

**Enfoque B: Construcción directa (recomendado)**
```batch
if /i "!logDuration!"=="Y" (
    powershell.exe ... -outputFile "!directoryLogOutput!\LogDuration.txt"
)
```
✅ Solución: Construir path directamente en el comando

---

## Patrones de Expresiones Regulares

### Timestamp

```regex
^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}[+-]\d{2}:\d{2}
```

**Ejemplo**: `2026-03-17T09:06:27.007-03:00`

**Formato PowerShell**:
```powershell
'yyyy-MM-ddTHH:mm:ss.fffzzz'
```

### Programa GeneXus

```regex
gxObject:(GeneXus\.Programs\.\S+)
```

**Ejemplos**:
- `gxObject:GeneXus.Programs.funciones.seguridad.getmysessionsid__default`
- `gxObject:GeneXus.Programs.declaraciones.cargas.ws_menscourierlogica_core`

**Normalización**:
```powershell
$fullName = $fullName -replace '^GeneXus\.Programs\.', ''
$fullName = $fullName -replace '__default$', ''
```

### Handle

```regex
handle\s*[:']\s*(\d+)
```

**Variantes**:
- `handle '1'`
- `handle:1`
- `handle: 1`

### Sentencia SQL

```regex
stmt:\s*(.+)
```

**Ejemplo**: `stmt: SELECT * FROM Tabla WHERE id = ?`

---

## Módulo Compartido

### Write-OutputAndFile.psm1

**Propósito**: Escribir simultáneamente a consola y archivo

**Implementación**:
```powershell
function Write-OutputAndFile {
    param(
        [string]$message,
        [string]$filePath
    )
    
    # Escribir a consola
    Write-Host $message
    
    # Escribir a archivo (append)
    Add-Content -Path $filePath -Value $message -Encoding UTF8
}

Export-ModuleMember -Function Write-OutputAndFile
```

**Uso en Scripts**:
```powershell
Import-Module "$PSScriptRoot\Write-OutputAndFile.psm1" -Force

Write-OutputAndFile -message "Procesando archivo..." -filePath $outputFile
```

**Ventajas**:
- Feedback visual al usuario mientras se procesa
- Output persistente en archivo
- Código DRY (no repetir `Write-Host` + `Add-Content`)

---

## Flujo de Ejecución

### Diagrama de Secuencia

```
Usuario  →  KBLogAnalyzer.cmd  →  PowerShell Scripts  →  Archivos Output
   │              │                      │                      │
   ├─ Ingresa paths                     │                      │
   │              ├─ Valida y normaliza │                      │
   │              │                      │                      │
   ├─ Selecciona análisis               │                      │
   │              │                      │                      │
   │              ├─ Invoca detectDelays.ps1                   │
   │              │                      ├─ Procesa logs       │
   │              │                      ├────────────────────>│ detectDelays.txt
   │              │                      │                      │
   │              ├─ Invoca filterErrorWarningAndUnknown.ps1   │
   │              │                      ├─ Procesa logs       │
   │              │                      ├────────────────────>│ ErrorWarning.txt
   │              │                      ├────────────────────>│ unknownLogType.txt
   │              │                      │                      │
   │              ├─ Invoca delaysByProgram.ps1                │
   │              │                      ├─ Procesa logs       │
   │              │                      ├────────────────────>│ DelaysByProgramDetail.txt
   │              │                      ├────────────────────>│ DelaysByProgramSummary.txt
   │              │                      │                      │
   │              ├─ Copia logs originales                     │
   │              ├───────────────────────────────────────────>│ *.log
   │              │                      │                      │
   │              ├─ Abre directorio     │                      │
   │<─────────────┤                      │                      │
```

### Orden de Ejecución

1. **Validación y Normalización** (batch)
2. **detectDelays.ps1** (si seleccionado)
3. **filterErrorWarningAndUnknown.ps1** (si seleccionado)
4. **totalByProgram** (si seleccionado):
   - Crear directorio temporal
   - findstr para extraer líneas
   - :CombinarYOrdenar (batch)
   - totalByProgram.ps1
   - Limpiar directorio temporal
5. **totalByStmt** (si seleccionado): similar a totalByProgram
6. **delaysByProgram.ps1** (si seleccionado)
7. **logDuration.ps1** (si seleccionado)
8. **connectionAnalysis.ps1** (si seleccionado)
9. **callTree.ps1** (si seleccionado)
10. **Copia de logs originales** (batch)
11. **Apertura de directorio** (batch)

---

## Consideraciones de Rendimiento

### Limitaciones de Batch

- **No streaming verdadero**: `findstr` y `sort` cargan todo en memoria
- **Procesamiento secuencial**: No hay paralelización nativa
- **Overhead de procesos**: Cada invocación de PowerShell tiene startup cost

### Optimizaciones Implementadas

#### En Scripts PowerShell

1. **Streaming de archivos**:
```powershell
Get-Content $logFile | ForEach-Object {
    # Procesa línea por línea sin cargar todo el archivo
}
```

2. **Early exit en búsquedas**:
```powershell
foreach ($line in $allLines) {
    if ($line -match $pattern) {
        $firstTimestamp = ...
        break  # No seguir buscando
    }
}
```

3. **Hashtables para lookups**:
```powershell
$programCounts = @{}  # O(1) lookup vs arrays O(n)
```

#### En Batch

1. **Consolidación antes de procesar**:
```batch
:: Consolidar múltiples archivos en uno solo antes de PowerShell
for %%i in (!directoryLogInput!\*.*) do findstr "patrón" "%%i" > "!WorkDir!\%%~nxi"
call :CombinarYOrdenar "!WorkDir!\*.*" !WorkDir!\Salida_ordenada.txt
```

2. **Limpieza de temporales**:
```batch
rmdir !WorkDir! /s /q > nul
```

### Recomendaciones para Logs Grandes

- **Logs > 1 GB**: Considerar dividir en batches más pequeños
- **Muchos archivos**: Procesar por grupos (ej: por día)
- **Análisis selectivos**: Ejecutar solo los análisis necesarios
- **Hardware**: SSD mejora significativamente el rendimiento de I/O

---

## Extensibilidad

### Agregar un Nuevo Análisis

#### Paso 1: Crear Script PowerShell

```powershell
# pscode\miNuevoAnalisis.ps1
param(
    [string]$directoryPath,
    [string]$outputFile
)

Import-Module "$PSScriptRoot\Write-OutputAndFile.psm1" -Force

Write-OutputAndFile -message "Iniciando Mi Nuevo Análisis..." -filePath $outputFile

Get-ChildItem -Path $directoryPath -Filter *.log | ForEach-Object {
    $logFile = $_.FullName
    
    Get-Content $logFile | ForEach-Object {
        # Lógica de análisis
        if ($_ -match "mi_patron") {
            Write-OutputAndFile -message $_ -filePath $outputFile
        }
    }
}

Write-OutputAndFile -message "Análisis completado." -filePath $outputFile
```

#### Paso 2: Agregar Prompt en Batch

```batch
:askMiNuevoAnalisis
set miNuevoAnalisis=N
set /p "miNuevoAnalisis=Ejecutar mi nuevo análisis? (Y/N): "

for %%i in ("!miNuevoAnalisis!") do set miNuevoAnalisis=%%~i

if /i "%miNuevoAnalisis%"=="Y" (
    goto :continue9
) else if /i "%miNuevoAnalisis%"=="N" (
    goto :continue9
) else (
    echo Entrada no válida. Por favor, ingrese Y o N.
    goto :askMiNuevoAnalisis
)
:continue9
```

#### Paso 3: Agregar Ejecución en :execute

```batch
if /i "!miNuevoAnalisis!"=="Y" (
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File "pscode\miNuevoAnalisis.ps1" -directoryPath "!directoryLogInput!" -outputFile "!directoryLogOutput!\MiNuevoAnalisis.txt"
)
```

### Modificar Patrones de Búsqueda

Para adaptar a diferentes formatos de log:

```powershell
# En el script correspondiente, modificar el patrón regex
# Antes:
if ($line -match '^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}') { ... }

# Después (para formato diferente):
if ($line -match '^\[\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\]') { ... }
```

### Agregar Nuevas Salidas

```powershell
# Ejemplo: exportar a CSV además de TXT
$results | Export-Csv -Path "$outputFile.csv" -NoTypeInformation -Encoding UTF8
```

### Integración con Sistemas Externos

```powershell
# Ejemplo: enviar resultados por email
Send-MailMessage -To "admin@company.com" `
                 -From "logs@company.com" `
                 -Subject "Análisis de Logs Completado" `
                 -Body "Ver archivos adjuntos" `
                 -Attachments $outputFile `
                 -SmtpServer "smtp.company.com"
```

---

## Debugging y Troubleshooting

### Habilitar Verbose en PowerShell

```powershell
# Al inicio del script
$VerbosePreference = "Continue"

# Luego usar
Write-Verbose "Variable X = $X"
```

### Debug en Batch

```batch
:: Temporalmente agregar echos
echo DEBUG: directoryLogInput=!directoryLogInput!
echo DEBUG: directoryLogOutput=!directoryLogOutput!
```

### Logs de PowerShell

```powershell
Start-Transcript -Path "C:\Logs\debug_transcript.txt"
# ... código del script ...
Stop-Transcript
```

---

## Mejoras Futuras Sugeridas

1. **Paralelización**: Procesar múltiples logs simultáneamente
2. **Interfaz GUI**: WinForms o WPF para configuración visual
3. **Exportación a formatos estructurados**: JSON, XML, CSV
4. **Gráficos**: Generar gráficos de tendencias (requiere libraries adicionales)
5. **Base de datos**: Almacenar resultados en SQLite para queries complejas
6. **Alertas**: Notificaciones automáticas cuando se detectan problemas críticos
7. **Modo incremental**: Procesar solo nuevos logs desde última ejecución
8. **Compresión automática**: Comprimir logs procesados para ahorrar espacio

---

**Última actualización**: Marzo 2026
