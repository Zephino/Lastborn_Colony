/**
 * Which web pages may call this Worker from a browser (CORS). The PC and phone
 * versions of the game don't send an Origin, so this only matters for the web
 * version at https://zephino.github.io/Lastborn_Colony/ (and a copy run on this
 * computer while testing). To host the web game somewhere else, add its
 * address (scheme + host, no path) to ALLOWED_ORIGINS.
 */

export const ALLOWED_ORIGINS = ["https://zephino.github.io"];
const LOCAL = /^https?:\/\/(localhost|127\.0\.0\.1)(:\d+)?$/;

export function originAllowed(origin) {
  return typeof origin === "string" && (ALLOWED_ORIGINS.includes(origin) || LOCAL.test(origin));
}

/** CORS headers for this request: the caller's origin is echoed only when it's allowed. */
export function corsHeaders(request, methods = "GET, POST, OPTIONS", headers = "Content-Type, Accept") {
  const out = {
    "Access-Control-Allow-Methods": methods,
    "Access-Control-Allow-Headers": headers,
    "Access-Control-Max-Age": "86400",
    Vary: "Origin",
  };
  const origin = request?.headers?.get("Origin");
  if (originAllowed(origin)) out["Access-Control-Allow-Origin"] = origin;
  return out;
}
