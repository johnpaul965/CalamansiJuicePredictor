// Calamansi Yield Predictor - Web Logic Matching Flutter Architecture
// Directly mirroring:
// - flutter_app/lib/main.dart (AuthGate, routing)
// - flutter_app/lib/screens/login_screen.dart (Sign In, Register, Demo Accounts)
// - flutter_app/lib/screens/home_screen.dart (Predict tab, unit toggles, presets, calculation)
// - flutter_app/lib/screens/model_results_screen.dart (Model Results tab, R², MAE, RMSE metrics)
// - flutter_app/lib/screens/history_screen.dart (Prediction history list)
// - flutter_app/lib/screens/admin_screen.dart (Admin Console tabs: Results, User Management, Logs)
// - flutter_app/lib/services/prediction_service.dart (Regression math formulas)

// ──────────────── RESEARCH REGRESSION ENGINE ────────────────
// Exact parameters from PredictionService.dart
const MODEL_CONFIG = {
  representativeUnitWeight: 12.0, // Average weight for medium calamansi in grams
  sizeCode: 2, // 1: Small (<=10g), 2: Medium (<=14g), 3: Large (>14g)
  sizeLabel: 'Medium Calamansi (10–14g)',

  // 1. Simple Linear Regression: Juice = 0.4569 * W - 0.6080
  simpleWeight: 0.4569,
  simpleIntercept: -0.6080,

  // 2. Multiple Linear Regression: Juice = 0.4580 * W - 0.0053 * S - 0.6108
  multipleWeight: 0.4580,
  multipleSize: -0.0053,
  multipleIntercept: -0.6108,

  // 3. Polynomial Regression (degree 2):
  // Juice = -0.5480 + 0.43568*W + 0.086517*S - 0.003075*W² + 0.047385*W*S - 0.164087*S²
  polyIntercept: -0.5480,
  polyCoefs: [0.43568, 0.086517, -0.003075, 0.047385, -0.164087],
};

function predictSimple(w) {
  const val = MODEL_CONFIG.simpleWeight * w + MODEL_CONFIG.simpleIntercept;
  return val > 0 ? val : 0;
}

function predictMultiple(w, s) {
  const val =
    MODEL_CONFIG.multipleWeight * w +
    MODEL_CONFIG.multipleSize * s +
    MODEL_CONFIG.multipleIntercept;
  return val > 0 ? val : 0;
}

function predictPoly(w, s) {
  const features = [w, s, w * w, w * s, s * s];
  let val = MODEL_CONFIG.polyIntercept;
  for (let i = 0; i < features.length; i++) {
    val += MODEL_CONFIG.polyCoefs[i] * features[i];
  }
  return val > 0 ? val : 0;
}

function runCalculationEngine(weightG) {
  const repWeight = MODEL_CONFIG.representativeUnitWeight;
  const sizeCode = MODEL_CONFIG.sizeCode;
  const count = Math.round(weightG / repWeight);
  const countFloat = weightG / repWeight;

  const slrPerFruit = predictSimple(repWeight);
  const mlrPerFruit = predictMultiple(repWeight, sizeCode);
  const polyPerFruit = predictPoly(repWeight, sizeCode);

  return {
    count,
    slrTotalMl: countFloat * slrPerFruit,
    mlrTotalMl: countFloat * mlrPerFruit,
    polyTotalMl: countFloat * polyPerFruit,
    sizeLabel: MODEL_CONFIG.sizeLabel,
  };
}

// ──────────────── LOCAL PERSISTENCE (Supabase & LocalStorage mirroring) ────────────────
const DEFAULT_USERS = [
  { username: 'admin', password: 'admin123', role: 'admin', status: 'Active', joined: '2026-09-01' },
  { username: 'farmer_juan', password: 'user123', role: 'user', status: 'Active', joined: '2026-09-02' },
  { username: 'tacloban_vendor', password: 'user123', role: 'user', status: 'Active', joined: '2026-09-03' },
];

const DEFAULT_LOGS = [
  {
    id: 'log-1',
    date: '2026-09-11 15:30',
    user: 'farmer_juan',
    weightG: 1000,
    weight: '1.00 kg (1000g)',
    size: 'Medium Calamansi (10–14g)',
    slr: '389.20 ml',
    mlr: '391.45 ml',
    poly: '394.80 ml',
  },
  {
    id: 'log-2',
    date: '2026-09-11 11:15',
    user: 'farmer_juan',
    weightG: 5000,
    weight: '5.00 kg (5000g)',
    size: 'Medium Calamansi (10–14g)',
    slr: '1946.00 ml',
    mlr: '1957.25 ml',
    poly: '1974.00 ml',
  },
  {
    id: 'log-3',
    date: '2026-09-11 09:45',
    user: 'tacloban_vendor',
    weightG: 2500,
    weight: '2.50 kg (2500g)',
    size: 'Medium Calamansi (10–14g)',
    slr: '973.00 ml',
    mlr: '978.60 ml',
    poly: '987.00 ml',
  },
];

function getUsers() {
  const raw = localStorage.getItem('calamansi_app_users');
  if (!raw) {
    localStorage.setItem('calamansi_app_users', JSON.stringify(DEFAULT_USERS));
    return [...DEFAULT_USERS];
  }
  try {
    return JSON.parse(raw);
  } catch {
    return [...DEFAULT_USERS];
  }
}

function saveUsers(users) {
  localStorage.setItem('calamansi_app_users', JSON.stringify(users));
}

function getLogs() {
  const raw = localStorage.getItem('local_prediction_logs');
  if (!raw) {
    localStorage.setItem('local_prediction_logs', JSON.stringify(DEFAULT_LOGS));
    return [...DEFAULT_LOGS];
  }
  try {
    return JSON.parse(raw);
  } catch {
    return [...DEFAULT_LOGS];
  }
}

function saveLogs(logs) {
  localStorage.setItem('local_prediction_logs', JSON.stringify(logs));
}

// ──────────────── APP STATE ────────────────
let currentUser = null;
let currentUnit = 'kg'; // 'kg' | 'g'
let registerMode = false;

// ──────────────── DOM ELEMENTS ────────────────
// Screens
const loginScreen = document.getElementById('loginScreen');
const userScaffold = document.getElementById('userScaffold');
const adminScaffold = document.getElementById('adminScaffold');

// Auth elements
const authForm = document.getElementById('authForm');
const usernameInput = document.getElementById('usernameInput');
const passwordInput = document.getElementById('passwordInput');
const confirmPasswordInput = document.getElementById('confirmPasswordInput');
const confirmPasswordGroup = document.getElementById('confirmPasswordGroup');
const authErrorBanner = document.getElementById('authErrorBanner');
const authErrorMessage = document.getElementById('authErrorMessage');
const authSubmitBtn = document.getElementById('authSubmitBtn');
const authSubmitLabel = document.getElementById('authSubmitLabel');
const tabSignIn = document.getElementById('tabSignIn');
const tabCreateAccount = document.getElementById('tabCreateAccount');
const togglePasswordBtn = document.getElementById('togglePasswordBtn');
const quickUserBtn = document.getElementById('quickUserBtn');
const quickAdminBtn = document.getElementById('quickAdminBtn');

// User Scaffold elements
const headerUsername = document.getElementById('headerUsername');
const userRolePill = document.getElementById('userRolePill');
const userSignOutBtn = document.getElementById('userSignOutBtn');
const userNavTabs = userScaffold.querySelectorAll('.flutter-navtabs .navtab-btn');
const viewPredict = document.getElementById('viewPredict');
const viewModelResults = document.getElementById('viewModelResults');
const viewHistory = document.getElementById('viewHistory');

// Predict Tab elements
const unitToggleKg = document.getElementById('unitToggleKg');
const unitToggleG = document.getElementById('unitToggleG');
const batchWeightValue = document.getElementById('batchWeightValue');
const weightUnitLabel = document.getElementById('weightUnitLabel');
const quickChipsContainer = document.getElementById('quickChipsContainer');
const homeErrorBanner = document.getElementById('homeErrorBanner');
const homeErrorMessage = document.getElementById('homeErrorMessage');
const runAllModelsBtn = document.getElementById('runAllModelsBtn');
const predictEmptyState = document.getElementById('predictEmptyState');
const predictionResultsCard = document.getElementById('predictionResultsCard');
const fruitSizeTag = document.getElementById('fruitSizeTag');
const outSlrMl = document.getElementById('outSlrMl');
const outSlrL = document.getElementById('outSlrL');
const outMlrMl = document.getElementById('outMlrMl');
const outMlrL = document.getElementById('outMlrL');
const outPolyMl = document.getElementById('outPolyMl');
const outPolyL = document.getElementById('outPolyL');
const refreshHomeHistoryBtn = document.getElementById('refreshHomeHistoryBtn');
const homeHistoryTableBody = document.getElementById('homeHistoryTableBody');
const historyListContainer = document.getElementById('historyListContainer');

// Admin Scaffold elements
const adminUsername = document.getElementById('adminUsername');
const adminSignOutBtn = document.getElementById('adminSignOutBtn');
const adminNavTabs = adminScaffold.querySelectorAll('.admin-top-pill');
const adminTab0 = document.getElementById('adminTab0');
const adminTab1 = document.getElementById('adminTab1');
const adminTab2 = document.getElementById('adminTab2');
const adminUserCardsContainer = document.getElementById('adminUserCardsContainer');
const adminLogsTableBody = document.getElementById('adminLogsTableBody');
const openAddUserModalBtn = document.getElementById('openAddUserModalBtn');
const addUserModal = document.getElementById('addUserModal');
const closeAddUserModal = document.getElementById('closeAddUserModal');
const cancelAddUser = document.getElementById('cancelAddUser');
const addUserForm = document.getElementById('addUserForm');
const exportLogsCsvBtn = document.getElementById('exportLogsCsvBtn');
const clearAllLogsBtn = document.getElementById('clearAllLogsBtn');

// ──────────────── AUTH GATE & ROUTING ────────────────
function setRegisterMode(isRegister) {
  registerMode = isRegister;
  authErrorBanner.classList.add('hidden');

  if (isRegister) {
    tabSignIn.classList.remove('active');
    tabCreateAccount.classList.add('active');
    confirmPasswordGroup.classList.remove('hidden');
    confirmPasswordInput.setAttribute('required', 'true');
    authSubmitLabel.textContent = 'Create Account & Sign In';
  } else {
    tabSignIn.classList.add('active');
    tabCreateAccount.classList.remove('active');
    confirmPasswordGroup.classList.add('hidden');
    confirmPasswordInput.removeAttribute('required');
    authSubmitLabel.textContent = 'Sign In to Predictor';
  }
}

tabSignIn.addEventListener('click', () => setRegisterMode(false));
tabCreateAccount.addEventListener('click', () => setRegisterMode(true));

togglePasswordBtn.addEventListener('click', () => {
  const isPass = passwordInput.getAttribute('type') === 'password';
  passwordInput.setAttribute('type', isPass ? 'text' : 'password');
  togglePasswordBtn.textContent = isPass ? '🙈' : '👁️';
});

function showAuthError(msg) {
  authErrorMessage.textContent = msg;
  authErrorBanner.classList.remove('hidden');
}

authForm.addEventListener('submit', (e) => {
  e.preventDefault();
  authErrorBanner.classList.add('hidden');

  const u = usernameInput.value.trim().toLowerCase();
  const p = passwordInput.value.trim();

  if (!u) {
    showAuthError('Please enter a username.');
    return;
  }
  if (!p) {
    showAuthError('Please enter a password.');
    return;
  }

  const users = getUsers();

  if (registerMode) {
    if (p.length < 4) {
      showAuthError('Password must be at least 4 characters.');
      return;
    }
    const confirmP = confirmPasswordInput.value.trim();
    if (p !== confirmP) {
      showAuthError('Passwords do not match. Please verify.');
      return;
    }
    if (users.some((x) => x.username.toLowerCase() === u)) {
      showAuthError('Username already registered. Please sign in or pick another.');
      return;
    }

    const newUser = {
      username: u,
      password: p,
      role: 'user',
      status: 'Active',
      joined: new Date().toISOString().split('T')[0],
    };
    users.push(newUser);
    saveUsers(users);
    handleLoginSuccess(newUser);
  } else {
    const existing = users.find((x) => x.username.toLowerCase() === u && x.password === p);
    if (!existing) {
      showAuthError('Incorrect username or password. Please verify and try again.');
      return;
    }
    if (existing.status === 'Suspended') {
      showAuthError('This account has been suspended by an Administrator.');
      return;
    }
    handleLoginSuccess(existing);
  }
});

quickUserBtn.addEventListener('click', () => {
  setRegisterMode(false);
  usernameInput.value = 'farmer_juan';
  passwordInput.value = 'user123';
  authForm.dispatchEvent(new Event('submit'));
});

quickAdminBtn.addEventListener('click', () => {
  setRegisterMode(false);
  usernameInput.value = 'admin';
  passwordInput.value = 'admin123';
  authForm.dispatchEvent(new Event('submit'));
});

function handleLoginSuccess(user) {
  currentUser = user;
  sessionStorage.setItem('active_calamansi_user', JSON.stringify(user));

  loginScreen.classList.add('hidden');

  if (user.role === 'admin') {
    showAdminScaffold();
  } else {
    showUserScaffold();
  }
}

function handleSignOut() {
  currentUser = null;
  sessionStorage.removeItem('active_calamansi_user');
  userScaffold.classList.add('hidden');
  adminScaffold.classList.add('hidden');
  loginScreen.classList.remove('hidden');
  authForm.reset();
  setRegisterMode(false);
}

userSignOutBtn.addEventListener('click', handleSignOut);
adminSignOutBtn.addEventListener('click', handleSignOut);

// ──────────────── USER VIEWS & NAVIGATION ────────────────
function showUserScaffold() {
  loginScreen.classList.add('hidden');
  adminScaffold.classList.add('hidden');
  userScaffold.classList.remove('hidden');

  headerUsername.textContent = currentUser.username;
  userRolePill.textContent = currentUser.role.toUpperCase();

  switchUserTab('predict');
  renderQuickChips();
  renderHomeHistoryTable();
  renderHistoryList();
}

function switchUserTab(tabKey) {
  userNavTabs.forEach((btn) => {
    btn.classList.toggle('active', btn.dataset.tab === tabKey);
  });

  viewPredict.classList.toggle('hidden', tabKey !== 'predict');
  viewModelResults.classList.toggle('hidden', tabKey !== 'results');
  viewHistory.classList.toggle('hidden', tabKey !== 'history');

  if (tabKey === 'history') {
    renderHistoryList();
  }
}

userNavTabs.forEach((btn) => {
  btn.addEventListener('click', () => switchUserTab(btn.dataset.tab));
});

// Unit switching
function setUnit(newUnit) {
  if (currentUnit === newUnit) return;
  const currentVal = parseFloat(batchWeightValue.value);

  currentUnit = newUnit;
  if (newUnit === 'g') {
    unitToggleG.classList.add('active');
    unitToggleKg.classList.remove('active');
    weightUnitLabel.textContent = 'g';
    batchWeightValue.placeholder = 'e.g. 1000';
    if (!isNaN(currentVal) && currentVal > 0) {
      batchWeightValue.value = (currentVal * 1000).toFixed(0);
    }
  } else {
    unitToggleKg.classList.add('active');
    unitToggleG.classList.remove('active');
    weightUnitLabel.textContent = 'kg';
    batchWeightValue.placeholder = 'e.g. 1';
    if (!isNaN(currentVal) && currentVal > 0) {
      batchWeightValue.value = (currentVal / 1000).toFixed(2);
    }
  }
  renderQuickChips();
}

unitToggleKg.addEventListener('click', () => setUnit('kg'));
unitToggleG.addEventListener('click', () => setUnit('g'));

function renderQuickChips() {
  quickChipsContainer.innerHTML = '';
  const presets =
    currentUnit === 'kg'
      ? [
          { label: '1 kg', val: 1 },
          { label: '5 kg', val: 5 },
          { label: '10 kg', val: 10 },
          { label: '25 kg', val: 25 },
          { label: '50 kg', val: 50 },
        ]
      : [
          { label: '250 g', val: 250 },
          { label: '500 g', val: 500 },
          { label: '1000 g', val: 1000 },
          { label: '2500 g', val: 2500 },
          { label: '5000 g', val: 5000 },
        ];

  presets.forEach((p) => {
    const btn = document.createElement('button');
    btn.type = 'button';
    btn.className = 'flutter-chip';
    btn.textContent = p.label;
    btn.addEventListener('click', () => {
      batchWeightValue.value = p.val;
      executePrediction();
    });
    quickChipsContainer.appendChild(btn);
  });
}

function executePrediction() {
  homeErrorBanner.classList.add('hidden');
  const val = parseFloat(batchWeightValue.value);

  if (isNaN(val) || val <= 0) {
    homeErrorMessage.textContent = 'Please enter a valid weight greater than zero.';
    homeErrorBanner.classList.remove('hidden');
    return;
  }

  const weightG = currentUnit === 'kg' ? val * 1000 : val;
  const res = runCalculationEngine(weightG);

  // Update results view
  fruitSizeTag.textContent = `🏷️ ${res.sizeLabel} • ~${res.count} calamansi`;
  outSlrMl.textContent = `${res.slrTotalMl.toFixed(2)} ml`;
  outSlrL.textContent = `~${(res.slrTotalMl / 1000).toFixed(4)} L`;

  outMlrMl.textContent = `${res.mlrTotalMl.toFixed(2)} ml`;
  outMlrL.textContent = `~${(res.mlrTotalMl / 1000).toFixed(4)} L`;

  outPolyMl.textContent = `${res.polyTotalMl.toFixed(2)} ml`;
  outPolyL.textContent = `~${(res.polyTotalMl / 1000).toFixed(4)} L`;

  predictEmptyState.classList.add('hidden');
  predictionResultsCard.classList.remove('hidden');

  // Record prediction log
  const now = new Date();
  const dateStr = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}-${String(now.getDate()).padStart(2, '0')} ${String(now.getHours()).padStart(2, '0')}:${String(now.getMinutes()).padStart(2, '0')}`;
  const weightStr =
    weightG >= 1000
      ? `${(weightG / 1000).toFixed(2)} kg (${weightG.toFixed(0)}g)`
      : `${weightG.toFixed(0)} g`;

  const logs = getLogs();
  logs.unshift({
    id: `log-${Date.now()}`,
    date: dateStr,
    user: currentUser.username,
    weightG,
    weight: weightStr,
    size: res.sizeLabel,
    slr: `${res.slrTotalMl.toFixed(2)} ml`,
    mlr: `${res.mlrTotalMl.toFixed(2)} ml`,
    poly: `${res.polyTotalMl.toFixed(2)} ml`,
  });
  if (logs.length > 50) logs.pop();
  saveLogs(logs);

  renderHomeHistoryTable();
  renderHistoryList();
}

runAllModelsBtn.addEventListener('click', executePrediction);
batchWeightValue.addEventListener('keydown', (e) => {
  if (e.key === 'Enter') executePrediction();
});

refreshHomeHistoryBtn.addEventListener('click', renderHomeHistoryTable);

function renderHomeHistoryTable() {
  const logs = getLogs();
  const userLogs = logs.filter(
    (l) => currentUser.role === 'admin' || l.user === currentUser.username
  );

  homeHistoryTableBody.innerHTML = '';
  if (userLogs.length === 0) {
    homeHistoryTableBody.innerHTML = `
      <tr>
        <td colspan="6" style="text-align: center; color: var(--text-muted); padding: 24px;">
          No harvest predictions recorded yet.
        </td>
      </tr>
    `;
    return;
  }

  userLogs.slice(0, 10).forEach((l) => {
    const tr = document.createElement('tr');
    tr.innerHTML = `
      <td>${l.date}</td>
      <td><strong>${l.weight}</strong></td>
      <td>${l.size}</td>
      <td>${l.slr}</td>
      <td>${l.mlr}</td>
      <td><strong style="color: var(--primary);">${l.poly}</strong></td>
    `;
    homeHistoryTableBody.appendChild(tr);
  });
}

// History List tab (mirroring history_screen.dart card list)
function renderHistoryList() {
  const logs = getLogs();
  const userLogs = logs.filter(
    (l) => currentUser.role === 'admin' || l.user === currentUser.username
  );

  historyListContainer.innerHTML = '';
  if (userLogs.length === 0) {
    historyListContainer.innerHTML = `
      <div class="empty-placeholder-card">
        <div class="empty-icon-circle">🍋</div>
        <h3 class="empty-title">No predictions yet</h3>
        <p class="empty-desc">Run a prediction to see your yield logs here.</p>
      </div>
    `;
    return;
  }

  userLogs.forEach((l) => {
    const card = document.createElement('div');
    card.className = 'history-card-item featured-history';
    card.innerHTML = `
      <div class="history-item-icon">🍋</div>
      <div class="history-item-content">
        <div class="history-item-title-row">
          <span class="history-algo-name">Polynomial Regression (d=2)</span>
          <span class="history-star-badge">★ Best</span>
        </div>
        <div class="history-item-meta">${l.weight} • ${l.size} • ${l.date}</div>
      </div>
      <div class="history-item-output">
        <div class="history-juice-amount">${l.poly}</div>
        <div class="history-liters-amount">SLR: ${l.slr} | MLR: ${l.mlr}</div>
      </div>
    `;
    historyListContainer.appendChild(card);
  });
}

// ──────────────── ADMIN CONSOLE LOGIC (admin_screen.dart) ────────────────
function showAdminScaffold() {
  loginScreen.classList.add('hidden');
  userScaffold.classList.add('hidden');
  adminScaffold.classList.remove('hidden');

  adminUsername.textContent = currentUser.username;
  switchAdminTab(0);
  renderAdminUsers();
  renderAdminLogs();
}

function switchAdminTab(index) {
  adminNavTabs.forEach((tab, i) => {
    tab.classList.toggle('active', i === index);
  });

  adminTab0.classList.toggle('hidden', index !== 0);
  adminTab1.classList.toggle('hidden', index !== 1);
  adminTab2.classList.toggle('hidden', index !== 2);
}

adminNavTabs.forEach((btn) => {
  btn.addEventListener('click', () => {
    const idx = parseInt(btn.dataset.admintab, 10);
    switchAdminTab(idx);
  });
});

function renderAdminUsers() {
  const users = getUsers();
  const logs = getLogs();

  adminUserCardsContainer.innerHTML = '';
  if (users.length === 0) {
    adminUserCardsContainer.innerHTML = `
      <div style="text-align: center; color: var(--text-muted); padding: 36px;">
        No accounts registered yet.
      </div>
    `;
    return;
  }

  users.forEach((u) => {
    const isSelf = u.username === currentUser.username;
    const isRootAdmin = u.username === 'admin';
    const isAdmin = u.role === 'admin';
    const isSuspended = u.status === 'Suspended';
    const joined = u.joined || '2026-09-01';

    const card = document.createElement('div');
    card.className = 'user-row-card';
    card.innerHTML = `
      <div class="user-row-card-left">
        <div class="user-avatar-box ${isAdmin ? 'admin' : 'user'}">
          ${isAdmin ? '🛡️' : '👨‍🌾'}
        </div>
        <div class="user-meta-lines">
          <div class="user-header-line">
            <span class="user-card-name">${u.username}</span>
            ${isSelf ? '<span class="user-card-self">(You)</span>' : ''}
            <span class="user-badge-pill ${isAdmin ? 'admin' : 'user'}">${isAdmin ? 'ADMIN' : 'USER'}</span>
            <span class="status-badge-pill ${isSuspended ? 'suspended' : 'active'}">${isSuspended ? 'SUSPENDED' : 'ACTIVE'}</span>
          </div>
          <span class="user-card-joined">Joined: ${joined}</span>
        </div>
      </div>
      <div class="user-row-card-actions">
        ${
          !isSelf
            ? `<button type="button" class="user-action-btn ${isSuspended ? 'active-toggle' : ''}" onclick="window.adminToggleStatus('${u.username}')">
                ${isSuspended ? 'Activate' : 'Suspend'}
              </button>
              <button type="button" class="user-action-btn" onclick="window.adminToggleRole('${u.username}')">
                ${isAdmin ? 'Make User' : 'Make Admin'}
              </button>
              <button type="button" class="user-action-btn" onclick="window.adminResetPassword('${u.username}')">
                Reset Password
              </button>`
            : '<span style="color: var(--text-muted); font-size: 11px;">Current Account</span>'
        }
        ${
          !isRootAdmin && !isSelf
            ? `<button type="button" class="user-action-btn delete" onclick="window.adminDeleteUser('${u.username}')">Delete</button>`
            : ''
        }
      </div>
    `;
    adminUserCardsContainer.appendChild(card);
  });
}

window.adminResetPassword = function (uName) {
  const newPass = prompt(`Enter new password for ${uName}:`);
  if (!newPass) return;
  if (newPass.length < 4) {
    alert('Password must be at least 4 characters long.');
    return;
  }
  const users = getUsers();
  const target = users.find((u) => u.username === uName);
  if (target) {
    target.password = newPass;
    saveUsers(users);
    alert(`Password updated for ${uName}!`);
  }
};

window.adminToggleStatus = function (uName) {
  const users = getUsers();
  const target = users.find((u) => u.username === uName);
  if (target) {
    target.status = target.status === 'Suspended' ? 'Active' : 'Suspended';
    saveUsers(users);
    renderAdminUsers();
  }
};

window.adminToggleRole = function (uName) {
  const users = getUsers();
  const target = users.find((u) => u.username === uName);
  if (target) {
    target.role = target.role === 'admin' ? 'user' : 'admin';
    saveUsers(users);
    renderAdminUsers();
  }
};

window.adminDeleteUser = function (uName) {
  if (confirm(`Are you sure you want to delete user "${uName}"?`)) {
    let users = getUsers();
    users = users.filter((u) => u.username !== uName);
    saveUsers(users);
    renderAdminUsers();
  }
};

// Add User Modal
openAddUserModalBtn.addEventListener('click', () => {
  addUserModal.classList.remove('hidden');
  addUserForm.reset();
});

function hideAddUserModal() {
  addUserModal.classList.add('hidden');
}

closeAddUserModal.addEventListener('click', hideAddUserModal);
cancelAddUser.addEventListener('click', hideAddUserModal);

addUserForm.addEventListener('submit', (e) => {
  e.preventDefault();
  const u = document.getElementById('newUsername').value.trim().toLowerCase();
  const p = document.getElementById('newPassword').value.trim();
  const r = document.getElementById('newRole').value;

  if (!u || !p) return;
  if (p.length < 4) {
    alert('Password must be at least 4 characters long.');
    return;
  }

  const users = getUsers();
  if (users.some((x) => x.username.toLowerCase() === u)) {
    alert('User already exists!');
    return;
  }

  users.push({
    username: u,
    password: p,
    role: r,
    status: 'Active',
    joined: new Date().toISOString().split('T')[0],
  });
  saveUsers(users);
  hideAddUserModal();
  renderAdminUsers();
});

// Admin Logs
function renderAdminLogs() {
  const logs = getLogs();
  adminLogsTableBody.innerHTML = '';

  if (logs.length === 0) {
    adminLogsTableBody.innerHTML = `
      <tr>
        <td colspan="7" style="text-align: center; color: var(--text-muted); padding: 24px;">
          No prediction logs recorded yet.
        </td>
      </tr>
    `;
    return;
  }

  logs.forEach((l) => {
    const tr = document.createElement('tr');
    tr.innerHTML = `
      <td>${l.date}</td>
      <td><strong>${l.user}</strong></td>
      <td>${l.weight}</td>
      <td>${l.size}</td>
      <td>${l.slr}</td>
      <td>${l.mlr}</td>
      <td><strong style="color: var(--primary);">${l.poly}</strong></td>
    `;
    adminLogsTableBody.appendChild(tr);
  });
}

exportLogsCsvBtn.addEventListener('click', () => {
  const logs = getLogs();
  const headers = ['Date', 'User', 'Batch Weight', 'Size Category', 'SLR Yield', 'MLR Yield', 'Polynomial Yield'];
  const rows = logs.map((l) => [l.date, l.user, l.weight, l.size, l.slr, l.mlr, l.poly]);

  const csv = [headers.join(','), ...rows.map((r) => r.map((c) => `"${c}"`).join(','))].join('\n');
  const blob = new Blob([csv], { type: 'text/csv' });
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = `calamansi_prediction_logs_${Date.now()}.csv`;
  a.click();
  URL.revokeObjectURL(url);
});

clearAllLogsBtn.addEventListener('click', () => {
  if (confirm('Are you sure you want to clear all prediction audit logs?')) {
    saveLogs([]);
    renderAdminLogs();
    renderHomeHistoryTable();
    renderHistoryList();
  }
});

// Restore saved session if exists
const savedSession = sessionStorage.getItem('active_calamansi_user');
if (savedSession) {
  try {
    const user = JSON.parse(savedSession);
    if (user && user.username) {
      currentUser = user;
      loginScreen.classList.add('hidden');
      if (user.role === 'admin') {
        showAdminScaffold();
      } else {
        showUserScaffold();
      }
    }
  } catch {
    sessionStorage.removeItem('active_calamansi_user');
  }
}
