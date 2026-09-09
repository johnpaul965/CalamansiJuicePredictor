import { createClient } from "npm:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, POST, PUT, DELETE, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, Authorization, X-Client-Info, Apikey",
};

interface PredictionResult {
  algorithm: string;
  predicted_juice: number;
}

interface RequestBody {
  weight_g: number;
  user_id: string;
  username: string;
  save: boolean;
}

// Fallback coefficients (from the last Python training run)
const FALLBACK_COEFFICIENTS = {
  simple: { weight: 0.4022, intercept: 0.0917 },
  multiple: { weight: 0.3058, size: 0.4745, intercept: 0.3224 },
  poly: {
    coefs: [-1.381236, 7.428875, 0.183833, -1.416874, 2.611992],
    intercept: 3.5026,
  },
};

function getSizeFromWeight(weightG: number): number {
  if (weightG <= 10) return 1;
  if (weightG <= 14) return 2;
  return 3;
}

function predictSimple(weightG: number, coef: { weight: number; intercept: number }): number {
  return Math.max(coef.weight * weightG + coef.intercept, 0);
}

function predictMultiple(
  weightG: number,
  size: number,
  coef: { weight: number; size: number; intercept: number }
): number {
  return Math.max(coef.weight * weightG + coef.size * size + coef.intercept, 0);
}

function predictPolynomial(
  weightG: number,
  size: number,
  coef: { coefs: number[]; intercept: number }
): number {
  const features = [weightG, size, weightG * weightG, weightG * size, size * size];
  let result = coef.intercept;
  for (let i = 0; i < features.length; i++) {
    result += coef.coefs[i] * features[i];
  }
  return Math.max(result, 0);
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 200, headers: corsHeaders });
  }

  try {
    const { weight_g, user_id, username, save } = (await req.json()) as RequestBody;

    if (!weight_g || weight_g <= 0) {
      return new Response(
        JSON.stringify({ error: "Weight must be greater than 0." }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Load live model coefficients from model_state (if retrained)
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
    );

    let coeffs = FALLBACK_COEFFICIENTS;

    const { data: state } = await supabase
      .from("model_state")
      .select("coefficients")
      .eq("id", 1)
      .maybeSingle();

    if (state?.coefficients) {
      coeffs = state.coefficients as typeof FALLBACK_COEFFICIENTS;
    }

    const size = getSizeFromWeight(weight_g);

    const results: PredictionResult[] = [
      {
        algorithm: "Simple Linear Regression",
        predicted_juice: predictSimple(weight_g, coeffs.simple),
      },
      {
        algorithm: "Multiple Linear Regression",
        predicted_juice: predictMultiple(weight_g, size, coeffs.multiple),
      },
      {
        algorithm: "Polynomial Regression (d=2)",
        predicted_juice: predictPolynomial(weight_g, size, coeffs.poly),
      },
    ];

    if (save && user_id && username) {
      for (const result of results) {
        await supabase.from("predictions").insert({
          user_id,
          username,
          weight_g,
          algorithm: result.algorithm,
          predicted_juice: Math.round(result.predicted_juice * 10000) / 10000,
        });
      }
    }

    return new Response(
      JSON.stringify({
        results,
        weight_g,
        assigned_size: size,
        size_label: size === 1 ? "Small" : size === 2 ? "Medium" : "Large",
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
