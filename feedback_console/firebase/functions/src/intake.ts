import {randomUUID} from "node:crypto";
import {getAuth} from "firebase-admin/auth";
import {FieldValue, getFirestore} from "firebase-admin/firestore";
import {getStorage} from "firebase-admin/storage";
import {defineString} from "firebase-functions/params";
import {HttpsError, onRequest} from "firebase-functions/v2/https";
import {formatFeedbackLogs} from "./logFile.js";

const applicationName = defineString("FEEDBACK_APPLICATION_NAME");
const applicationId = defineString("FEEDBACK_APPLICATION_ID");
const storageBucket = defineString("FEEDBACK_STORAGE_BUCKET");
const MB = 1024 * 1024;
type ObjectValue = Record<string, unknown>;
const bad = () => new HttpsError("invalid-argument", "Invalid feedback payload.");
function object(value: unknown): ObjectValue {
  if (!value || typeof value !== "object" || Array.isArray(value)) throw bad();
  return value as ObjectValue;
}
function text(value: unknown, max: number): string {
  if (typeof value !== "string" || value.length > max) throw bad();
  return value;
}
function binary(value: unknown, max: number): Buffer {
  const encoded = text(value, Math.ceil(max / 3) * 4);
  if (!encoded.length || !/^[A-Za-z0-9+/]+={0,2}$/.test(encoded)) throw bad();
  const bytes = Buffer.from(encoded, "base64");
  if (!bytes.length || bytes.length > max || bytes.toString("base64") !== encoded) throw bad();
  return bytes;
}
function mediaType(bytes: Buffer, mime: string): boolean {
  if (mime === "image/png") return bytes.subarray(0, 8).equals(Buffer.from("89504e470d0a1a0a", "hex"));
  if (mime === "image/jpeg") return bytes.subarray(0, 3).equals(Buffer.from("ffd8ff", "hex"));
  if (mime === "image/webp") return bytes.toString("ascii", 0, 4) === "RIFF" && bytes.toString("ascii", 8, 12) === "WEBP";
  if (["video/mp4", "video/quicktime"].includes(mime)) return bytes.toString("ascii", 4, 8) === "ftyp";
  return false;
}

/** Validates portable SDK JSON before allocating Storage objects. */
export function parseFeedback(value: unknown) {
  const data = object(value);
  const mime = text(data.contentType, 40);
  const screenshot = binary(data.imageBase64, 5 * MB);
  if (!mime.startsWith("image/") || !mediaType(screenshot, mime)) throw bad();
  const message = data.message == null ? "" : text(data.message, 10000);
  const title = data.title == null ? "" : text(data.title, 150).trim();
  const kind = data.kind ?? "feedback";
  if (!["feedback", "bug"].includes(String(kind))) throw bad();
  const context: ObjectValue = {};
  const rawContext = data.context == null ? {} : object(data.context);
  for (const key of ["appVersion", "buildNumber", "platform", "operatingSystemVersion", "screenName", "locale"]) {
    if (rawContext[key] !== undefined) context[key] = text(rawContext[key], 250);
  }
  if (rawContext.environment !== undefined) {
    if (!["dev", "stage", "prod"].includes(String(rawContext.environment))) throw bad();
    context.environment = rawContext.environment;
  }
  if (rawContext.metadata !== undefined) {
    const metadata = object(rawContext.metadata);
    if (Object.keys(metadata).length > 20) throw bad();
    context.metadata = Object.fromEntries(Object.entries(metadata).map(([key, val]) => [text(key, 60), text(val, 250)]));
  }
  const capturedAt = text(data.capturedAt, 40);
  if (!Number.isFinite(Date.parse(capturedAt))) throw bad();
  const rawAttachments = data.attachments ?? [];
  if (!Array.isArray(rawAttachments) || rawAttachments.length > 5) throw bad();
  const attachments = rawAttachments.map((raw) => {
    const attachment = object(raw);
    const bytes = binary(attachment.dataBase64, 15 * MB);
    const mimeType = text(attachment.mimeType, 40);
    if (!mediaType(bytes, mimeType)) throw bad();
    return {bytes, mimeType, fileName: text(attachment.fileName, 200)};
  });
  if (attachments.reduce((size, file) => size + file.bytes.length, screenshot.length) > 20 * MB) throw bad();
  const logs = data.logs ?? [];
  if (!Array.isArray(logs) || logs.length > 1000 || JSON.stringify(logs).length > 500000) throw bad();
  const validatedLogs = logs.map((raw) => {
    const log = object(raw);
    const timestamp = text(log.timestamp, 40);
    if (!Number.isFinite(Date.parse(timestamp)) || !["info", "warning", "error"].includes(String(log.level))) throw bad();
    return {timestamp, level: log.level, message: text(log.message, 2000), ...(log.category === undefined ? {} : {category: text(log.category, 100)})};
  });
  const strokes = data.annotationStrokes ?? [];
  if (!Array.isArray(strokes) || strokes.length > 500) throw bad();
  // The SDK submits the rendered image; strokes are used only for the count.
  return {screenshot, mime, message, title, kind, context, capturedAt, attachments, logs: validatedLogs, annotationCount: strokes.length};
}

/** Authenticated intake. Submit access is independent from reviewer access. */
export const feedbackIntake = onRequest({region: "europe-west1", invoker: "public", memory: "512MiB", timeoutSeconds: 120, maxInstances: 3, concurrency: 5}, async (req, res) => {
  res.set("Cache-Control", "no-store");
  if (req.method !== "POST") { res.status(405).json({message: "Use POST."}); return; }
  try {
    const header = req.get("Authorization") ?? "";
    if (!header.startsWith("Bearer ")) throw new HttpsError("unauthenticated", "Sign in to submit feedback.");
    const user = await getAuth().verifyIdToken(header.slice(7), true).catch(() => { throw new HttpsError("unauthenticated", "Sign in again."); });
    const db = getFirestore();
    const member = (await db.doc(`users/${user.uid}`).get()).data();
    if (member?.feedbackCanSubmit !== true) throw new HttpsError("permission-denied", "Feedback submission is not enabled for this account.");
    if (req.rawBody.length > 29 * MB) throw bad();
    const report = parseFeedback(req.body);
    await db.runTransaction(async (tx) => {
      const ref = db.doc(`feedbackRateLimits/${user.uid}`);
      const previous = (await tx.get(ref)).data();
      const now = Date.now();
      const active = now - (previous?.windowStart ?? 0) < 60000;
      const count = active ? previous?.count ?? 0 : 0;
      if (count >= 5) throw new HttpsError("resource-exhausted", "Please wait before submitting another report.");
      tx.set(ref, {windowStart: active ? previous?.windowStart : now, count: count + 1});
    });
    const ref = db.collection("feedbackReports").doc();
    const bucket = getStorage().bucket(storageBucket.value());
    const saved: string[] = [];
    const save = async (path: string, bytes: Buffer, contentType: string) => {
      await bucket.file(path).save(bytes, {resumable: false, metadata: {contentType, metadata: {firebaseStorageDownloadTokens: randomUUID()}}});
      saved.push(path);
      return path;
    };
    try {
      const screenshotPath = await save(`feedback/${ref.id}/screenshot`, report.screenshot, report.mime);
      const attachments = [];
      for (const [index, file] of report.attachments.entries()) {
        const path = await save(`feedback/${ref.id}/media-${index}`, file.bytes, file.mimeType);
        attachments.push({path, fileName: file.fileName, mimeType: file.mimeType, sizeBytes: file.bytes.length});
      }
      const logsPath = report.logs.length ? await save(`feedback/${ref.id}/logs.txt`, Buffer.from(formatFeedbackLogs(report)), "text/plain") : null;
      await ref.set({applicationName: applicationName.value(), applicationId: applicationId.value(), message: report.message, kind: report.kind,
        ...(report.title ? {title: report.title} : {}),
        context: {...report.context, userId: user.uid}, capturedAt: report.capturedAt, annotationCount: report.annotationCount,
        screenshotPath, attachments, logsPath, logCount: report.logs.length,
        logs: report.logs.slice(-20), status: "new", createdAt: FieldValue.serverTimestamp(), updatedAt: FieldValue.serverTimestamp()});
      res.status(201).json({feedbackId: ref.id});
    } catch (error) {
      await Promise.allSettled(saved.map((path) => bucket.file(path).delete()));
      throw error;
    }
  } catch (error) {
    const codes: Record<string, number> = {"unauthenticated": 401, "permission-denied": 403, "invalid-argument": 400, "resource-exhausted": 429};
    res.status(error instanceof HttpsError ? codes[error.code] ?? 503 : 503).json({message: error instanceof HttpsError ? error.message : "Could not store feedback. Please try again."});
  }
});
