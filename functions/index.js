// functions/index.js
const functions = require('firebase-functions');
const admin = require('firebase-admin');
const twilio = require('twilio');

admin.initializeApp();

// ============================================================================
// TWILIO CONFIGURATION
// ============================================================================
const TWILIO_ACCOUNT_SID = 'AC496c5573ed02397f8f4b38325f28aada';
const TWILIO_AUTH_TOKEN = 'a33e8a591fde4927a9a8990dd2ac7c19';
const TWILIO_PHONE_NUMBER = '+233557881454';

const twilioClient = twilio(TWILIO_ACCOUNT_SID, TWILIO_AUTH_TOKEN);

// ============================================================================
// SEND OTP FUNCTION (Combined SMS + Email + Firestore)
// ============================================================================
exports.sendOTP = functions.https.onCall(async (data, context) => {
  try {
    const { email, phone, name, otpCode, type } = data;

    // Validate input
    if (!email || !phone || !otpCode) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Email, phone, and OTP code are required'
      );
    }

    console.log(`🔐 Sending OTP ${otpCode} to ${email} and ${phone}`);

    const results = {
      email: null,
      sms: null,
      firestore: null,
    };

    // 1. Send Email via Firestore mail collection
    try {
      const emailData = {
        to: [email.toLowerCase().trim()],
        message: {
          subject: 'S3TS Account Registration - Verification Code',
          html: buildEmailTemplate(name, otpCode),
        },
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        status: 'pending',
        type: type || 'registration',
      };

      const emailDoc = await admin.firestore().collection('mail').add(emailData);
      results.email = { success: true, id: emailDoc.id };
      console.log('✅ Email queued successfully');
    } catch (emailError) {
      console.error('❌ Email error:', emailError);
      results.email = { success: false, error: emailError.message };
    }

    // 2. Send SMS via Twilio
    try {
      let formattedPhone = phone.trim();

      // Format phone number for Ghana (+233)
      if (!formattedPhone.startsWith('+')) {
        // Remove leading zeros and add Ghana country code
        formattedPhone = '+233' + formattedPhone.replace(/^0+/, '');
      }

      const smsMessage = `Hello ${name}, your S3TS verification code is: ${otpCode}. Valid for 10 minutes. Do not share this code.`;

      console.log(`📱 Sending SMS to ${formattedPhone}`);

      const twilioResponse = await twilioClient.messages.create({
        body: smsMessage,
        to: formattedPhone,
        from: TWILIO_PHONE_NUMBER,
      });

      // Log SMS in Firestore
      await admin.firestore().collection('sms_logs').add({
        to: formattedPhone,
        originalPhone: phone,
        message: smsMessage,
        type: 'otp',
        status: 'sent',
        twilioSid: twilioResponse.sid,
        twilioStatus: twilioResponse.status,
        sentAt: admin.firestore.FieldValue.serverTimestamp(),
        metadata: {
          email: email,
          name: name,
          otpCode: otpCode,
        },
      });

      results.sms = {
        success: true,
        twilioSid: twilioResponse.sid,
        status: twilioResponse.status,
        phone: formattedPhone,
      };

      console.log(`✅ SMS sent successfully. SID: ${twilioResponse.sid}`);
    } catch (smsError) {
      console.error('❌ SMS error:', smsError);
      results.sms = { success: false, error: smsError.message };

      // Log failed SMS
      await admin.firestore().collection('sms_logs').add({
        to: phone,
        message: `OTP: ${otpCode}`,
        type: 'otp',
        status: 'failed',
        error: smsError.message,
        failedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }

    // 3. Store OTP in Firestore for verification
    try {
      const otpData = {
        email: email.toLowerCase().trim(),
        phone: phone.trim(),
        code: otpCode,
        used: false,
        attempts: 0,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        expiresAt: admin.firestore.Timestamp.fromDate(
          new Date(Date.now() + 10 * 60 * 1000) // 10 minutes
        ),
        type: type || 'registration',
      };

      const otpDoc = await admin.firestore().collection('otpCodes').add(otpData);
      results.firestore = { success: true, id: otpDoc.id };
      console.log('✅ OTP stored in Firestore');
    } catch (firestoreError) {
      console.error('❌ Firestore error:', firestoreError);
      results.firestore = { success: false, error: firestoreError.message };
    }

    // Determine overall success
    const overallSuccess = results.email.success || results.sms.success;

    return {
      success: overallSuccess,
      results: results,
      message: overallSuccess
        ? 'OTP sent successfully'
        : 'Failed to send OTP via all channels',
    };
  } catch (error) {
    console.error('❌ Error in sendOTP:', error);
    throw new functions.https.HttpsError(
      'internal',
      `Failed to send OTP: ${error.message}`
    );
  }
});

// ============================================================================
// VERIFY OTP FUNCTION
// ============================================================================
exports.verifyOTP = functions.https.onCall(async (data, context) => {
  try {
    const { email, code } = data;

    if (!email || !code) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Email and OTP code are required'
      );
    }

    console.log(`🔍 Verifying OTP for ${email}`);

    // Find the OTP record
    const otpSnapshot = await admin
      .firestore()
      .collection('otpCodes')
      .where('email', '==', email.toLowerCase().trim())
      .where('code', '==', code.trim())
      .where('used', '==', false)
      .orderBy('createdAt', 'desc')
      .limit(1)
      .get();

    if (otpSnapshot.empty) {
      console.log('❌ Invalid OTP code');
      return {
        success: false,
        message: 'Invalid OTP code',
      };
    }

    const otpDoc = otpSnapshot.docs[0];
    const otpData = otpDoc.data();

    // Check if OTP is expired
    const now = admin.firestore.Timestamp.now();
    if (now.toMillis() > otpData.expiresAt.toMillis()) {
      console.log('❌ OTP expired');
      return {
        success: false,
        message: 'OTP has expired. Please request a new code.',
      };
    }

    // Check attempts
    if (otpData.attempts >= 3) {
      console.log('❌ Too many attempts');
      return {
        success: false,
        message: 'Too many verification attempts. Please request a new code.',
      };
    }

    // Mark OTP as used
    await otpDoc.ref.update({
      used: true,
      verifiedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    console.log('✅ OTP verified successfully');

    return {
      success: true,
      message: 'OTP verified successfully',
    };
  } catch (error) {
    console.error('❌ Error verifying OTP:', error);
    throw new functions.https.HttpsError(
      'internal',
      `Failed to verify OTP: ${error.message}`
    );
  }
});

// ============================================================================
// TWILIO WEBHOOK (Handle Twilio Status Callbacks)
// ============================================================================
exports.twilioWebhook = functions.https.onRequest(async (req, res) => {
  try {
    const { MessageSid, MessageStatus, To } = req.body;

    console.log(`📬 Twilio webhook: ${MessageSid} - Status: ${MessageStatus}`);

    // Update SMS log in Firestore
    const smsSnapshot = await admin
      .firestore()
      .collection('sms_logs')
      .where('twilioSid', '==', MessageSid)
      .limit(1)
      .get();

    if (!smsSnapshot.empty) {
      await smsSnapshot.docs[0].ref.update({
        twilioStatus: MessageStatus,
        lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
      });
      console.log(`✅ Updated SMS log for SID: ${MessageSid}`);
    }

    res.status(200).send('Webhook received');
  } catch (error) {
    console.error('❌ Webhook error:', error);
    res.status(500).send('Webhook error');
  }
});

// ============================================================================
// EMAIL TEMPLATE BUILDER
// ============================================================================
function buildEmailTemplate(name, otpCode) {
  return `
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
    </head>
    <body style="margin: 0; padding: 0; font-family: Arial, sans-serif; background-color: #f4f4f4;">
      <div style="max-width: 600px; margin: 0 auto; background-color: #ffffff;">
        <div style="background: linear-gradient(135deg, #0A1929 0%, #1A2F3F 100%); padding: 30px; text-align: center;">
          <h1 style="color: #ffffff; margin: 0; font-size: 28px;">findMe</h1>
          <p style="color: #ffffff; margin: 10px 0 0 0; font-size: 14px;">School Safety & Security Tracking System</p>
        </div>

        <div style="padding: 40px 30px;">
          <h2 style="color: #333333; margin: 0 0 20px 0; font-size: 24px;">Welcome, ${name}!</h2>

          <p style="color: #666666; font-size: 16px; line-height: 1.6; margin: 0 0 20px 0;">
            Thank you for registering with S3TS. To complete your registration, please use the verification code below:
          </p>

          <div style="background-color: #f8f9fa; padding: 30px; text-align: center; border-radius: 10px; margin: 30px 0;">
            <div style="font-size: 36px; font-weight: bold; letter-spacing: 10px; color: #0A1929; font-family: 'Courier New', monospace;">
              ${otpCode}
            </div>
          </div>

          <div style="background-color: #fff3cd; border-left: 4px solid #ffc107; padding: 15px; margin: 20px 0; border-radius: 4px;">
            <p style="margin: 0; color: #856404; font-size: 14px;">
              <strong>⚠️ Important:</strong> This code will expire in 10 minutes.
            </p>
          </div>

          <p style="color: #666666; font-size: 14px; line-height: 1.6; margin: 20px 0 0 0;">
            If you didn't request this code, please ignore this email or contact our support team if you have concerns.
          </p>
        </div>

        <div style="background-color: #f8f9fa; padding: 20px 30px; border-top: 1px solid #e9ecef;">
          <p style="margin: 0; color: #999999; font-size: 12px; text-align: center;">
            © 2024 findMe. All rights reserved.<br>
            This is an automated message, please do not reply.
          </p>
        </div>
      </div>
    </body>
    </html>
  `;
}