// Development-only. Full coverage and Windows export are independent suite options.
const FULL_TESTS = new Set([
  "tilt_shift_workshop_preview_test",
  "tilt_shift_rotation_contact_test",
]);

export function includeGodotTest(name, { full = false, release = false } = {}) {
  if (name === "standalone_build_editor_integration_test") return release;
  return full || !FULL_TESTS.has(name);
}
