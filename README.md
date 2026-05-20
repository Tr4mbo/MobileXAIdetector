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
- La pantalla de analisis usa una animacion circular y deja la generacion XAI justo debajo del scanner, sin texto de APK en el flujo principal.
- Decision, Datos, XAI y SDK son pantallas separadas accesibles desde una navbar vertical que se abre tocando el escudo.
- Los APKs externos entran fuera de la app mediante intents Android `VIEW`/`SEND` y abren una ventana de analisis externa con explicabilidad.
- La prediccion mostrada por Flutter todavia no usa el `.joblib`, porque un modelo scikit-learn serializado con joblib no se ejecuta directamente en Dart.
- La capa de inferencia esta separada para conectar despues un backend Python, ONNX/TFLite o un plugin nativo.
- Android incluye un puente MethodChannel para listar apps instaladas, recibir APKs externos y abrir ajustes de acceso de uso.

## Archivos clave

- `lib/main.dart`: interfaz futurista, analisis global, ventana externa de APK y navbar lateral.
- `lib/services/model_asset_repository.dart`: carga metadata del modelo desde assets.
- `lib/services/detector_service.dart`: motor prototipo temporal.
- `lib/services/android_app_scanner_service.dart`: puente Flutter hacia Android para leer apps instaladas y recibir APKs externos.
- `lib/services/inference_api_client.dart`: cliente preparado para un backend `/predict`.
- `backend/inference_api.py`: API Python para ejecutar el `.joblib` cuando exista un vector compatible.
- `scripts/install_to_phone.ps1`: build debug e instalacion por ADB.

## Ejecutar

```powershell
flutter pub get
flutter run -d chrome
```

Para Android:

```powershell
flutter run -d android
```

Para generar e instalar en un telefono conectado con depuracion USB:

```powershell
.\scripts\install_to_phone.ps1
```

Permisos Android preparados:

- `QUERY_ALL_PACKAGES`: permite listar apps instaladas durante pruebas locales.
- `PACKAGE_USAGE_STATS`: abre la puerta a acceso de uso, pero el usuario debe activarlo manualmente en ajustes.
- `ACTION_VIEW` / `ACTION_SEND` para `application/vnd.android.package-archive`: permite que Android ofrezca MXAI al abrir o compartir un APK descargado.
- `AppAnalysisService`: servicio nativo reservado para ejecutar analisis en segundo plano cuando se conecte el extractor real.

## Backend de inferencia

```powershell
python -m pip install -r backend\requirements.txt
python -m uvicorn backend.inference_api:app --reload --host 127.0.0.1 --port 8000
```

`POST /predict` acepta `vector` con 470 valores o `features` como diccionario ordenado por nombre.
