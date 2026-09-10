// ═══════════════════════════════════════════════════
// CALAMANSI YIELD — Weighing Ticket App Logic
// ═══════════════════════════════════════════════════

const SUPABASE_URL = 'https://ajsrgydvjavxxxqdtned.supabase.co';
const SUPABASE_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImFqc3JneWR2amF2eHh4cWR0bmVkIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODg5NzQwMjYsImV4cCI6MjEwNDU1MDAyNn0.zs_jE0ReBapyMu7Z6KWhoOMNW-ib5dGO5JO3OCmiJXc';

const headers = {
  'Content-Type': 'application/json',
  'apikey': SUPABASE_KEY,
  'Authorization': `Bearer ${SUPABASE_KEY}`,
};

const BEST_MODEL = 'Simple Linear Regression';

const $ = (sel) => document.querySelector(sel);
const authView = $('#authView');
const mainView = $('#mainView');
const authForm = $('#authForm');
const authError = $('#authError');

let user = null;

async function hash(value) {
  const bytes = new TextEncoder().encode(value);
  const buffer = await crypto.subtle.digest('SHA-256', bytes);
  return [...new Uint8Array(buffer)].map(b => b.toString(16).padStart(2, '0')).join('');
}

async function request(path, options = {}) {
  const response = await fetch(`${SUPABASE_URL}/rest/v1/${path}`, {
    ...options,
    headers: { ...headers, ...(options.headers || {}) },
  });
  if (!response.ok) throw new Error('Request failed.');
  return response.status === 204 ? null : response.json();
}

async function login(username, password) {
  const rows = await request(
    `app_users?select=id,username,role&username=eq.${encodeURIComponent(username.trim())}&password=eq.${await hash(password)}&limit=1`
  );
  return rows[0] || null;
}

authForm.addEventListener('submit', async (event) => {
  event.preventDefault();
  authError.textContent = '';
  const button = authForm.querySelector('button[type="submit"]');
  button.disabled = true;
  button.textContent = 'Please wait...';
  try {
    user = await login($('#username').value, $('#password').value);
    if (!user) throw new Error('Incorrect username or password.');
    sessionStorage.setItem('calamansi_user', JSON.stringify(user));
    showMain();
  } catch (error) {
    authError.textContent = error.message;
  } finally {
    button.disabled = false;
    button.textContent = 'Log in';
  }
});

$('#registerButton').addEventListener('click', async () => {
  const username = prompt('Choose a username');
  const password = prompt('Choose a password of at least 4 characters');
  if (!username || !password || password.length < 4) return;
  try {
    await request('app_users', {
      method: 'POST',
      body: JSON.stringify({ username: username.trim(), password: await hash(password), role: 'user' }),
    });
    alert('Account created. You can now log in.');
  } catch (error) {
    authError.textContent = 'That username is already taken.';
  }
});

function showMain() {
  authView.classList.add('hidden');
  mainView.classList.remove('hidden');
  switchTab('predict');
}

$('#logoutButton').addEventListener('click', () => {
  sessionStorage.removeItem('calamansi_user');
  user = null;
  mainView.classList.add('hidden');
  authView.classList.remove('hidden');
});

function switchTab(tab) {
  const predictTab = $('#predictTab');
  const historyTab = $('#historyTab');
  const navPredict = $('#navPredict');
  const navHistory = $('#navHistory');

  if (tab === 'predict') {
    predictTab.classList.remove('hidden');
    historyTab.classList.add('hidden');
    navPredict.classList.add('active-tab');
    navHistory.classList.remove('active-tab');
  } else {
    predictTab.classList.add('hidden');
    historyTab.classList.remove('hidden');
    navPredict.classList.remove('active-tab');
    navHistory.classList.add('active-tab');
    loadHistory();
  }
}

$('#navPredict').addEventListener('click', () => switchTab('predict'));
$('#navHistory').addEventListener('click', () => switchTab('history'));

$('#predictButton').addEventListener('click', async () => {
  const input = $('#weightInput');
  const errorEl = $('#predictionError');
  const button = $('#predictButton');
  const weight = Number(input.value);

  errorEl.textContent = '';
  if (!weight || weight <= 0) {
    errorEl.textContent = 'Enter a weight greater than zero.';
    return;
  }

  button.disabled = true;
  button.textContent = 'Running models...';

  try {
    const response = await fetch(`${SUPABASE_URL}/functions/v1/predict`, {
      method: 'POST',
      headers,
      body: JSON.stringify({ weight_g: weight, user_id: user.id, username: user.username, save: true }),
    });
    const body = await response.json();
    if (!response.ok) throw new Error(body.error || 'Prediction failed.');

    renderResults(body, weight);
  } catch (error) {
    errorEl.textContent = error.message;
  } finally {
    button.disabled = false;
    button.textContent = 'Run all 3 models';
  }
});

function sortedResults(results) {
  const best = results.find(r => r.algorithm === BEST_MODEL);
  const rest = results.filter(r => r.algorithm !== BEST_MODEL)
    .sort((a, b) => b.predicted_juice - a.predicted_juice);
  return best ? [best, ...rest] : results.sort((a, b) => b.predicted_juice - a.predicted_juice);
}

function renderResults(body, weight) {
  const results = body.results || [];
  const sizeLabel = body.size_label || '—';
  const sorted = sortedResults(results);
  const hero = sorted[0];
  const others = sorted.slice(1);

  const resultsEl = $('#results');
  resultsEl.classList.remove('hidden');

  $('#sizeLabel').textContent = `${sizeLabel} batch`;
  $('#weightLabel').textContent = `${weight.toLocaleString()} g`;

  const heroEl = $('#heroResult');
  heroEl.innerHTML = '';
  heroEl.appendChild(buildHero(hero));

  const otherEl = $('#otherResults');
  otherEl.innerHTML = '';
  const label = document.createElement('p');
  label.className = 'other-label';
  label.textContent = 'Other results';
  otherEl.appendChild(label);
  others.forEach(r => otherEl.appendChild(buildOtherRow(r)));

  const ticket = document.querySelector('.results-ticket');
  if (ticket) {
    ticket.style.animation = 'none';
    ticket.offsetHeight;
    ticket.style.animation = '';
  }
}

function buildHero(result) {
  const juice = Number(result.predicted_juice);
  const wrap = document.createElement('div');

  const badge = document.createElement('span');
  badge.className = 'hero-badge';
  badge.textContent = '★ Recommended Estimate';

  const modelName = document.createElement('p');
  modelName.className = 'hero-model-name';
  modelName.textContent = result.algorithm;

  const numberRow = document.createElement('div');
  const number = document.createElement('span');
  number.className = 'hero-number';
  number.textContent = juice.toFixed(2);
  const unit = document.createElement('span');
  unit.className = 'hero-unit';
  unit.textContent = 'ml';
  numberRow.append(number, unit);

  const litersEl = document.createElement('p');
  litersEl.className = 'hero-liters';
  litersEl.textContent = `${(juice / 1000).toFixed(4)} L`;

  const confidence = document.createElement('p');
  confidence.className = 'hero-confidence';
  confidence.textContent = 'Recommended model — highest historical accuracy';

  wrap.append(badge, modelName, numberRow, litersEl, confidence);
  return wrap;
}

function buildOtherRow(result) {
  const juice = Number(result.predicted_juice);
  const row = document.createElement('div');
  row.className = 'other-row';

  const left = document.createElement('div');
  const name = document.createElement('p');
  name.className = 'other-name';
  name.textContent = result.algorithm;
  const liters = document.createElement('p');
  liters.className = 'other-liters';
  liters.textContent = `${(juice / 1000).toFixed(4)} L`;
  left.append(name, liters);

  const right = document.createElement('div');
  right.style.textAlign = 'right';
  const juiceEl = document.createElement('span');
  juiceEl.className = 'other-juice';
  juiceEl.textContent = `${juice.toFixed(2)} ml`;
  right.appendChild(juiceEl);

  row.append(left, right);
  return row;
}

async function loadHistory() {
  const listEl = $('#historyList');
  listEl.innerHTML = '<p class="muted">Loading...</p>';

  try {
    const rows = await request(
      `predictions?select=id,algorithm,predicted_juice,weight_g,created_at&user_id=eq.${user.id}&order=created_at.desc&limit=200`
    );

    if (!rows || rows.length === 0) {
      listEl.innerHTML = '<p class="history-empty">No predictions yet. Run your first estimate on the Predict tab.</p>';
      return;
    }

    renderHistory(rows);
  } catch (error) {
    listEl.innerHTML = '<p class="history-empty">Could not load history. Try again.</p>';
  }
}

function renderHistory(rows) {
  const listEl = $('#historyList');
  listEl.innerHTML = '';

  const groups = {};
  rows.forEach(row => {
    const day = (row.created_at || '').split('T')[0];
    if (!groups[day]) groups[day] = [];
    groups[day].push(row);
  });

  const sortedDays = Object.keys(groups).sort((a, b) => b.localeCompare(a));

  sortedDays.forEach(day => {
    const group = document.createElement('div');
    group.className = 'history-day-group';

    const header = document.createElement('div');
    header.className = 'history-day-header';
    header.textContent = formatDay(day);
    group.appendChild(header);

    groups[day].forEach(row => {
      const juice = Number(row.predicted_juice);
      const item = document.createElement('div');
      item.className = 'history-row';

      const left = document.createElement('div');
      left.className = 'history-row-left';
      const algo = document.createElement('span');
      algo.className = 'history-algo';
      algo.textContent = row.algorithm;
      const weight = document.createElement('span');
      weight.className = 'history-weight';
      weight.textContent = `${Number(row.weight_g).toLocaleString()} g`;
      const time = document.createElement('span');
      time.className = 'history-time';
      time.textContent = formatTime(row.created_at);
      left.append(algo, weight, time);

      const right = document.createElement('div');
      right.style.textAlign = 'right';
      const juiceEl = document.createElement('div');
      juiceEl.className = 'history-juice';
      juiceEl.textContent = `${juice.toFixed(2)} ml`;
      const litersEl = document.createElement('div');
      litersEl.className = 'history-juice-l';
      litersEl.textContent = `${(juice / 1000).toFixed(4)} L`;
      right.append(juiceEl, litersEl);

      item.append(left, right);
      group.appendChild(item);
    });

    listEl.appendChild(group);
  });
}

function formatDay(dateStr) {
  if (!dateStr) return 'Unknown date';
  const d = new Date(dateStr + 'T00:00:00');
  return d.toLocaleDateString('en-US', { weekday: 'short', month: 'short', day: 'numeric' });
}

function formatTime(isoStr) {
  if (!isoStr) return '';
  const d = new Date(isoStr);
  return d.toLocaleTimeString('en-US', { hour: 'numeric', minute: '2-digit' });
}

try {
  user = JSON.parse(sessionStorage.getItem('calamansi_user'));
  if (user) showMain();
} catch (_) {
  sessionStorage.removeItem('calamansi_user');
}
