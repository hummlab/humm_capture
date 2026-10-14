import {HttpsError} from "firebase-functions/v2/https";

/** Keep server authorization aligned with the existing console role contract. */
export function assertFeedbackAdministrator(user: Record<string, unknown> | undefined): void {
  if (user?.feedbackRole !== "admin" && user?.role !== "admin") {
    throw new HttpsError("permission-denied", "A feedback administrator is required.");
  }
}
