param(
    [string]$OllamaBaseUrl = "",
    [switch]$SkipOllamaSetup
)

$ErrorActionPreference = "Stop"

function Get-LocalOllamaBaseUrl {
    $addresses = Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
        Where-Object {
            $_.IPAddress -notlike "127.*" -and
            $_.IPAddress -notlike "169.254.*" -and
            $_.AddressState -eq "Preferred"
        } |
        Sort-Object InterfaceMetric, InterfaceIndex

    $address = $addresses | Select-Object -First 1 -ExpandProperty IPAddress
    if ($address) {
        return "http://$address`:11434"
    }

    return ""
}

function Test-OllamaEndpoint {
    param([string]$BaseUrl)

    try {
        Invoke-RestMethod -Uri "$BaseUrl/api/tags" -Method Get -TimeoutSec 4 | Out-Null
        return $true
    }
    catch {
        return $false
    }
}

Push-Location (Join-Path $PSScriptRoot "..")
try {
    if (-not $SkipOllamaSetup) {
        if (Get-Command ollama -ErrorAction SilentlyContinue) {
            powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "create_ollama_models.ps1")
        }
        else {
            Write-Warning "No encontre ollama en PATH. Se instalara el APK, pero el reporte/chat no responderan hasta configurar Ollama."
        }
    }

    if ($OllamaBaseUrl -eq "") {
        $OllamaBaseUrl = Get-LocalOllamaBaseUrl
    }

    if ($OllamaBaseUrl -ne "") {
        if (-not (Test-OllamaEndpoint -BaseUrl $OllamaBaseUrl)) {
            Write-Warning "No pude alcanzar Ollama desde $OllamaBaseUrl."
            Write-Warning "Si Ollama corre en esta PC, abre una terminal y ejecuta:"
            Write-Warning '$env:OLLAMA_HOST="0.0.0.0:11434"; ollama serve'
            Write-Warning "Tambien revisa que Windows Firewall permita el puerto 11434 en tu red local."
        }
    }

    $buildArgs = @("build", "apk", "--debug")
    if ($OllamaBaseUrl -ne "") {
        $buildArgs += "--dart-define=OLLAMA_BASE_URL=$OllamaBaseUrl"
    }

    flutter @buildArgs

    $apkPath = Join-Path (Get-Location) "build\app\outputs\flutter-apk\app-debug.apk"
    if (-not (Test-Path $apkPath)) {
        throw "No se encontro el APK generado en $apkPath"
    }

    adb devices
    adb install -r $apkPath

    Write-Host "Instalado en el telefono: $apkPath"
    if ($OllamaBaseUrl -ne "") {
        Write-Host "Ollama configurado en el APK: $OllamaBaseUrl"
    }
    Write-Host "Si Android pide permisos, abre MXAI Detector y entra a Servicios > Abrir acceso de uso."
}
finally {
    Pop-Location
}
