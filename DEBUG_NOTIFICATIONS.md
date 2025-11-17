# Debugging Push Notifications

## What We Implemented
✅ **System Push Notifications** (notification bar/lock screen)
- Appear even when app is closed
- Appear on lock screen
- Show in notification tray
- Can be tapped to open app

❌ **NOT** in-app notifications (those would only show when app is open)

## Debugging Checklist

### 1. Check Device Token Registration
- Go to Supabase Dashboard → Database → `device_tokens` table
- Verify your user's device token exists
- Check `is_active = true`
- Note the `device_token` value

### 2. Check Edge Function Logs
- Go to Supabase Dashboard → Edge Functions → `send-yield-notification` → Logs
- Look for:
  - `[send-yield-notification] start`
  - `Found X distributions`
  - `Found X device tokens`
  - `Success for user...` or error messages

### 3. Check OneSignal Dashboard
- Go to OneSignal Dashboard → Delivery
- Check if notifications were sent
- Look for delivery status (delivered/failed)

### 4. Verify OneSignal Configuration
- Check `.env` file has `ONESIGNAL_APP_ID` set
- Verify OneSignal secrets in Supabase:
  - `ONESIGNAL_APP_ID`
  - `ONESIGNAL_REST_API_KEY`
- Check OneSignal App ID matches between Flutter app and Edge Function

### 5. Check Android Permissions
- On your phone: Settings → Apps → Your App → Notifications
- Ensure notifications are enabled
- Check if "Show notifications" is ON

### 6. Test Direct from OneSignal
- Go to OneSignal Dashboard → Messages → New Push
- Select "Send to Specific Users"
- Enter your device token from `device_tokens` table
- Send test notification
- If this works, the issue is with Edge Function/Webhook
- If this doesn't work, the issue is with OneSignal setup

## Common Issues

### Issue: Device Token Not Stored
**Symptoms:** No entry in `device_tokens` table
**Fix:**
- Check if `ONESIGNAL_APP_ID` is in `.env` file
- Check app logs for OneSignal initialization errors
- Rebuild APK with correct `.env` file

### Issue: Edge Function Not Called
**Symptoms:** No logs in Edge Function
**Fix:**
- Verify webhook is created and enabled
- Check webhook URL is correct
- Test webhook manually from Supabase Dashboard

### Issue: Edge Function Called But No Notifications
**Symptoms:** Edge Function logs show success but no notification
**Fix:**
- Check OneSignal dashboard for delivery status
- Verify OneSignal REST API Key is correct
- Check device token format matches OneSignal player ID format

### Issue: Notifications Work in Test But Not Production
**Symptoms:** Test notifications work, real yield updates don't
**Fix:**
- Check if distributions exist for the yield
- Verify user has device token stored
- Check Edge Function retry logic is working

