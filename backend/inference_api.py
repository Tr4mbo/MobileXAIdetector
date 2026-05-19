from __future__ import annotations

import json
import warnings
from pathlib import Path
from typing import Any

import joblib
import numpy as np
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, Field

try:
    import shap
except Exception:  # pragma: no cover - optional at runtime
    shap = None


ROOT = Path(__file__).resolve().parents[1]
MODEL_DIR = ROOT / "Android_Malwaredetector"
MODEL_PATH = MODEL_DIR / "android_malware_detector.joblib"
FEATURES_PATH = MODEL_DIR / "selected_features.json"

app = FastAPI(title="Mobile X AI Detector Inference API")


class PredictRequest(BaseModel):
    vector: list[float] | None = Field(default=None, min_length=470, max_length=470)
    features: dict[str, float] | None = None
    explain: bool = True


class ModelBundle:
    def __init__(self) -> None:
        self.features = json.loads(FEATURES_PATH.read_text(encoding="utf-8"))
        with warnings.catch_warnings():
            warnings.simplefilter("ignore")
            self.model = joblib.load(MODEL_PATH)
        self.explainer = shap.TreeExplainer(self.model) if shap is not None else None

    def to_vector(self, request: PredictRequest) -> np.ndarray:
        if request.vector is not None:
            return np.asarray(request.vector, dtype=float).reshape(1, -1)

        if request.features is None:
            raise HTTPException(
                status_code=422,
                detail="Send either a 470-value vector or a feature dictionary.",
            )

        vector = [float(request.features.get(name, 0.0)) for name in self.features]
        return np.asarray(vector, dtype=float).reshape(1, -1)

    def explain(self, vector: np.ndarray, top_k: int = 8) -> list[dict[str, Any]]:
        if self.explainer is not None:
            shap_values = self.explainer.shap_values(vector)
            values = _class_one_shap_values(shap_values)
        else:
            values = self.model.feature_importances_ * vector[0]

        ranked = np.argsort(np.abs(values))[::-1][:top_k]
        return [
            {
                "feature": self.features[index],
                "contribution": float(values[index]),
                "value": float(vector[0][index]),
            }
            for index in ranked
        ]


def _class_one_shap_values(shap_values: Any) -> np.ndarray:
    if isinstance(shap_values, list):
        return np.asarray(shap_values[1][0])

    values = np.asarray(shap_values)
    if values.ndim == 3:
        return values[0, :, 1]
    return values[0]


bundle = ModelBundle()


@app.get("/health")
def health() -> dict[str, Any]:
    return {"status": "ok", "feature_count": len(bundle.features)}


@app.get("/metadata")
def metadata() -> dict[str, Any]:
    return {
        "model": type(bundle.model).__name__,
        "feature_count": len(bundle.features),
        "classes": [int(label) for label in bundle.model.classes_],
    }


@app.post("/predict")
def predict(request: PredictRequest) -> dict[str, Any]:
    vector = bundle.to_vector(request)
    if vector.shape[1] != len(bundle.features):
        raise HTTPException(
            status_code=422,
            detail=f"Expected {len(bundle.features)} features, got {vector.shape[1]}.",
        )

    prediction = int(bundle.model.predict(vector)[0])
    probabilities = bundle.model.predict_proba(vector)[0]
    response: dict[str, Any] = {
        "prediction": "Malware" if prediction == 1 else "Benign",
        "class_id": prediction,
        "probabilities": {
            "Benign": float(probabilities[0]),
            "Malware": float(probabilities[1]),
        },
    }

    if request.explain:
        response["local_importance"] = bundle.explain(vector)

    return response
