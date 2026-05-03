import { createClient, type SupabaseClient, type User } from "npm:@supabase/supabase-js@2";

export type FunctionContext = {
  authHeader: string;
  serviceClient: SupabaseClient;
  user: User;
  userClient: SupabaseClient;
};

export async function getFunctionContext(req: Request): Promise<FunctionContext> {
  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const authHeader = req.headers.get("Authorization") ?? "";
  const token = authHeader.replace("Bearer ", "");

  if (!supabaseUrl || !anonKey || !serviceRoleKey) {
    throw new Error("supabase_env_missing");
  }

  if (!token || authHeader === token) {
    throw new Error("missing_bearer_token");
  }

  const userClient = createClient(supabaseUrl, anonKey, {
    global: {
      headers: {
        Authorization: authHeader
      }
    }
  });

  const serviceClient = createClient(supabaseUrl, serviceRoleKey, {
    auth: {
      autoRefreshToken: false,
      persistSession: false
    }
  });

  const { data, error } = await serviceClient.auth.getUser(token);

  if (error || !data.user) {
    throw new Error("unauthorized");
  }

  return {
    authHeader,
    serviceClient,
    user: data.user,
    userClient
  };
}

export function errorStatus(error: unknown): number {
  const message = error instanceof Error ? error.message : String(error);

  if (message === "unauthorized" || message === "missing_bearer_token") return 401;
  if (message === "invalid_json") return 400;
  if (message === "not_found") return 404;
  if (message === "template_missing") return 409;
  if (message === "field_map_not_verified") return 422;
  return 500;
}
