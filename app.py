
import streamlit as st
import sqlite3
import hashlib
import joblib
import os
import json
import numpy as np
import pandas as pd
from datetime import datetime

BASE_DIR      = os.path.dirname(os.path.abspath(__file__))
DB_PATH       = os.path.join(BASE_DIR, "database.db")
METRICS_PATH  = os.path.join(BASE_DIR, "model_metrics.json")

MODEL_PATHS = {
    "Simple Linear Regression":    os.path.join(BASE_DIR, "model_simple.pkl"),
    "Multiple Linear Regression":  os.path.join(BASE_DIR, "model_multiple.pkl"),
    "Polynomial Regression (d=2)": os.path.join(BASE_DIR, "model_poly.pkl"),
}

DEFAULT_ADMIN_USER = "admin"
DEFAULT_ADMIN_PASS = "admin123"

# ═══════════════════════════════════════════════════════════════
#  SECURITY
# ═══════════════════════════════════════════════════════════════
def hash_password(password: str) -> str:
    return hashlib.sha256(password.encode()).hexdigest()

# ═══════════════════════════════════════════════════════════════
#  DATABASE — TABLES
# ═══════════════════════════════════════════════════════════════
def create_tables():
    conn = sqlite3.connect(DB_PATH)
    c    = conn.cursor()

    c.execute("""
        CREATE TABLE IF NOT EXISTS users (
            id       INTEGER PRIMARY KEY AUTOINCREMENT,
            username TEXT    UNIQUE NOT NULL,
            password TEXT    NOT NULL,
            role     TEXT    NOT NULL DEFAULT 'user'
        )
    """)

    c.execute("""
        CREATE TABLE IF NOT EXISTS predictions (
            id              INTEGER PRIMARY KEY AUTOINCREMENT,
            username        TEXT    NOT NULL,
            weight_g        REAL    NOT NULL,
            small_count     INTEGER NOT NULL,
            medium_count    INTEGER NOT NULL,
            large_count     INTEGER NOT NULL,
            algorithm       TEXT    NOT NULL,
            predicted_juice REAL    NOT NULL,
            timestamp       TEXT    NOT NULL
        )
    """)

    # Seed default admin
    c.execute("SELECT id FROM users WHERE username = ?", (DEFAULT_ADMIN_USER,))
    if c.fetchone() is None:
        c.execute(
            "INSERT INTO users (username, password, role) VALUES (?, ?, 'admin')",
            (DEFAULT_ADMIN_USER, hash_password(DEFAULT_ADMIN_PASS))
        )

    conn.commit()
    conn.close()

# ═══════════════════════════════════════════════════════════════
#  DATABASE — USER FUNCTIONS
# ═══════════════════════════════════════════════════════════════
def register_user(username, password, role="user"):
    if not username.strip() or not password.strip():
        return False, "Username and password cannot be empty."
    if len(password) < 6:
        return False, "Password must be at least 6 characters."
    try:
        conn = sqlite3.connect(DB_PATH)
        c    = conn.cursor()
        c.execute(
            "INSERT INTO users (username, password, role) VALUES (?, ?, ?)",
            (username.strip(), hash_password(password), role)
        )
        conn.commit()
        conn.close()
        return True, f"Account '{username}' created successfully."
    except sqlite3.IntegrityError:
        return False, f"Username '{username}' is already taken."


def login_user(username, password):
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    c = conn.cursor()
    c.execute(
        "SELECT * FROM users WHERE username = ? AND password = ?",
        (username.strip(), hash_password(password))
    )
    row = c.fetchone()
    conn.close()
    return dict(row) if row else None


def delete_user(user_id):
    conn = sqlite3.connect(DB_PATH)
    c    = conn.cursor()
    c.execute("DELETE FROM users WHERE id = ?", (user_id,))
    conn.commit()
    conn.close()


def update_user_role(user_id, new_role):
    conn = sqlite3.connect(DB_PATH)
    c    = conn.cursor()
    c.execute("UPDATE users SET role = ? WHERE id = ?", (new_role, user_id))
    conn.commit()
    conn.close()

# ═══════════════════════════════════════════════════════════════
#  DATABASE — PREDICTION FUNCTIONS
# ═══════════════════════════════════════════════════════════════
def save_prediction(username, weight_g, small, medium, large, algorithm, predicted_juice):
    conn = sqlite3.connect(DB_PATH)
    c    = conn.cursor()
    c.execute("""
        INSERT INTO predictions
            (username, weight_g, small_count, medium_count, large_count,
             algorithm, predicted_juice, timestamp)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    """, (
        username, weight_g, small, medium, large,
        algorithm, round(predicted_juice, 4),
        datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    ))
    conn.commit()
    conn.close()


def get_user_history(username):
    conn = sqlite3.connect(DB_PATH)
    df   = pd.read_sql_query(
        "SELECT * FROM predictions WHERE username = ? ORDER BY id DESC",
        conn, params=(username,)
    )
    conn.close()
    return df


def get_all_predictions():
    conn = sqlite3.connect(DB_PATH)
    df   = pd.read_sql_query("SELECT * FROM predictions ORDER BY id DESC", conn)
    conn.close()
    return df


def get_all_users():
    conn = sqlite3.connect(DB_PATH)
    df   = pd.read_sql_query("SELECT id, username, role FROM users ORDER BY id", conn)
    conn.close()
    return df


# ── NEW: Delete a single prediction (user can only delete their own) ──
def delete_prediction(prediction_id, username):
    conn = sqlite3.connect(DB_PATH)
    c    = conn.cursor()
    c.execute(
        "DELETE FROM predictions WHERE id = ? AND username = ?",
        (prediction_id, username)
    )
    conn.commit()
    conn.close()


# ═══════════════════════════════════════════════════════════════
#  ML MODELS
# ═══════════════════════════════════════════════════════════════
@st.cache_resource
def load_models():
    models = {}
    for name, path in MODEL_PATHS.items():
        if os.path.exists(path):
            models[name] = joblib.load(path)
    return models


@st.cache_data
def load_metrics():
    if not os.path.exists(METRICS_PATH):
        return None
    with open(METRICS_PATH) as f:
        return json.load(f)


def predict_juice(model, algorithm, weight_g, avg_size):
    """Run prediction — Simple LR uses only weight; others use weight + size."""
    import warnings
    with warnings.catch_warnings():
        warnings.simplefilter("ignore")
        if algorithm == "Simple Linear Regression":
            features = np.array([[weight_g]])
        else:
            features = np.array([[weight_g, avg_size]])
        return max(float(model.predict(features)[0]), 0)

# ═══════════════════════════════════════════════════════════════
#  PAGE — AUTH
# ═══════════════════════════════════════════════════════════════
def _do_login(username, password, expected_role):
    if not username or not password:
        st.error("Please fill in both fields.")
        return
    user = login_user(username, password)
    if not user:
        st.error("❌ Incorrect username or password.")
        return
    if user["role"] != expected_role:
        st.error(
            f"❌ This account is registered as **{user['role']}**, "
            f"not **{expected_role}**."
        )
        return
    st.session_state["logged_in"] = True
    st.session_state["username"]  = user["username"]
    st.session_state["role"]      = user["role"]
    st.rerun()


def page_auth():
    st.title("🍋 Calamansi Juice Yield Predictor")
    st.markdown("---")

    account_type = st.radio(
        "Login as", ["👤 User", "🛡️ Admin"],
        horizontal=True, key="auth_account_type"
    )
    st.markdown("---")

    if account_type == "👤 User":
        tab_login, tab_register = st.tabs(["🔑 User Login", "📝 Register"])

        with tab_login:
            st.subheader("👤 User Login")
            username = st.text_input("Username", key="user_login_user")
            password = st.text_input("Password", type="password", key="user_login_pass")
            if st.button("Login as User", use_container_width=True, type="primary"):
                _do_login(username, password, expected_role="user")

        with tab_register:
            st.subheader("📝 Create a New User Account")
            new_user  = st.text_input("Choose a Username", key="reg_user")
            new_pass  = st.text_input("Choose a Password (min. 6 chars)", type="password", key="reg_pass")
            conf_pass = st.text_input("Confirm Password", type="password", key="reg_conf")
            if st.button("Register", use_container_width=True, type="primary"):
                if new_pass != conf_pass:
                    st.error("❌ Passwords do not match.")
                else:
                    ok, msg = register_user(new_user, new_pass, role="user")
                    st.success(f"✅ {msg}") if ok else st.error(f"❌ {msg}")
    else:
        st.subheader("🛡️ Admin Login")
        st.caption("Restricted area — admin credentials required.")
        username = st.text_input("Admin Username", key="admin_login_user")
        password = st.text_input("Admin Password", type="password", key="admin_login_pass")
        if st.button("Login as Admin", use_container_width=True, type="primary"):
            _do_login(username, password, expected_role="admin")

# ═══════════════════════════════════════════════════════════════
#  PAGE — USER DASHBOARD
# ═══════════════════════════════════════════════════════════════
def page_user_dashboard():
    username = st.session_state["username"]

    with st.sidebar:
        st.markdown(f"### 👤 {username}")
        st.markdown("---")
        menu = st.radio(
            "Menu",
            ["🏠 Home", "🔮 Predict", "📋 My History", "🚪 Logout"],
            label_visibility="collapsed"
        )

    # ── HOME ─────────────────────────────────────────────────
    if menu == "🏠 Home":
        st.title("🍋 Calamansi Juice Yield Predictor")
        st.markdown(f"Welcome back, **{username}**! 👋")
        st.markdown("---")
        st.markdown("""
        ### What can you do here?

        | Section       | Description                                              |
        |---------------|----------------------------------------------------------|
        | 🔮 Predict    | Enter calamansi details and get a juice yield estimate   |
        | 📋 History    | Review and delete your past predictions                  |

        ### How Prediction Works
        The system compares **three regression algorithms** trained on **295 real calamansi samples**.
        You provide:
        - **Total weight** of your calamansi (in kg)
        - **Count** of small / medium / large calamansi
        - **Which algorithm** you want to use for prediction

        The model predicts juice yield in **millilitres** and converts it to **litres**.

        ### The Three Algorithms

        | Algorithm | Features Used | Description |
        |-----------|---------------|-------------|
        | Simple Linear Regression | Weight only | Baseline — one predictor |
        | Multiple Linear Regression | Weight + Size | Two predictors, linear |
        | Polynomial Regression (d=2) | Weight + Size + interactions | Captures curved relationships |
        """)

    # ── PREDICT ──────────────────────────────────────────────
    elif menu == "🔮 Predict":
        st.title("🔮 Predict Calamansi Juice Yield")
        st.markdown("Fill in the details about your calamansi below.")
        st.markdown("---")

        models = load_models()
        if not models:
            st.error("❌ Models not found. Please run `python train_model.py` first.")
            return

        col1, col2 = st.columns(2)
        with col1:
            weight_kg = st.number_input(
                "🏋️ Total Weight (kg)",
                min_value=0.01, max_value=50.0, value=1.0, step=0.1,
                help="Total weight of all your calamansi in kilograms."
            )
            small_count = st.number_input(
                "🟢 Small Calamansi (count)",
                min_value=0, max_value=1000, value=10
            )
        with col2:
            medium_count = st.number_input(
                "🟡 Medium Calamansi (count)",
                min_value=0, max_value=1000, value=10
            )
            large_count = st.number_input(
                "🔴 Large Calamansi (count)",
                min_value=0, max_value=1000, value=10
            )

        st.markdown("---")
        st.markdown("#### 🤖 Choose Algorithm")
        algorithm = st.radio(
            "Algorithm",
            list(MODEL_PATHS.keys()),
            label_visibility="collapsed",
            help=(
                "**Simple LR** uses only weight. "
                "**Multiple LR** adds size as a second predictor. "
                "**Polynomial** captures non-linear patterns between weight & size."
            )
        )

        algo_desc = {
            "Simple Linear Regression":
                "Uses **Weight only**. Good baseline — simplest possible model.",
            "Multiple Linear Regression":
                "Uses **Weight + Size**. Adds size as a second linear predictor.",
            "Polynomial Regression (d=2)":
                "Uses **Weight + Size + squared/interaction terms**. Can capture curves.",
        }
        st.info(algo_desc[algorithm])
        st.markdown("---")

        if st.button("🔮 Predict Yield", use_container_width=True, type="primary"):
            weight_g    = weight_kg * 1000
            total_count = small_count + medium_count + large_count

            if total_count == 0:
                st.error("❌ Please enter at least one calamansi count.")
            elif algorithm not in models:
                st.error(f"❌ Model for '{algorithm}' not found.")
            else:
                avg_size = (
                    (1 * small_count) + (2 * medium_count) + (3 * large_count)
                ) / total_count

                size_label = (
                    "Small"  if avg_size < 1.5 else
                    "Medium" if avg_size < 2.5 else
                    "Large"
                )

                predicted_ml    = predict_juice(models[algorithm], algorithm, weight_g, avg_size)
                predicted_liters = predicted_ml / 1000

                st.markdown("## 📊 Prediction Result")
                r1, r2 = st.columns(2)
                r1.metric("🧃 Juice (ml)",     f"{predicted_ml:.2f} ml")
                r2.metric("🍶 Juice (liters)", f"{predicted_liters:.4f} L")

                with st.expander("📌 Input Summary"):
                    st.write({
                        "Total Weight (g)": weight_g,
                        "Total Calamansi":  total_count,
                        "Avg Size":         f"{avg_size:.2f} ({size_label})",
                        "Algorithm Used":   algorithm,
                    })

                save_prediction(
                    username, weight_g,
                    small_count, medium_count, large_count,
                    algorithm, predicted_ml
                )
                st.success("✅ Prediction saved to your history!")

                # Show all 3 results for comparison
                st.markdown("---")
                st.markdown("#### 🔁 Compare All 3 Algorithms")
                comp_cols = st.columns(3)
                for i, (algo_name, m) in enumerate(models.items()):
                    pred = predict_juice(m, algo_name, weight_g, avg_size)
                    comp_cols[i].metric(
                        algo_name.replace(" (d=2)", ""),
                        f"{pred:.2f} ml",
                        delta=f"{pred - predicted_ml:+.2f} ml vs chosen" if algo_name != algorithm else "← selected"
                    )

    # ── HISTORY ──────────────────────────────────────────────
    elif menu == "📋 My History":
        st.title("📋 My Prediction History")
        df = get_user_history(username)
        if df.empty:
            st.info("You have no predictions yet. Go to 🔮 Predict to get started!")
        else:
            st.markdown(f"**{len(df)} prediction(s) found.**")

            # ── DELETE SECTION ──────────────────────────────────
            with st.expander("🗑️ Delete a Prediction", expanded=False):
                st.caption("Select a prediction to delete from your history.")
                del_id = st.selectbox(
                    "Select Prediction to Delete",
                    df["id"].tolist(),
                    format_func=lambda i: (
                        f"ID {i}  |  "
                        f"{df[df['id']==i]['timestamp'].values[0]}  |  "
                        f"{df[df['id']==i]['algorithm'].values[0]}  |  "
                        f"{df[df['id']==i]['predicted_juice'].values[0]:.2f} ml"
                    )
                )
                if st.button("🗑️ Delete Selected Prediction", type="primary"):
                    delete_prediction(del_id, username)
                    st.success(f"✅ Prediction ID {del_id} deleted.")
                    st.rerun()
            # ────────────────────────────────────────────────────

            df_display = df.rename(columns={
                "id":              "ID",
                "username":        "User",
                "weight_g":        "Weight (g)",
                "small_count":     "Small",
                "medium_count":    "Medium",
                "large_count":     "Large",
                "algorithm":       "Algorithm",
                "predicted_juice": "Juice (ml)",
                "timestamp":       "Date & Time",
            })
            df_display["Juice (L)"] = (df_display["Juice (ml)"] / 1000).round(4)
            st.dataframe(df_display.drop(columns=["User"]), use_container_width=True)

    elif menu == "🚪 Logout":
        for key in ["logged_in", "username", "role"]:
            st.session_state.pop(key, None)
        st.rerun()

# ═══════════════════════════════════════════════════════════════
#  PAGE — ADMIN DASHBOARD
# ═══════════════════════════════════════════════════════════════
def page_admin_dashboard():
    username = st.session_state["username"]

    with st.sidebar:
        st.markdown(f"### 🛡️ Admin: {username}")
        st.markdown("---")
        menu = st.radio(
            "Admin Menu",
            ["👥 Manage Users", "📊 View Predictions", "🤖 Model Results", "🚪 Logout"],
            label_visibility="collapsed"
        )

    # ── MANAGE USERS ─────────────────────────────────────────
    if menu == "👥 Manage Users":
        st.title("👥 Manage Users")

        with st.expander("➕ Add New User or Admin", expanded=False):
            a1, a2 = st.columns(2)
            with a1:
                new_uname = st.text_input("Username", key="add_uname")
                new_upass = st.text_input("Password", type="password", key="add_upass")
            with a2:
                new_role = st.selectbox("Role", ["user", "admin"], key="add_role")
                st.markdown("<br>", unsafe_allow_html=True)
                if st.button("➕ Create Account", type="primary"):
                    ok, msg = register_user(new_uname, new_upass, role=new_role)
                    st.success(f"✅ {msg}") if ok else st.error(f"❌ {msg}")
                    if ok: st.rerun()

        st.markdown("---")
        df = get_all_users()
        st.markdown(f"**{len(df)} user(s) registered.**")

        def highlight_role(row):
            color = "#fff3cd" if row["role"] == "admin" else "#e8f5e9"
            return [f"background-color: {color}"] * len(row)

        st.dataframe(df.style.apply(highlight_role, axis=1), use_container_width=True)
        st.caption("🟡 Yellow = Admin  |  🟢 Green = Regular user")

        st.markdown("---")
        st.markdown("#### ✏️ Change User Role")
        user_options = df[df["username"] != username]
        if not user_options.empty:
            selected_id   = st.selectbox(
                "Select User", user_options["id"].tolist(),
                format_func=lambda i: df[df["id"] == i]["username"].values[0]
            )
            selected_role = st.selectbox("New Role", ["user", "admin"], key="new_role_sel")
            if st.button("✏️ Update Role"):
                update_user_role(selected_id, selected_role)
                st.success("✅ Role updated.")
                st.rerun()

        st.markdown("---")
        st.markdown("#### 🗑️ Delete User")
        del_options = df[df["username"] != username]
        if not del_options.empty:
            del_id = st.selectbox(
                "Select User to Delete", del_options["id"].tolist(),
                format_func=lambda i: df[df["id"] == i]["username"].values[0],
                key="del_user_sel"
            )
            if st.button("🗑️ Delete User", type="primary"):
                delete_user(del_id)
                st.success("✅ User deleted.")
                st.rerun()
        else:
            st.info("No other users to manage.")

    # ── VIEW PREDICTIONS ─────────────────────────────────────
    elif menu == "📊 View Predictions":
        st.title("📊 All Predictions")
        df = get_all_predictions()

        if df.empty:
            st.info("No predictions have been made yet.")
        else:
            total        = len(df)
            avg_juice    = df["predicted_juice"].mean()
            unique_users = df["username"].nunique()

            m1, m2, m3 = st.columns(3)
            m1.metric("Total Predictions", total)
            m2.metric("Unique Users",       unique_users)
            m3.metric("Avg Juice (ml)",     f"{avg_juice:.2f}")

            # Algorithm usage breakdown
            if "algorithm" in df.columns:
                st.markdown("---")
                st.subheader("🤖 Predictions by Algorithm")
                algo_counts = df["algorithm"].value_counts().reset_index()
                algo_counts.columns = ["Algorithm", "Count"]
                st.bar_chart(algo_counts.set_index("Algorithm"))

            st.markdown("---")
            st.subheader("All Records")
            df_display = df.rename(columns={
                "id":              "ID",
                "username":        "User",
                "weight_g":        "Weight (g)",
                "small_count":     "Small",
                "medium_count":    "Medium",
                "large_count":     "Large",
                "algorithm":       "Algorithm",
                "predicted_juice": "Juice (ml)",
                "timestamp":       "Date & Time",
            })
            df_display["Juice (L)"] = (df_display["Juice (ml)"] / 1000).round(4)
            st.dataframe(df_display, use_container_width=True)

    # ── MODEL RESULTS ─────────────────────────────────────────
    elif menu == "🤖 Model Results":
        st.title("🤖 Machine Learning Model Results")
        st.markdown("Comparison of **3 Linear Regression variants** trained on your real calamansi dataset.")
        st.markdown("---")

        m = load_metrics()
        if m is None:
            st.error("❌ Metrics file not found. Please run `python train_model.py` first.")
            return

        # ── Dataset summary ───────────────────────────────────
        st.subheader("📂 Dataset Summary")
        d1, d2, d3 = st.columns(3)
        d1.metric("Total Samples",    m["dataset_rows"])
        d2.metric("Training Samples", m["training_samples"])
        d3.metric("Test Samples",     m["test_samples"])

        st.markdown("---")

        # ── Algorithm comparison table ─────────────────────────
        st.subheader("📊 Algorithm Performance Comparison")
        st.caption("All models trained on **Weight** and **Size** only (no Ripeness).")

        metrics = m["metrics"]
        comp_data = []
        for algo, vals in metrics.items():
            comp_data.append({
                "Algorithm":    algo,
                "Features Used": "Weight only" if "Simple" in algo else "Weight + Size",
                "R² Score":     round(vals["r2"], 4),
                "MAE (ml)":     round(vals["mae"], 4),
                "Best?":        "✅ Best" if algo == m["best_model"] else ""
            })
        comp_df = pd.DataFrame(comp_data)
        st.dataframe(comp_df, use_container_width=True, hide_index=True)

        # R² bar chart
        st.markdown("##### R² Score (higher = better)")
        r2_df = pd.DataFrame({
            "Algorithm": list(metrics.keys()),
            "R²":        [v["r2"] for v in metrics.values()]
        }).set_index("Algorithm")
        st.bar_chart(r2_df)

        # MAE bar chart
        st.markdown("##### Mean Absolute Error — ml (lower = better)")
        mae_df = pd.DataFrame({
            "Algorithm": list(metrics.keys()),
            "MAE":       [v["mae"] for v in metrics.values()]
        }).set_index("Algorithm")
        st.bar_chart(mae_df)

        st.markdown("---")

        # ── Size distribution ─────────────────────────────────
        st.subheader("📏 Size Distribution")
        size_df = pd.DataFrame(
            list(m["size_dist"].items()),
            columns=["Size", "Count"]
        )
        st.bar_chart(size_df.set_index("Size"))

        st.markdown("---")

        # ── Coefficients per model ─────────────────────────────
        st.subheader("📐 Learned Coefficients")

        tab1, tab2, tab3 = st.tabs([
            "Simple Linear Regression",
            "Multiple Linear Regression",
            "Polynomial Regression (d=2)"
        ])

        with tab1:
            st.markdown("**Formula:** `Juice = Weight × coef + intercept`")
            coef_df = pd.DataFrame([
                {"Feature": "Weight (g)", "Coefficient": m["simple_coef_weight"],
                 "Meaning": f"+{m['simple_coef_weight']:.4f} ml per gram"},
                {"Feature": "Intercept",  "Coefficient": m["simple_intercept"],
                 "Meaning": "Base value"},
            ])
            st.dataframe(coef_df, use_container_width=True, hide_index=True)
            st.code(f"Juice = (Weight × {m['simple_coef_weight']}) + {m['simple_intercept']}")

        with tab2:
            st.markdown("**Formula:** `Juice = Weight × w1 + Size × w2 + intercept`")
            coef_df = pd.DataFrame([
                {"Feature": "Weight (g)", "Coefficient": m["multiple_coef_weight"],
                 "Meaning": f"+{m['multiple_coef_weight']:.4f} ml per gram"},
                {"Feature": "Size (1–3)", "Coefficient": m["multiple_coef_size"],
                 "Meaning": f"+{m['multiple_coef_size']:.4f} ml per size step"},
                {"Feature": "Intercept",  "Coefficient": m["multiple_intercept"],
                 "Meaning": "Base value"},
            ])
            st.dataframe(coef_df, use_container_width=True, hide_index=True)
            st.code(
                f"Juice = (Weight × {m['multiple_coef_weight']}) "
                f"+ (Size × {m['multiple_coef_size']}) "
                f"+ {m['multiple_intercept']}"
            )

        with tab3:
            st.markdown("**Features:** Weight, Size, Weight², Weight×Size, Size²")
            poly_rows = []
            for feat, coef in zip(m["poly_feat_names"], m["poly_coefs"]):
                poly_rows.append({"Feature": feat, "Coefficient": coef})
            poly_rows.append({"Feature": "Intercept", "Coefficient": m["poly_intercept"]})
            st.dataframe(pd.DataFrame(poly_rows), use_container_width=True, hide_index=True)

        st.markdown("---")

        # ── Key insight ────────────────────────────────────────
        best = m["best_model"]
        best_r2 = metrics[best]["r2"]
        st.info(f"""
        **🏆 Best Performing Algorithm: {best}**

        R² = {best_r2:.4f} — this model explains {best_r2*100:.1f}% of juice yield variation
        using only **Weight** and **Size** as inputs (Ripeness removed).

        All three algorithms are variants of Linear Regression, each adding more
        complexity. The results show how adding more features or polynomial terms
        affects prediction accuracy on this dataset.
        """)

        st.markdown("---")
        st.caption("Model: scikit-learn LinearRegression / Pipeline(PolynomialFeatures) | Dataset: 295 real calamansi samples | Features: Weight (g), Size (1–3)")

    elif menu == "🚪 Logout":
        for key in ["logged_in", "username", "role"]:
            st.session_state.pop(key, None)
        st.rerun()

# ═══════════════════════════════════════════════════════════════
#  MAIN
# ═══════════════════════════════════════════════════════════════
def main():
    st.set_page_config(
        page_title="Calamansi Juice Yield Predictor",
        page_icon="🍋",
        layout="wide",
        initial_sidebar_state="expanded"
    )
    create_tables()

    if not st.session_state.get("logged_in"):
        page_auth()
    elif st.session_state.get("role") == "admin":
        page_admin_dashboard()
    else:
        page_user_dashboard()


if __name__ == "__main__":
    main()