"""
Train and select the best prediction model using total weight only.

This is intentionally separate from train_model.py so the original
weight-and-size model files and administrator metrics remain available.
"""

import json
import os

import joblib
import pandas as pd
from sklearn.linear_model import LinearRegression
from sklearn.metrics import mean_absolute_error, r2_score
from sklearn.model_selection import train_test_split
from sklearn.pipeline import Pipeline
from sklearn.preprocessing import PolynomialFeatures


BASE_DIR = os.path.dirname(os.path.abspath(__file__))
DATASET_PATH = os.path.join(BASE_DIR, "dataset.csv")
MODEL_PATH = os.path.join(BASE_DIR, "model_weight_only.pkl")
METRICS_PATH = os.path.join(BASE_DIR, "weight_only_metrics.json")


def main():
    df = pd.read_csv(DATASET_PATH)
    X = df[["Weight"]]
    y = df["Juice"]

    X_train, X_test, y_train, y_test = train_test_split(
        X, y, test_size=0.2, random_state=42
    )

    candidates = {
        "Simple Linear Regression (Weight only)": LinearRegression(),
        "Polynomial Regression (Weight only, d=2)": Pipeline(
            [
                ("poly", PolynomialFeatures(degree=2, include_bias=False)),
                ("linear", LinearRegression()),
            ]
        ),
    }

    metrics = {}
    fitted_models = {}
    for name, model in candidates.items():
        model.fit(X_train, y_train)
        predictions = model.predict(X_test)
        metrics[name] = {
            "mae": float(mean_absolute_error(y_test, predictions)),
            "r2": float(r2_score(y_test, predictions)),
        }
        fitted_models[name] = model

    # Select by highest R², then lowest MAE for an exact tie.
    best_name = min(
        metrics,
        key=lambda name: (-metrics[name]["r2"], metrics[name]["mae"]),
    )
    best_model = fitted_models[best_name]

    joblib.dump(best_model, MODEL_PATH)
    with open(METRICS_PATH, "w", encoding="utf-8") as metrics_file:
        json.dump(
            {
                "best_model": best_name,
                "metrics": metrics,
                "dataset_rows": len(df),
                "training_samples": len(X_train),
                "test_samples": len(X_test),
                "feature": "Weight (g)",
            },
            metrics_file,
            indent=2,
        )

    print("Weight-only model comparison")
    for name, values in metrics.items():
        print(
            f"{name}: MAE={values['mae']:.6f} ml, "
            f"R2={values['r2']:.6f}"
        )
    print(f"Selected: {best_name}")
    print(f"Saved model: {MODEL_PATH}")
    print(f"Saved metrics: {METRICS_PATH}")


if __name__ == "__main__":
    main()