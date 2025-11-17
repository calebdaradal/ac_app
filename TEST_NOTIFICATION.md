# Test Notification Setup

## Your Device Token
`155d3534-5973-49f3-a8c5-2e0cd5ab764e`

## Quick Tests

### Test 1: Verify Device Token in Database
Run this SQL in Supabase SQL Editor:
```sql
SELECT * FROM device_tokens 
WHERE device_token = '155d3534-5973-49f3-a8c5-2e0cd5ab764e';
```

Expected: Should return 1 row with your user_id, platform='android', is_active=true

### Test 2: Send Test Notification from OneSignal
1. Go to OneSignal Dashboard → Messages → New Push
2. Select "Send to Specific Users"
3. Enter: `155d3534-5973-49f3-a8c5-2e0cd5ab764e`
4. Title: "Test Notification"
5. Message: "This is a test"
6. Click "Send Message"

If this works → OneSignal is configured correctly, issue is with Edge Function
If this doesn't work → OneSignal setup issue

### Test 3: Check Edge Function Logs After "start"
Look for these log messages after `[send-yield-notification] start`:
- `Found X distributions`
- `Found X device tokens`
- `Success for user...`
- Any error messages

If logs stop at "start" → Function is failing early (check for errors)

### Test 4: Check if Distributions Exist
Run this SQL to check if distributions were created for your yield:
```sql
SELECT * FROM user_yield_distributions 
WHERE user_uid = 'YOUR_USER_ID'
ORDER BY created_at DESC 
LIMIT 5;
```

Replace `YOUR_USER_ID` with your actual user ID from the `device_tokens` table.

### Test 5: Manual Edge Function Test
Test the Edge Function directly with curl:
```bash
curl -X POST 'https://cuuuncuhqweyiyduzfiz.supabase.co/functions/v1/send-yield-notification' \
  -H 'Authorization: Bearer YOUR_ANON_KEY' \
  -H 'Content-Type: application/json' \
  -d '{
    "yield_id": YOUR_YIELD_ID,
    "vehicle_id": YOUR_VEHICLE_ID,
    "yield_amount": 100,
    "yield_type": "Amount",
    "applied_date": "2025-11-17"
  }'
```

Replace:
- `YOUR_ANON_KEY` with your Supabase anon key
- `YOUR_YIELD_ID` with an actual yield ID from the `yields` table
- `YOUR_VEHICLE_ID` with your vehicle ID

