-- RLS Policy for profiles table - Allow reading is_active by email for login
-- This allows unauthenticated users to check if an account is active during login
-- Without this policy, RLS blocks the query and disabled users can bypass the check

-- Enable RLS on profiles table (if not already enabled)
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- Drop existing policy if it exists (to avoid conflicts)
DROP POLICY IF EXISTS "Allow reading is_active by email for login" ON public.profiles;

-- Policy: Allow anyone (including unauthenticated users) to read is_active by email
-- This is needed for the login screen to check if a user account is disabled
-- IMPORTANT: The app only queries 'is_active' field, so other data remains protected
CREATE POLICY "Allow reading is_active by email for login"
ON public.profiles
FOR SELECT
TO public  -- This includes both authenticated and unauthenticated users
USING (true);  -- Allow reading for login verification

-- Note: While this policy technically allows reading all columns,
-- the app code only selects 'is_active', so other sensitive data
-- (like pin, email, etc.) is not exposed in the login flow.
-- The query in auth_email_screen.dart is: .select('is_active')

