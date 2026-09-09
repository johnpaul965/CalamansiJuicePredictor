import { readFile } from 'node:fs/promises';
import { resolve } from 'node:path';

const BATCH_SIZE = 500;

function loadEnv(text) {
  const values = {};
  for (const line of text.split(/\r?\n/)) {
    const match = line.match(/^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*?)\s*$/);
    if (!match || match[1].startsWith('#')) continue;
    values[match[1]] = match[2].replace(/^['"]|['"]$/g, '');
  }
  return values;
}

function parseCsv(text) {
  const rows = text
    .split(/\r?\n/)
    .map((line) => line.trim())
    .filter(Boolean)
    .map((line, index) => ({
      lineNumber: index + 1,
      fields: line.split(',').map((field) => field.trim()),
    }));

  if (rows.length === 0) throw new Error('The CSV file is empty.');

  const first = rows[0].fields.map((field) => field.toLowerCase());
  const start = first[0] === 'weight' && first[1] === 'size' && first[2] === 'juice' ? 1 : 0;
  const dataRows = rows.slice(start);
  const parsed = [];

  for (const row of dataRows) {
    if (row.fields.length !== 3) {
      throw new Error(`Line ${row.lineNumber} must contain Weight, Size, and Juice.`);
    }

    const [weightText, sizeText, juiceText] = row.fields;
    const weight = Number(weightText);
    const size = Number(sizeText);
    const juice = Number(juiceText);

    if (!Number.isFinite(weight) || weight <= 0) {
      throw new Error(`Line ${row.lineNumber} has an invalid weight.`);
    }
    if (!Number.isInteger(size) || size < 1 || size > 3) {
      throw new Error(`Line ${row.lineNumber} size must be 1, 2, or 3.`);
    }
    if (!Number.isFinite(juice) || juice < 0) {
      throw new Error(`Line ${row.lineNumber} has an invalid juice value.`);
    }

    parsed.push({ weight, size, juice });
  }

  if (parsed.length === 0) throw new Error('The CSV file contains no data rows.');
  return parsed;
}

async function requestJson(url, options) {
  const response = await fetch(url, options);
  const text = await response.text();
  let body = {};
  try {
    body = text ? JSON.parse(text) : {};
  } catch {
    body = { error: text || 'The server returned an unreadable response.' };
  }
  if (!response.ok) {
    throw new Error(body.error || `Request failed with status ${response.status}.`);
  }
  return body;
}

async function main() {
  const csvPath = process.argv[2];
  if (!csvPath) throw new Error('Provide a CSV file path, for example: node scripts/import_dataset.mjs new-data.csv');

  const localEnv = loadEnv(await readFile(resolve('.env'), 'utf8').catch(() => ''));
  const supabaseUrl = process.env.SUPABASE_URL || process.env.VITE_SUPABASE_URL || localEnv.SUPABASE_URL || localEnv.VITE_SUPABASE_URL;
  const anonKey = process.env.SUPABASE_ANON_KEY || process.env.VITE_SUPABASE_ANON_KEY || localEnv.SUPABASE_ANON_KEY || localEnv.VITE_SUPABASE_ANON_KEY;

  if (!supabaseUrl || !anonKey) {
    throw new Error('Supabase connection settings were not found.');
  }

  const rows = parseCsv(await readFile(resolve(csvPath), 'utf8'));
  const headers = {
    apikey: anonKey,
    Authorization: `Bearer ${anonKey}`,
    'Content-Type': 'application/json',
    Prefer: 'return=minimal',
  };

  console.log(`Validated ${rows.length} rows. Uploading them in batches...`);
  for (let start = 0; start < rows.length; start += BATCH_SIZE) {
    const batch = rows.slice(start, start + BATCH_SIZE);
    await requestJson(`${supabaseUrl}/rest/v1/dataset_rows`, {
      method: 'POST',
      headers,
      body: JSON.stringify(batch),
    });
    console.log(`Uploaded ${Math.min(start + BATCH_SIZE, rows.length)} of ${rows.length}.`);
  }

  console.log('Starting retraining...');
  const result = await requestJson(`${supabaseUrl}/functions/v1/retrain`, {
    method: 'POST',
    headers: {
      apikey: anonKey,
      Authorization: `Bearer ${anonKey}`,
      'Content-Type': 'application/json',
    },
    body: '{}',
  });

  console.log(result.message || 'Retraining completed.');
  console.log(`Total dataset rows: ${result.dataset_rows}`);
  console.log(`Best model: ${result.best_model}`);
}

main().catch((error) => {
  console.error(`Import stopped: ${error.message}`);
  process.exitCode = 1;
});
