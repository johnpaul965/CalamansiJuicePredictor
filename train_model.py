"""
train_model.py
==============
Trains and compares THREE Linear Regression variants to predict
calamansi juice yield — WITHOUT the Ripeness feature.

Features used:  Weight (g), Size (1=Small, 2=Medium, 3=Large)
Target:         Juice (ml)

Algorithms compared:
  1. Simple Linear Regression   — Weight only (single predictor)
  2. Multiple Linear Regression — Weight + Size (two predictors)
  3. Polynomial Regression (d=2)— Weight + Size + interaction/quadratic terms
"""

import pandas as pd
import numpy as np
from sklearn.linear_model import LinearRegression
from sklearn.preprocessing import PolynomialFeatures
from sklearn.pipeline import Pipeline
from sklearn.model_selection import train_test_split
from sklearn.metrics import mean_absolute_error, r2_score
import joblib
import os
import json

# ─────────────────────────────────────────────
# 1. LOAD DATASET
# ─────────────────────────────────────────────
print("=" * 60)
print("   CALAMANSI JUICE YIELD — MODEL TRAINER (3 Algorithms)")
print("=" * 60)

script_dir = os.path.dirname(os.path.abspath(__file__))
csv_path   = os.path.join(script_dir, "dataset.csv")

df = pd.read_csv(csv_path)
print(f"\n✔  Loaded dataset   : {len(df)} rows")
print(f"   Columns used     : Weight, Size → Juice  (Ripeness removed)")
print()
print(df[["Weight", "Size", "Juice"]].head(8).to_string(index=False))

# ─────────────────────────────────────────────
# 2. SIZE DISTRIBUTION
# ─────────────────────────────────────────────
print("\n✔  Size distribution:")
size_labels = {1: "Small", 2: "Medium", 3: "Large"}
for size, count in df["Size"].value_counts().sort_index().items():
    print(f"   Size {size} ({size_labels[size]:6s}): {count:3d} samples")

# ─────────────────────────────────────────────
# 3. DEFINE FEATURES & TARGET
# ─────────────────────────────────────────────
X_simple   = df[["Weight"]]              # Algorithm 1: Weight only
X_multiple = df[["Weight", "Size"]]      # Algorithms 2 & 3: Weight + Size
y          = df["Juice"]

# ─────────────────────────────────────────────
# 4. TRAIN / TEST SPLIT  (80% train, 20% test)
# ─────────────────────────────────────────────
X_tr_s, X_te_s, y_train, y_test = train_test_split(
    X_simple, y, test_size=0.2, random_state=42
)
X_tr_m, X_te_m, _, _ = train_test_split(
    X_multiple, y, test_size=0.2, random_state=42
)

print(f"\n✔  Training samples : {len(X_tr_m)}")
print(f"   Test samples     : {len(X_te_m)}")

# ─────────────────────────────────────────────
# 5. TRAIN ALL THREE MODELS
# ─────────────────────────────────────────────

# --- Algorithm 1: Simple Linear Regression (Weight only) ---
model_simple = LinearRegression()
model_simple.fit(X_tr_s, y_train)
pred_simple  = model_simple.predict(X_te_s)

# --- Algorithm 2: Multiple Linear Regression (Weight + Size) ---
model_multiple = LinearRegression()
model_multiple.fit(X_tr_m, y_train)
pred_multiple  = model_multiple.predict(X_te_m)

# --- Algorithm 3: Polynomial Regression degree=2 (Weight + Size) ---
model_poly = Pipeline([
    ("poly",   PolynomialFeatures(degree=2, include_bias=False)),
    ("linear", LinearRegression())
])
model_poly.fit(X_tr_m, y_train)
pred_poly = model_poly.predict(X_te_m)

# ─────────────────────────────────────────────
# 6. EVALUATE ALL THREE
# ─────────────────────────────────────────────
results = {
    "Simple Linear Regression":   (pred_simple,   model_simple),
    "Multiple Linear Regression": (pred_multiple, model_multiple),
    "Polynomial Regression (d=2)":(pred_poly,     model_poly),
}

test_preds = {
    "Simple Linear Regression":    pred_simple,
    "Multiple Linear Regression":  pred_multiple,
    "Polynomial Regression (d=2)": pred_poly,
}

print("\n" + "=" * 60)
print("📊  MODEL COMPARISON RESULTS")
print("=" * 60)
print(f"   {'Algorithm':<30} {'MAE':>8} {'R²':>8}")
print(f"   {'-'*30} {'-'*8} {'-'*8}")

best_model_name = None
best_r2 = -999

metrics_store = {}

for name, preds in test_preds.items():
    mae = mean_absolute_error(y_test, preds)
    r2  = r2_score(y_test, preds)
    metrics_store[name] = {"mae": mae, "r2": r2}
    flag = " ← BEST" if r2 > best_r2 else ""
    if r2 > best_r2:
        best_r2 = r2
        best_model_name = name
    print(f"   {name:<30} {mae:>8.4f} {r2:>8.4f}{flag}")

print()

# ─────────────────────────────────────────────
# 7. PRINT COEFFICIENTS
# ─────────────────────────────────────────────
print("📐  Coefficients — Simple Linear Regression (Weight only):")
print(f"   Weight    : {model_simple.coef_[0]:+.4f}")
print(f"   Intercept : {model_simple.intercept_:.4f}")

print("\n📐  Coefficients — Multiple Linear Regression (Weight + Size):")
for feat, coef in zip(["Weight", "Size"], model_multiple.coef_):
    print(f"   {feat:10s}: {coef:+.4f}")
print(f"   {'Intercept':10s}: {model_multiple.intercept_:.4f}")

print("\n📐  Coefficients — Polynomial Regression (degree=2):")
poly_feats = PolynomialFeatures(degree=2, include_bias=False)
poly_feats.fit(X_tr_m)
feat_names = poly_feats.get_feature_names_out(["Weight", "Size"])
lr_step = model_poly.named_steps["linear"]
for feat, coef in zip(feat_names, lr_step.coef_):
    print(f"   {feat:15s}: {coef:+.6f}")
print(f"   {'Intercept':15s}: {lr_step.intercept_:.4f}")

# ─────────────────────────────────────────────
# 8. SAVE ALL THREE MODELS + METRICS
# ─────────────────────────────────────────────
models_to_save = {
    "model_simple.pkl":   model_simple,
    "model_multiple.pkl": model_multiple,
    "model_poly.pkl":     model_poly,
}

for filename, m in models_to_save.items():
    path = os.path.join(script_dir, filename)
    joblib.dump(m, path)
    print(f"\n✅  Saved → {path}")

# Save metrics dict for app.py to read
metrics_path = os.path.join(script_dir, "model_metrics.json")
with open(metrics_path, "w") as fp:
    json.dump({
        "metrics": metrics_store,
        "best_model": best_model_name,
        "simple_coef_weight":      round(float(model_simple.coef_[0]), 4),
        "simple_intercept":        round(float(model_simple.intercept_), 4),
        "multiple_coef_weight":    round(float(model_multiple.coef_[0]), 4),
        "multiple_coef_size":      round(float(model_multiple.coef_[1]), 4),
        "multiple_intercept":      round(float(model_multiple.intercept_), 4),
        "poly_feat_names":         [str(n) for n in feat_names],
        "poly_coefs":              [round(float(c), 6) for c in lr_step.coef_],
        "poly_intercept":          round(float(lr_step.intercept_), 4),
        "dataset_rows":            len(df),
        "training_samples":        len(X_tr_m),
        "test_samples":            len(X_te_m),
        "size_dist": {
            "Small":  int((df["Size"] == 1).sum()),
            "Medium": int((df["Size"] == 2).sum()),
            "Large":  int((df["Size"] == 3).sum()),
        }
    }, fp, indent=2)
print(f"\n✅  Metrics saved → {metrics_path}")

print("\n" + "=" * 60)
print(f"   🏆  Best model: {best_model_name}")
print(f"       R² = {best_r2:.4f}")
print("=" * 60)
print("   Next step:  streamlit run app.py")
print("=" * 60)