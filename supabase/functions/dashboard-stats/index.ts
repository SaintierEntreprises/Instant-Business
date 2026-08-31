// Fonction serveur pour le tableau de bord (docs/dashboard/).
//
// Tourne côté Supabase, jamais dans le navigateur : c'est elle qui détient la clé
// service_role (injectée par la plateforme, jamais écrite ici), la seule capable de lire
// au travers des politiques RLS. La page ne connaît qu'un secret partagé
// (DASHBOARD_TOKEN) qui n'ouvre l'accès qu'à des chiffres agrégés.
//
// Paramètre optionnel `?days=7|30|90` pour la fenêtre d'analyse (défaut 30).

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const dashboardToken = Deno.env.get("DASHBOARD_TOKEN")!;

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, x-dashboard-token",
};

const DAY_MS = 24 * 60 * 60 * 1000;

type EventRow = {
  user_id: string;
  name: string;
  created_at: string;
  is_premium: boolean | null;
  app_version: string | null;
  properties: Record<string, unknown> | null;
};

/** Compte d'occurrences trié, ramené aux `limit` premiers. */
function topOf(counts: Map<string, number>, limit: number): { key: string; count: number }[] {
  return Array.from(counts.entries())
    .sort((a, b) => b[1] - a[1])
    .slice(0, limit)
    .map(([key, count]) => ({ key, count }));
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  if (req.headers.get("x-dashboard-token") !== dashboardToken) {
    return new Response(JSON.stringify({ error: "unauthorized" }), {
      status: 401,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  const url = new URL(req.url);
  const requestedDays = Number(url.searchParams.get("days") ?? 30);
  const windowDays = [7, 30, 90].includes(requestedDays) ? requestedDays : 30;

  const supabase = createClient(supabaseUrl, serviceRoleKey);
  const now = new Date();

  // Une seule lecture couvrant la plus large fenêtre demandée. Toutes les mesures en
  // découlent : multiplier les requêtes pour des périodes qui se recouvrent coûterait
  // plusieurs aller-retours sans rien apporter.
  const since = new Date(now.getTime() - windowDays * DAY_MS).toISOString();
  const { data: rawEvents } = await supabase
    .from("events")
    .select("user_id, name, created_at, is_premium, app_version, properties")
    .gte("created_at", since)
    .order("created_at", { ascending: false })
    .limit(50000);

  const events = (rawEvents ?? []) as EventRow[];
  const at = (row: EventRow) => new Date(row.created_at).getTime();

  const distinctUsersSince = (msAgo: number) => {
    const cutoff = now.getTime() - msAgo;
    const set = new Set<string>();
    for (const e of events) if (at(e) >= cutoff) set.add(e.user_id);
    return set.size;
  };

  const countSince = (name: string, msAgo: number) => {
    const cutoff = now.getTime() - msAgo;
    return events.filter((e) => e.name === name && at(e) >= cutoff).length;
  };

  // --- Courbe quotidienne : actifs, ouvertures, favoris, partages ------------------
  const dayKeys: string[] = [];
  for (let i = windowDays - 1; i >= 0; i--) {
    dayKeys.push(new Date(now.getTime() - i * DAY_MS).toISOString().slice(0, 10));
  }
  const dailyUsers = new Map<string, Set<string>>();
  const dailyOpens = new Map<string, number>();
  const dailyFavorites = new Map<string, number>();
  const dailyShares = new Map<string, number>();
  for (const key of dayKeys) {
    dailyUsers.set(key, new Set());
    dailyOpens.set(key, 0);
    dailyFavorites.set(key, 0);
    dailyShares.set(key, 0);
  }
  for (const e of events) {
    const day = e.created_at.slice(0, 10);
    dailyUsers.get(day)?.add(e.user_id);
    if (e.name === "app_opened") dailyOpens.set(day, (dailyOpens.get(day) ?? 0) + 1);
    if (e.name === "quote_favorited") dailyFavorites.set(day, (dailyFavorites.get(day) ?? 0) + 1);
    if (e.name === "quote_shared") dailyShares.set(day, (dailyShares.get(day) ?? 0) + 1);
  }
  const daily = dayKeys.map((date) => ({
    date,
    active: dailyUsers.get(date)?.size ?? 0,
    opens: dailyOpens.get(date) ?? 0,
    favorites: dailyFavorites.get(date) ?? 0,
    shares: dailyShares.get(date) ?? 0,
  }));

  // --- Répartition horaire des ouvertures -----------------------------------------
  // Dit directement si une notification tombe à une heure où personne n'est là.
  const hourly = Array.from({ length: 24 }, () => 0);
  for (const e of events) {
    if (e.name === "app_opened") hourly[new Date(e.created_at).getUTCHours()]++;
  }

  // --- Origine des ouvertures ------------------------------------------------------
  const sources = new Map<string, number>();
  for (const e of events) {
    if (e.name !== "app_opened") continue;
    const source = (e.properties?.source as string) ?? "direct";
    sources.set(source, (sources.get(source) ?? 0) + 1);
  }

  // --- Contenu : auteurs, citations, catégories ------------------------------------
  const sharedAuthors = new Map<string, number>();
  const favoritedAuthors = new Map<string, number>();
  const favoritedQuotes = new Map<string, number>();
  const categoryEngagement = new Map<string, number>();
  const openedAuthors = new Map<string, number>();
  for (const e of events) {
    const author = e.properties?.author as string | undefined;
    const category = e.properties?.category as string | undefined;
    if (e.name === "quote_shared" && author) sharedAuthors.set(author, (sharedAuthors.get(author) ?? 0) + 1);
    if (e.name === "quote_favorited") {
      if (author) favoritedAuthors.set(author, (favoritedAuthors.get(author) ?? 0) + 1);
      const quoteID = e.properties?.quote_id as string | undefined;
      if (quoteID) favoritedQuotes.set(quoteID, (favoritedQuotes.get(quoteID) ?? 0) + 1);
    }
    if (category && (e.name === "quote_favorited" || e.name === "quote_shared")) {
      categoryEngagement.set(category, (categoryEngagement.get(category) ?? 0) + 1);
    }
    if (e.name === "author_opened" && author) {
      openedAuthors.set(author, (openedAuthors.get(author) ?? 0) + 1);
    }
  }

  // --- Paywall : entonnoir global et par point d'entrée ----------------------------
  const paywallByOrigin = new Map<string, { shown: number; started: number; completed: number }>();
  for (const e of events) {
    if (!["paywall_shown", "purchase_started", "purchase_completed"].includes(e.name)) continue;
    const origin = (e.properties?.origin as string) ?? "unknown";
    const bucket = paywallByOrigin.get(origin) ?? { shown: 0, started: 0, completed: 0 };
    if (e.name === "paywall_shown") bucket.shown++;
    if (e.name === "purchase_started") bucket.started++;
    if (e.name === "purchase_completed") bucket.completed++;
    paywallByOrigin.set(origin, bucket);
  }

  // --- Catégories verrouillées touchées : signal de demande -------------------------
  const lockedTaps = new Map<string, number>();
  for (const e of events) {
    if (e.name !== "locked_category_tapped") continue;
    const category = (e.properties?.category as string) ?? "?";
    lockedTaps.set(category, (lockedTaps.get(category) ?? 0) + 1);
  }

  // --- Profils du quiz --------------------------------------------------------------
  const quizProfiles = new Map<string, number>();
  for (const e of events) {
    if (e.name !== "quiz_completed") continue;
    const profile = (e.properties?.profile as string) ?? "?";
    quizProfiles.set(profile, (quizProfiles.get(profile) ?? 0) + 1);
  }

  // --- Versions de l'app en circulation ---------------------------------------------
  //
  // Chaque personne compte une fois, sous sa version la plus récente. Ranger quelqu'un
  // dans chaque version d'où il a émis un évènement le comptait deux fois pendant qu'il
  // mettait à jour : le tableau était donc faux précisément pendant une migration, le
  // seul moment où on le consulte.
  //
  // `events` arrive trié du plus récent au plus ancien : la première occurrence d'une
  // personne porte sa version actuelle.
  const latestVersion = new Map<string, string>();
  for (const e of events) {
    if (latestVersion.has(e.user_id)) continue;
    latestVersion.set(e.user_id, e.app_version ?? "?");
  }
  const versionCounts = new Map<string, number>();
  for (const version of latestVersion.values()) {
    versionCounts.set(version, (versionCounts.get(version) ?? 0) + 1);
  }
  const versions = Array.from(versionCounts.entries())
    .map(([version, users]) => ({ version, users }))
    .sort((a, b) => b.users - a.users);

  // --- Rétention : reviennent-ils le lendemain, la semaine suivante ? ----------------
  // Calculée sur la première activité observée dans la fenêtre — approximation
  // honnête tant que la fenêtre ne remonte pas avant le lancement des mesures.
  const firstSeen = new Map<string, number>();
  const daysActive = new Map<string, Set<string>>();
  for (const e of events) {
    const t = at(e);
    const prev = firstSeen.get(e.user_id);
    if (prev === undefined || t < prev) firstSeen.set(e.user_id, t);
    if (!daysActive.has(e.user_id)) daysActive.set(e.user_id, new Set());
    daysActive.get(e.user_id)!.add(e.created_at.slice(0, 10));
  }
  let d1Eligible = 0, d1Returned = 0, d7Eligible = 0, d7Returned = 0;
  for (const [userID, first] of firstSeen) {
    const days = daysActive.get(userID)!;
    const firstDay = new Date(first).toISOString().slice(0, 10);
    if (now.getTime() - first >= 2 * DAY_MS) {
      d1Eligible++;
      const nextDay = new Date(first + DAY_MS).toISOString().slice(0, 10);
      if (days.has(nextDay)) d1Returned++;
    }
    if (now.getTime() - first >= 8 * DAY_MS) {
      d7Eligible++;
      for (let i = 1; i <= 7; i++) {
        const d = new Date(first + i * DAY_MS).toISOString().slice(0, 10);
        if (d !== firstDay && days.has(d)) { d7Returned++; break; }
      }
    }
  }

  // --- Utilisateurs les plus actifs --------------------------------------------------
  const perUser = new Map<string, number>();
  for (const e of events) perUser.set(e.user_id, (perUser.get(e.user_id) ?? 0) + 1);

  // --- Tables annexes ----------------------------------------------------------------
  const { data: states } = await supabase
    .from("user_state")
    .select("streak_count, premium_granted, first_name, last_name, user_id");
  const rows = states ?? [];
  const streakValues = rows.map((s) => s.streak_count ?? 0).filter((n) => n > 0);
  const avgStreak = streakValues.length
    ? streakValues.reduce((a, b) => a + b, 0) / streakValues.length
    : 0;
  const bestStreak = streakValues.length ? Math.max(...streakValues) : 0;
  const streakBuckets = { j1: 0, j2a3: 0, j4a7: 0, j8plus: 0 };
  for (const v of streakValues) {
    if (v === 1) streakBuckets.j1++;
    else if (v <= 3) streakBuckets.j2a3++;
    else if (v <= 7) streakBuckets.j4a7++;
    else streakBuckets.j8plus++;
  }

  const { count: favoritesTotal } = await supabase
    .from("favorites").select("*", { count: "exact", head: true });
  const { count: reachableDevices } = await supabase
    .from("device_tokens").select("*", { count: "exact", head: true });

  const { data: usersPage } = await supabase.auth.admin.listUsers({ page: 1, perPage: 1000 });
  const allUsers = usersPage?.users ?? [];
  const signupsByDay = new Map<string, number>();
  for (const key of dayKeys) signupsByDay.set(key, 0);
  for (const u of allUsers) {
    const day = u.created_at.slice(0, 10);
    if (signupsByDay.has(day)) signupsByDay.set(day, (signupsByDay.get(day) ?? 0) + 1);
  }

  // Nom lisible pour les listes de personnes, sans exposer d'e-mail.
  const nameByUser = new Map<string, string>();
  for (const s of rows) {
    const name = [s.first_name, s.last_name].filter(Boolean).join(" ").trim();
    if (name) nameByUser.set(s.user_id, name);
  }

  const premiumActive7d = new Set(
    events.filter((e) => e.is_premium && at(e) >= now.getTime() - 7 * DAY_MS).map((e) => e.user_id),
  ).size;

  const body = {
    updated_at: now.toISOString(),
    window_days: windowDays,

    live: {
      active_now: distinctUsersSince(5 * 60 * 1000),
      active_last_hour: distinctUsersSince(60 * 60 * 1000),
    },
    totals: {
      today_active: distinctUsersSince(DAY_MS),
      today_opens: countSince("app_opened", DAY_MS),
      week_active: distinctUsersSince(7 * DAY_MS),
      week_opens: countSince("app_opened", 7 * DAY_MS),
      window_active: distinctUsersSince(windowDays * DAY_MS),
      window_opens: countSince("app_opened", windowDays * DAY_MS),
      accounts: allUsers.length,
      signups_week: allUsers.filter((u) => new Date(u.created_at).getTime() >= now.getTime() - 7 * DAY_MS).length,
      profiles: rows.length,
      favorites_total: favoritesTotal ?? 0,
      reachable_devices: reachableDevices ?? 0,
      premium_active_7d: premiumActive7d,
      premium_granted: rows.filter((s) => s.premium_granted).length,
      events_total: events.length,
      events_per_user: perUser.size ? Math.round((events.length / perUser.size) * 10) / 10 : 0,
    },
    streaks: {
      average: Math.round(avgStreak * 10) / 10,
      best: bestStreak,
      buckets: streakBuckets,
    },
    retention: {
      d1: d1Eligible ? Math.round((d1Returned / d1Eligible) * 100) : null,
      d1_base: d1Eligible,
      d7: d7Eligible ? Math.round((d7Returned / d7Eligible) * 100) : null,
      d7_base: d7Eligible,
    },
    daily,
    signups_daily: dayKeys.map((date) => ({ date, count: signupsByDay.get(date) ?? 0 })),
    hourly,
    sources: Array.from(sources.entries()).map(([source, count]) => ({ source, count })),
    notifications: {
      opened: countSince("notification_opened", windowDays * DAY_MS),
      enabled: countSince("notifications_enabled", windowDays * DAY_MS),
      disabled: countSince("notifications_disabled", windowDays * DAY_MS),
      widget_opened: countSince("widget_opened", windowDays * DAY_MS),
    },
    paywall: Array.from(paywallByOrigin.entries())
      .map(([origin, v]) => ({ origin, ...v }))
      .sort((a, b) => b.shown - a.shown),
    locked_taps: topOf(lockedTaps, 6),
    content: {
      shared_authors: topOf(sharedAuthors, 8),
      favorited_authors: topOf(favoritedAuthors, 8),
      favorited_quotes: topOf(favoritedQuotes, 8),
      opened_authors: topOf(openedAuthors, 8),
      categories: topOf(categoryEngagement, 4),
    },
    quiz_profiles: topOf(quizProfiles, 8),
    versions,
    top_users: topOf(perUser, 8).map((u) => ({
      name: nameByUser.get(u.key) ?? u.key.slice(0, 8),
      user_id: u.key,
      events: u.count,
    })),
    recent: events.slice(0, 40).map((e) => ({
      at: e.created_at,
      name: e.name,
      who: nameByUser.get(e.user_id) ?? e.user_id.slice(0, 8),
      detail: (e.properties?.author as string) ?? (e.properties?.category as string) ??
        (e.properties?.origin as string) ?? (e.properties?.source as string) ?? "",
    })),
  };

  return new Response(JSON.stringify(body), {
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
});
