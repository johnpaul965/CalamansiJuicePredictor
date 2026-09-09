import { createClient } from "npm:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, POST, PUT, DELETE, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, Authorization, X-Client-Info, Apikey",
};

interface DataRow {
  weight: number;
  size: number;
  juice: number;
}

// ── Linear algebra helpers (least-squares closed form: beta = (X^T X)^-1 X^T y) ──

function transpose(m: number[][]): number[][] {
  return m[0].map((_, i) => m.map((row) => row[i]));
}

function multiply(a: number[][], b: number[][]): number[][] {
  const rows = a.length;
  const cols = b[0].length;
  const inner = b.length;
  const result: number[][] = Array.from({ length: rows }, () => Array(cols).fill(0));
  for (let i = 0; i < rows; i++) {
    for (let j = 0; j < cols; j++) {
      let sum = 0;
      for (let k = 0; k < inner; k++) {
        sum += a[i][k] * b[k][j];
      }
      result[i][j] = sum;
    }
  }
  return result;
}

function multiplyVec(a: number[][], v: number[]): number[] {
  return a.map((row) => row.reduce((sum, val, i) => sum + val * v[i], 0));
}

// Gaussian elimination with partial pivoting for matrix inversion
function invert(matrix: number[][]): number[][] {
  const n = matrix.length;
  const augmented: number[][] = matrix.map((row, i) => [
    ...row,
    ...Array.from({ length: n }, (_, j) => (i === j ? 1 : 0)),
  ]);

  for (let col = 0; col < n; col++) {
    // Find pivot
    let maxRow = col;
    for (let row = col + 1; row < n; row++) {
      if (Math.abs(augmented[row][col]) > Math.abs(augmented[maxRow][col])) {
        maxRow = row;
      }
    }
    [augmented[col], augmented[maxRow]] = [augmented[maxRow], augmented[col]];

    const pivot = augmented[col][col];
    if (Math.abs(pivot) < 1e-12) {
      throw new Error("Matrix is singular and cannot be inverted.");
    }

    for (let j = 0; j < 2 * n; j++) {
      augmented[col][j] /= pivot;
    }

    for (let row = 0; row < n; row++) {
      if (row === col) continue;
      const factor = augmented[row][col];
      for (let j = 0; j < 2 * n; j++) {
        augmented[row][j] -= factor * augmented[col][j];
      }
    }
  }

  return augmented.map((row) => row.slice(n));
}

// Train ordinary least squares: returns coefficients (excluding intercept) + intercept
function trainOLS(X: number[][], y: number[]): { coefs: number[]; intercept: number } {
  const n = X.length;
  const k = X[0].length;

  // Add intercept column (all 1s) to X
  const XWithIntercept = X.map((row) => [1, ...row]);

  // X^T
  const Xt = transpose(XWithIntercept);

  // X^T * X
  const XtX = multiply(Xt, XWithIntercept);

  // (X^T * X)^-1
  const XtXInv = invert(XtX);

  // X^T * y
  const Xty = multiplyVec(Xt, y);

  // beta = (X^T X)^-1 * X^T y
  const beta = multiplyVec(XtXInv, Xty);

  return {
    intercept: beta[0],
    coefs: beta.slice(1),
  };
}

// Predict with OLS coefficients
function predictOLS(
  features: number[],
  coefs: number[],
  intercept: number
): number {
  let result = intercept;
  for (let i = 0; i < features.length; i++) {
    result += coefs[i] * features[i];
  }
  return result;
}

// ── Metrics ──

function meanAbsoluteError(actual: number[], predicted: number[]): number {
  const n = actual.length;
  let sum = 0;
  for (let i = 0; i < n; i++) {
    sum += Math.abs(actual[i] - predicted[i]);
  }
  return sum / n;
}

function r2Score(actual: number[], predicted: number[]): number {
  const mean = actual.reduce((a, b) => a + b, 0) / actual.length;
  let ssRes = 0;
  let ssTot = 0;
  for (let i = 0; i < actual.length; i++) {
    ssRes += Math.pow(actual[i] - predicted[i], 2);
    ssTot += Math.pow(actual[i] - mean, 2);
  }
  return ssTot === 0 ? 0 : 1 - ssRes / ssTot;
}

// ── Train/test split (shuffled, reproducible with simple LCG) ──

function trainTestSplit<T>(arr: T[], testRatio: number, seed: number): [T[], T[]] {
  // Fisher-Yates shuffle with seeded LCG
  const shuffled = [...arr];
  let s = seed;
  const rand = () => {
    s = (s * 1103515245 + 12345) & 0x7fffffff;
    return s / 0x7fffffff;
  };
  for (let i = shuffled.length - 1; i > 0; i--) {
    const j = Math.floor(rand() * (i + 1));
    [shuffled[i], shuffled[j]] = [shuffled[j], shuffled[i]];
  }
  const testSize = Math.round(shuffled.length * testRatio);
  return [shuffled.slice(testSize), shuffled.slice(0, testSize)];
}

// ── Main ──

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 200, headers: corsHeaders });
  }

  try {
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
    );

    // Fetch all dataset rows
    const { data: rows, error: fetchError } = await supabase
      .from("dataset_rows")
      .select("weight, size, juice")
      .order("created_at", { ascending: true });

    if (fetchError) throw new Error(fetchError.message);
    if (!rows || rows.length < 10) {
      return new Response(
        JSON.stringify({ error: "Need at least 10 data rows to train." }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const data: DataRow[] = rows as DataRow[];

    // Train/test split (80/20, seed=42 to match Python random_state=42)
    const [trainData, testData] = trainTestSplit(data, 0.2, 42);

    // ── Model 1: Simple Linear Regression (Weight only) ──
    const XTrainSimple = trainData.map((r) => [r.weight]);
    const yTrain = trainData.map((r) => r.juice);
    const simpleModel = trainOLS(XTrainSimple, yTrain);

    const XTestSimple = testData.map((r) => [r.weight]);
    const yTest = testData.map((r) => r.juice);
    const simplePreds = XTestSimple.map((f) =>
      Math.max(predictOLS(f, simpleModel.coefs, simpleModel.intercept), 0)
    );

    // ── Model 2: Multiple Linear Regression (Weight + Size) ──
    const XTrainMulti = trainData.map((r) => [r.weight, r.size]);
    const multiModel = trainOLS(XTrainMulti, yTrain);

    const XTestMulti = testData.map((r) => [r.weight, r.size]);
    const multiPreds = XTestMulti.map((f) =>
      Math.max(predictOLS(f, multiModel.coefs, multiModel.intercept), 0)
    );

    // ── Model 3: Polynomial Regression (degree=2) ──
    // Features: Weight, Size, Weight^2, Weight*Size, Size^2
    const toPolyFeatures = (w: number, s: number) => [w, s, w * w, w * s, s * s];
    const XTrainPoly = trainData.map((r) => toPolyFeatures(r.weight, r.size));
    const polyModel = trainOLS(XTrainPoly, yTrain);

    const XTestPoly = testData.map((r) => toPolyFeatures(r.weight, r.size));
    const polyPreds = XTestPoly.map((f) =>
      Math.max(predictOLS(f, polyModel.coefs, polyModel.intercept), 0)
    );

    // ── Compute metrics ──
    const metrics: Record<string, { mae: number; r2: number }> = {
      "Simple Linear Regression": {
        mae: meanAbsoluteError(yTest, simplePreds),
        r2: r2Score(yTest, simplePreds),
      },
      "Multiple Linear Regression": {
        mae: meanAbsoluteError(yTest, multiPreds),
        r2: r2Score(yTest, multiPreds),
      },
      "Polynomial Regression (d=2)": {
        mae: meanAbsoluteError(yTest, polyPreds),
        r2: r2Score(yTest, polyPreds),
      },
    };

    // Determine best model (highest R²)
    let bestModel = "Simple Linear Regression";
    let bestR2 = -Infinity;
    for (const [name, m] of Object.entries(metrics)) {
      if (m.r2 > bestR2) {
        bestR2 = m.r2;
        bestModel = name;
      }
    }

    // Size distribution
    const sizeDist: Record<string, number> = {
      Small: data.filter((r) => r.size === 1).length,
      Medium: data.filter((r) => r.size === 2).length,
      Large: data.filter((r) => r.size === 3).length,
    };

    // Round coefficients to match Python precision
    const round4 = (v: number) => Math.round(v * 10000) / 10000;
    const round6 = (v: number) => Math.round(v * 1000000) / 1000000;

    const coefficients = {
      simple: {
        weight: round4(simpleModel.coefs[0]),
        intercept: round4(simpleModel.intercept),
      },
      multiple: {
        weight: round4(multiModel.coefs[0]),
        size: round4(multiModel.coefs[1]),
        intercept: round4(multiModel.intercept),
      },
      poly: {
        feat_names: ["Weight", "Size", "Weight^2", "Weight Size", "Size^2"],
        coefs: polyModel.coefs.map(round6),
        intercept: round4(polyModel.intercept),
      },
    };

    const roundedMetrics: Record<string, { mae: number; r2: number }> = {};
    for (const [name, m] of Object.entries(metrics)) {
      roundedMetrics[name] = {
        mae: Math.round(m.mae * 10000) / 10000,
        r2: Math.round(m.r2 * 10000) / 10000,
      };
    }

    // ── Save to model_state (upsert singleton row) ──
    const stateRow = {
      id: 1,
      coefficients,
      metrics: roundedMetrics,
      best_model: bestModel,
      dataset_rows: data.length,
      training_samples: trainData.length,
      test_samples: testData.length,
      size_dist: sizeDist,
      updated_at: new Date().toISOString(),
    };

    const { error: upsertError } = await supabase
      .from("model_state")
      .upsert(stateRow, { onConflict: "id" });

    if (upsertError) throw new Error(upsertError.message);

    return new Response(
      JSON.stringify({
        success: true,
        message: `Retrained on ${data.length} rows.`,
        best_model: bestModel,
        metrics: roundedMetrics,
        dataset_rows: data.length,
        training_samples: trainData.length,
        test_samples: testData.length,
        size_dist: sizeDist,
        coefficients,
      }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (err) {
    return new Response(
      JSON.stringify({ error: err.message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
