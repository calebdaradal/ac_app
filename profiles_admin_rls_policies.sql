-- RLS Policies for profiles table - Admin Update Access
-- This allows admin users to update any user's profile
-- Regular users can only update their own profile

-- Enable RLS on profiles table (if not already enabled)
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- Drop existing admin update policy if it exists (to avoid conflicts)
DROP POLICY IF EXISTS "Allow admin users to update any profile" ON public.profiles;

-- Policy: Allow admin users to UPDATE any profile
-- This policy allows admins to update any user's profile fields
-- The USING clause checks if the current user is an admin
-- The WITH CHECK clause allows the update to proceed if the user is an admin
CREATE POLICY "Allow admin users to update any profile"
ON public.profiles
FOR UPDATE
TO authenticated
USING (
  -- Check if the current authenticated user is an admin
  EXISTS (
    SELECT 1 FROM public.profiles p
    WHERE p.id = auth.uid()::text
    AND p.is_admin = true
  )
)
WITH CHECK (
  -- Allow the update if the current user is an admin
  EXISTS (
    SELECT 1 FROM public.profiles p
    WHERE p.id = auth.uid()::text
    AND p.is_admin = true
  )
);

-- Note: This policy works alongside any existing policy that allows users to update their own profile.
-- Supabase uses OR logic between policies, so:
-- - Admins can update ANY profile (this policy)
-- - Regular users can only update their own profile (if that policy exists)

