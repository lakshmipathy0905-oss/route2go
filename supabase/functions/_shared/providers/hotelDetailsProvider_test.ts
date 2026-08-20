import {
  assertEquals,
} from "https://deno.land/std@0.221.0/assert/mod.ts";
import {
  getHotelDetails,
} from "./hotelDetailsProvider.ts";

function withKey(fn: () => Promise<void>) {
  const prev = Deno.env.get("SERPAPI_KEY");
  Deno.env.set("SERPAPI_KEY", "test-key");
  return async () => {
    try {
      await fn();
    } finally {
      if (prev === undefined) Deno.env.delete("SERPAPI_KEY");
      else Deno.env.set("SERPAPI_KEY", prev);
    }
  };
}

function stubFetch(payload: unknown, ok = true) {
  const realFetch = globalThis.fetch;
  globalThis.fetch = async () =>
    new Response(ok ? JSON.stringify(payload) : "boom", {
      status: ok ? 200 : 500,
      headers: { "content-type": "application/json" },
    });
  return () => {
    globalThis.fetch = realFetch;
  };
}

Deno.test(
  "getHotelDetails returns null when SERPAPI_KEY is absent",
  async () => {
    Deno.env.delete("SERPAPI_KEY");
    const restore = stubFetch({ hotel_results: [] });
    try {
      const details = await getHotelDetails({ name: "Taj Bengaluru" });
      assertEquals(details, null);
    } finally {
      restore();
    }
  },
);

Deno.test(
  "getHotelDetails returns null when upstream fails",
  withKey(async () => {
    const restore = stubFetch({}, false);
    try {
      const details = await getHotelDetails({ name: "Taj Bengaluru" });
      assertEquals(details, null);
    } finally {
      restore();
    }
  }),
);

Deno.test(
  "getHotelDetails returns null when no listing matches the name",
  withKey(async () => {
    const restore = stubFetch({
      hotel_results: [{ name: "Some Other Hotel", thumbnail: "x.jpg" }],
    });
    try {
      const details = await getHotelDetails({ name: "Taj Bengaluru" });
      assertEquals(details, null, "never attributes a photo to the wrong hotel");
    } finally {
      restore();
    }
  }),
);

Deno.test(
  "getHotelDetails maps the matched listing to HotelDetails",
  withKey(async () => {
    const restore = stubFetch({
      hotel_results: [
        {
          name: "The Taj Mahal Palace, Mumbai",
          thumbnail: "https://img.example/taj.jpg",
          rating: 4.7,
          reviews: 3200,
          price: "₹18,500",
          link: "https://example.com/taj",
        },
      ],
    });
    try {
      const details = await getHotelDetails({
        name: "Taj Mahal Palace",
        city: "Mumbai",
      });
      assertEquals(details?.name, "The Taj Mahal Palace, Mumbai");
      assertEquals(details?.photoUrl, "https://img.example/taj.jpg");
      assertEquals(details?.rating, 4.7);
      assertEquals(details?.reviewCount, 3200);
      assertEquals(details?.pricePerNight, 18500);
      assertEquals(details?.bookingUrl, "https://example.com/taj");
    } finally {
      restore();
    }
  }),
);

Deno.test(
  "getHotelDetails keeps parsing intact when optional fields are missing",
  withKey(async () => {
    const restore = stubFetch({
      hotel_results: [{ name: "ITC Gardenia" }],
    });
    try {
      const details = await getHotelDetails({ name: "ITC Gardenia" });
      assertEquals(details?.name, "ITC Gardenia");
      assertEquals(details?.photoUrl, undefined);
      assertEquals(details?.rating, undefined);
      assertEquals(details?.bookingUrl, undefined);
    } finally {
      restore();
    }
  }),
);