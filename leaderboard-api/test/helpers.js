/** Shared test helpers for the suggestion tests (not a test file itself). */

export const payload = {
  category: "Balance",
  title: "Vent Taps feel too strong",
  description: "On Hollow a single Vent Tap covers the whole west edge's heat by turn 20.",
  website: "",
  client: { game_version: "00.01.07", runtime: "Web", device_type: "Phone", platform: "Android", browser: "Chrome" },
};

export function suggestEnv(extra = {}) {
  const data = new Map();
  return {
    GITHUB_TOKEN: "test-token",
    LEADERBOARD_KV: {
      async get(key) {
        return data.get(key) ?? null;
      },
      async put(key, value) {
        data.set(key, value);
      },
    },
    _data: data,
    ...extra,
  };
}

export function suggestRequest(body = payload, headers = {}) {
  return new Request("https://example.workers.dev/suggestions", {
    method: "POST",
    headers: { "Content-Type": "application/json", "CF-Connecting-IP": "1.2.3.4", ...headers },
    body: typeof body === "string" ? body : JSON.stringify(body),
  });
}

/** A pretend GitHub that records what it was sent. */
export function fakeGitHub(status = 201) {
  const calls = [];
  const fn = async (url, init) => {
    calls.push({ url, init, issue: JSON.parse(init.body) });
    return new Response(JSON.stringify({ number: 42, secret: "do-not-repeat" }), { status });
  };
  fn.calls = calls;
  return fn;
}

