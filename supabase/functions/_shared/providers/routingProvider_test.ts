import { assert, assertEquals, assertThrows } from "https://deno.land/std@0.221.0/assert/mod.ts";
import {
  getRoutingProvider,
  type RoutingProvider,
} from "./routingProvider.ts";

// --- helpers ---------------------------------------------------------------

const SAVED_ENV: Record<string, string | undefined> = {
  VALHALLA_BASE_URL: Deno.env.get("VALHALLA_BASE_URL"),
  ROUTING_PROVIDER_BASE_URL: Deno.env.get("ROUTING_PROVIDER_BASE_URL"),
  ROUTING_PROVIDER_KEY: Deno.env.get("ROUTING_PROVIDER_KEY"),
};

function restoreEnv() {
  for (const [k, v] of Object.entries(SAVED_ENV)) {
    if (v === undefined) Deno.env.delete(k);
    else Deno.env.set(k, v);
  }
}

type FetchStub = (url: string, init: RequestInit) => Promise<Response>;

function withFetch(stub: FetchStub, fn: () => Promise<void>) {
  const original = globalThis.fetch;
  // deno-lint-ignore no-explicit-any
  (globalThis as any).fetch = stub;
  return fn().finally(() => {
    // deno-lint-ignore no-explicit-any
    (globalThis as any).fetch = original;
  });
}

const jsonRes = (body: unknown, status = 200): Response =>
  new Response(JSON.stringify(body), { status });

function minimalTripResponse() {
  return {
    trip: {
      legs: [
        {
          shape: { type: "LineString", coordinates: [[77.5946, 12.9716], [76.6552, 12.3052]] },
          summary: { length: 10, time: 600 },
          maneuvers: [],
        },
      ],
      summary: { length: 10, time: 600 },
    },
  };
}

const points = {
  origin: { label: "A", lat: 12.9716, lng: 77.5946 },
  destination: { label: "B", lat: 12.3052, lng: 76.6552 },
};

// --- tests -----------------------------------------------------------------

Deno.test("getRoutingProvider returns the mock when no base URL is set", async () => {
  Deno.env.delete("VALHALLA_BASE_URL");
  Deno.env.delete("ROUTING_PROVIDER_BASE_URL");
  Deno.env.delete("ROUTING_PROVIDER_KEY");
  const provider = getRoutingProvider();
  const isMock =
    provider.constructor.name === "MockRoutingProvider";
  assert(isMock, "expected MockRoutingProvider when unconfigured");
  const alternatives = await provider.getRouteAlternatives({
    ...points,
    roundTrip: false,
  });
  assert(alternatives.length > 0, "mock returns options");
  assert(
    alternatives.every((a) => a.provider === "mock-dev-fixture"),
    "mock results are labelled so they are never mistaken for real data",
  );
});

Deno.test("VALHALLA_BASE_URL wins over the legacy ROUTING_PROVIDER_BASE_URL", async () => {
  Deno.env.set("VALHALLA_BASE_URL", "https://valhalla.example");
  Deno.env.set("ROUTING_PROVIDER_BASE_URL", "https://legacy.example");
  let calledUrl = "";
  await withFetch(async (url: string) => {
    calledUrl = url;
    return jsonRes(minimalTripResponse());
  }, async () => {
    const provider = getRoutingProvider();
    const alts = await provider.getRouteAlternatives({
      ...points,
      roundTrip: false,
    });
    assertEquals(calledUrl, "https://valhalla.example/route");
    assert(alts.length >= 1, "parses the live response");
  });
  restoreEnv();
});

Deno.test("legacy ROUTING_PROVIDER_BASE_URL alone activates Valhalla", async () => {
  Deno.env.delete("VALHALLA_BASE_URL");
  Deno.env.set("ROUTING_PROVIDER_BASE_URL", "https://legacy.example/");
  let calledUrl = "";
  await withFetch(async (url: string) => {
    calledUrl = url;
    return jsonRes(minimalTripResponse());
  }, async () => {
    const provider = getRoutingProvider();
    await provider.getRouteAlternatives({ ...points, roundTrip: false });
    // Trailing slash is stripped.
    assertEquals(calledUrl, "https://legacy.example/route");
  });
  restoreEnv();
});

Deno.test("Valhalla no-route (HTTP 400 error_code 171) yields an empty option list", async () => {
  Deno.env.set("VALHALLA_BASE_URL", "https://valhalla.example");
  await withFetch(async () =>
    jsonRes(
      { error_code: 171, error: "No suitable edges near location", status_code: 400 },
      400,
    )
  , async () => {
    const provider = getRoutingProvider();
    const alts = await provider.getRouteAlternatives({
      ...points,
      roundTrip: false,
    });
    assertEquals(alts, []);
  });
  restoreEnv();
});

Deno.test("Valhalla HTTP 500 is fatal and propagates", async () => {
  Deno.env.set("VALHALLA_BASE_URL", "https://valhalla.example");
  await withFetch(async () => jsonRes({ error: "boom" }, 500), async () => {
    const provider = getRoutingProvider();
    await assertRejects(
      provider.getRouteAlternatives({ ...points, roundTrip: false }),
      Error,
      "500",
    );
  });
  restoreEnv();
});

Deno.test("Valhalla 5xx is retried once, then fails clearly (bounded retry)", async () => {
  Deno.env.set("VALHALLA_BASE_URL", "https://valhalla.example");
  let calls = 0;
  let serverErrors = 0;
  await withFetch(async () => {
    calls++;
    if (calls === 1) {
      serverErrors++;
      return jsonRes({ error: "upstream" }, 503);
    }
    return jsonRes(minimalTripResponse());
  }, async () => {
    const provider = getRoutingProvider();
    const alts = await provider.getRouteAlternatives({
      ...points,
      roundTrip: false,
    });
    assert(alts.length >= 1, "second attempt succeeded");
  });
  // Main profile = 2 attempts (1x 503 + 1x 200), toll-free profile = 1 attempt
  // (200). Exactly ONE retry happened for the failing request.
  assertEquals(serverErrors, 1, "exactly one 503 observed");
  assertEquals(calls, 3, "2 main attempts + 1 toll-free attempt, no more");
  restoreEnv();
});

Deno.test("Valhalla 4xx input errors are NOT retried (no server hammering)", async () => {
  Deno.env.set("VALHALLA_BASE_URL", "https://valhalla.example");
  let calls = 0;
  await withFetch(async () => {
    calls++;
    return jsonRes({ error: "bad request" }, 400);
  }, async () => {
    const provider = getRoutingProvider();
    await assertRejects(
      provider.getRouteAlternatives({ ...points, roundTrip: false }),
      Error,
      "400",
    );
  });
  assertEquals(calls, 1, "a 400 must never be re-issued");
  restoreEnv();
});

Deno.test("Valhalla sends the bearer key when configured", async () => {
  Deno.env.set("VALHALLA_BASE_URL", "https://valhalla.example");
  Deno.env.set("ROUTING_PROVIDER_KEY", "sekret");
  let authHeader = "";
  await withFetch(async (_url: string, init: RequestInit) => {
    authHeader = (init.headers as Record<string, string>).Authorization;
    return jsonRes(minimalTripResponse());
  }, async () => {
    await getRoutingProvider().getRouteAlternatives({
      ...points,
      roundTrip: false,
    });
    assertEquals(authHeader, "Bearer sekret");
  });
  restoreEnv();
});

function assertRejects(p: Promise<unknown>, Err: typeof Error, messagePart: string) {
  return p.then(
    () => {
      throw new Error("expected promise to reject");
    },
    (err: unknown) => {
      assert(err instanceof Err, `expected ${Err.name}`);
      assert(String(err.message).includes(messagePart), `message ${err.message} should include ${messagePart}`);
    },
  );
}