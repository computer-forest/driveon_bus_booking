/**
 * Availability rules, ported 1:1 from lib/data/availability.dart.
 *
 * The server is the only judge of whether a bus can be held: the app keeps
 * its copy for the admin calendar and for optimistic display. All times are
 * epoch milliseconds; "days" and "weekdays" are in India Standard Time
 * (UTC+5:30, no daylight saving), because the windows admins set are
 * wall-clock times in India.
 */

const DAY = 24 * 60 * 60 * 1000;
const IST_OFFSET = 330 * 60 * 1000;

/** One stretch of a day when a bus can be chartered, in minutes since midnight. */
export interface Slot {
  start: number;
  end: number;
}

export interface DayWindow {
  available: boolean;
  /** Earliest first; never empty on an available day. */
  slots: Slot[];
}

/** The most slots a bus can have on one weekday. */
export const MAX_SLOTS_PER_DAY = 4;

/**
 * Reads one stored day. Days saved before multi-slot days carry only
 * start/end; malformed slots are dropped.
 */
export function toDayWindow(w: unknown): DayWindow {
  const d = (w ?? {}) as Record<string, unknown>;
  const valid = (s: unknown): s is Slot => {
    const o = s as Record<string, unknown>;
    return !!o && typeof o.start === "number" && typeof o.end === "number" && o.start < o.end;
  };
  const stored = Array.isArray(d.slots) ? d.slots.filter(valid).map((s) => ({ start: s.start, end: s.end })) : [];
  const single = { start: Number(d.start ?? 0), end: Number(d.end ?? 0) };
  const slots = (stored.length > 0 ? stored : valid(single) ? [single] : [])
    .slice(0, MAX_SLOTS_PER_DAY)
    .sort((a, b) => a.start - b.start);
  return { available: d.available === true && slots.length > 0, slots };
}

function slotContaining(day: DayWindow, minutes: number): Slot | undefined {
  return day.slots.find((s) => minutes >= s.start && minutes <= s.end);
}

export interface Bus {
  id: string;
  active: boolean;
  capacity: number;
  weeklyAvailability: DayWindow[];
}

/** A period during which a bus is taken. */
export interface Occupied {
  busId: string;
  start: number;
  end: number;
}

export interface Blackout {
  busId: string;
  from: number;
  to: number;
}

/** Midnight (IST) at the start of the day [ms] falls on. */
export function dayStart(ms: number): number {
  return Math.floor((ms + IST_OFFSET) / DAY) * DAY - IST_OFFSET;
}

/** 0 = Monday ... 6 = Sunday, in IST. */
export function weekdayIndex(ms: number): number {
  return (new Date(ms + IST_OFFSET).getUTCDay() + 6) % 7;
}

/** Minutes since midnight, in IST. */
export function minutesOfDay(ms: number): number {
  const d = new Date(ms + IST_OFFSET);
  return d.getUTCHours() * 60 + d.getUTCMinutes();
}

/** Parses a wall-clock "YYYY-MM-DDTHH:mm" as India time. Null if malformed. */
export function parseIst(text: unknown): number | null {
  if (typeof text !== "string") return null;
  const m = /^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2})/.exec(text);
  if (!m) return null;
  const [y, mo, d, h, mi] = m.slice(1).map(Number);
  if (mo < 1 || mo > 12 || d < 1 || d > 31 || h > 23 || mi > 59) return null;
  return Date.UTC(y, mo - 1, d, h, mi) - IST_OFFSET;
}

function overlaps(aStart: number, aEnd: number, bStart: number, bEnd: number): boolean {
  return aStart < bEnd && bStart < aEnd;
}

function daysTouched(start: number, end: number): number[] {
  const days: number[] = [];
  for (let day = dayStart(start); day <= dayStart(end); day += DAY) days.push(day);
  return days;
}

/** Blackouts are whole days, inclusive of both ends. */
export function isBlackedOut(busId: string, start: number, end: number, blackouts: Blackout[]): boolean {
  return blackouts.some(
    (b) => b.busId === busId && overlaps(start, end, dayStart(b.from), dayStart(b.to) + DAY),
  );
}

/**
 * A bus is free when it is active, every day the charter touches is one the
 * admin marked available, pickup falls inside one of that day's slots, drop
 * falls inside a slot too (the same one, for a same-day trip), no blackout
 * covers the span, and nothing else is booked. On a multi-day charter the
 * slots gate departure and return, not the hours between.
 */
export function isBusFree(
  bus: Bus,
  start: number,
  end: number,
  occupied: Occupied[],
  blackouts: Blackout[],
  bufferBefore = 0,
  bufferAfter = 0,
): boolean {
  if (!bus.active) return false;
  if (bus.weeklyAvailability.length !== 7) return false;

  for (const day of daysTouched(start, end)) {
    if (!bus.weeklyAvailability[weekdayIndex(day)].available) return false;
  }

  const departure = slotContaining(bus.weeklyAvailability[weekdayIndex(start)], minutesOfDay(start));
  if (!departure) return false;
  const arrival = minutesOfDay(end);
  if (dayStart(start) === dayStart(end)) {
    // A same-day trip must fit in one slot: the gap between slots is not bookable.
    if (arrival > departure.end) return false;
  } else if (!slotContaining(bus.weeklyAvailability[weekdayIndex(end)], arrival)) {
    return false;
  }

  if (isBlackedOut(bus.id, start, end, blackouts)) return false;

  return !occupied.some(
    (o) => o.busId === bus.id && overlaps(start, end, o.start - bufferBefore, o.end + bufferAfter),
  );
}

/** Stages in which a booking still takes its bus. */
const FREED_STAGES = new Set(["expired", "cancelled"]);

/** True while a booking occupies its bus: not cancelled or expired, and, for
 *  an unconfirmed hold, not yet past its expiry. */
export function occupiesBus(stage: string, holdExpiresAtMs: number | null, nowMs: number): boolean {
  if (FREED_STAGES.has(stage)) return false;
  if (stage === "requested" && holdExpiresAtMs !== null && holdExpiresAtMs <= nowMs) return false;
  return true;
}
