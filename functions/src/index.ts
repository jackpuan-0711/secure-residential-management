import * as admin from "firebase-admin";
import { onCall } from "firebase-functions/v2/https";

admin.initializeApp();

/**
 * Health-check callable. Returns {ok: true}.
 *
 * Call this from the Flutter client after wiring up the emulator to confirm
 * the full chain: Flutter SDK → Functions emulator → TypeScript handler.
 * No auth required — intentionally open so it works before any user is signed in.
 */
export const ping = onCall(
  { region: "asia-southeast1" },
  async (_request) => {
    return { ok: true };
  }
);
