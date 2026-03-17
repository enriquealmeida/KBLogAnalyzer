param (
    [string]$inputFile,
    [string]$prefix,
    [string]$postfix,
	[string]$outputFile
	
)

# Verificar que los parámetros no estén vacíos
if ([string]::IsNullOrEmpty($inputFile) -or [string]::IsNullOrEmpty($prefix) -or [string]::IsNullOrEmpty($postfix) -or [string]::IsNullOrEmpty($outputFile)) {
    Write-Host "Por favor, especifica todos los parámetros: -inputFile, -prefix, -postfix y -outputFile."
    exit
} else {
	 Write-Host "Leyendo archivo $inputFile, filtrando por el texto entre $prefix y $postFix y guardando el resultado en $outputFile."
}

# Escapar caracteres especiales en el prefijo y el postfijo para que sean tratados literalmente en la expresión regular
$escapedPrefix = [regex]::Escape($prefix)
$escapedPostfix = [regex]::Escape($postfix)

# Utilizar una expresión regular para encontrar el texto deseado
$pattern = "$escapedPrefix(.*?)$escapedPostfix"

# Inicializar un diccionario para almacenar los conteos
$counter = @{}

# Leer el archivo de log línea por línea
Get-Content $inputFile | ForEach-Object {
	
	$match = $_ | Select-String -Pattern $pattern

	# Extraer el texto después del texto de búsqueda
	if ($match.Matches.Count -gt 0) {
		 $foundText = $match.Matches[0].Groups[1].Value

		# Incrementar el contador para este texto
		if ($counter.ContainsKey($foundText)) {
			$counter[$foundText]++
		} else {
			$counter[$foundText] = 1
		}
	}
}


# Escribir las cuentas en un nuevo archivo
"Cantidad_de_Veces;Programa" | Out-File "$outputFile"
$counter.GetEnumerator() | Sort-Object Value -Descending | ForEach-Object {
    "$($_.Value);$($_.Name)" | Out-File "$outputFile" -Append
}







