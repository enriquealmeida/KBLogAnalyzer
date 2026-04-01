# KBLogAnalyzer

**Herramienta de análisis de logs para aplicaciones GeneXus en Windows**

![Version](https://img.shields.io/badge/version-1.5-blue)
![Platform](https://img.shields.io/badge/platform-Windows-lightgrey)
![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-blue)

---

## 📋 Descripción

**KBLogAnalyzer** es una herramienta completa para analizar archivos de log generados por aplicaciones GeneXus. Permite identificar problemas de rendimiento, errores, patrones de ejecución y mucho más a través de múltiples análisis automatizados.

### Características principales

✅ **Detección de demoras** - Identifica operaciones lentas  
✅ **Script SQL para Oracle** - Genera script ejecutable con las sentencias SQL que demoran  
✅ **Análisis de errores** - Separa y agrupa errores y warnings  
✅ **Totalización por programa** - Cuenta ejecuciones de cada programa  
✅ **Totalización por SQL** - Identifica queries más frecuentes  
✅ **Análisis de conexiones** - Detecta conexiones lentas o no cerradas  
✅ **Duración de logs** - Calcula el periodo cubierto por cada log  
✅ **SQL por programa** - Lista sentencias SQL únicas ejecutadas por cada programa  
✅ **Conteo de ejecuciones SQL** - Cuenta ejecuciones con parámetros resueltos  
✅ **Accesos a tablas** - Cuenta INSERT/UPDATE/DELETE/SELECT por tabla  
✅ **Interfaz interactiva** - Configuración paso a paso fácil de usar

---

## 🚀 Inicio Rápido

### Requisitos

- Windows 10 o superior
- PowerShell 5.1 o superior (incluido por defecto en Windows 10+)

### Instalación

1. **Clonar o descargar** este repositorio
2. **Configurar política de ejecución** de PowerShell (si es necesario):
   ```powershell
   Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
   ```

### Uso Básico

1. Ejecutar `KBLogAnalyzer.cmd`
2. Ingresar el directorio con los archivos `.log`
3. Seleccionar los análisis deseados (Y/N)
4. Revisar los resultados en el directorio de salida (se abre automáticamente)

**Ejemplo**:

```cmd
C:\KBLogAnalyzer> KBLogAnalyzer.cmd

==========================================
  KBLogAnalyzer v1.4 (2026.03)
==========================================

Directorio de los logs: C:\MiApp\logs
Directorio de resultados: [ENTER para usar default]

Desea detectar demoras? (Y/N): Y
Mostrar logs que demoran mas que (default 500 ms): 1000

Separa Errores, Warnings y no conocidos? (Y/N): Y
...
```

---

## 📊 Análisis Disponibles

| Análisis | Script | Descripción | Archivo de Salida |
|----------|--------|-------------|-------------------|
| **Detectar Demoras** | `detectDelays.ps1` | Operaciones que superan umbral de tiempo | `detectDelays.txt`, `DelaysSQLStatements.sql` |
| **Errores/Warnings** | `filterErrorWarningAndUnknown.ps1` | Separa errores, warnings y líneas desconocidas | `ErrorWarning.txt`, `unknownLogType.txt` |
| **Demoras por Programa** | `delaysByProgram.ps1` | Agrupa y totaliza demoras por programa | `DelaysByProgramDetail.txt`, `DelaysByProgramSummary.txt` |
| **Total por Programa** | `totalByProgram.ps1` | Cuenta ejecuciones de cada programa | `totalByPrograms.txt` |
| **Total por SQL** | `totalByStmt.ps1` | Cuenta ejecuciones de cada sentencia SQL | `totalByStmt.txt` |
| **Duración de Logs** | `logDuration.ps1` | Calcula inicio, fin y duración de cada log | `LogDuration.txt` |
| **Análisis de Conexiones** | `connectionAnalysis.ps1` | Detecta conexiones lentas o no cerradas | `ConnectionAnalysis.txt` |
| **SQL por Programa** | `stmtByProgram.ps1` | Lista sentencias SQL únicas por programa | `StmtByProgram.txt` |
| **Conteo Ejecuciones SQL** | `stmtExecutionCount.ps1` | Cuenta ejecuciones SQL con parámetros resueltos | `StmtExecutionCount.txt` |
| **Accesos a Tablas** | `tableAccessCount.ps1` | Cuenta accesos por tabla y tipo de operación | `TableAccessCount.txt` |

---

## 📁 Estructura del Proyecto

```
KBLogAnalyzer/
│
├── KBLogAnalyzer.cmd              # Script principal
├── TestKBLogAnalyzer.cmd          # Script de pruebas
├── README.md                      # Este archivo
├── .gitignore                     # Archivos ignorados por Git
│
├── pscode/                        # Scripts PowerShell
│   ├── detectDelays.ps1
│   ├── filterErrorWarningAndUnknown.ps1
│   ├── delaysByProgram.ps1
│   ├── totalByProgram.ps1
│   ├── totalByStmt.ps1
│   ├── logDuration.ps1
│   ├── connectionAnalysis.ps1
│   ├── stmtByProgram.ps1
│   ├── stmtExecutionCount.ps1
│   ├── tableAccessCount.ps1
│   └── Write-OutputAndFile.psm1   # Módulo compartido
│
├── doc/                           # Documentación detallada
│   ├── README.md                  # Documentación completa
│   ├── USER_GUIDE.md              # Guía de usuario
│   └── TECHNICAL_GUIDE.md         # Guía técnica
│
└── TestLogs/                      # Logs de ejemplo (opcional)
```

---

## 📖 Documentación

- **[Guía de Usuario](doc/USER_GUIDE.md)** - Instrucciones detalladas, casos de uso y FAQ
- **[Guía Técnica](doc/TECHNICAL_GUIDE.md)** - Arquitectura, desarrollo y extensibilidad
- **[Documentación Completa](doc/README.md)** - Referencia completa de todas las funcionalidades

---

## 💡 Casos de Uso

### Optimización de Rendimiento

```cmd
# Detectar operaciones lentas y agrupar por programa
Desea detectar demoras? (Y/N): Y
Mostrar logs que demoran mas que: 500

Mide demoras por programa? (Y/N): Y
```

**Resultado**: Identifica qué programas son más lentos y prioriza optimizaciones.

### Troubleshooting de Errores

```cmd
# Separar errores y warnings
Separa Errores, Warnings y no conocidos? (Y/N): Y

Calcula duración de archivos de log? (Y/N): Y
```

**Resultado**: Lista de todos los errores con timestamps para correlacionar con incidentes.

### Análisis de Base de Datos

```cmd
# Detectar problemas de conexiones
Analiza conexiones a BD (lentas/no cerradas)? (Y/N): Y
Umbral para conexiones lentas: 5000

Agrupa y totaliza por SENTENCIA SQL? (Y/N): Y
```

**Resultado**: Identifica queries problemáticas y connection leaks.

---

## 🔧 Configuración

### Umbrales Recomendados

| Parámetro | Valor Default | Uso General | Análisis Detallado |
|-----------|---------------|-------------|-------------------|
| Umbral de demoras | 500 ms | 1000 ms | 100 ms |
| Umbral conexiones lentas | 5000 ms | 2000-3000 ms | 500-1000 ms |

### Directorio de Salida

Por defecto, los resultados se guardan en:
```
{directorio_logs}\KBLogAnalyzer_{timestamp}\
```

Ejemplo: `C:\logs\KBLogAnalyzer_20260317_153045\`

Puedes especificar un directorio personalizado cuando se te solicite.

---

## ⚠️ Solución de Problemas

### Error: "No se puede ejecutar el script"

**Causa**: Política de ejecución de PowerShell restrictiva

**Solución**:
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### Variables no se expanden correctamente

**Causa**: Problema con delayed expansion en batch

**Solución**: El script ya maneja esto automáticamente. Si persiste, reportar issue.

---

## 🤝 Contribuciones

Las contribuciones son bienvenidas. Para cambios importantes:

1. Fork el proyecto
2. Crea una rama para tu feature (`git checkout -b feature/AmazingFeature`)
3. Commit tus cambios (`git commit -m 'Add some AmazingFeature'`)
4. Push a la rama (`git push origin feature/AmazingFeature`)
5. Abre un Pull Request

---

## 📝 Notas Técnicas

- **Formato de timestamp esperado**: `YYYY-MM-DDTHH:MM:SS.fff±HH:MM`
- **Codificación**: UTF-8
- **Compatibilidad**: Windows 10+, PowerShell 5.1+
- **Rendimiento**: Optimizado para logs de hasta 1GB por archivo

---

## 📜 Licencia

Este proyecto no tiene licencia especificada actualmente.

---

## 📧 Contacto

Para reportar bugs o solicitar features, por favor abre un issue en GitHub.

---

**Última actualización**: Marzo 2026
