KBLogAnalyzer

Es un archivo de comandos que permite procesar un directorio que contiene archivos de log generados por GeneXus, en el generador .NET. 

ENTRADA:
 - Directorio de archivos de log
 - Directorio de salida
 
SALIDA
 - Archivos con el resultado del procesamiento
    "detectDelays.txt"  Entrdas de log, que demoraron mas que un umbral (threshold) dado
    "totalByPrograms.txt" Ranking de cantidad de veces que ejecuto un programa
    "totalByStmt.txt"     Ranking de cantidad de veces que ejecuto una sentencia SQL
	"unknounLogType.txt" Entradas de log, que no tiene un tipo de log conocido
    "ErrorWarning.txt"  Entrdas de log, que son ERROR/FATAL/WARN	

Permite sacar

- Entradas de log consecutivas que demoran (sentencias "lentas")
Lee los archivos y lista aquellas entradas cuya diferencia de timestamp es mayor a un limite dado (que se recibe por parametros)

- Errores / Warnings y lineas que no tenga el tipo de log correcto
Facilita la deteccion y el estudio de sentencias que dieron algun error.  Luego hay que ir a buscarlas al archivo original para tener mas contexto. 

- Resumen de Sentencias SQL
Saca un resumen del total de veces que fue ejecutada una sentencia SQL

- Resumen de Programas
Saca un resumen del total de veces que se ejecuto un programa (que se conecta al datastore default)

