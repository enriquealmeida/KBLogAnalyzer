param (
    [string]$inputFile,
    [string]$searchText,
	[string]$outputFile
)

# Verificar que los parámetros no estén vacíos
if ([string]::IsNullOrEmpty($inputFile) -or [string]::IsNullOrEmpty($searchText) -or [string]::IsNullOrEmpty($outputFile)) {
    Write-Host "Por favor, especifica ambos parámetros: -inputFile, -searchText y -outputFile."
    exit
} else {
	 Write-Host "Leyendo archivo $inputFile, filtrando por $searchText, contando y guardando el resultado en $outputFile."
}

# Inicializar un diccionario para almacenar los conteos
$counter = @{}

# Leer el archivo de log línea por línea
Get-Content $inputFile | ForEach-Object {
    # Buscar la aparición del texto de búsqueda
    if ($_ -match $searchText) {
        # Extraer el texto después del texto de búsqueda
        $foundText = ($_ -split $searchText)[1]
		$foundText = $foundText.Replace(",c.opened:0=0", "")
		$foundText = $foundText.Replace(", ((GxItemStmt)o).opened: 0", "")
		$foundText = $foundText.Trim()
        # Incrementar el contador para este texto
        if ($counter.ContainsKey($foundText)) {
            $counter[$foundText]++
        } else {
            $counter[$foundText] = 1
        }
    }
}

# Escribir las cuentas en un nuevo archivo
"Cantidad_de_Veces;Sentencia" | Out-File "$outputFile"
$counter.GetEnumerator() | Sort-Object Value -Descending | ForEach-Object {
    "$($_.Value);$($_.Name)" | Out-File "$outputFile" -Append
}
