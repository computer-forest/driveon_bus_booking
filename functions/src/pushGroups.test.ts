import { strict as assert } from "node:assert";
import { test } from "node:test";
import { PUSH_GROUPS } from "./notifications";

test("only reminders and trip progress can be switched off", () => {
  assert.equal(PUSH_GROUPS["hold-expiring"], "reminders");
  assert.equal(PUSH_GROUPS["trip-started"], "tripUpdates");
});

test("fares, confirmations, cancellations, bus changes and staff alerts are always pushed", () => {
  for (const kind of ["cost-confirmed", "confirmed", "cancelled", "reallocated", "cancellation-declined", "staff-new-request", "staff-hold-expiring"]) {
    assert.equal(PUSH_GROUPS[kind], undefined, kind);
  }
});
