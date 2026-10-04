import test from "node:test";
import assert from "node:assert/strict";
import { controllerSocketUrl } from "../build/network_config.js";

test("canonical transport pairs schemes and preserves the joining hostname", () => {
  const config = {
    protocol: 1,
    session_id: "session",
    http_scheme: "http",
    websocket_scheme: "ws",
    websocket_port: 8081,
  };
  assert.equal(controllerSocketUrl(config, "http://192.168.1.50:8080/"), "ws://192.168.1.50:8081/");
  const secure = { ...config, http_scheme: "https", websocket_scheme: "wss" };
  assert.equal(
    controllerSocketUrl(secure, "https://playshapes.local:8080/"),
    "wss://playshapes.local:8081/",
  );
  for (const invalid of [
    { ...secure, websocket_scheme: "ws" },
    { ...secure, websocket_port: 0 },
    { ...secure, websocket_port: 8081.5 },
    { ...secure, protocol: 2 },
  ]) {
    assert.throws(() => controllerSocketUrl(invalid, "https://playshapes.local:8080/"));
  }
});
