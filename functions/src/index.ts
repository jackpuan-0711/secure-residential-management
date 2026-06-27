import * as admin from "firebase-admin";
import { HttpsError, onCall } from "firebase-functions/v2/https";

admin.initializeApp();

const region = "asia-southeast1";
const db = admin.firestore();
const auth = admin.auth();

type Role = "superadmin" | "admin" | "staff" | "resident" | "public";
type UserStatus = "pending_approval" | "active" | "suspended";

const validRoles = new Set<Role>([
  "superadmin",
  "admin",
  "staff",
  "resident",
  "public",
]);

function requireVerifiedRole(
  request: { auth?: { uid: string; token: admin.auth.DecodedIdToken } },
  allowed: Role[],
): { uid: string; role: Role } {
  const caller = request.auth;
  if (!caller) {
    throw new HttpsError("unauthenticated", "Sign in is required.");
  }
  if (caller.token.email_verified !== true) {
    throw new HttpsError(
      "permission-denied",
      "Verify your email before using this action.",
    );
  }

  const role = caller.token.role;
  if (typeof role !== "string" || !validRoles.has(role as Role)) {
    throw new HttpsError("permission-denied", "No privileged role claim.");
  }
  if (!allowed.includes(role as Role)) {
    throw new HttpsError("permission-denied", "This role is not allowed.");
  }

  return { uid: caller.uid, role: role as Role };
}

function requireVerifiedUser(
  request: { auth?: { uid: string; token: admin.auth.DecodedIdToken } },
): string {
  const caller = request.auth;
  if (!caller) {
    throw new HttpsError("unauthenticated", "Sign in is required.");
  }
  if (caller.token.email_verified !== true) {
    throw new HttpsError(
      "permission-denied",
      "Verify your email before using this action.",
    );
  }
  return caller.uid;
}

function requiredString(data: unknown, key: string): string {
  if (typeof data !== "object" || data === null) {
    throw new HttpsError("invalid-argument", "Request body is required.");
  }

  const value = (data as Record<string, unknown>)[key];
  if (typeof value !== "string" || value.trim().length === 0) {
    throw new HttpsError(
      "invalid-argument",
      `Field "${key}" must be a non-empty string.`,
    );
  }
  return value.trim();
}

async function setRoleClaim(uid: string, role: Role): Promise<void> {
  const user = await auth.getUser(uid);
  await auth.setCustomUserClaims(uid, {
    ...(user.customClaims ?? {}),
    role,
  });
}

function readStatus(data: admin.firestore.DocumentData): UserStatus {
  const status = data.status;
  if (
    status !== "pending_approval" &&
    status !== "active" &&
    status !== "suspended"
  ) {
    throw new HttpsError("failed-precondition", "Profile status is invalid.");
  }
  return status;
}

async function approveResidentInternal(
  targetUid: string,
  approvedByUid: string,
): Promise<void> {
  if (targetUid === approvedByUid) {
    throw new HttpsError(
      "failed-precondition",
      "You cannot approve your own account.",
    );
  }

  await db.runTransaction(async (tx) => {
    const ref = db.collection("users").doc(targetUid);
    const snap = await tx.get(ref);
    if (!snap.exists) {
      throw new HttpsError("not-found", "Resident application not found.");
    }

    const data = snap.data() ?? {};
    if (readStatus(data) !== "pending_approval") {
      throw new HttpsError(
        "failed-precondition",
        "Only pending applications can be approved.",
      );
    }

    const requestedUnit = data.requestedUnit;
    if (typeof requestedUnit !== "string" || requestedUnit.length === 0) {
      throw new HttpsError(
        "failed-precondition",
        "This application has no requested unit.",
      );
    }

    const requestedRole = data.requestedRole;
    const role = data.role;
    const isResidentRequest =
      role === "resident" || requestedRole === "resident";
    if (!isResidentRequest) {
      throw new HttpsError(
        "failed-precondition",
        "This is not a resident application.",
      );
    }

    tx.update(ref, {
      role: "resident",
      status: "active",
      requestedRole: null,
      requestedUnit: null,
      unitNumber: requestedUnit,
      approvedAt: admin.firestore.FieldValue.serverTimestamp(),
      approvedBy: approvedByUid,
      rejectedAt: null,
      rejectedBy: null,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  });
}

async function rejectResidentInternal(
  targetUid: string,
  rejectedByUid: string,
): Promise<void> {
  if (targetUid === rejectedByUid) {
    throw new HttpsError(
      "failed-precondition",
      "You cannot reject your own account.",
    );
  }

  await db.runTransaction(async (tx) => {
    const ref = db.collection("users").doc(targetUid);
    const snap = await tx.get(ref);
    if (!snap.exists) {
      throw new HttpsError("not-found", "Resident application not found.");
    }

    const data = snap.data() ?? {};
    if (readStatus(data) !== "pending_approval") {
      throw new HttpsError(
        "failed-precondition",
        "Only pending applications can be rejected.",
      );
    }

    const requestedRole = data.requestedRole;
    const role = data.role;
    const isResidentRequest =
      role === "resident" || requestedRole === "resident";
    if (!isResidentRequest) {
      throw new HttpsError(
        "failed-precondition",
        "This is not a resident application.",
      );
    }

    tx.update(ref, {
      role: "public",
      status: "active",
      requestedRole: null,
      requestedUnit: null,
      unitNumber: null,
      rejectedAt: admin.firestore.FieldValue.serverTimestamp(),
      rejectedBy: rejectedByUid,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  });
}

/**
 * Health-check callable. Returns {ok: true}.
 */
export const ping = onCall({ region }, async () => {
  return { ok: true };
});

export const approveResident = onCall({ region }, async (request) => {
  const caller = requireVerifiedRole(request, ["admin", "superadmin"]);
  const targetUid = requiredString(request.data, "targetUid");

  await approveResidentInternal(targetUid, caller.uid);

  return { ok: true };
});

export const rejectResident = onCall({ region }, async (request) => {
  const caller = requireVerifiedRole(request, ["admin", "superadmin"]);
  const targetUid = requiredString(request.data, "targetUid");

  await rejectResidentInternal(targetUid, caller.uid);

  return { ok: true };
});

export const addAdmin = onCall({ region }, async (request) => {
  const caller = requireVerifiedRole(request, ["superadmin"]);
  const email = requiredString(request.data, "email").toLowerCase();

  let target: admin.auth.UserRecord;
  try {
    target = await auth.getUserByEmail(email);
  } catch (error) {
    if ((error as { code?: string }).code === "auth/user-not-found") {
      throw new HttpsError(
        "not-found",
        "No account uses this email. Ask the administrator to sign up as a public user first.",
      );
    }
    throw error;
  }

  if (target.uid === caller.uid) {
    throw new HttpsError(
      "failed-precondition",
      "You cannot change your own superadmin access.",
    );
  }
  if (!target.emailVerified) {
    throw new HttpsError(
      "failed-precondition",
      "The account must verify its email before it can become an administrator.",
    );
  }
  if (target.customClaims?.role === "superadmin") {
    throw new HttpsError(
      "failed-precondition",
      "A superadmin account cannot be changed to an administrator.",
    );
  }

  const ref = db.collection("users").doc(target.uid);
  const snap = await ref.get();
  if (!snap.exists) {
    throw new HttpsError(
      "failed-precondition",
      "This account must complete its public profile first.",
    );
  }

  const data = snap.data() ?? {};
  if (data.role !== "public" || readStatus(data) !== "active") {
    throw new HttpsError(
      "failed-precondition",
      "Only an active public account can be added as an administrator.",
    );
  }

  await setRoleClaim(target.uid, "admin");
  try {
    await ref.update({
      role: "admin",
      status: "active",
      requestedRole: null,
      requestedUnit: null,
      unitNumber: null,
      approvedAt: admin.firestore.FieldValue.serverTimestamp(),
      approvedBy: caller.uid,
      rejectedAt: null,
      rejectedBy: null,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  } catch (error) {
    await setRoleClaim(target.uid, "public");
    throw error;
  }

  return { ok: true };
});

export const removeAdmin = onCall({ region }, async (request) => {
  const caller = requireVerifiedRole(request, ["superadmin"]);
  const targetUid = requiredString(request.data, "targetUid");

  if (targetUid === caller.uid) {
    throw new HttpsError(
      "failed-precondition",
      "You cannot remove your own superadmin access.",
    );
  }

  const ref = db.collection("users").doc(targetUid);
  const snap = await ref.get();
  if (!snap.exists) {
    throw new HttpsError("not-found", "Administrator not found.");
  }

  const data = snap.data() ?? {};
  if (data.role !== "admin") {
    throw new HttpsError(
      "failed-precondition",
      "This account is not an administrator.",
    );
  }

  await setRoleClaim(targetUid, "public");
  await auth.revokeRefreshTokens(targetUid);
  await ref.update({
    role: "public",
    status: "active",
    requestedRole: null,
    requestedUnit: null,
    unitNumber: null,
    approvedAt: null,
    approvedBy: null,
    rejectedAt: null,
    rejectedBy: null,
    adminRemovedAt: admin.firestore.FieldValue.serverTimestamp(),
    adminRemovedBy: caller.uid,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  return { ok: true };
});

export const startEvCharging = onCall({ region }, async (request) => {
  const uid = requireVerifiedUser(request);
  const stationId = requiredString(request.data, "stationId");

  let sessionId = "";
  await db.runTransaction(async (tx) => {
    const profileRef = db.collection("users").doc(uid);
    const stationRef = db.collection("ev_stations").doc(stationId);
    const sessionRef = db.collection("ev_sessions").doc();

    const [profileSnap, stationSnap] = await Promise.all([
      tx.get(profileRef),
      tx.get(stationRef),
    ]);

    if (!profileSnap.exists) {
      throw new HttpsError("not-found", "Resident profile not found.");
    }
    const profile = profileSnap.data() ?? {};
    if (
      profile.role !== "resident" ||
      profile.status !== "active" ||
      typeof profile.unitNumber !== "string" ||
      profile.unitNumber.length === 0
    ) {
      throw new HttpsError(
        "permission-denied",
        "Only verified residents can start charging.",
      );
    }

    if (!stationSnap.exists) {
      throw new HttpsError("not-found", "Charging station not found.");
    }
    const station = stationSnap.data() ?? {};
    if (station.status !== "available") {
      throw new HttpsError(
        "failed-precondition",
        "This station is not available right now.",
      );
    }

    tx.set(sessionRef, {
      stationId,
      userId: uid,
      unitNumber: profile.unitNumber,
      startedAt: admin.firestore.FieldValue.serverTimestamp(),
      endedAt: null,
      status: "active",
    });
    tx.update(stationRef, {
      status: "inUse",
      currentSessionId: sessionRef.id,
    });
    sessionId = sessionRef.id;
  });

  return { ok: true, sessionId };
});

export const stopEvCharging = onCall({ region }, async (request) => {
  const caller = requireVerifiedUser(request);
  const stationId = requiredString(request.data, "stationId");

  await db.runTransaction(async (tx) => {
    const stationRef = db.collection("ev_stations").doc(stationId);
    const stationSnap = await tx.get(stationRef);
    if (!stationSnap.exists) {
      throw new HttpsError("not-found", "Charging station not found.");
    }

    const station = stationSnap.data() ?? {};
    const sessionId = station.currentSessionId;
    if (station.status !== "inUse" || typeof sessionId !== "string") {
      throw new HttpsError(
        "failed-precondition",
        "This station is not in use.",
      );
    }

    const sessionRef = db.collection("ev_sessions").doc(sessionId);
    const sessionSnap = await tx.get(sessionRef);
    if (!sessionSnap.exists) {
      throw new HttpsError("not-found", "Charging session not found.");
    }

    const session = sessionSnap.data() ?? {};
    const callerRole = request.auth?.token.role;
    const isAdmin = callerRole === "admin" || callerRole === "superadmin";
    if (session.userId !== caller && !isAdmin) {
      throw new HttpsError(
        "permission-denied",
        "You can only stop a session you started.",
      );
    }
    if (session.status !== "active") {
      throw new HttpsError(
        "failed-precondition",
        "This charging session is already closed.",
      );
    }

    tx.update(sessionRef, {
      status: "completed",
      endedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    tx.update(stationRef, {
      status: "available",
      currentSessionId: null,
    });
  });

  return { ok: true };
});
