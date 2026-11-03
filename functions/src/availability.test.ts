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
  toDayWindow,
  weekdayIndex,
} from "./availability";

const afternoon: DayWindow = { available: true, slots: [{ start: 14 * 60, end: 22 * 60 }] };
const closed: DayWindow = { available: false, slots: [{ start: 360, end: 1320 }] };
/** 3-5 PM and 9-10 PM, every day. */
const twice: DayWindow = { available: true, slots: [{ start: 15 * 60, end: 17 * 60 }, { start: 21 * 60, end: 22 * 60 }] };
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

test("with two slots a day, a trip inside either slot is free", () => {
  const b = bus(Array(7).fill(twice));
  assert.ok(isBusFree(b, at("2026-09-14T15:30"), at("2026-09-14T16:30"), [], []));
  assert.ok(isBusFree(b, at("2026-09-14T21:00"), at("2026-09-14T22:00"), [], []));
});

test("a same-day trip may not run across the gap between slots", () => {
  const b = bus(Array(7).fill(twice));
  assert.ok(!isBusFree(b, at("2026-09-14T16:00"), at("2026-09-14T21:30"), [], []));
  assert.ok(!isBusFree(b, at("2026-09-14T18:00"), at("2026-09-14T19:00"), [], [])); // inside the gap
  assert.ok(!isBusFree(b, at("2026-09-14T14:00"), at("2026-09-14T16:00"), [], [])); // before the first slot
});

test("a multi-day trip departs in one slot and returns in a slot on its last day", () => {
  const b = bus(Array(7).fill(twice));
  assert.ok(isBusFree(b, at("2026-09-14T21:00"), at("2026-09-16T16:00"), [], []));
  assert.ok(!isBusFree(b, at("2026-09-14T21:00"), at("2026-09-16T19:00"), [], []));
});

test("stored days are read in the new shape and the old one", () => {
  assert.deepEqual(toDayWindow({ available: true, start: 360, end: 600 }), { available: true, slots: [{ start: 360, end: 600 }] });
  assert.deepEqual(
    toDayWindow({ available: true, start: 900, end: 1020, slots: [{ start: 1260, end: 1320 }, { start: 900, end: 1020 }, { start: 5, end: "x" }] }),
    { available: true, slots: [{ start: 900, end: 1020 }, { start: 1260, end: 1320 }] },
  );
  assert.equal(toDayWindow({ available: true, start: 600, end: 300 }).available, false);
  assert.equal(toDayWindow(null).available, false);
  assert.equal(toDayWindow({ available: true, slots: Array(6).fill({ start: 60, end: 120 }) }).slots.length, 4);
});
