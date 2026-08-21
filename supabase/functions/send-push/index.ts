// Envoi manuel de notifications push, à tout le monde ou à une personne.
//
// Protégée par le même secret que le tableau de bord (DASHBOARD_TOKEN) : sans lui, la
// fonction refuse. C'est essentiel — une fonction d'envoi ouverte permettrait à
// n'importe qui d'écrire à tous tes utilisateurs.
//
// Trois secrets à configurer côté Supabase, en plus de DASHBOARD_TOKEN :
//   APNS_KEY_ID    — l'identifiant de la clé (10 caractères), donné par Apple
//   APNS_TEAM_ID   — 7L2K39BW92
//   APNS_KEY_P8    — le contenu du fichier .p8, en-têtes BEGIN/END compris
//
// Corps attendu :
//   { "title": "...", "body": "...", "user_id": "..." | null, "quote_id": "..." | null }
//   user_id absent ou nul => envoi à tout le monde.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const dashboardToken = Deno.env.get("DASHBOARD_TOKEN")!;
const apnsKeyId = Deno.env.get("APNS_KEY_ID")!;
const apnsTeamId = Deno.env.get("APNS_TEAM_ID")!;
const apnsKeyP8 = Deno.env.get("APNS_KEY_P8")!;

const BUNDLE_ID = "com.instantbusiness.app";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, x-dashboard-token",
};

// --- Signature du jeton d'authentification Apple (JWT ES256) ---------------------

function base64UrlEncode(bytes: Uint8Array): string {
  return btoa(String.fromCharCode(...bytes))
    .replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

async function importApnsKey(): Promise<CryptoKey> {
  // Le .p8 est au format PEM ; on retire l'armure et les retours à la ligne pour
  // récupérer le DER que Web Crypto attend.
  const pem = apnsKeyP8
    .replace(/-----BEGIN PRIVATE KEY-----/, "")
    .replace(/-----END PRIVATE KEY-----/, "")
    .replace(/\s+/g, "");
  const der = Uint8Array.from(atob(pem), (c) => c.charCodeAt(0));
  return crypto.subtle.importKey(
    "pkcs8",
    der,
    { name: "ECDSA", namedCurve: "P-256" },
    false,
    ["sign"],
  );
}

async function makeApnsJwt(): Promise<string> {
  const header = { alg: "ES256", kid: apnsKeyId };
  const payload = { iss: apnsTeamId, iat: Math.floor(Date.now() / 1000) };
  const encoder = new TextEncoder();
  const unsigned =
    base64UrlEncode(encoder.encode(JSON.stringify(header))) + "." +
    base64UrlEncode(encoder.encode(JSON.stringify(payload)));

  const key = await importApnsKey();
  const signature = await crypto.subtle.sign(
    { name: "ECDSA", hash: "SHA-256" },
    key,
    encoder.encode(unsigned),
  );
  return unsigned + "." + base64UrlEncode(new Uint8Array(signature));
}

// --- Envoi ------------------------------------------------------------------------

async function sendToToken(
  token: string,
  environment: string,
  jwt: string,
  payload: Record<string, unknown>,
): Promise<{ ok: boolean; status: number; reason?: string }> {
  // Apple sert deux réseaux distincts et rejette un jeton présenté au mauvais : un
  // build TestFlight ou Xcode parle au bac à sable, l'App Store à la production.
  const host = environment === "sandbox"
    ? "api.sandbox.push.apple.com"
    : "api.push.apple.com";

  const res = await fetch(`https://${host}/3/device/${token}`, {
    method: "POST",
    headers: {
      "authorization": `bearer ${jwt}`,
      "apns-topic": BUNDLE_ID,
      "apns-push-type": "alert",
      "apns-priority": "10",
      "content-type": "application/json",
    },
    body: JSON.stringify(payload),
  });

  if (res.ok) return { ok: true, status: res.status };
  const text = await res.text();
  let reason = text;
  try { reason = JSON.parse(text).reason ?? text; } catch { /* corps non JSON */ }
  return { ok: false, status: res.status, reason };
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.headers.get("x-dashboard-token") !== dashboardToken) {
    return new Response(JSON.stringify({ error: "unauthorized" }), {
      status: 401,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  let input: { title?: string; body?: string; user_id?: string | null; quote_id?: string | null };
  try {
    input = await req.json();
  } catch {
    return new Response(JSON.stringify({ error: "corps JSON invalide" }), {
      status: 400,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  const title = (input.title ?? "").trim();
  const body = (input.body ?? "").trim();
  if (!title || !body) {
    return new Response(JSON.stringify({ error: "title et body sont obligatoires" }), {
      status: 400,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  const supabase = createClient(supabaseUrl, serviceRoleKey);

  let query = supabase.from("device_tokens").select("token, environment");
  if (input.user_id) query = query.eq("user_id", input.user_id);
  const { data: tokens, error } = await query;

  if (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
  if (!tokens || tokens.length === 0) {
    return new Response(JSON.stringify({ sent: 0, failed: 0, note: "aucun appareil enregistré" }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  const jwt = await makeApnsJwt();

  // Même clé de charge utile que les notifications locales : appuyer sur un push
  // portant une citation l'ouvre donc dans l'app exactement comme les autres.
  const payload: Record<string, unknown> = {
    aps: { alert: { title, body }, sound: "default" },
  };
  if (input.quote_id) payload.quoteID = input.quote_id;

  const results = await Promise.all(
    tokens.map((t) => sendToToken(t.token, t.environment, jwt, payload)),
  );

  // Apple répond 410 pour un appareil qui a désinstallé l'app : on nettoie, sinon la
  // table se remplit indéfiniment de destinataires morts.
  const goneTokens = tokens
    .filter((_, i) => results[i].status === 410)
    .map((t) => t.token);
  if (goneTokens.length > 0) {
    await supabase.from("device_tokens").delete().in("token", goneTokens);
  }

  const failures = results.filter((r) => !r.ok);
  return new Response(JSON.stringify({
    sent: results.filter((r) => r.ok).length,
    failed: failures.length,
    removed_stale: goneTokens.length,
    errors: failures.slice(0, 5).map((f) => `${f.status} ${f.reason ?? ""}`.trim()),
  }), {
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
});
