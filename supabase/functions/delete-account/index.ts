import { createClient } from "jsr:@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

const jsonHeaders = { "Content-Type": "application/json" };

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") {
    return new Response(
      JSON.stringify({ error: "Method not allowed" }),
      { status: 405, headers: jsonHeaders }
    );
  }

  const authHeader = req.headers.get("authorization");
  if (!authHeader?.startsWith("Bearer ")) {
    return new Response(
      JSON.stringify({ error: "Missing authorization" }),
      { status: 401, headers: jsonHeaders }
    );
  }

  const jwt = authHeader.slice(7);
  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);

  const {
    data: { user },
    error: authError,
  } = await supabase.auth.getUser(jwt);

  if (authError || !user) {
    return new Response(
      JSON.stringify({ error: "Invalid token" }),
      { status: 401, headers: jsonHeaders }
    );
  }

  // Remove user-owned data before deleting auth user to satisfy FK constraints.
  const { error: usageDeleteError } = await supabase
    .from("usage_events")
    .delete()
    .eq("user_id", user.id);

  if (usageDeleteError) {
    return new Response(
      JSON.stringify({ error: "Failed to delete usage history" }),
      { status: 500, headers: jsonHeaders }
    );
  }

  const { error: quotaDeleteError } = await supabase
    .from("user_quotas")
    .delete()
    .eq("user_id", user.id);

  if (quotaDeleteError) {
    return new Response(
      JSON.stringify({ error: "Failed to delete quota records" }),
      { status: 500, headers: jsonHeaders }
    );
  }

  const { error: subscriptionDeleteError } = await supabase
    .from("user_subscriptions")
    .delete()
    .eq("user_id", user.id);

  if (subscriptionDeleteError) {
    return new Response(
      JSON.stringify({ error: "Failed to delete subscriptions" }),
      { status: 500, headers: jsonHeaders }
    );
  }

  const { error: authDeleteError } = await supabase.auth.admin.deleteUser(user.id);

  if (authDeleteError) {
    return new Response(
      JSON.stringify({ error: "Failed to delete user account" }),
      { status: 500, headers: jsonHeaders }
    );
  }

  return new Response(
    JSON.stringify({ success: true }),
    { status: 200, headers: jsonHeaders }
  );
});
