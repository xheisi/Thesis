const { onCall } = require("firebase-functions/v2/https");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const admin = require("firebase-admin");
const nodemailer = require("nodemailer");
const stripe = require("stripe")("YOUR_STRIPE_SECRET_KEY");
admin.initializeApp();

const GMAIL_USER = "YOUR_GMAIL@gmail.com";
const GMAIL_APP_PASSWORD = "YOUR_APP_PASSWORD";

function createTransporter() {
  return nodemailer.createTransport({
    service: "gmail",
    auth: { user: GMAIL_USER, pass: GMAIL_APP_PASSWORD },
  });
}

// ─── Helper: save to Firestore inbox + send FCM push ─────────────────────
async function sendNotification({ userId, title, body, type }) {
  await admin.firestore()
    .collection("users").doc(userId)
    .collection("notifications").add({
      title, body, type,
      read: false,
      created_at: admin.firestore.FieldValue.serverTimestamp(),
    });

  const userDoc = await admin.firestore().collection("users").doc(userId).get();
  const token = userDoc.data()?.fcm_token;
  if (!token) return;
  try {
    await admin.messaging().send({
      token,
      notification: { title, body },
      data: { type, userId },
      android: { priority: "high" },
      apns: { payload: { aps: { sound: "default", badge: 1 } } },
    });
  } catch (err) {
    console.error("FCM send failed:", err.message);
  }
}

// ─── Create Payment Intent ────────────────────────────────────────────────
exports.createPaymentIntent = onCall(
  { invoker: "public" },
  async (request) => {
    const { amount, currency } = request.data;
    const paymentIntent = await stripe.paymentIntents.create({
      amount: Math.round(amount),
      currency: (currency || "eur").toLowerCase(),
      payment_method_types: ["card"],
    });
    return { clientSecret: paymentIntent.client_secret };
  }
);

// ─── Create Staff Account ─────────────────────────────────────────────────
exports.createStaffAccount = onCall(
  { invoker: "public" },
  async (request) => {
    const callerUid = request.auth?.uid;
    if (!callerUid) throw new Error("Nuk jeni të kyçur.");

    const callerDoc = await admin.firestore().collection("users").doc(callerUid).get();
    const callerRole = callerDoc.data()?.role;
    if (callerRole !== "super_admin" && callerRole !== "line_admin") {
      throw new Error("Nuk keni leje për këtë veprim.");
    }

    const { name, surname, email, role, lineId, lineName } = request.data;
    if (callerRole === "line_admin" && role !== "faturino") {
      throw new Error("Line admin mund të krijojë vetëm faturino.");
    }

    const tempPassword = request.data.password;
    if (!tempPassword || tempPassword.length < 6) {
      throw new Error("Fjalëkalimi duhet të ketë të paktën 6 karaktere.");
    }

    let userRecord;
    try {
      userRecord = await admin.auth().createUser({
        email: email.trim(),
        password: tempPassword,
        displayName: `${name} ${surname}`.trim(),
      });
    } catch (err) {
      if (err.code === "auth/email-already-exists") throw new Error("Ky email ekziston tashmë.");
      throw new Error("Gabim gjatë krijimit të llogarisë: " + err.message);
    }

    await admin.firestore().collection("users").doc(userRecord.uid).set({
      name: name.trim(),
      surname: surname.trim(),
      email: email.trim(),
      role, status: "active",
      line_id: lineId || null,
      line_name: lineName || null,
      created_by: callerUid,
      created_at: admin.firestore.FieldValue.serverTimestamp(),
    });

    try {
      const transporter = createTransporter();
      const roleLabel = role === "line_admin" ? "Line Admin" : "Faturino";
      await transporter.sendMail({
        from: `"Urbane App" <${GMAIL_USER}>`,
        to: email.trim(),
        subject: "Mirësevini në Urbane — kredencialet tuaja",
        html: `
          <div style="font-family:sans-serif;max-width:480px;margin:auto;padding:32px;background:#f8f9fa;border-radius:12px">
            <h2 style="color:#3A7DFF">Mirësevini në Urbane! 🚌</h2>
            <p>Llogaria juaj si <strong>${roleLabel}</strong> u krijua.</p>
            ${lineName ? `<p>Linja: <strong>${lineName}</strong></p>` : ""}
            <div style="background:#fff;border-radius:10px;padding:20px;margin:20px 0;border:1px solid #e0e0e0">
              <p><strong>Email:</strong> ${email.trim()}</p>
              <p><strong>Fjalëkalimi:</strong></p>
              <p style="font-family:monospace;font-size:20px;color:#3A7DFF;font-weight:bold">${tempPassword}</p>
            </div>
          </div>`,
      });
    } catch (emailErr) {
      console.error("Email failed:", emailErr.message);
    }

    return { uid: userRecord.uid, tempPassword };
  }
);

// ─── Firestore trigger: send FCM push on new notification doc ─────────────
exports.sendPushOnNotification = onDocumentCreated(
  {
    document: "users/{userId}/notifications/{notifId}",
    region: "europe-west3",
  },
  async (event) => {
    const data = event.data?.data();
    if (!data) return;
    const userId = event.params.userId;
    const { title, body, type } = data;
    const userDoc = await admin.firestore().collection("users").doc(userId).get();
    const token = userDoc.data()?.fcm_token;
    if (!token) return;
    try {
      await admin.messaging().send({
        token,
        notification: { title, body },
        data: { type: type || "system", userId },
        android: { priority: "high" },
        apns: { payload: { aps: { sound: "default", badge: 1 } } },
      });
    } catch (err) {
      console.error("FCM push failed:", err.message);
    }
  }
);

// ─── Scheduled: Daily 9am — notify users whose abone expires TOMORROW ─────
exports.checkExpiringAbonements = onSchedule(
  { schedule: "0 9 * * *", timeZone: "Europe/Tirane" },
  async () => {
    const now = new Date();
    const tomorrow = new Date(now);
    tomorrow.setDate(tomorrow.getDate() + 1);
    const startOfTomorrow = new Date(tomorrow.setHours(0, 0, 0, 0));
    const endOfTomorrow = new Date(tomorrow.setHours(23, 59, 59, 999));

    const snapshot = await admin.firestore()
      .collection("abonements")
      .where("status", "==", "active")
      .where("valid_until", ">=", admin.firestore.Timestamp.fromDate(startOfTomorrow))
      .where("valid_until", "<=", admin.firestore.Timestamp.fromDate(endOfTomorrow))
      .get();

    for (const doc of snapshot.docs) {
      const userId = doc.data().user_id;
      if (!userId) continue;
      await sendNotification({
        userId,
        title: "Abonja skadon nesër ⚠️",
        body: "Afati i abonës suaj mbaron sot, mos harroni të paguani muajin tjetër!",
        type: "abone_expiring",
      });
    }

    // Auto-expire any overdue abonements silently
    const expiredSnap = await admin.firestore()
      .collection("abonements")
      .where("status", "==", "active")
      .where("valid_until", "<", admin.firestore.Timestamp.fromDate(now))
      .get();

    for (const doc of expiredSnap.docs) {
      await doc.reference.update({ status: "expired" });
    }

    console.log(`Expiring: ${snapshot.size}, Expired: ${expiredSnap.size}`);
  }
);

// ─── Scheduled: 1st of every month 00:01 — remind ALL passengers ─────────
exports.monthlyAboneReminder = onSchedule(
  { schedule: "1 0 1 * *", timeZone: "Europe/Tirane" },
  async () => {
    // Activate any approved_pending_activation abonements
    const pendingSnap = await admin.firestore()
      .collection("abonements")
      .where("status", "==", "approved_pending_activation")
      .get();

    const now = new Date();
    const endOfMonth = new Date(now.getFullYear(), now.getMonth() + 1, 0, 23, 59, 59);

    for (const doc of pendingSnap.docs) {
      await doc.reference.update({
        status: "active",
        valid_from: admin.firestore.Timestamp.fromDate(now),
        valid_until: admin.firestore.Timestamp.fromDate(endOfMonth),
        activated_at: admin.firestore.FieldValue.serverTimestamp(),
      });
    }

    // Notify ALL passengers regardless of abone status
    const usersSnap = await admin.firestore()
      .collection("users")
      .where("role", "==", "passenger")
      .where("status", "==", "active")
      .get();

    for (const userDoc of usersSnap.docs) {
      await sendNotification({
        userId: userDoc.id,
        title: "Abonja e këtij muaji është hapur! 🚌",
        body: "Blini abonenë dhe udhëtim të këndshëm!",
        type: "monthly_reminder",
      });
    }

    console.log(`Monthly reminder sent to ${usersSnap.size} passengers.`);
  }
);