import crypto from "node:crypto";
import path from "node:path";
import process from "node:process";
import { fileURLToPath } from "node:url";
import { createClient } from "@supabase/supabase-js";
import dotenv from "dotenv";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const rootDir = path.resolve(__dirname, "..");

for (const envPath of [".env.local", ".env", "apps/web/.env.local"]) {
  dotenv.config({ path: path.join(rootDir, envPath), override: false });
}

const supabaseUrl = process.env.SUPABASE_URL ?? process.env.VITE_SUPABASE_URL;
const serviceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

if (!supabaseUrl || !serviceRoleKey) {
  throw new Error("Missing SUPABASE_URL/VITE_SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY.");
}

const supabase = createClient(supabaseUrl, serviceRoleKey, {
  auth: {
    autoRefreshToken: false,
    persistSession: false
  }
});

function extensionFor(contentType, url) {
  const lower = `${contentType ?? ""} ${url}`.toLowerCase();
  if (lower.includes("pdf")) return "pdf";
  if (lower.includes("json")) return "json";
  if (lower.includes("html")) return "html";
  return "txt";
}

function snapshotPath(source, contentType) {
  const timestamp = new Date().toISOString().replace(/[:.]/g, "-");
  const jurisdiction = source.jurisdiction || "US";
  const sourceKind = source.source_kind || "source";
  return `${jurisdiction}/${sourceKind}/${source.id}-${timestamp}.${extensionFor(contentType, source.url)}`;
}

async function recordSnapshot(source, payload) {
  const { error } = await supabase.from("official_source_snapshots").insert({
    source_id: source.id,
    http_status: payload.httpStatus ?? null,
    content_type: payload.contentType ?? null,
    content_sha256: payload.sha256 ?? null,
    byte_size: payload.byteSize ?? null,
    storage_bucket: payload.storagePath ? "official-source-snapshots" : null,
    storage_path: payload.storagePath ?? null,
    snapshot_status: payload.status,
    error_message: payload.errorMessage ?? null,
    extracted_metadata: payload.metadata ?? {}
  });

  if (error) throw error;
}

async function syncSource(source) {
  try {
    const response = await fetch(source.url, {
      redirect: "follow",
      headers: {
        Accept: "application/pdf,text/html,application/json,text/plain,*/*",
        "User-Agent": "USA-Latino-Prime/1.0 official-source-sync"
      }
    });

    const contentType = response.headers.get("content-type") ?? "application/octet-stream";
    const body = Buffer.from(await response.arrayBuffer());
    const sha256 = crypto.createHash("sha256").update(body).digest("hex");
    const storagePath = snapshotPath(source, contentType);

    if (!response.ok) {
      await recordSnapshot(source, {
        byteSize: body.byteLength,
        contentType,
        httpStatus: response.status,
        sha256,
        status: "failed",
        errorMessage: `HTTP ${response.status}`
      });
      return { ok: false, source: source.url, reason: `HTTP ${response.status}` };
    }

    const { error: uploadError } = await supabase.storage
      .from("official-source-snapshots")
      .upload(storagePath, body, {
        contentType,
        upsert: false
      });

    if (uploadError) throw uploadError;

    await recordSnapshot(source, {
      byteSize: body.byteLength,
      contentType,
      httpStatus: response.status,
      metadata: {
        final_url: response.url,
        title: source.title
      },
      sha256,
      status: "fetched",
      storagePath
    });

    return { ok: true, source: source.url };
  } catch (error) {
    const message = error instanceof Error ? error.message : "unknown_error";
    await recordSnapshot(source, {
      status: "failed",
      errorMessage: message
    });
    return { ok: false, source: source.url, reason: message };
  }
}

const limitArg = Number.parseInt(process.argv[2] ?? "", 10);
const limit = Number.isFinite(limitArg) ? limitArg : 250;

const { data: sources, error } = await supabase
  .from("official_sources")
  .select("id, title, url, source_kind, jurisdiction")
  .in("authority", ["official", "official_api"])
  .order("jurisdiction")
  .limit(limit);

if (error) throw error;

let ok = 0;
let failed = 0;

for (const source of sources ?? []) {
  const result = await syncSource(source);
  if (result.ok) ok += 1;
  else failed += 1;
  console.log(`${result.ok ? "OK" : "FAIL"} ${result.source}${result.reason ? ` ${result.reason}` : ""}`);
}

console.log(`Synced official sources: ok=${ok} failed=${failed}`);
