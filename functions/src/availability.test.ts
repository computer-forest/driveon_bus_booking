import { strict as assert } from "node:assert";
import { test } from "node:test";
import {
  Bus,
  DayWindow,
  Occupied,
  isBusFree,
  minutesOfDay,
  occupiesBus,
  parseIst,
  weekdayIndex,
} from "./availability";

const afternoon: DayWindow = { available: true, start: 14 * 60, end: 22 * 60 };
const closed: DayWindow = { available: false, start: 360, end: 1320 };
const bus = (week: DayWindow[], active = true): Bus => ({ id: "b1", active, capacity: 20, weeklyAvailability: week });
const weekdaysOnly = [afternoon, afternoon, afternoon, afternoon, afternoon, closed, closed];
const at = (s: string) => parseIst(s)!;

test("IST wall-clock times round trip through weekday and minutes", () => {
  const monday = at("2026-09-14T15:30"); // Monday
  assert.equal(weekdayIndex(monday), 0);
  assert.equal(minutesOfDay(monday), 15 * 60 + 30);
  assert.equal(weekdayIndex(at("2026-09-20T01:00")), 6); // Sunday early morning, still Sunday in IST
  assert.equal(parseIst("2026-13-01T00:00"), null);
  assert.equal(parseIst("nonsense"), null);
});

test("free inside the weekday window, not outside it", () => {
  const b = bus(weekdaysOnly);
  assert.ok(isBusFree(b, at("2026-09-14T15:00"), at("2026-09-14T20:00"), [], []));
  assert.ok(!isBusFree(b, at("2026-09-14T13:00"), at("2026-09-14T20:00"), [], [])); // leaves before it opens
  assert.ok(!isBusFree(b, at("2026-09-14T15:00"), at("2026-09-14T23:00"), [], [])); // back after it closes
});

test("a closed weekday rules the bus out, including in the middle of a multi-day trip", () => {
  const b = bus(weekdaysOnly);
  assert.ok(!isBusFree(b, at("2026-09-19T15:00"), at("2026-09-19T20:00"), [], [])); // Saturday
  assert.ok(!isBusFree(b, at("2026-09-18T15:00"), at("2026-09-21T20:00"), [], [])); // spans the weekend
});

test("overnight hours between departure and return are not gated", () => {
  const b = bus([afternoon, afternoon, afternoon, afternoon, afternoon, afternoon, afternoon]);
  assert.ok(isBusFree(b, at("2026-09-14T15:00"), at("2026-09-15T20:00"), [], []));
});

test("an inactive bus is never free", () => {
  assert.ok(!isBusFree(bus(weekdaysOnly, false), at("2026-09-14T15:00"), at("2026-09-14T20:00"), [], []));
});

test("an overlapping booking blocks it; back-to-back does not", () => {
  const b = bus(weekdaysOnly);
  const taken: Occupied[] = [{ busId: "b1", start: at("2026-09-14T15:00"), end: at("2026-09-14T18:00") }];
  assert.ok(!isBusFree(b, at("2026-09-14T17:00"), at("2026-09-14T20:00"), taken, []));
  assert.ok(isBusFree(b, at("2026-09-14T18:00"), at("2026-09-14T20:00"), taken, []));
  const otherBus: Occupied[] = [{ busId: "b2", start: at("2026-09-14T15:00"), end: at("2026-09-14T18:00") }];
  assert.ok(isBusFree(b, at("2026-09-14T15:00"), at("2026-09-14T20:00"), otherBus, []));
});

test("buffers widen existing bookings", () => {
  const b = bus(weekdaysOnly);
  const taken: Occupied[] = [{ busId: "b1", start: at("2026-09-14T15:00"), end: at("2026-09-14T18:00") }];
  assert.ok(!isBusFree(b, at("2026-09-14T18:00"), at("2026-09-14T20:00"), taken, [], 0, 45 * 60000));
});

test("a blackout covers its whole days, inclusive of both ends", () => {
  const b = bus(weekdaysOnly);
  const black = [{ busId: "b1", from: at("2026-09-15T00:00"), to: at("2026-09-16T00:00") }];
  assert.ok(!isBusFree(b, at("2026-09-16T15:00"), at("2026-09-16T20:00"), [], black));
  assert.ok(isBusFree(b, at("2026-09-17T15:00"), at("2026-09-17T20:00"), [], black));
});

test("which bookings still occupy a bus", () => {
  const now = at("2026-09-14T10:00");
  assert.ok(occupiesBus("confirmed", null, now));
  assert.ok(occupiesBus("requested", now + 1000, now));
  assert.ok(!occupiesBus("requested", now - 1000, now)); // lapsed hold, even if the sweeper has not run
  assert.ok(!occupiesBus("expired", null, now));
  assert.ok(!occupiesBus("cancelled", null, now));
});
