/**
 * Calls a person is waiting on (sign-in, search, hold, staff actions) get a
 * full vCPU so they answer quickly and start fast. Everything that runs in the
 * background (the hold sweep, audit and notification triggers, photo cleanup)
 * keeps the small default set in index.ts. Both only bill while a request or
 * event is actually running.
 */
export const interactive = { cpu: 1 } as const;
