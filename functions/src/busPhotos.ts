import { getFirestore } from "firebase-admin/firestore";
import { getStorage } from "firebase-admin/storage";
import { logger } from "firebase-functions/v2";
import { onDocumentWritten } from "firebase-functions/v2/firestore";
import { onSchedule } from "firebase-functions/v2/scheduler";

/**
 * Keeps Cloud Storage tidy so nothing is paid for that no bus shows.
 *
 * The app never deletes a photo that is already on a bus; it only drops it
 * from the bus's `photos` list. These pick up what is no longer referenced:
 *  - a trigger on every bus change deletes the files that fell out of the list;
 *  - a weekly sweep deletes files nothing refers to that are over a day old
 *    (a form that was abandoned after uploading).
 */

const bucket = () => getStorage().bucket();

type Photo = { id?: unknown; full?: unknown; thumb?: unknown };

/** The photo ids a bus document currently refers to. */
export function photoIds(data: FirebaseFirestore.DocumentData | undefined): Set<string> {
  const ids = new Set<string>();
  const list = Array.isArray(data?.photos) ? (data!.photos as Photo[]) : [];
  for (const p of list) if (typeof p?.id === "string" && p.id) ids.add(p.id);
  return ids;
}

/** `ph-abc` from `buses/bus-1/ph-abc.jpg` or `buses/bus-1/ph-abc_thumb.jpg`. */
export function idOfFile(path: string): string | null {
  const m = /^buses\/[^/]+\/(ph-[A-Za-z0-9_-]+?)(?:_thumb)?\.jpg$/.exec(path);
  return m ? m[1] : null;
}

/** Deletes every file under buses/{busId}/ whose photo id is not in [keep]. */
export async function deleteUnreferenced(busId: string, keep: Set<string>, olderThanMs = 0): Promise<number> {
  const [files] = await bucket().getFiles({ prefix: `buses/${busId}/` });
  const cutoff = Date.now() - olderThanMs;
  let deleted = 0;
  for (const file of files) {
    const id = idOfFile(file.name);
    if (id === null || keep.has(id)) continue;
    if (olderThanMs > 0) {
      const created = Date.parse(String(file.metadata.timeCreated ?? ""));
      if (!Number.isFinite(created) || created > cutoff) continue;
    }
    await file.delete({ ignoreNotFound: true });
    deleted++;
  }
  return deleted;
}

export const cleanBusPhotos = onDocumentWritten({ document: "buses/{id}", region: "asia-south1" }, async (event) => {
  const before = event.data?.before.data();
  const after = event.data?.after.data();
  const removed = [...photoIds(before)].filter((id) => !photoIds(after).has(id));
  if (removed.length === 0) return;
  // Only files that used to be on the bus. A fresh upload that has not been
  // saved yet is not in `before`, so it is never touched here.
  const busId = event.params.id;
  for (const id of removed) {
    for (const name of [`buses/${busId}/${id}.jpg`, `buses/${busId}/${id}_thumb.jpg`]) {
      await bucket().file(name).delete({ ignoreNotFound: true });
    }
  }
  logger.info("removed bus photos", { busId, count: removed.length, bucket: bucket().name });
});

/** Weekly: abandoned uploads that no bus ever referenced. */
export async function sweepOrphanPhotos(): Promise<number> {
  const buses = await getFirestore().collection("buses").get();
  const keepByBus = new Map(buses.docs.map((d) => [d.id, photoIds(d.data())]));
  const [files] = await bucket().getFiles({ prefix: "buses/" });
  const busIds = new Set<string>();
  for (const f of files) {
    const m = /^buses\/([^/]+)\//.exec(f.name);
    if (m) busIds.add(m[1]);
  }
  let deleted = 0;
  for (const busId of busIds) deleted += await deleteUnreferenced(busId, keepByBus.get(busId) ?? new Set(), 24 * 60 * 60 * 1000);
  if (deleted > 0) logger.info("swept orphan bus photos", { deleted });
  return deleted;
}

export const sweepBusPhotos = onSchedule({ schedule: "every sunday 03:00", timeZone: "Asia/Kolkata", region: "asia-south1" }, async () => {
  await sweepOrphanPhotos();
});
