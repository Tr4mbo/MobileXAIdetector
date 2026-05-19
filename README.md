# Mobile X AI Detector

Interfaz Flutter para analizar APKs con el modelo `Android_Malwaredetector/android_malware_detector.joblib`.

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
- La UI permite seleccionar un APK y ejecutar un flujo prototipo.
- La prediccion mostrada por Flutter todavia no usa el `.joblib`, porque un modelo scikit-learn serializado con joblib no se ejecuta directamente en Dart.
- La capa de inferencia esta separada para conectar despues un backend Python, ONNX/TFLite o un plugin nativo.

## Archivos clave

- `lib/main.dart`: interfaz futurista y paneles del flujo.
- `lib/services/model_asset_repository.dart`: carga metadata del modelo desde assets.
- `lib/services/detector_service.dart`: motor prototipo temporal.
- `lib/services/inference_api_client.dart`: cliente preparado para un backend `/predict`.
- `backend/inference_api.py`: API Python para ejecutar el `.joblib` cuando exista un vector compatible.

## Ejecutar

```powershell
flutter pub get
flutter run -d chrome
```

Para Android:

```powershell
flutter run -d android
```

## Backend de inferencia

```powershell
python -m pip install -r backend\requirements.txt
python -m uvicorn backend.inference_api:app --reload --host 127.0.0.1 --port 8000
```

`POST /predict` acepta `vector` con 470 valores o `features` como diccionario ordenado por nombre.
