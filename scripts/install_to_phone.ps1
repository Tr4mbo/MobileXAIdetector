$ErrorActionPreference = "Stop"

Push-Location (Join-Path $PSScriptRoot "..")
try {
    flutter build apk --debug

    $apkPath = Join-Path (Get-Location) "build\app\outputs\flutter-apk\app-debug.apk"
    if (-not (Test-Path $apkPath)) {
        throw "No se encontro el APK generado en $apkPath"
    }

    adb devices
    adb install -r $apkPath

    Write-Host "Instalado en el telefono: $apkPath"
    Write-Host "Si Android pide permisos, abre MXAI Detector y entra a Servicios > Abrir acceso de uso."
}
finally {
    Pop-Location
}
