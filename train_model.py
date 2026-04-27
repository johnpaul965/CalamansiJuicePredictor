"""
train_model.py
==============
Trains a Multiple Linear Regression model to predict calamansi juice yield.

Dataset source: Real experimental data (Small / Medium / Large calamansi)
  - Weight (g), Juice (ml), and Ripeness were all manually recorded
    during the data collection experiment.

      1  Unripe     (dark green skin)
      2  Ripe       (light green / yellowish)
      3  Overripe   (yellow / soft skin)

Steps:
  1. Load dataset.csv  (contains Weight, Size, Juice, Ripeness columns)
  2. Train LinearRegression on Weight, Size, Ripeness → Juice (ml)
  3. Evaluate and save as model.pkl
"""

import pandas as pd
import numpy as np
from sklearn.linear_model import LinearRegression
from sklearn.model_selection import train_test_split
from sklearn.metrics import mean_absolute_error, r2_score
import joblib
import os

# ─────────────────────────────────────────────
# 1. LOAD DATASET
# ─────────────────────────────────────────────
print("=" * 55)
print("   CALAMANSI JUICE YIELD — MODEL TRAINER")
print("=" * 55)

script_dir = os.path.dirname(os.path.abspath(__file__))
csv_path   = os.path.join(script_dir, "dataset.csv")

df = pd.read_csv(csv_path)
print(f"\n✔  Loaded dataset   : {len(df)} rows")
print(f"   Columns          : {list(df.columns)}")
print()
print(df.head(8).to_string(index=False))

# ─────────────────────────────────────────────
# 2. RIPENESS ALREADY IN DATASET
# ─────────────────────────────────────────────
# Ripeness was manually recorded during data collection.
# This column already exists in dataset.csv — no re-engineering needed.
print("\n✔  Ripeness distribution (manually recorded during experiment):")
counts = df["Ripeness"].value_counts().sort_index()
labels = {1: "Unripe", 2: "Ripe", 3: "Overripe"}
for level, count in counts.items():
    bar = "█" * count
    print(f"   Level {level} ({labels[level]:8s}): {count:3d} samples  {bar}")

print("\n✔  Size distribution:")
size_labels = {1: "Small", 2: "Medium", 3: "Large"}
for size, count in df["Size"].value_counts().sort_index().items():
    print(f"   Size {size} ({size_labels[size]:6s}): {count:3d} samples")

# ─────────────────────────────────────────────
# 3. DEFINE FEATURES & TARGET
# ─────────────────────────────────────────────
X = df[["Weight", "Size", "Ripeness"]]   # input features
y = df["Juice"]                           # target: ml of juice

# ─────────────────────────────────────────────
# 4. TRAIN / TEST SPLIT  (80% train, 20% test)
# ─────────────────────────────────────────────
X_train, X_test, y_train, y_test = train_test_split(
    X, y, test_size=0.2, random_state=42
)
print(f"\n✔  Training samples : {len(X_train)}")
print(f"   Test samples     : {len(X_test)}")

# ─────────────────────────────────────────────
# 5. TRAIN MULTIPLE LINEAR REGRESSION
# ─────────────────────────────────────────────
model = LinearRegression()
model.fit(X_train, y_train)

# ─────────────────────────────────────────────
# 6. EVALUATE
# ─────────────────────────────────────────────
y_pred = model.predict(X_test)
mae  = mean_absolute_error(y_test, y_pred)
r2   = r2_score(y_test, y_pred)

print("\n📊  MODEL PERFORMANCE")
print(f"   Mean Absolute Error : {mae:.4f} ml")
print(f"   R² Score            : {r2:.4f}  (1.0 = perfect)")

print("\n📐  Learned Coefficients:")
for feat, coef in zip(X.columns, model.coef_):
    direction = "up" if coef > 0 else "down"
    print(f"   {feat:12s}: {coef:+.4f} ml per unit ({direction})")
print(f"   {'Intercept':12s}: {model.intercept_:.4f}")

# Quick sanity check
sample = np.array([[10, 1, 2]])
sample_pred = model.predict(sample)[0]
print(f"\n  Sanity check: 10g Small Ripe fruit -> predicted {sample_pred:.2f} ml juice")

# ─────────────────────────────────────────────
# 7. SAVE MODEL
# ─────────────────────────────────────────────
model_path = os.path.join(script_dir, "model.pkl")
joblib.dump(model, model_path)
print(f"\n✅  Model saved → {model_path}")
print("=" * 55)
print("   Next step:  streamlit run app.py")
print("=" * 55)