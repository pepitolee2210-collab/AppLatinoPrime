import Stripe from "npm:stripe@18.5.0";
import { jsonResponse, preflight } from "../_shared/http.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

Deno.serve(async (req) => {
  const cors = preflight(req);
  if (cors) return cors;

  if (req.method !== "POST") {
    return jsonResponse({ error: "method_not_allowed" }, 405);
  }

  const stripeSecretKey = Deno.env.get("STRIPE_SECRET_KEY");
  const stripeWebhookSecret = Deno.env.get("STRIPE_WEBHOOK_SECRET");
  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

  if (!stripeSecretKey || !stripeWebhookSecret || !supabaseUrl || !serviceRoleKey) {
    return jsonResponse({ error: "stripe_not_configured" }, 503);
  }

  const signature = req.headers.get("stripe-signature");
  if (!signature) {
    return jsonResponse({ error: "missing_stripe_signature" }, 400);
  }

  const rawBody = await req.text();
  const stripe = new Stripe(stripeSecretKey);
  const supabase = createClient(supabaseUrl, serviceRoleKey, {
    auth: {
      autoRefreshToken: false,
      persistSession: false
    }
  });

  let event: Stripe.Event;

  try {
    event = await stripe.webhooks.constructEventAsync(rawBody, signature, stripeWebhookSecret);
  } catch {
    return jsonResponse({ error: "invalid_stripe_signature" }, 400);
  }

  if (event.type === "checkout.session.completed") {
    const session = event.data.object as Stripe.Checkout.Session;
    const requestId = session.metadata?.premium_service_request_id;

    if (requestId) {
      await supabase
        .from("premium_service_requests")
        .update({
          status: "paid",
          stripe_checkout_session_id: session.id
        })
        .eq("id", requestId);
    }
  }

  return jsonResponse({ received: true });
});
