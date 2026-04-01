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
               ├─► stmtByProgram.ps1
               ├─► stmtExecutionCount.ps1
               ├─► tableAccessCount.ps1
               └─► generateCsvDuration.ps1
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

**Propósito**: Detectar operaciones que exceden un umbral de tiempo y generar script SQL para Oracle

**Parámetros**:
```powershell
param(
    [int]$threshold,
    [string]$directoryPath,
    [string]$outputFile,
    [string]$outputSQLFile
)
```

**Lógica Principal**:
```powershell
# 1. Rastrear última línea de parámetros (ExecuteReader/ExecuteNonQuery)
if ($line -match "Execute(?:Reader|NonQuery): Parameters") {
    $lastParams = ParseParameters $line
}

# 2. Detectar demoras entre líneas consecutivas
$deltaMs = ($currTimeRef - $prevTime).TotalMilliseconds
if ($deltaMs -gt $threshold) {
    # 3. Si la línea contiene stmt:, extraer SQL
    $sql = ExtractSQL $prevLine
    # 4. Reemplazar bind variables (:param) con valores reales
    $sqlWithValues = ReplaceBindVariables $sql $lastParams
}
```

**Funciones de resolución de parámetros**:
- `ParseParameters`: Extrae pares `nombre='valor'` de líneas `ExecuteReader: Parameters` y `ExecuteNonQuery: Parameters`
- `FormatOracleValue`: Detecta fechas y las convierte a `TO_DATE()`, demás valores quedan como strings
- `ReplaceBindVariables`: Sustituye `:paramName` por valores reales en el SQL

**Salidas**:
- `detectDelays.txt`: Listado de operaciones lentas
- `DelaysSQLStatements.sql`: Script Oracle con `EXPLAIN PLAN FOR`, `SET TIMING ON/OFF` y valores resueltos

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
```

---

### 10. generateCsvDuration.ps1

**Propósito**: Generar un archivo CSV con el número de línea y los milisegundos transcurridos desde el inicio del log.

**Parámetros**:
```powershell
param(
    [string]$directoryPath,
    [string]$outputFile
)
```

**Lógica Principal**:
- Procesa cada archivo en el directorio especificado.
- Extrae cada línea con un timestamp, calcula el tiempo transcurrido desde la primera marca de tiempo en milisegundos.
- Genera un CSV con los resultados formateados adecuadamente, codificado en UTF-8 para prevenir problemas de caracteres.

---
