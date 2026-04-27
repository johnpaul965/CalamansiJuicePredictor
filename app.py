"""
app.py — Calamansi Juice Yield Predictor
"""

import streamlit as st
import sqlite3
import hashlib
import joblib
import os
import numpy as np
import pandas as pd
from datetime import datetime

BASE_DIR   = os.path.dirname(os.path.abspath(__file__))
DB_PATH    = os.path.join(BASE_DIR, "database.db")
MODEL_PATH = os.path.join(BASE_DIR, "model.pkl")

# Default admin account seeded automatically on first run
DEFAULT_ADMIN_USER = "admin"
DEFAULT_ADMIN_PASS = "admin123"

# ═══════════════════════════════════════════════════════════════
#  SECURITY
# ═══════════════════════════════════════════════════════════════
def hash_password(password: str) -> str:
    return hashlib.sha256(password.encode()).hexdigest()

# ═══════════════════════════════════════════════════════════════
#  DATABASE — TABLES (seeds a default admin if missing)
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
            ripeness        INTEGER NOT NULL,
            predicted_juice REAL    NOT NULL,
            timestamp       TEXT    NOT NULL
        )
    """)

    # Seed the default admin account if it does not exist
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
def register_user(username: str, password: str, role: str = "user"):
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


def login_user(username: str, password: str):
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


def delete_user(user_id: int):
    conn = sqlite3.connect(DB_PATH)
    c    = conn.cursor()
    c.execute("DELETE FROM users WHERE id = ?", (user_id,))
    conn.commit()
    conn.close()


def update_user_role(user_id: int, new_role: str):
    conn = sqlite3.connect(DB_PATH)
    c    = conn.cursor()
    c.execute("UPDATE users SET role = ? WHERE id = ?", (new_role, user_id))
    conn.commit()
    conn.close()

# ═══════════════════════════════════════════════════════════════
#  DATABASE — PREDICTION FUNCTIONS
# ═══════════════════════════════════════════════════════════════
def save_prediction(username, weight_g, small, medium, large,
                    ripeness, predicted_juice):
    conn = sqlite3.connect(DB_PATH)
    c    = conn.cursor()
    c.execute("""
        INSERT INTO predictions
            (username, weight_g, small_count, medium_count, large_count,
             ripeness, predicted_juice, timestamp)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    """, (
        username, weight_g, small, medium, large,
        ripeness, round(predicted_juice, 4),
        datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    ))
    conn.commit()
    conn.close()


def get_user_history(username: str) -> pd.DataFrame:
    conn = sqlite3.connect(DB_PATH)
    df   = pd.read_sql_query(
        "SELECT * FROM predictions WHERE username = ? ORDER BY id DESC",
        conn, params=(username,)
    )
    conn.close()
    return df


def get_all_predictions() -> pd.DataFrame:
    conn = sqlite3.connect(DB_PATH)
    df   = pd.read_sql_query("SELECT * FROM predictions ORDER BY id DESC", conn)
    conn.close()
    return df


def get_all_users() -> pd.DataFrame:
    conn = sqlite3.connect(DB_PATH)
    df   = pd.read_sql_query("SELECT id, username, role FROM users ORDER BY id", conn)
    conn.close()
    return df

# ═══════════════════════════════════════════════════════════════
#  ML MODEL
# ═══════════════════════════════════════════════════════════════
@st.cache_resource
def load_model():
    if not os.path.exists(MODEL_PATH):
        return None
    return joblib.load(MODEL_PATH)


# ═══════════════════════════════════════════════════════════════
#  MODEL RESULTS SUMMARY (for Admin dashboard)
# ═══════════════════════════════════════════════════════════════
MODEL_RESULTS = {
    "dataset_rows": 295,
    "training_samples": 236,
    "test_samples": 59,
    "mae": 0.3430,
    "r2": 0.8830,
    "coef_weight": 0.3158,
    "coef_size": 0.3236,
    "coef_ripeness": 1.0418,
    "intercept": -2.0515,
    "ripeness_dist": {"Unripe (1)": 26, "Ripe (2)": 233, "Overripe (3)": 36},
    "size_dist": {"Small": 137, "Medium": 109, "Large": 49},
}

# ═══════════════════════════════════════════════════════════════
#  PAGE — LOGIN / REGISTER
# ═══════════════════════════════════════════════════════════════
def _do_login(username: str, password: str, expected_role: str):
    """Shared login handler that enforces the chosen role."""
    if not username or not password:
        st.error("Please fill in both fields.")
        return
    user = login_user(username, password)
    if not user:
        st.error("❌ Incorrect username or password.")
        return
    if user["role"] != expected_role:
        st.error(
            f"❌ This account is registered as **{user['role']}**, not "
            f"**{expected_role}**. Please use the correct login page."
        )
        return
    st.session_state["logged_in"] = True
    st.session_state["username"]  = user["username"]
    st.session_state["role"]      = user["role"]
    st.rerun()


def page_auth():
    st.title("🍋 Calamansi Juice Yield Predictor")
    st.markdown("---")

    # Account-type selector — keeps user and admin entry points fully separate
    account_type = st.radio(
        "Login as",
        ["👤 User", "🛡️ Admin"],
        horizontal=True,
        key="auth_account_type",
    )

    st.markdown("---")

    # ─── USER ENTRY ─────────────────────────────────────────────
    if account_type == "👤 User":
        tab_login, tab_register = st.tabs(["🔑 User Login", "📝 Register"])

        with tab_login:
            st.subheader("👤 User Login")
            st.caption("Log in with your registered user account.")
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
                    if ok:
                        st.success(f"✅ {msg}")
                    else:
                        st.error(f"❌ {msg}")

    # ─── ADMIN ENTRY ────────────────────────────────────────────
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

        | Section       | Description                                         |
        |---------------|-----------------------------------------------------|
        | 🔮 Predict    | Enter calamansi details and get a juice yield estimate |
        | 📋 History    | Review all your past predictions                    |

        ### How Prediction Works
        The system uses **Multiple Linear Regression** trained on **295 real calamansi samples**.
        You provide:
        - **Total weight** of your calamansi (in kg)
        - **Count** of small / medium / large calamansi
        - **Ripeness** (1 = Unripe → 3 = Overripe), manually recorded during data collection

        The model predicts juice yield in **millilitres** and converts it to **litres**.
        """)

    # ── PREDICT ──────────────────────────────────────────────
    elif menu == "🔮 Predict":
        st.title("🔮 Predict Calamansi Juice Yield")
        st.markdown("Fill in the details about your calamansi below.")
        st.markdown("---")

        model = load_model()
        if model is None:
            st.error("❌ Model not found. Please run `python train_model.py` first.")
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
                min_value=0, max_value=1000, value=10,
                help="Number of small-sized calamansi."
            )

        with col2:
            medium_count = st.number_input(
                "🟡 Medium Calamansi (count)",
                min_value=0, max_value=1000, value=10,
                help="Number of medium-sized calamansi."
            )
            large_count = st.number_input(
                "🔴 Large Calamansi (count)",
                min_value=0, max_value=1000, value=10,
                help="Number of large-sized calamansi."
            )

        ripeness = st.select_slider(
            "🌿 Ripeness",
            options=[1, 2, 3],
            value=2,
            format_func=lambda x: {
                1: "1 – Unripe (dark green skin)",
                2: "2 – Ripe (light green / yellowish)",
                3: "3 – Overripe (yellow / soft skin)"
            }[x]
        )

        st.markdown("---")

        if st.button("🔮 Predict Yield", use_container_width=True, type="primary"):
            weight_g     = weight_kg * 1000
            total_count  = small_count + medium_count + large_count

            if total_count == 0:
                st.error("❌ Please enter at least one calamansi count.")
            else:
                avg_size = (
                    (1 * small_count) + (2 * medium_count) + (3 * large_count)
                ) / total_count

                size_label = (
                    "Small"  if avg_size < 1.5 else
                    "Medium" if avg_size < 2.5 else
                    "Large"
                )

                import warnings
                with warnings.catch_warnings():
                    warnings.simplefilter("ignore")
                    features     = np.array([[weight_g, avg_size, ripeness]])
                    predicted_ml = float(model.predict(features)[0])
                predicted_ml    = max(predicted_ml, 0)
                predicted_liters = predicted_ml / 1000

                # ── Results ───────────────────────────────────
                st.markdown("## 📊 Prediction Result")
                r1, r2 = st.columns(2)
                r1.metric("🧃 Juice (ml)",     f"{predicted_ml:.2f} ml")
                r2.metric("🍶 Juice (liters)", f"{predicted_liters:.4f} L")

                with st.expander("📌 Input Summary"):
                    st.write({
                        "Total Weight (g)":  weight_g,
                        "Total Calamansi":   total_count,
                        "Avg Size":          f"{avg_size:.2f} ({size_label})",
                        "Ripeness Score":    ripeness,
                    })

                # Save to DB
                save_prediction(
                    username, weight_g,
                    small_count, medium_count, large_count,
                    ripeness, predicted_ml
                )
                st.success("✅ Prediction saved to your history!")

    # ── HISTORY ──────────────────────────────────────────────
    elif menu == "📋 My History":
        st.title("📋 My Prediction History")
        df = get_user_history(username)
        if df.empty:
            st.info("You have no predictions yet. Go to 🔮 Predict to get started!")
        else:
            st.markdown(f"**{len(df)} prediction(s) found.**")
            df = df.rename(columns={
                "id":              "ID",
                "username":        "User",
                "weight_g":        "Weight (g)",
                "small_count":     "Small",
                "medium_count":    "Medium",
                "large_count":     "Large",
                "ripeness":        "Ripeness",
                "predicted_juice": "Juice (ml)",
                "timestamp":       "Date & Time",
            })
            df["Juice (L)"] = (df["Juice (ml)"] / 1000).round(4)
            st.dataframe(df.drop(columns=["User"]), use_container_width=True)

    # ── LOGOUT ───────────────────────────────────────────────
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

        # ── Add new user / admin ──────────────────────────────
        with st.expander("➕ Add New User or Admin", expanded=False):
            st.markdown("Create a new account with a specific role.")
            a1, a2 = st.columns(2)
            with a1:
                new_uname = st.text_input("Username", key="add_uname")
                new_upass = st.text_input("Password", type="password", key="add_upass")
            with a2:
                new_role  = st.selectbox("Role", ["user", "admin"], key="add_role")
                st.markdown("<br>", unsafe_allow_html=True)
                if st.button("➕ Create Account", type="primary"):
                    ok, msg = register_user(new_uname, new_upass, role=new_role)
                    if ok:
                        st.success(f"✅ {msg}")
                        st.rerun()
                    else:
                        st.error(f"❌ {msg}")

        st.markdown("---")

        # ── Users table ───────────────────────────────────────
        df = get_all_users()
        st.markdown(f"**{len(df)} user(s) registered.**")

        def highlight_role(row):
            color = "#fff3cd" if row["role"] == "admin" else "#e8f5e9"
            return [f"background-color: {color}"] * len(row)

        st.dataframe(
            df.style.apply(highlight_role, axis=1),
            use_container_width=True
        )
        st.caption("🟡 Yellow = Admin  |  🟢 Green = Regular user")

        # ── Change role ───────────────────────────────────────
        st.markdown("---")
        st.markdown("#### ✏️ Change User Role")
        user_options = df[df["username"] != username]  # can't change own role
        if not user_options.empty:
            selected_id   = st.selectbox(
                "Select User",
                user_options["id"].tolist(),
                format_func=lambda i: df[df["id"] == i]["username"].values[0]
            )
            selected_role = st.selectbox("New Role", ["user", "admin"], key="new_role_sel")
            if st.button("✏️ Update Role"):
                update_user_role(selected_id, selected_role)
                st.success("✅ Role updated.")
                st.rerun()

        # ── Delete user ───────────────────────────────────────
        st.markdown("---")
        st.markdown("#### 🗑️ Delete User")
        del_options = df[df["username"] != username]
        if not del_options.empty:
            del_id = st.selectbox(
                "Select User to Delete",
                del_options["id"].tolist(),
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

            st.markdown("---")
            st.subheader("All Records")
            df_display = df.rename(columns={
                "id":              "ID",
                "username":        "User",
                "weight_g":        "Weight (g)",
                "small_count":     "Small",
                "medium_count":    "Medium",
                "large_count":     "Large",
                "ripeness":        "Ripeness",
                "predicted_juice": "Juice (ml)",
                "timestamp":       "Date & Time",
            })
            df_display["Juice (L)"] = (df_display["Juice (ml)"] / 1000).round(4)
            st.dataframe(df_display, use_container_width=True)

    # ── MODEL RESULTS ─────────────────────────────────────────
    elif menu == "🤖 Model Results":
        st.title("🤖 Machine Learning Model Results")
        st.markdown("Results from training the Multiple Linear Regression model on your real calamansi dataset.")
        st.markdown("---")

        # ── Dataset summary ───────────────────────────────────
        st.subheader("📂 Dataset Summary")
        d1, d2, d3 = st.columns(3)
        d1.metric("Total Samples",    MODEL_RESULTS["dataset_rows"])
        d2.metric("Training Samples", MODEL_RESULTS["training_samples"])
        d3.metric("Test Samples",     MODEL_RESULTS["test_samples"])

        st.markdown("---")

        # ── Size distribution ─────────────────────────────────
        st.subheader("📏 Size Distribution")
        size_df = pd.DataFrame(
            list(MODEL_RESULTS["size_dist"].items()),
            columns=["Size", "Count"]
        )
        st.bar_chart(size_df.set_index("Size"))

        # ── Ripeness distribution ──────────────────────────────
        st.subheader("🌿 Ripeness Distribution")
        ripe_df = pd.DataFrame(
            list(MODEL_RESULTS["ripeness_dist"].items()),
            columns=["Ripeness Level", "Count"]
        )
        st.bar_chart(ripe_df.set_index("Ripeness Level"))
        st.caption("Ripeness was manually recorded during the data collection experiment.")

        st.markdown("---")

        # ── Model performance ─────────────────────────────────
        st.subheader("📊 Model Performance")
        p1, p2 = st.columns(2)
        p1.metric(
            "R² Score",
            f"{MODEL_RESULTS['r2']:.4f}",
            help="Closer to 1.0 = better. 0.88 means the model explains 88% of juice yield variation."
        )
        p2.metric(
            "Mean Absolute Error",
            f"{MODEL_RESULTS['mae']:.4f} ml",
            help="On average, predictions are off by only 0.34 ml — very accurate."
        )

        st.progress(MODEL_RESULTS["r2"], text=f"Model Accuracy: {MODEL_RESULTS['r2']*100:.1f}%")

        st.markdown("---")

        # ── Coefficients ──────────────────────────────────────
        st.subheader("📐 Learned Coefficients")
        st.markdown("These tell us how much each feature affects the juice yield:")

        coef_data = {
            "Feature":     ["Weight (g)", "Size (1–3)", "Ripeness (1–3)", "Intercept"],
            "Coefficient": [
                MODEL_RESULTS["coef_weight"],
                MODEL_RESULTS["coef_size"],
                MODEL_RESULTS["coef_ripeness"],
                MODEL_RESULTS["intercept"]
            ],
            "Meaning": [
                "Every 1g more weight → +0.3158 ml juice",
                "Each size step up (S→M→L) → +0.3236 ml juice",
                "Each ripeness level up → +1.0418 ml juice",
                "Base value when all inputs are zero"
            ]
        }
        st.dataframe(pd.DataFrame(coef_data), use_container_width=True)

        st.info("""
        **Key Insight:** Ripeness has the strongest effect per unit (+1.04 ml per level),
        followed by weight (+0.32 ml per gram) and size (+0.32 ml per size step).
        This means a riper calamansi produces significantly more juice regardless of size.
        """)

        st.markdown("---")

        # ── Formula ───────────────────────────────────────────
        st.subheader("🧮 Prediction Formula")
        st.code("""
Predicted Juice (ml) =
    (Weight × 0.3158)
  + (Size   × 0.3236)
  + (Ripeness × 1.0418)
  + (-2.0515)
        """)

        st.markdown("---")
        st.caption("Model: Multiple Linear Regression | Library: scikit-learn | Dataset: 295 real calamansi samples")

    # ── LOGOUT ───────────────────────────────────────────────
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