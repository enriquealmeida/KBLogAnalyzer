# Escribe en consola y en archivo
function Write-OutputAndFile {
    param (
        [string]$message,
        [string]$filePath
    )

    Write-Host $message
    Add-Content -Path $filePath -Value $message
}