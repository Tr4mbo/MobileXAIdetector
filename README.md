# Mobile X AI Detector

Interfaz Flutter para analisis global Android y analisis externo de APKs con el modelo `Android_Malwaredetector/android_malware_detector.joblib`.

## Flujo objetivo

```text
APK o comportamiento observado
-> extractor de features compatible
-> vector de 470 columnas
-> android_malware_detector.joblib
-> prediccion Benign/Malware
-> SHAP / importancia local
-> Ollama explica el resultado
```

## Estado actual

- La app Flutter ya carga metadata real del modelo: features, metricas e importancia global.
- La UI movil principal ya no selecciona APKs ni apps individuales: ejecuta un analisis global con un unico boton `Analizar`.
- La pantalla de analisis usa una animacion circular y deja el reporte XAI justo debajo del scanner, sin texto de APK en el flujo principal.
- Decision, Datos, XAI y SDK son pantallas separadas accesibles desde una navbar vertical que se abre tocando el escudo.
- Los APKs externos se analizan despues de la descarga mediante `Compartir/Enviar a MXAI`; la app no reemplaza el instalador ni compite con la descarga.
- El analisis global usa calibracion conservadora para reducir falsos positivos: separa apps de usuario de apps sistema/OEM y no marca Malware solo por conteo bruto de permisos.
- La prediccion mostrada por Flutter todavia no usa el `.joblib`, porque un modelo scikit-learn serializado con joblib no se ejecuta directamente en Dart.
- La capa de inferencia esta separada para conectar despues un backend Python, ONNX/TFLite o un plugin nativo.
- Android incluye un puente MethodChannel para listar apps instaladas, recibir APKs externos y abrir ajustes de acceso de uso.
- Ollama queda dividido en tres modelos locales: `mxai-xai-report` para reportes del analisis global, `mxai-cyber-chat` para el modo chatbot defensivo y `mxai-tinyllama-local` para validar/importar el GGUF local.

## Archivos clave

- `lib/main.dart`: interfaz futurista, analisis global, ventana externa de APK y navbar lateral.
- `lib/services/model_asset_repository.dart`: carga metadata del modelo desde assets.
- `lib/services/detector_service.dart`: motor prototipo temporal.
- `lib/services/android_app_scanner_service.dart`: puente Flutter hacia Android para leer apps instaladas y recibir APKs externos.
- `lib/services/inference_api_client.dart`: cliente preparado para un backend `/predict`.
- `lib/services/ollama_service.dart`: cliente local para `mxai-xai-report` y `mxai-cyber-chat`.
- `backend/inference_api.py`: API Python para ejecutar el `.joblib` cuando exista un vector compatible.
- `ollama/Modelfile.xai-report`: prompt de reporte XAI basado solo en datos del analisis.
- `ollama/Modelfile.cyber-chat`: prompt de chatbot defensivo sobre ciberseguridad y MXAI.
- `ollama/Modelfile.tinyllama-local`: importa `tinyllama.Q4_K_M.gguf` como modelo Ollama de validacion.
- `scripts/create_ollama_models.ps1`: crea los alias Ollama `mxai-xai-report`, `mxai-cyber-chat` y `mxai-tinyllama-local`.
- `scripts/install_to_phone.ps1`: crea modelos Ollama, compila con `OLLAMA_BASE_URL` e instala por ADB.

## Ejecutar

```powershell
flutter pub get
flutter run -d chrome
```

## Documento PDF

La documentacion tecnica del programa esta en:

```text
docs\MXAI_Detector_Documentacion_Tecnica.pdf
```

Desde la raiz del proyecto puedes abrirlo directamente desde el explorador o con:

```powershell
Start-Process .\docs\MXAI_Detector_Documentacion_Tecnica.pdf
```

Para Android:

```powershell
flutter run -d android
```

Para generar e instalar en un telefono conectado con depuracion USB:

```powershell
.\scripts\install_to_phone.ps1
```

El script intenta detectar la IP local de la PC y compilar el APK con esa direccion para que el telefono no use `127.0.0.1`. Si necesitas fijarla manualmente:

```powershell
.\scripts\install_to_phone.ps1 -OllamaBaseUrl "http://TU_IP_LOCAL:11434"
```

Si el telefono no conecta, inicia Ollama escuchando en la red local antes de instalar:

```powershell
$env:OLLAMA_HOST="0.0.0.0:11434"
ollama serve
```

Permisos Android preparados:

- `INTERNET`: permite conectar con Ollama o backend de inferencia en la red local.
- `QUERY_ALL_PACKAGES`: permite listar apps instaladas durante pruebas locales.
- `PACKAGE_USAGE_STATS`: abre la puerta a acceso de uso, pero el usuario debe activarlo manualmente en ajustes.
- `ACTION_SEND` para `application/vnd.android.package-archive`: permite analizar un APK cuando ya fue descargado y se comparte con MXAI.
- `AppAnalysisService`: servicio nativo reservado para ejecutar analisis en segundo plano cuando se conecte el extractor real.

## Ollama XAI

Primero crea los modelos locales:

```powershell
.\scripts\create_ollama_models.ps1
```

- `mxai-xai-report`: genera reportes usando solo prediccion, probabilidades y factores locales.
- `mxai-cyber-chat`: responde preguntas defensivas de ciberseguridad relacionadas con MXAI.
- `mxai-tinyllama-local`: carga el archivo local `tinyllama.Q4_K_M.gguf`; si su salida sale corrupta, cambia el GGUF por una variante instruct/chat compatible.

Nota Android: el APK no instala otro APK ni un servicio Ollama por dentro. Para una version 100% offline dentro de la app, el siguiente paso seria integrar un runtime nativo tipo llama.cpp/ONNX/TFLite y cargar el GGUF como asset.

## Backend de inferencia

```powershell
python -m pip install -r backend\requirements.txt
python -m uvicorn backend.inference_api:app --reload --host 127.0.0.1 --port 8000
```

`POST /predict` acepta `vector` con 470 valores o `features` como diccionario ordenado por nombre.
