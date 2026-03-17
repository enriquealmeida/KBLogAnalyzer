# KBLogAnalyzer - Guía de Usuario

## Índice

1. [Inicio Rápido](#inicio-rápido)
2. [Interfaz Interactiva](#interfaz-interactiva)
3. [Configuración de Análisis](#configuración-de-análisis)
4. [Interpretación de Resultados](#interpretación-de-resultados)
5. [Casos de Uso Comunes](#casos-de-uso-comunes)
6. [Preguntas Frecuentes](#preguntas-frecuentes)

---

## Inicio Rápido

### Paso 1: Preparar los Logs

1. Reunir todos los archivos `.log` que desea analizar en un mismo directorio
2. Asegurarse de tener permisos de lectura sobre esos archivos

### Paso 2: Ejecutar KBLogAnalyzer

1. Hacer doble clic en `KBLogAnalyzer.cmd` o ejecutarlo desde línea de comandos
2. Aparecerá la pantalla de bienvenida:

```
==========================================
  KBLogAnalyzer v1.3 (2026.03)
==========================================
```

### Paso 3: Especificar Directorios

**Directorio de logs (requerido)**:
```
Directorio de los logs: C:\MiAplicacion\logs
```
- Ingresar la ruta completa donde están los archivos `.log`
- El directorio debe existir
- Puede copiar y pegar la ruta desde el Explorador de Windows

**Directorio de resultados (opcional)**:
```
Directorio de resultados: (default C:\MiAplicacion\logs\KBLogAnalyzer_20260317_103045)
```
- Si presiona ENTER sin escribir nada, usará el directorio predeterminado
- El directorio predeterminado se crea automáticamente dentro del directorio de logs
- Incluye timestamp para evitar sobrescribir resultados anteriores
- Si especifica un directorio personalizado y no existe, se creará automáticamente

### Paso 4: Seleccionar Análisis

Responder **Y** (Sí) o **N** (No) a cada opción:

```
Desea detectar demoras? (Y/N): Y
Mostrar logs que demoran mas que (default 500 ms): 1000

Separa Errores, Warnings y no conocidos? (Y/N): Y
Agrupa y totaliza por programa? (Y/N): Y
Agrupa y totaliza por SENTENCIA SQL? (Y/N): N
Mide demoras por programa? (Y/N): Y
Calcula duración de archivos de log? (Y/N): Y
Analiza conexiones a BD (lentas/no cerradas)? (Y/N): Y
Umbral para conexiones lentas (default 5000 ms): 

Genera arbol de llamadas entre programas? (Y/N): N
```

### Paso 5: Revisar Resultados

Al terminar el procesamiento:
- Se muestra un mensaje de confirmación
- Se abre automáticamente el Explorador de Windows con los resultados
- Revisar los archivos `.txt` generados

---

## Interfaz Interactiva

### Validación de Entradas

El script valida automáticamente:

✅ **Directorio de logs existe**
- Si no existe, solicita ingresar uno válido

✅ **Respuestas Y/N**
- Solo acepta Y (Sí) o N (No), no distingue mayúsculas/minúsculas
- Si ingresa otra cosa, vuelve a preguntar

✅ **Valores numéricos (umbrales)**
- Debe ser un número entero mayor a 0
- Si ingresa 0 o texto no numérico, solicita reingresar

### Valores Predeterminados

Puede presionar ENTER para usar valores predeterminados:

| Parámetro | Valor Default |
|-----------|---------------|
| Directorio de salida | `{dir_logs}\KBLogAnalyzer_{timestamp}` |
| Umbral de demoras | 500 ms |
| Umbral conexiones lentas | 5000 ms |

---

## Configuración de Análisis

### 1. Detectar Demoras

**¿Cuándo usar?**
- Cuando necesite identificar operaciones lentas
- Para optimización de rendimiento
- Para encontrar cuellos de botella

**Parámetros**:
- **Umbral**: Tiempo mínimo en ms para considerar una operación como "lenta"
  - Menor umbral = más operaciones detectadas (más detallado pero más ruido)
  - Mayor umbral = solo operaciones muy lentas (menos resultados, más específico)
  
**Recomendaciones**:
- **500 ms**: Análisis general de rendimiento
- **1000 ms**: Problemas evidentes de performance
- **100 ms**: Análisis muy detallado (genera mucho output)

---

### 2. Separar Errores y Warnings

**¿Cuándo usar?**
- Siempre recomendado para troubleshooting
- Para detectar problemas en producción
- Para análisis post-mortem de incidentes

**No requiere parámetros adicionales**

**Salida**:
- `ErrorWarning.txt`: Todos los errores y warnings
- `unknownLogType.txt`: Líneas con formato inesperado (puede indicar corrupción de log)

---

### 3. Totalizar por Programa

**¿Cuándo usar?**
- Para entender qué programas se ejecutan más frecuentemente
- Para identificar programas "calientes" (hot paths)
- Para optimización basada en uso real

**Proceso**:
1. Extrae líneas con `gxObject:`
2. Las consolida y ordena
3. Cuenta ejecuciones por programa

**Advertencia**: Genera directorios temporales que se limpian automáticamente

---

### 4. Totalizar por Sentencia SQL

**¿Cuándo usar?**
- Para identificar queries más ejecutadas
- Para optimización de base de datos
- Para detectar N+1 queries o consultas repetitivas

**Proceso**:
1. Extrae líneas con `stmt:`
2. Las consolida y ordena
3. Cuenta ejecuciones por sentencia

**Nota**: Sentencias parametrizadas aparecen como una sola entrada

---

### 5. Demoras por Programa

**¿Cuándo usar?**
- Para saber qué programa específico es lento
- Para priorizar optimizaciones
- Para análisis de performance por módulo

**Salidas**:
- **Detail**: Lista completa de cada demora detectada con contexto
- **Summary**: Resumen con totales, promedios y cantidad por programa

**Interpretación del Summary**:
```
Programa        Total (ms)    Count    Promedio (ms)
-------------------------------------------------------
ProgramaA       50000         100      500
ProgramaB       30000         10       3000
```
- **ProgramaA**: Muchas ejecuciones, cada una rápida → revisar si es necesario ejecutarlo tanto
- **ProgramaB**: Pocas ejecuciones pero muy lentas → optimizar el código del programa

---

### 6. Duración de Archivos de Log

**¿Cuándo usar?**
- Para entender el periodo cubierto por cada log
- Para detectar logs incompletos
- Para correlacionar con eventos externos (ej: ventanas de mantenimiento)

**Salida**: Muestra inicio, fin y duración de cada archivo

---

### 7. Análisis de Conexiones

**¿Cuándo usar?**
- Para detectar connection leaks
- Para identificar conexiones que tardan mucho en abrirse
- Para troubleshooting de problemas de BD

**Parámetros**:
- **Umbral conexiones lentas**: Tiempo en ms para considerar una apertura como "lenta"
  - Default: 5000 ms (5 segundos)
  - Red lenta: usar 2000-3000 ms
  - Red local: usar 500-1000 ms

**Salidas**:
- Conexiones lentas al abrirse
- Conexiones que no fueron cerradas explícitamente

---

### 8. Árbol de Llamadas

**¿Cuándo usar?**
- Para entender el flujo de ejecución
- Para ver la jerarquía de programas
- Para debugging de flujos complejos

**Salida**: Árbol jerárquico con indentación mostrando:
- Programa
- Duración aproximada
- Nivel de anidamiento (basado en handle)

**Limitaciones**:
- Duraciones son aproximadas
- El último programa de cada handle puede mostrar 0 ms
- Requiere que los logs contengan información de handles

---

## Interpretación de Resultados

### Formato de Archivos de Salida

Todos los archivos de salida son archivos de texto plano (`.txt`) que pueden abrirse con:
- Notepad
- Notepad++
- Visual Studio Code
- Cualquier editor de texto

### Patrones a Buscar

#### En `detectDelays.txt`:
```
Archivo: mi_log.log
  Línea 5234: [2500 ms] 2026-03-17T09:06:27.007-03:00 [1] DEBUG ...
```
- **Línea**: Número de línea en el archivo original (útil para volver al log completo)
- **[2500 ms]**: Duración de la operación
- Resto: Contenido completo de la línea del log

**Buscar**:
- Operaciones que se repiten frecuentemente y son lentas
- Picos de tiempo inesperados
- Patrones por horario (si varios logs de diferentes momentos)

#### En `DelaysByProgramSummary.txt`:
```
Programa                    Total (ms)    Count    Promedio (ms)
------------------------------------------------------------------
ReporteMensual              150000        50       3000
ConsultaRapida              5000          1000     5
```

**Análisis**:
- **ReporteMensual**: Pocas ejecuciones pero muy lentas → candidato principal para optimización
- **ConsultaRapida**: Muchas ejecuciones rápidas → normal, posible candidato a caché si el total es alto

#### En `ErrorWarning.txt`:
```
ERROR: Connection timeout after 30s
WARNING: Cache eviction due to memory pressure
```

**Priorizar**:
1. Todos los ERROR
2. Warnings que aparecen frecuentemente
3. Warnings únicos que pueden indicar configuración incorrecta

---

## Casos de Uso Comunes

### Caso 1: Aplicación Lenta en Producción

**Objetivo**: Identificar qué está causando lentitud

**Análisis recomendados**:
1. ✅ Detectar demoras (umbral: 1000 ms)
2. ✅ Demoras por programa
3. ✅ Análisis de conexiones (umbral: 2000 ms)
4. ❌ Totalizar por programa (no es urgente)
5. ❌ Árbol de llamadas (solo si necesita entender flujo)

**Pasos**:
1. Ejecutar análisis
2. Revisar `DelaysByProgramSummary.txt` → identificar programa más lento
3. Revisar `ConnectionAnalysis.txt` → verificar si hay problemas de BD
4. Revisar `detectDelays.txt` → buscar patrones o picos específicos

---

### Caso 2: Errores Intermitentes Reportados

**Objetivo**: Encontrar y diagnosticar errores

**Análisis recomendados**:
1. ✅ Separar errores y warnings
2. ✅ Duración de archivos de log (para correlacionar con horarios)
3. ❌ Resto de análisis (no relevante para este caso)

**Pasos**:
1. Ejecutar análisis
2. Revisar `ErrorWarning.txt` → buscar mensajes de error
3. Revisar `LogDuration.txt` → identificar en qué periodo ocurrieron
4. Volver a los logs originales para ver contexto completo alrededor del error

---

### Caso 3: Optimización Proactiva

**Objetivo**: Mejorar rendimiento general antes de problemas

**Análisis recomendados**:
1. ✅ Todos los análisis
2. Umbral de demoras: 500 ms
3. Umbral de conexiones: 5000 ms

**Pasos**:
1. Ejecutar análisis completo
2. Revisar `totalByPrograms.txt` → identificar programas más ejecutados
3. Revisar `totalByStmt.txt` → identificar queries más frecuentes
4. Cruzar con `DelaysByProgramSummary.txt` → priorizar optimizaciones
   - Mayor impacto: programas frecuentes Y lentos
5. Revisar `CallTree.txt` → entender jerarquías y dependencias

---

### Caso 4: Análisis Post-Incidente

**Objetivo**: Entender qué pasó durante un incidente

**Análisis recomendados**:
1. ✅ Todos los análisis
2. Umbrales bajos para capturar todo

**Pasos**:
1. Reunir logs del periodo del incidente
2. Ejecutar análisis completo
3. Revisar cronológicamente:
   - `LogDuration.txt` → verificar periodo cubierto
   - `ErrorWarning.txt` → buscar errores en el momento del incidente
   - `detectDelays.txt` → buscar picos de latencia
   - `ConnectionAnalysis.txt` → verificar problemas de BD
4. Documentar hallazgos con números de línea para evidencia

---

## Preguntas Frecuentes

### ¿Puedo analizar logs de varios días/horas juntos?

**Sí**, solo coloque todos los archivos `.log` en el mismo directorio antes de ejecutar el análisis.

### ¿Se modifican los logs originales?

**No**, los logs originales solo se leen. Se hace una copia en el directorio de salida, pero los originales permanecen intactos.

### ¿Cuánto espacio en disco necesito?

Aproximadamente **2-3 veces** el tamaño de los logs originales:
- 1x para los logs (se copian al directorio de salida)
- 1-2x para los archivos de análisis (depende de cuántos análisis ejecute)

### ¿Cuánto tiempo tarda el análisis?

Depende del tamaño y cantidad de logs:
- **Logs pequeños** (< 10 MB): segundos
- **Logs medianos** (10-100 MB): 1-2 minutos
- **Logs grandes** (> 100 MB): varios minutos

Los análisis más lentos son:
- Totalizar por programa (requiere consolidación)
- Totalizar por sentencia SQL (requiere consolidación)

### ¿Puedo interrumpir el análisis?

**Sí**, presione `Ctrl+C`. Los archivos ya generados permanecerán en el directorio de salida, pero el proceso se detendrá.

### ¿Los resultados se sobrescriben?

**No**, si usa el directorio predeterminado. Cada ejecución crea un nuevo directorio con timestamp.

Si especifica un directorio personalizado que ya existe, **sí se sobrescriben** los archivos con el mismo nombre.

### ¿Qué hacer si un script PowerShell falla?

1. Verificar que PowerShell puede ejecutar scripts:
   ```powershell
   Get-ExecutionPolicy
   ```
   Si es `Restricted`, cambiar a `RemoteSigned`:
   ```powershell
   Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
   ```

2. Verificar el mensaje de error específico
3. Consultar la sección de Solución de Problemas en `README.md`

### ¿Puedo ejecutar solo un análisis específico?

**Sí**, responda **N** (No) a todos los análisis excepto el que desea ejecutar.

### ¿Los logs deben tener un formato específico?

**Sí**, los logs deben ser de aplicaciones GeneXus con el formato estándar:
```
YYYY-MM-DDTHH:MM:SS.fff±HH:MM [thread] LEVEL Componente - Mensaje
```

Ejemplo:
```
2026-03-17T09:06:27.007-03:00 [1] DEBUG GeneXus.Data.ADO.GxCommand - ExecuteReader...
```

### ¿Funciona con logs comprimidos (.zip, .gz)?

**No**, primero debe descomprimir los logs y luego ejecutar el análisis.

### ¿Puedo automatizar la ejecución?

**Sí**, puede crear un archivo de configuración con las respuestas y redirigirlo:
```cmd
KBLogAnalyzer.cmd < respuestas.txt
```

Contenido de `respuestas.txt`:
```
C:\MisLogs
C:\MisResultados
Y
1000
Y
N
...
```

---

**¿Más preguntas?** Consultar `README.md` o la documentación técnica en `TECHNICAL_GUIDE.md`.
