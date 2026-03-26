const { onSchedule } = require("firebase-functions/v2/scheduler");
const { initializeApp } = require("firebase-admin/app");
const { getDatabase } = require("firebase-admin/database");

initializeApp();

/**
 * Scheduled function: runs every hour to clean up stale rooms.
 * Deletes rooms (and their publicRooms entries) older than 24 hours.
 */
exports.cleanupStaleRooms = onSchedule(
  {
    schedule: "every 1 hours",
    timeoutSeconds: 120,
    region: "us-central1",
  },
  async () => {
    const db = getDatabase();
    const now = Date.now();
    const cutoffMs = now - 24 * 60 * 60 * 1000;

    console.log(`[cleanup] Running at ${new Date(now).toISOString()}, cutoff: ${new Date(cutoffMs).toISOString()}`);

    const roomsSnap = await db.ref("rooms").once("value");
    if (!roomsSnap.exists()) {
      console.log("[cleanup] No rooms found.");
      return;
    }

    const rooms = roomsSnap.val();
    const updates = {};
    let deletedCount = 0;

    for (const [roomCode, roomData] of Object.entries(rooms)) {
      const createdAt = roomData.createdAt;
      if (typeof createdAt === "number" && createdAt < cutoffMs) {
        updates[`rooms/${roomCode}`] = null;

        if (roomData.isPublic && roomData.groupCode) {
          updates[`publicRooms/${roomData.groupCode}/${roomCode}`] = null;
        }

        deletedCount++;
      }
    }

    // Clean up orphaned publicRooms entries
    const publicSnap = await db.ref("publicRooms").once("value");
    if (publicSnap.exists()) {
      const publicRooms = publicSnap.val();
      for (const [groupCode, groupData] of Object.entries(publicRooms)) {
        if (typeof groupData !== "object" || groupData === null) continue;
        for (const [roomCode, entry] of Object.entries(groupData)) {
          if (!rooms[roomCode]) {
            updates[`publicRooms/${groupCode}/${roomCode}`] = null;
          } else if (typeof entry.createdAt === "number" && entry.createdAt < cutoffMs) {
            updates[`publicRooms/${groupCode}/${roomCode}`] = null;
          }
        }
      }
    }

    if (Object.keys(updates).length > 0) {
      await db.ref().update(updates);
      console.log(`[cleanup] Deleted ${deletedCount} stale rooms. Total updates: ${Object.keys(updates).length}`);
    } else {
      console.log("[cleanup] No stale rooms found.");
    }
  }
);
