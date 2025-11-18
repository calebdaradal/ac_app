-- Diagnostic SQL to check trigger setup
-- Run this in Supabase SQL Editor

-- 1. Check if triggers exist
SELECT 
  trigger_name, 
  event_object_table, 
  event_manipulation,
  action_statement 
FROM information_schema.triggers 
WHERE trigger_name IN (
  'yield_update_notification_trigger',
  'transaction_verification_notification_trigger'
);

-- 2. Check if pg_net extension is enabled
SELECT 
  extname, 
  extversion 
FROM pg_extension 
WHERE extname = 'pg_net';

-- If pg_net is NOT enabled, run this:
-- CREATE EXTENSION IF NOT EXISTS pg_net;

-- 3. Check database configuration variables
SHOW app.supabase_url;
SHOW app.supabase_anon_key;

-- If these are NULL or empty, set them with:
-- ALTER DATABASE postgres SET app.supabase_url = 'https://cuuuncuhqweyiyduzfiz.supabase.co';
-- ALTER DATABASE postgres SET app.supabase_anon_key = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImN1dXVuY3VocXdleWl5ZHV6Zml6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjIzMzA1MDYsImV4cCI6MjA3NzkwNjUwNn0.xDAVoZQ72R7baaa2wdddl7AveH5_B_uTe1I7kY6QFGo';

-- 4. Check if notification functions exist
SELECT 
  proname, 
  prosrc 
FROM pg_proc 
WHERE proname IN (
  'notify_yield_update',
  'notify_transaction_verification'
);

-- 5. Test: Check recent yields (to see if trigger should have fired)
SELECT 
  id, 
  vehicle_id, 
  yield_amount, 
  yield_type, 
  applied_date, 
  created_at 
FROM yields 
ORDER BY id DESC 
LIMIT 5;

-- 6. Check device tokens exist
SELECT 
  COUNT(*) as total_tokens,
  COUNT(DISTINCT user_id) as unique_users,
  COUNT(*) FILTER (WHERE is_active = true) as active_tokens
FROM device_tokens;

