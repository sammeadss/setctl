// Setup type definitions for built-in Supabase Runtime APIs
import "@supabase/functions-js/edge-runtime.d.ts";
import { withSupabase } from "@supabase/server";

// Deletes the signed-in caller's account. Every table that references the user
// cascades, so their server data goes with it. The id comes from the verified
// token, never from the request.
export default {
  fetch: withSupabase({ auth: "user" }, async (req, ctx) => {
    if (req.method !== "POST") {
      return new Response(null, { status: 405 });
    }

    const userId = ctx.userClaims?.id;
    if (!userId) {
      return Response.json({ error: "unauthorized" }, { status: 401 });
    }

    const { error } = await ctx.supabaseAdmin.auth.admin.deleteUser(userId);
    // An account that is already gone counts as deleted, so a retry after a lost response still succeeds.
    if (error && error.code !== "user_not_found") {
      console.error("deleteUser failed", error.message);
      return Response.json({ error: "delete failed" }, { status: 500 });
    }

    return new Response(null, { status: 204 });
  }),
};
