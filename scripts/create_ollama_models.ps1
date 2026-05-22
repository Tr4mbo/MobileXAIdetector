$ErrorActionPreference = "Stop"

Push-Location (Join-Path $PSScriptRoot "..")
try {
    function New-MxaiOllamaModel {
        param(
            [string]$Name,
            [string]$Modelfile
        )

        ollama create $Name -f $Modelfile
        if ($LASTEXITCODE -ne 0) {
            throw "No se pudo crear el modelo Ollama: $Name"
        }
    }

    New-MxaiOllamaModel -Name "mxai-tinyllama-local" -Modelfile ".\ollama\Modelfile.tinyllama-local"
    New-MxaiOllamaModel -Name "mxai-xai-report" -Modelfile ".\ollama\Modelfile.xai-report"
    New-MxaiOllamaModel -Name "mxai-cyber-chat" -Modelfile ".\ollama\Modelfile.cyber-chat"

    Write-Host "Modelos Ollama creados:"
    Write-Host "  mxai-tinyllama-local"
    Write-Host "  mxai-xai-report"
    Write-Host "  mxai-cyber-chat"
}
finally {
    Pop-Location
}
