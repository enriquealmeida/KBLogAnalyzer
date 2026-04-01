param(
    [Parameter(Mandatory=$true)]
    [string]$directoryPath,
    
    [Parameter(Mandatory=$true)]
    [string]$outputFile
)

Import-Module "$PSScriptRoot\Write-OutputAndFile.psm1" -Force

$timestampPattern = '^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}[+-]\d{2}:\d{2}'

$header = "LineNumber,ElapsedMilliseconds"
Set-Content -Path $outputFile -Value $header -Encoding UTF8

Get-ChildItem -Path $directoryPath -File | ForEach-Object {
    $logFile = $_.FullName
    $allLines = Get-Content -Path $logFile

    $firstTimestamp = $null
    $lineNumber = 0

    foreach ($line in $allLines) {
        if (-not [string]::IsNullOrWhiteSpace($line)) {
            $lineNumber++

            if ($line -match $timestampPattern) {
                $timestampStr = $line -replace '^(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}[+-]\d{2}:\d{2}).*', '$1'
                $currentTimestamp = [DateTime]::ParseExact($timestampStr, "yyyy-MM-ddTHH:mm:ss.fffzzz", $null)

                if ($null -eq $firstTimestamp) {
                    $firstTimestamp = $currentTimestamp
                }

                $elapsedMilliseconds = ($currentTimestamp - $firstTimestamp).TotalMilliseconds
                "$lineNumber,$elapsedMilliseconds" | Out-File -Append -FilePath $outputFile -Encoding UTF8
            }
        }
    }
}

Write-OutputAndFile -message "CSV generation complete. Output file: $outputFile" -filePath $outputFile