// Тестовое подключение Instagram: вебхук Meta, синхронизация и чтение сообщений по паролю.
// Развёрнута с verify_jwt=false: функция проверяет доступ сама.
import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const env = (k: string) => (Deno.env.get(k) ?? "").trim();
const GRAPH = "https://graph.instagram.com/v26.0";
const ORIGIN = "https://dmytrovertikov.github.io";
const enc = new TextEncoder();

const cors = {
  "Access-Control-Allow-Origin": ORIGIN,
  "Access-Control-Allow-Headers": "content-type, x-page-password",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
};
const json = (data: unknown, status = 200) =>
  new Response(JSON.stringify(data), { status, headers: { ...cors, "Content-Type": "application/json", "Cache-Control": "no-store" } });

async function same(a: string, b: string) {
  const [x, y] = await Promise.all([a, b].map(async (s) => new Uint8Array(await crypto.subtle.digest("SHA-256", enc.encode(s)))));
  let d = 0;
  for (let i = 0; i < x.length; i++) d |= x[i] ^ y[i];
  return d === 0;
}

// IG_APP_SECRET может содержать несколько значений через запятую (Instagram app secret и App secret).
async function validSignature(raw: Uint8Array, header: string) {
  for (const secret of env("IG_APP_SECRET").split(",").map((s) => s.trim()).filter(Boolean)) {
    const key = await crypto.subtle.importKey("raw", enc.encode(secret), { name: "HMAC", hash: "SHA-256" }, false, ["sign"]);
    const mac = new Uint8Array(await crypto.subtle.sign("HMAC", key, raw));
    const hex = "sha256=" + Array.from(mac, (b) => b.toString(16).padStart(2, "0")).join("");
    if (await same(hex, header)) return true;
  }
  return false;
}

async function db(path: string, init: RequestInit = {}) {
  const key = env("SUPABASE_SERVICE_ROLE_KEY");
  const r = await fetch(`${env("SUPABASE_URL")}/rest/v1/${path}`, {
    ...init,
    headers: { apikey: key, Authorization: `Bearer ${key}`, "Content-Type": "application/json", ...(init.headers ?? {}) },
  });
  if (!r.ok) throw new Error(`db ${r.status}: ${await r.text()}`);
  return r;
}

async function save(rows: Record<string, unknown>[], overwrite: boolean) {
  if (!rows.length) return;
  await db("ig_messages?on_conflict=mid", {
    method: "POST",
    headers: { Prefer: `resolution=${overwrite ? "merge" : "ignore"}-duplicates,return=minimal` },
    body: JSON.stringify(rows),
  });
}

// deno-lint-ignore no-explicit-any
async function handleEvent(ev: any) {
  const m = ev?.message;
  if (!m?.mid) return;
  if (m.is_deleted) {
    await db(`ig_messages?mid=eq.${encodeURIComponent(m.mid)}`, { method: "DELETE" });
    return;
  }
  const t = Number(ev.timestamp);
  // Имена не передаём, чтобы не затереть уже полученные синхронизацией.
  await save([{
    mid: m.mid,
    sender_id: ev.sender?.id ?? null,
    recipient_id: ev.recipient?.id ?? null,
    body: m.text ?? null,
    attachments: m.attachments ?? null,
    is_echo: !!m.is_echo,
    sent_at: new Date(t ? (t < 1e12 ? t * 1000 : t) : Date.now()).toISOString(),
  }], false);
}

async function graph(path: string, params: Record<string, string>) {
  const url = new URL(`${GRAPH}/${path}`);
  for (const [k, v] of Object.entries(params)) url.searchParams.set(k, v);
  const r = await fetch(url, { headers: { Authorization: `Bearer ${env("IG_ACCESS_TOKEN")}` } });
  const data = await r.json();
  if (!r.ok) throw new Error(`Instagram: ${data?.error?.message ?? r.status}`);
  return data;
}

// Забирает последние сообщения через Conversations API (работает и без вебхуков).
async function sync() {
  if (!env("IG_ACCESS_TOKEN")) throw new Error("Не задан секрет IG_ACCESS_TOKEN");
  const me = await graph("me", { fields: "user_id,username" });
  const list = await graph("me/conversations", {
    platform: "instagram",
    limit: "10",
    fields: "id,messages.limit(20){id,created_time,from,to,message}",
  });
  const rows = [];
  for (const c of list.data ?? []) {
    for (const m of c.messages?.data ?? []) {
      const to = m.to?.data?.[0];
      rows.push({
        mid: m.id,
        sender_id: m.from?.id ?? null,
        sender_name: m.from?.username ?? null,
        recipient_id: to?.id ?? null,
        recipient_name: to?.username ?? null,
        body: m.message || null,
        is_echo: m.from?.username === me.username,
        sent_at: new Date(m.created_time).toISOString(),
      });
    }
  }
  // attachments не входят в строку, поэтому при обновлении сохраняются.
  await save(rows, true);
  return rows.length;
}

Deno.serve(async (req: Request) => {
  const url = new URL(req.url);
  try {
    if (req.method === "OPTIONS") return new Response(null, { status: 204, headers: cors });

    // 1. Проверка адреса вебхука со стороны Meta.
    if (req.method === "GET" && url.searchParams.has("hub.mode")) {
      const token = env("IG_VERIFY_TOKEN");
      const ok = token && url.searchParams.get("hub.mode") === "subscribe" &&
        await same(url.searchParams.get("hub.verify_token") ?? "", token);
      return ok ? new Response(url.searchParams.get("hub.challenge") ?? "") : new Response("Forbidden", { status: 403 });
    }

    // 2. Уведомление от Meta.
    const signature = req.headers.get("x-hub-signature-256");
    if (req.method === "POST" && signature) {
      const raw = new Uint8Array(await req.arrayBuffer());
      if (!await validSignature(raw, signature)) {
        console.warn("webhook: неверная подпись");
        return new Response("Bad signature", { status: 401 });
      }
      const payload = JSON.parse(new TextDecoder().decode(raw));
      for (const entry of payload.entry ?? []) {
        for (const ev of entry.messaging ?? []) await handleEvent(ev);
        for (const ch of entry.changes ?? []) if (ch.field === "messages") await handleEvent(ch.value);
      }
      return new Response("OK");
    }

    // 3. Запросы страницы.
    const password = env("PAGE_PASSWORD");
    if (password.length < 12) return json({ error: "Секрет PAGE_PASSWORD не задан или короче 12 символов" }, 503);
    if (!await same(req.headers.get("x-page-password") ?? "", password)) {
      await new Promise((r) => setTimeout(r, 1000));
      return json({ error: "Неверный пароль" }, 401);
    }
    let synced: number | undefined;
    if (req.method === "POST" && url.searchParams.get("action") === "sync") synced = await sync();
    const r = await db("ig_messages?select=*&order=sent_at.desc&limit=200");
    return json({ messages: await r.json(), synced });
  } catch (e) {
    console.error(e);
    const msg = e instanceof Error && e.message.startsWith("Instagram:") || String(e).includes("IG_ACCESS_TOKEN")
      ? (e as Error).message : "Ошибка сервера, подробности в логах функции";
    return json({ error: msg }, 500);
  }
});
