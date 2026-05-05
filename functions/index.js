/* Cloud Functions for MangoSense notifications */

const functions = require("firebase-functions");
const admin = require("firebase-admin");
const nodemailer = require("nodemailer");

// Initialize admin SDK once
try {
  admin.app();
} catch (e) {
  admin.initializeApp();
}

const db = admin.firestore();
const messaging = admin.messaging();

// Email configuration
const transporter = nodemailer.createTransport({
  service: "gmail", // You can change this to other services
  auth: {
    user: functions.config().gmail?.email || "your-email@gmail.com",
    pass: functions.config().gmail?.password || "your-app-password",
  },
});

// Function to send email notification
async function sendEmailNotification(to, subject, htmlContent) {
  try {
    const mailOptions = {
      from: functions.config().gmail?.email || "your-email@gmail.com",
      to: to,
      subject: subject,
      html: htmlContent,
    };

    const result = await transporter.sendMail(mailOptions);
    console.log("Email sent successfully:", result.messageId);
    return { success: true, messageId: result.messageId };
  } catch (error) {
    console.error("Error sending email:", error);
    return { success: false, error: error.message };
  }
}

// Utility: send a notification to a list of device tokens
async function sendToTokens(tokens, payload) {
  if (!tokens || tokens.length === 0)
    return { successCount: 0, failureCount: 0 };
  const response = await messaging.sendEachForMulticast(
    { tokens, ...payload },
    false,
  );
  return response;
}

// Trigger 1: When a new scan request is created → notify experts
exports.notifyExpertsOnNewRequest = functions.firestore
  .document("scan_requests/{requestId}")
  .onCreate(async (snap, context) => {
    const data = snap.data() || {};
    const status = data.status || "pending";
    if (status !== "pending" && status !== "pending_review") return null;

    // If already notified for experts, skip
    if (data.expertsNotified === true) return null;

    const userName = data.userName || "A farmer";
    const requestId = context.params.requestId;

    const title = "New review request";
    const body = `${userName} submitted a leaf scan for expert review.`;

    // Broadcast to all expert devices via topic
    await messaging.send({
      topic: "experts",
      notification: {
        title,
        body,
      },
      data: {
        type: "scan_request_created",
        requestId: String(requestId || ""),
        userName: String(userName || ""),
      },
    });

    // Mark as notified to prevent duplicates
    try {
      await db
        .collection("scan_requests")
        .doc(requestId)
        .set({ expertsNotified: true }, { merge: true });
    } catch (_) {}

    return null;
  });

// Trigger 1b: When status transitions into pending/pending_review → notify experts
exports.notifyExpertsOnPendingUpdate = functions.firestore
  .document("scan_requests/{requestId}")
  .onUpdate(async (change, context) => {
    const before = change.before.data() || {};
    const after = change.after.data() || {};

    const beforeStatus = before.status || "";
    const afterStatus = after.status || "";

    const becamePending =
      beforeStatus !== afterStatus &&
      (afterStatus === "pending" || afterStatus === "pending_review");

    if (!becamePending) return null;

    // If experts already notified, skip
    if (after.expertsNotified === true) return null;

    const userName = after.userName || before.userName || "A farmer";
    const requestId = context.params.requestId;

    const title = "New review request";
    const body = `${userName} submitted a leaf scan for expert review.`;

    await messaging.send({
      topic: "experts",
      notification: { title, body },
      data: {
        type: "scan_request_created",
        requestId: String(requestId || ""),
        userName: String(userName || ""),
      },
    });

    // Mark as notified to prevent duplicates
    try {
      await db
        .collection("scan_requests")
        .doc(requestId)
        .set({ expertsNotified: true }, { merge: true });
    } catch (_) {}

    return null;
  });

// Trigger 2: When a scan request is reviewed/completed → notify the farmer
exports.notifyUserOnReviewCompleted = functions.firestore
  .document("scan_requests/{requestId}")
  .onUpdate(async (change, context) => {
    const before = change.before.data() || {};
    const after = change.after.data() || {};

    const beforeStatus = before.status || "";
    const afterStatus = after.status || "";

    // Only proceed when transitioning into completed/reviewed
    if (
      beforeStatus === afterStatus ||
      (afterStatus !== "completed" && afterStatus !== "reviewed")
    ) {
      return null;
    }

    // If already notified user for completion, skip
    if (after.userNotifiedCompleted === true) return null;

    const userId = after.userId || before.userId;
    if (!userId) return null;

    // Get farmer token and notification preference
    const userDoc = await db.collection("users").doc(userId).get();
    const user = userDoc.exists ? userDoc.data() || {} : {};
    const token = user.fcmToken;
    const enabled = user.enableNotifications;
    if (!token || enabled === false) return null;

    const expertName = after.expertName || "An expert";
    const title = "Your review is ready";
    const body = `${expertName} has completed the analysis of your leaf scan.`;

    const requestId = context.params.requestId;

    const payload = {
      notification: {
        title,
        body,
      },
      data: {
        type: "scan_request_completed",
        requestId: String(requestId || ""),
        expertName: String(expertName || ""),
      },
    };

    await sendToTokens([token], payload);

    // Mark as notified to prevent duplicates
    try {
      await db
        .collection("scan_requests")
        .doc(requestId)
        .set({ userNotifiedCompleted: true }, { merge: true });
    } catch (_) {}
    return null;
  });

// Trigger 3: When a user's status changes to "active" → send email notification
exports.notifyUserOnApproval = functions.firestore
  .document("users/{userId}")
  .onUpdate(async (change, context) => {
    const before = change.before.data() || {};
    const after = change.after.data() || {};

    const beforeStatus = before.status || "";
    const afterStatus = after.status || "";

    // Only proceed when status changes to "active"
    if (beforeStatus === afterStatus || afterStatus !== "active") {
      return null;
    }

    // If already notified for approval, skip
    if (after.emailNotifiedApproval === true) return null;

    const userEmail = after.email;
    const userName = after.fullName || "User";

    if (!userEmail) {
      console.log("No email found for user approval notification");
      return null;
    }

    const subject = "🎉 Welcome to MangoSense - Your Account is Approved!";
    const htmlContent = `
      <!DOCTYPE html>
      <html>
      <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Account Approved - MangoSense</title>
        <style>
          body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
          .container { max-width: 600px; margin: 0 auto; padding: 20px; }
          .header { background: linear-gradient(135deg, #4CAF50, #45a049); color: white; padding: 30px; text-align: center; border-radius: 10px 10px 0 0; }
          .content { background: #f9f9f9; padding: 30px; border-radius: 0 0 10px 10px; }
          .button { display: inline-block; background: #4CAF50; color: white; padding: 12px 30px; text-decoration: none; border-radius: 5px; margin: 20px 0; }
          .footer { text-align: center; margin-top: 30px; color: #666; font-size: 14px; }
        </style>
      </head>
      <body>
        <div class="container">
          <div class="header">
            <h1>🎉 Welcome to MangoSense!</h1>
            <p>Your account has been approved and is now active</p>
          </div>
          <div class="content">
            <h2>Hello ${userName}!</h2>
            <p>Great news! Your MangoSense account has been reviewed and approved by our team. You can now access all the features of our mango disease detection app.</p>
            
            <h3>What you can do now:</h3>
            <ul>
              <li>🔍 Scan mango leaves for disease detection</li>
              <li>📊 View detailed analysis reports</li>
              <li>👨‍🌾 Get expert recommendations for treatment</li>
              <li>📱 Access your scan history and progress</li>
            </ul>
            
            <p>Simply log in to your account using the same credentials you used during registration to start using MangoSense.</p>
            
            <p><strong>Next Steps:</strong></p>
            <ul>
              <li>Open the MangoSense app on your device</li>
              <li>Log in with your registered email and password</li>
              <li>Start detecting mango diseases and getting expert advice</li>
            </ul>
            
            <p><strong>Need help?</strong> If you have any questions or need assistance, feel free to contact our support team.</p>
          </div>
          <div class="footer">
            <p>Best regards,<br>The MangoSense Team</p>
            <p>This is an automated message. Please do not reply to this email.</p>
          </div>
        </div>
      </body>
      </html>
    `;

    // Send email notification
    const emailResult = await sendEmailNotification(
      userEmail,
      subject,
      htmlContent,
    );

    if (emailResult.success) {
      console.log(`Approval email sent to ${userEmail}`);

      // Mark as notified to prevent duplicates
      try {
        await db
          .collection("users")
          .doc(context.params.userId)
          .set({ emailNotifiedApproval: true }, { merge: true });
      } catch (error) {
        console.error("Error updating email notification status:", error);
      }
    } else {
      console.error(
        `Failed to send approval email to ${userEmail}:`,
        emailResult.error,
      );
    }

    return null;
  });
