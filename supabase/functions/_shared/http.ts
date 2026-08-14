// Shared HTTP helpers for Route2Go edge functions.
// Ensures every endpoint returns the same typed error shape and never
// leaks internal stack traces to the client.

const corsHeaders = {
  "Access-Control-Allow-Origin": "*", // tighten to your admin/app origins in production
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

export function requestId(): string {
  return crypto.randomUUID();
}

export function jsonOk(data: unknown, reqId: string, status = 200): Response {
  return new Response(
    JSON.stringify({ data, requestId: reqId }),
    {
      status,
      headers: { "Content-Type": "application/json", ...corsHeaders },
    }
  );
}

export function jsonError(
  status: number,
  code: string,
  message: string,
  reqId: string,
  retryable: boolean
): Response {
  return new Response(
    JSON.stringify({
      code,
      message,
      requestId: reqId,
      retryable,
    }),
    {
      status,
      headers: { "Content-Type": "application/json", ...corsHeaders },
    }
  );
}
