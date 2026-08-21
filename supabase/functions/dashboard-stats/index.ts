// Fonction serveur pour le mini tableau de bord (docs/dashboard/).
//
// Tourne côté Supabase, jamais dans le navigateur : c'est elle qui détient la clé
// service_role (injectée automatiquement par la plateforme, jamais écrite ici), la
// seule capable de lire au travers des politiques RLS. La page web, elle, ne connaît
// qu'un secret partagé (DASHBOARD_TOKEN) qui n'ouvre l'accès qu'à des chiffres agrégés
// — jamais une ligne brute, jamais un identifiant de compte individuel.
//
// Double vérification à l'entrée : l'en-tête Authorization (la clé publishable, déjà
// publique dans l'app) satisfait la passerelle Supabase elle-même ; l'en-tête
// x-dashboard-token est le vrai contrôle d'accès, comparé au secret ci-dessous.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const dashboardToken = Deno.env.get("DASHBOARD_TOKEN")!;

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, x-dashboard-token",
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  const token = req.headers.get("x-dashboard-token");
  if (token !== dashboardToken) {
    return new Response(JSON.stringify({ error: "unauthorized" }), {
      status: 401,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  const supabase = createClient(supabaseUrl, serviceRoleKey);
  const now = new Date();
  const dayMs = 24 * 60 * 60 * 1000;

  // Une seule lecture pour les 14 derniers jours : elle alimente en ce moment, dans
  // l'heure, aujourd'hui, cette semaine et la courbe quotidienne, sans multiplier les
  // aller-retours pour des fenêtres qui se recouvrent toutes.
  const since14d = new Date(now.getTime() - 14 * dayMs).toISOString();
  const { data: recentEvents } = await supabase
    .from("events")
    .select("user_id, name, created_at, is_premium")
    .gte("created_at", since14d);

  const rows = recentEvents ?? [];

  const distinctUsersSince = (msAgo: number) => {
    const cutoff = now.getTime() - msAgo;
    const set = new Set<string>();
    for (const row of rows) {
      if (new Date(row.created_at).getTime() >= cutoff) set.add(row.user_id);
    }
    return set.size;
  };

  const countEventsSince = (name: string, msAgo: number) => {
    const cutoff = now.getTime() - msAgo;
    return rows.filter((r) => r.name === name && new Date(r.created_at).getTime() >= cutoff).length;
  };

  // Courbe des 14 jours : un groupe de comptes distincts par jour calendaire.
  const dailyBuckets = new Map<string, Set<string>>();
  for (let i = 13; i >= 0; i--) {
    const day = new Date(now.getTime() - i * dayMs).toISOString().slice(0, 10);
    dailyBuckets.set(day, new Set());
  }
  for (const row of rows) {
    const day = row.created_at.slice(0, 10);
    dailyBuckets.get(day)?.add(row.user_id);
  }
  const daily = Array.from(dailyBuckets.entries()).map(([date, set]) => ({
    date,
    active: set.size,
  }));

  // Premium actif : chaque évènement porte l'état d'abonnement du moment où il a été
  // émis (voir Analytics.swift). Le compte distinct sur 7 jours reflète aussi bien un
  // abonnement StoreKit qu'un accès offert, sans dépendre d'une seule table.
  const premiumActive7d = new Set(
    rows.filter((r) => r.is_premium && new Date(r.created_at).getTime() >= now.getTime() - 7 * dayMs)
      .map((r) => r.user_id)
  ).size;

  // Séries : lue directement, hors RLS grâce au rôle de service.
  const { data: streaks } = await supabase.from("user_state").select("streak_count");
  const streakValues = (streaks ?? []).map((s) => s.streak_count).filter((n) => n > 0);
  const avgStreak = streakValues.length
    ? streakValues.reduce((a, b) => a + b, 0) / streakValues.length
    : 0;

  // Notifications : ouvertures réelles vs envoyées, sur 7 jours.
  const notificationsOpened7d = countEventsSince("notification_opened", 7 * dayMs);
  const appOpenedViaNotif7d = rows.filter(
    (r) => r.name === "app_opened" && new Date(r.created_at).getTime() >= now.getTime() - 7 * dayMs
  ).length;

  // Entonnoir du paywall, sur 30 jours : requête séparée, fenêtre plus large que le
  // lot principal.
  const since30d = new Date(now.getTime() - 30 * dayMs).toISOString();
  const { data: paywallEvents } = await supabase
    .from("events")
    .select("name")
    .in("name", ["paywall_shown", "purchase_started", "purchase_completed"])
    .gte("created_at", since30d);
  const paywallCount = (name: string) => (paywallEvents ?? []).filter((r) => r.name === name).length;

  // Auteurs les plus partagés, sur 30 jours.
  const { data: shareEvents } = await supabase
    .from("events")
    .select("properties")
    .eq("name", "quote_shared")
    .gte("created_at", since30d);
  const authorCounts = new Map<string, number>();
  for (const row of shareEvents ?? []) {
    const author = (row.properties as Record<string, unknown>)?.author as string | undefined;
    if (!author) continue;
    authorCounts.set(author, (authorCounts.get(author) ?? 0) + 1);
  }
  const topAuthors = Array.from(authorCounts.entries())
    .sort((a, b) => b[1] - a[1])
    .slice(0, 5)
    .map(([author, shares]) => ({ author, shares }));

  // Inscriptions : l'API d'administration, seule façon d'atteindre auth.users depuis
  // un client Supabase — ce schéma n'est pas exposé via les tables ordinaires.
  const { data: usersPage } = await supabase.auth.admin.listUsers({ page: 1, perPage: 1000 });
  const allUsers = usersPage?.users ?? [];
  const signupsThisWeek = allUsers.filter(
    (u) => new Date(u.created_at).getTime() >= now.getTime() - 7 * dayMs
  ).length;

  const body = {
    updated_at: now.toISOString(),
    active_now: distinctUsersSince(5 * 60 * 1000),
    active_last_hour: distinctUsersSince(60 * 60 * 1000),
    today: {
      active: distinctUsersSince(dayMs),
      opens: countEventsSince("app_opened", dayMs),
    },
    week: {
      active: distinctUsersSince(7 * dayMs),
      opens: countEventsSince("app_opened", 7 * dayMs),
      signups: signupsThisWeek,
    },
    total_accounts: allUsers.length,
    avg_streak: Math.round(avgStreak * 10) / 10,
    premium_active_7d: premiumActive7d,
    daily,
    notifications_7d: {
      opened: notificationsOpened7d,
      opens_attributed: appOpenedViaNotif7d,
    },
    paywall_30d: {
      shown: paywallCount("paywall_shown"),
      started: paywallCount("purchase_started"),
      completed: paywallCount("purchase_completed"),
    },
    top_authors_30d: topAuthors,
  };

  return new Response(JSON.stringify(body), {
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
});
