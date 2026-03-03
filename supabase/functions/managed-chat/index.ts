import { createClient } from "jsr:@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const OPENAI_API_KEY = Deno.env.get("OPENAI_API_KEY") ?? "";
const GOOGLE_API_KEY = Deno.env.get("GOOGLE_API_KEY") ?? "";

type ManagedProvider = "openai" | "anthropic" | "gemini" | "grok";
type RuntimeProvider = "openai" | "gemini";

interface ManagedChatRequestBody {
  provider?: string;
  model?: string;
  messages?: Array<{ role?: string; content?: string }>;
}

interface ProviderResult {
  text: string | null;
  error: string | null;
}

const VALID_ROLES = new Set(["system", "user", "assistant"]);

function jsonResponse(body: Record<string, unknown>, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

function resolveProvider(rawProvider: string | undefined): ManagedProvider {
  switch ((rawProvider ?? "").toLowerCase()) {
    case "anthropic":
      return "anthropic";
    case "gemini":
      return "gemini";
    case "grok":
      return "grok";
    default:
      return "openai";
  }
}

function normalizeMessages(
  rawMessages: ManagedChatRequestBody["messages"]
): Array<{ role: "system" | "user" | "assistant"; content: string }> {
  if (!rawMessages || rawMessages.length === 0) {
    return [];
  }

  return rawMessages.flatMap((message) => {
    const role = (message.role ?? "").toLowerCase();
    const content = (message.content ?? "").trim();

    if (!VALID_ROLES.has(role) || content.length === 0) {
      return [];
    }

    return [{ role: role as "system" | "user" | "assistant", content }];
  });
}

function parseUpstreamError(rawText: string, fallback: string): string {
  if (!rawText) {
    return fallback;
  }

  try {
    const parsed = JSON.parse(rawText);
    const message = parsed?.error?.message ?? parsed?.error;
    if (typeof message === "string" && message.length > 0) {
      return message;
    }
  } catch {
    // Ignore parsing errors.
  }

  return rawText;
}

function resolveRuntimeOrder(requested: ManagedProvider): RuntimeProvider[] {
  const order: RuntimeProvider[] = [];

  if (requested === "gemini") {
    order.push("gemini", "openai");
  } else {
    order.push("openai", "gemini");
  }

  return order;
}

function isRuntimeConfigured(provider: RuntimeProvider): boolean {
  switch (provider) {
    case "openai":
      return OPENAI_API_KEY.length > 0;
    case "gemini":
      return GOOGLE_API_KEY.length > 0;
  }
}

function resolveOpenAIModel(requested?: string): string {
  if (
    requested &&
    (requested.startsWith("gpt-") ||
      requested.startsWith("o1") ||
      requested.startsWith("o3") ||
      requested.startsWith("o4"))
  ) {
    return requested;
  }

  return "gpt-4o-mini";
}

function resolveGeminiModel(requested?: string): string {
  if (requested && requested.startsWith("gemini-")) {
    return requested;
  }

  return "gemini-2.0-flash";
}

function extractOpenAIText(responseBody: any): string {
  const content = responseBody?.choices?.[0]?.message?.content;
  if (typeof content === "string") {
    return content.trim();
  }

  if (Array.isArray(content)) {
    return content
      .map((part) => (typeof part?.text === "string" ? part.text : ""))
      .join("")
      .trim();
  }

  return "";
}

function extractGeminiText(responseBody: any): string {
  const parts = responseBody?.candidates?.[0]?.content?.parts;
  if (!Array.isArray(parts)) {
    return "";
  }

  return parts
    .map((part: any) => (typeof part?.text === "string" ? part.text : ""))
    .join("")
    .trim();
}

async function callOpenAI(
  messages: Array<{ role: "system" | "user" | "assistant"; content: string }>,
  requestedModel?: string
): Promise<ProviderResult> {
  const model = resolveOpenAIModel(requestedModel);

  const response = await fetch("https://api.openai.com/v1/chat/completions", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${OPENAI_API_KEY}`,
    },
    body: JSON.stringify({
      model,
      messages,
      temperature: 0.7,
    }),
  });

  const rawText = await response.text();
  if (!response.ok) {
    return {
      text: null,
      error: parseUpstreamError(rawText, `OpenAI request failed (${response.status})`),
    };
  }

  let parsed: any;
  try {
    parsed = JSON.parse(rawText);
  } catch {
    return { text: null, error: "OpenAI returned invalid JSON" };
  }

  const text = extractOpenAIText(parsed);
  if (!text) {
    return { text: null, error: "OpenAI returned no content" };
  }

  return { text, error: null };
}

function toGeminiContents(
  messages: Array<{ role: "system" | "user" | "assistant"; content: string }>
): {
  systemInstruction?: { parts: Array<{ text: string }> };
  contents: Array<{ role: "user" | "model"; parts: Array<{ text: string }> }>;
} {
  const systemText = messages
    .filter((message) => message.role === "system")
    .map((message) => message.content)
    .join("\n\n")
    .trim();

  const contents = messages
    .filter((message) => message.role !== "system")
    .map((message) => ({
      role: message.role === "assistant" ? "model" : "user",
      parts: [{ text: message.content }],
    }));

  return {
    systemInstruction: systemText
      ? { parts: [{ text: systemText }] }
      : undefined,
    contents:
      contents.length > 0
        ? contents
        : [{ role: "user", parts: [{ text: "Hello" }] }],
  };
}

async function callGemini(
  messages: Array<{ role: "system" | "user" | "assistant"; content: string }>,
  requestedModel?: string
): Promise<ProviderResult> {
  const model = resolveGeminiModel(requestedModel);
  const payload = toGeminiContents(messages);

  const response = await fetch(
    `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${GOOGLE_API_KEY}`,
    {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
      },
      body: JSON.stringify(payload),
    }
  );

  const rawText = await response.text();
  if (!response.ok) {
    return {
      text: null,
      error: parseUpstreamError(rawText, `Gemini request failed (${response.status})`),
    };
  }

  let parsed: any;
  try {
    parsed = JSON.parse(rawText);
  } catch {
    return { text: null, error: "Gemini returned invalid JSON" };
  }

  const text = extractGeminiText(parsed);
  if (!text) {
    return { text: null, error: "Gemini returned no content" };
  }

  return { text, error: null };
}

async function runProvider(
  provider: RuntimeProvider,
  messages: Array<{ role: "system" | "user" | "assistant"; content: string }>,
  requestedModel?: string
): Promise<ProviderResult> {
  switch (provider) {
    case "gemini":
      return await callGemini(messages, requestedModel);
    case "openai":
    default:
      return await callOpenAI(messages, requestedModel);
  }
}

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") {
    return jsonResponse({ error: "Method not allowed" }, 405);
  }

  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);
  const authHeader = req.headers.get("authorization");
  const jwt = authHeader?.startsWith("Bearer ")
    ? authHeader.slice(7)
    : null;
  let userID: string | null = null;

  if (jwt) {
    const {
      data: { user },
    } = await supabase.auth.getUser(jwt);
    userID = user?.id ?? null;
  }

  let payload: ManagedChatRequestBody;
  try {
    payload = await req.json();
  } catch {
    return jsonResponse({ error: "Invalid JSON body" }, 400);
  }

  const requestedProvider = resolveProvider(payload.provider);
  const messages = normalizeMessages(payload.messages);

  if (messages.length === 0) {
    return jsonResponse({ error: "At least one message is required" }, 400);
  }

  const runtimeOrder = resolveRuntimeOrder(requestedProvider);
  const errors: string[] = [];

  for (const runtimeProvider of runtimeOrder) {
    if (!isRuntimeConfigured(runtimeProvider)) {
      errors.push(`${runtimeProvider} is not configured`);
      continue;
    }

    const result = await runProvider(runtimeProvider, messages, payload.model);
    if (result.text) {
      // Best-effort usage event for observability.
      try {
        await supabase.from("usage_events").insert({
          user_id: userID,
          provider: runtimeProvider,
          tier: "managed",
          duration_seconds: 0,
          device_id: userID ? "managed-chat-user" : "managed-chat-anon",
        });
      } catch {
        // Non-critical.
      }

      return jsonResponse({
        text: result.text,
        provider: runtimeProvider,
        requestedProvider,
      });
    }

    errors.push(`${runtimeProvider}: ${result.error ?? "unknown error"}`);
  }

  return jsonResponse(
    {
      error: errors.join(" | ") || "No managed providers are configured",
    },
    502
  );
});
