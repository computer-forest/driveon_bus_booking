import { getAuth } from "firebase-admin/auth";
import { getFirestore, FieldValue } from "firebase-admin/firestore";
import { logger } from "firebase-functions/v2";
import { onDocumentWrittenWithAuthContext } from "firebase-functions/v2/firestore";

/**
 * Writes an audit entry (ADM-13) for every staff change to master data.
 *
 * The app cannot write `auditLog` (rules deny it); this trigger does, so
 * nothing a staff member changes goes unrecorded. Who made the change is
 * `updatedBy`, which the rules force to equal the signed-in user. Writes from
 * the server itself (seeding, migrations) carry no `updatedBy`, or one that
 * starts with "system:", and are not audited.
 *
 * A deletion carries no new document, so its author is read from the event's
 * auth context (who made the Firestore write) instead.
 */

type Data = Record<string, unknown>;

const SPECS: Record<string, { entity: string; label: (id: string, d: Data) => string }> = {
  buses: { entity: "Bus", label: (_, d) => String(d.regNumber ?? "") },
  busAdmin: { entity: "Bus GPS link", label: (id) => `bus ${id}` },
  vendors: { entity: "Vendor", label: (_, d) => String(d.name ?? "") },
  drivers: { entity: "Driver", label: (_, d) => String(d.name ?? "") },
  locations: { entity: "Location", label: (_, d) => `${d.area ?? ""}, ${d.city ?? ""}` },
  blackouts: { entity: "Blackout", label: (_, d) => `${d.busReg ?? ""}: ${d.reason ?? ""}` },
  templates: { entity: "Template", label: (_, d) => String(d.name ?? "") },
  packages: { entity: "Package rates", label: (_, d) => String(d.city ?? "") },
  faqs: { entity: "FAQ", label: (_, d) => String(d.question ?? "") },
  legal: { entity: "Legal text", label: (id) => (id === "terms" ? "Terms & Conditions" : "Privacy Policy") },
  config: { entity: "Configuration", label: () => "App configuration" },
};

const STAMPS = new Set(["updatedAt", "updatedBy"]);

function changedFields(before: Data, after: Data): string[] {
  const keys = new Set([...Object.keys(before), ...Object.keys(after)]);
  return [...keys].filter((k) => !STAMPS.has(k) && JSON.stringify(before[k]) !== JSON.stringify(after[k])).sort();
}

async function actorName(uid: string): Promise<string> {
  try {
    const user = await getAuth().getUser(uid);
    return user.displayName ?? uid.replace(/^staff_/, "+");
  } catch {
    return uid;
  }
}

function makeTrigger(collection: string) {
  const spec = SPECS[collection];
  return onDocumentWrittenWithAuthContext({ document: `${collection}/{id}`, region: "asia-south1" }, async (event) => {
    const before = (event.data?.before.data() ?? undefined) as Data | undefined;
    const after = (event.data?.after.data() ?? undefined) as Data | undefined;
    const id = event.params.id;

    let action: string;
    let actor: string;
    let actorUid: string | null = null;
    let detail = spec.label(id, (after ?? before) as Data);

    if (after) {
      const by = typeof after.updatedBy === "string" ? after.updatedBy : "";
      if (!by || by.startsWith("system:")) return;
      actorUid = by;
      actor = await actorName(by);
      if (!before) {
        action = `${spec.entity} added`;
      } else {
        const fields = changedFields(before, after);
        if (fields.length === 0) return;
        action = `${spec.entity} updated`;
        // Never log what a staff-only field holds, only that it changed.
        detail += ` · changed: ${fields.join(", ")}`;
      }
    } else {
      const by = typeof before?.updatedBy === "string" ? before.updatedBy : "";
      if (by.startsWith("system:")) return;
      action = `${spec.entity} removed`;
      // Only a signed-in person's delete is attributed; server writes are not.
      const signedIn = event.authId && !["service_account", "api_key", "system", "unauthenticated"].includes(event.authType);
      if (signedIn) {
        const uid = String(event.authId);
        const name = await actorName(uid);
        // An id that is not a known account (the emulator sends a placeholder)
        // is not recorded as the author.
        actor = name === uid ? "Staff" : name;
        actorUid = name === uid ? null : uid;
      } else {
        actor = "Staff";
      }
    }

    await getFirestore().collection("auditLog").add({
      actor,
      actorUid,
      action,
      detail,
      collection,
      docId: id,
      at: FieldValue.serverTimestamp(),
    });
    logger.info("audit", { collection, id, action });
  });
}

export const auditBuses = makeTrigger("buses");
export const auditBusAdmin = makeTrigger("busAdmin");
export const auditVendors = makeTrigger("vendors");
export const auditDrivers = makeTrigger("drivers");
export const auditLocations = makeTrigger("locations");
export const auditBlackouts = makeTrigger("blackouts");
export const auditTemplates = makeTrigger("templates");
export const auditPackages = makeTrigger("packages");
export const auditFaqs = makeTrigger("faqs");
export const auditLegal = makeTrigger("legal");
export const auditConfig = makeTrigger("config");
