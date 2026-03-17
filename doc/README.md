# KBLogAnalyzer - Documentación

## Descripción General

**KBLogAnalyzer** es una herramienta de análisis de logs para aplicaciones GeneXus. Permite procesar archivos de log (.log) y extraer información relevante sobre el rendimiento, errores, ejecución de programas y operaciones de base de datos.

## Versión

**v1.3** (Marzo 2026)

---

## Requisitos del Sistema

- **Sistema Operativo**: Windows 10 o superior
- **PowerShell**: Versión 5.1 o superior
- **Permisos**: Permisos de lectura en los directorios de logs y escritura en el directorio de salida

---

## Estructura del Proyecto

```
KBLogAnalyzer/
│
├── KBLogAnalyzer.cmd          # Script principal (Batch)
├── TestKBLogAnalyzer.cmd      # Script de pruebas
├── Readme.txt                 # Archivo de ayuda básica
├── FaltaHacer.txt            # Lista de tareas pendientes
│
├── pscode/                    # Scripts PowerShell
│   ├── detectDelays.ps1
│   ├── filterErrorWarningAndUnknown.ps1
│   ├── delaysByProgram.ps1
│   ├── totalByProgram.ps1
│   ├── totalByStmt.ps1
│   ├── logDuration.ps1
│   ├── connectionAnalysis.ps1
│   ├── callTree.ps1
│   └── Write-OutputAndFile.psm1
│
├── TestLogs/                  # Logs de prueba (opcional)
├── TestOutput/                # Salida de pruebas (opcional)
└── doc/                       # Documentación
    ├── README.md
    ├── USER_GUIDE.md
    └── TECHNICAL_GUIDE.md
```

---

## Instalación

1. **Descargar o clonar** el proyecto en un directorio local
2. **Verificar** que PowerShell está habilitado en tu sistema
3. **Configurar permisos de ejecución** (si es necesario):
   ```powershell
   Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
   ```

---

## Uso Rápido

### Ejecución Básica

1. Ejecutar `KBLogAnalyzer.cmd`
2. Ingresar la ruta del directorio con los logs
3. Ingresar (opcional) el directorio de salida o usar el predeterminado
4. Seleccionar los análisis deseados (Y/N para cada opción)
5. Esperar a que el proceso complete
6. Se abrirá automáticamente el directorio con los resultados

### Ejemplo de Uso

```cmd
C:\KBLogAnalyzer> KBLogAnalyzer.cmd

==========================================
  KBLogAnalyzer v1.3 (2026.03)
==========================================

Directorio de los logs: C:\MiApp\logs
Directorio de resultados: (default C:\MiApp\logs\KBLogAnalyzer_20260317_103045)

Desea detectar demoras? (Y/N): Y
Mostrar logs que demoran mas que (default 500 ms): 1000

Separa Errores, Warnings y no conocidos? (Y/N): Y
Agrupa y totaliza por programa? (Y/N): Y
...
```

---

## Funcionalidades

### 1. Detectar Demoras (Detect Delays)

**Script**: `detectDelays.ps1`

**Descripción**: Identifica operaciones que superan un umbral de tiempo especificado.

**Parámetros**:
- `threshold`: Tiempo mínimo en milisegundos (default: 500 ms)
- `directoryPath`: Directorio de entrada con logs
- `outputFile`: Archivo de salida con resultados

**Salida**: `detectDelays.txt`

**Formato**:
```
Archivo: mi_log.log
  Línea 1234: [2500 ms] Operación lenta detectada...
  Línea 5678: [3500 ms] Otra operación lenta...
```

---

### 2. Filtrar Errores, Warnings y Desconocidos

**Script**: `filterErrorWarningAndUnknown.ps1`

**Descripción**: Separa las líneas de log en tres categorías:
- Errores (ERROR)
- Advertencias (WARNING, WARN)
- Tipos desconocidos (líneas que no siguen el formato esperado)

**Parámetros**:
- `directoryPath`: Directorio de entrada con logs
- `outputDir`: Directorio de salida

**Salidas**:
- `ErrorWarning.txt`: Errores y warnings encontrados
- `unknownLogType.txt`: Líneas con formato no reconocido

---

### 3. Demoras por Programa

**Script**: `delaysByProgram.ps1`

**Descripción**: Analiza y agrupa demoras por programa GeneXus.

**Parámetros**:
- `directoryPath`: Directorio de entrada con logs
- `outputFileDetail`: Archivo con detalles de todas las demoras
- `outputFileSummary`: Archivo con resumen totalizado

**Salidas**:
- `DelaysByProgramDetail.txt`: Detalle de cada demora por programa
- `DelaysByProgramSummary.txt`: Resumen con totales y promedios

**Formato del Resumen**:
```
Programa                    Total (ms)    Count    Promedio (ms)
------------------------------------------------------------------
MiPrograma                  15000         10       1500
OtroProgramas               8000          5        1600
```

---

### 4. Totalizar por Programa

**Script**: `totalByProgram.ps1`

**Descripción**: Cuenta y totaliza la cantidad de veces que se ejecuta cada programa.

**Parámetros**:
- `inputFile`: Archivo de entrada (consolidado)
- `prefix`: Prefijo a buscar (ej: "gxObject:GeneXus.Programs.")
- `postfix`: Sufijo a buscar (ej: "__default")
- `outputFile`: Archivo de salida

**Salida**: `totalByPrograms.txt`

**Formato**:
```
Programa                    Ejecuciones
----------------------------------------
MiPrograma                  1234
OtroProgramas               567
```

---

### 5. Totalizar por Sentencia SQL

**Script**: `totalByStmt.ps1`

**Descripción**: Cuenta y totaliza la cantidad de veces que se ejecuta cada sentencia SQL.

**Parámetros**:
- `inputFile`: Archivo de entrada (consolidado)
- `searchText`: Texto a buscar (ej: "stmt:")
- `outputFile`: Archivo de salida

**Salida**: `totalByStmt.txt`

**Formato**:
```
Sentencia SQL                           Ejecuciones
----------------------------------------------------
SELECT * FROM Tabla1...                 456
INSERT INTO Tabla2...                   123
```

---

### 6. Duración de Archivos de Log

**Script**: `logDuration.ps1`

**Descripción**: Calcula la duración (diferencia entre primer y último timestamp) de cada archivo de log.

**Parámetros**:
- `directoryPath`: Directorio de entrada con logs
- `outputFile`: Archivo de salida

**Salida**: `LogDuration.txt`

**Formato**:
```
Archivo: mi_log_1.log
  Inicio:    2026-03-17 09:06:27
  Fin:       2026-03-17 12:45:30
  Duración:  3h 39m 3s

Archivo: mi_log_2.log
  Inicio:    2026-03-17 13:00:00
  Fin:       2026-03-17 14:30:00
  Duración:  1h 30m 0s
```

---

### 7. Análisis de Conexiones

**Script**: `connectionAnalysis.ps1`

**Descripción**: Analiza conexiones a base de datos, detectando conexiones lentas y conexiones no cerradas correctamente.

**Parámetros**:
- `directoryPath`: Directorio de entrada con logs
- `outputFile`: Archivo de salida
- `slowConnectionThreshold`: Umbral en ms para conexiones lentas (default: 5000)

**Salida**: `ConnectionAnalysis.txt`

**Formato**:
```
=== CONEXIONES LENTAS ===
Handle: 5
  Tiempo de apertura: 6500 ms
  Timestamp: 2026-03-17T09:06:27.007-03:00

=== CONEXIONES NO CERRADAS ===
Handle: 12
  Abierta en: 2026-03-17T09:06:27.007-03:00
  Estado: No cerrada explícitamente
```

---

### 8. Árbol de Llamadas (Call Tree)

**Script**: `callTree.ps1`

**Descripción**: Genera un árbol jerárquico de llamadas entre programas, mostrando la relación de ejecución y duración aproximada.

**Parámetros**:
- `directoryPath`: Directorio de entrada con logs
- `outputFile`: Archivo de salida

**Salida**: `CallTree.txt`

**Formato**:
```
=== ARBOL DE EJECUCION ===

ProgramaPrincipal (1.5s)
  +- SubPrograma1 (450 ms)
  +- SubPrograma2 (800 ms)
    +- SubSubPrograma (200 ms)
```

**Nota**: Los tiempos se calculan aproximadamente usando la diferencia entre el inicio de un programa y el inicio del siguiente con el mismo handle. El último programa de cada handle puede mostrar 0 ms si no hay evento de cierre explícito.

---

## Normalización de Paths

El script principal normaliza automáticamente los paths de entrada y salida:

1. **Remueve trailing backslashes**: `C:\logs\` → `C:\logs`
2. **Elimina dobles backslashes**: `C:\logs\\data` → `C:\logs\data`
3. **Construye paths seguros**: Evita problemas de escape en comillas

---

## Archivos de Salida

Todos los archivos de salida se generan en el directorio especificado (o en el predeterminado):

```
C:\logs\KBLogAnalyzer_YYYYMMDD_HHMMSS\
├── detectDelays.txt
├── ErrorWarning.txt
├── unknownLogType.txt
├── DelaysByProgramDetail.txt
├── DelaysByProgramSummary.txt
├── totalByPrograms.txt
├── totalByStmt.txt
├── LogDuration.txt
├── ConnectionAnalysis.txt
├── CallTree.txt
└── *.log (copias de los logs originales)
```

Al finalizar, se abre automáticamente el explorador de Windows en este directorio.

---

## Solución de Problemas

### Error: "No se puede ejecutar el script"

**Causa**: Política de ejecución de PowerShell restrictiva

**Solución**:
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### Error: "PathNotFound"

**Causa**: Path con caracteres especiales o trailing backslashes

**Solución**: El script ya normaliza automáticamente. Si persiste, verificar que el directorio exista.

### Los tiempos en CallTree están en 0 ms

**Causa**: Los logs no contienen eventos de cierre explícito de programas

**Solución**: El script usa una aproximación (tiempo hasta el siguiente programa). Si todos son 0, revisar que los logs contengan líneas con:
- `gxObject:...handle 'X'`
- `Start DataStoreProvider.Ctr...handle 'X'...dataStoreHelper:GeneXus.Programs...`

### Variables no se expanden correctamente

**Causa**: Problema con delayed expansion en batch

**Solución**: El script ya usa `setlocal enabledelayedexpansion` y variables temporales. Si persiste, reportar el problema.

---

## Notas Técnicas

- **Formato de timestamp esperado**: `YYYY-MM-DDTHH:MM:SS.fff±HH:MM`
- **Codificación**: UTF-8
- **Separador de línea**: Windows (CRLF)
- **Módulo compartido**: `Write-OutputAndFile.psm1` se usa en todos los scripts para salida dual (consola + archivo)

---

## Contribuciones y Mejoras

Ver `FaltaHacer.txt` para lista de mejoras pendientes.

---

## Licencia

[Especificar licencia si aplica]

---

## Contacto y Soporte

[Información de contacto o enlaces a repositorio]

---

**Última actualización**: Marzo 2026
