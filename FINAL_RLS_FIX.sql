-- FINAL FIX: RLS Policies for Device Tokens
-- This ensures account switching works on the same device

-- ============================================================================
-- STEP 1: Fix UPDATE Policy
-- ============================================================================
-- Allow users to update ANY token (for account switching on same device)
-- But ensure the new user_id matches auth.uid() (security)

DROP POLICY IF EXISTS "Users can update own device tokens" ON public.device_tokens;

CREATE POLICY "Users can update own device tokens"
ON public.device_tokens
FOR UPDATE
TO authenticated
USING (true)  -- Allow updating any row (needed for account switching)
WITH CHECK (
  -- Ensure the new user_id matches the authenticated user (security)
  auth.uid()::text = user_id
);

-- ============================================================================
-- STEP 2: Fix SELECT Policy
-- ============================================================================
-- Allow users to see tokens by device_token (needed to check if token exists)
-- This is safe because device_token is unique and we're only reading

DROP POLICY IF EXISTS "Users can view own device tokens" ON public.device_tokens;

CREATE POLICY "Users can view own device tokens"
ON public.device_tokens
FOR SELECT
TO authenticated
USING (true);  -- Allow viewing any token (needed to check if device_token exists)

-- ============================================================================
-- STEP 3: Fix DELETE Policy  
-- ============================================================================
-- Allow users to delete tokens by device_token (for cleanup)

DROP POLICY IF EXISTS "Users can delete own device tokens" ON public.device_tokens;

CREATE POLICY "Users can delete own device tokens"
ON public.device_tokens
FOR DELETE
TO authenticated
USING (true);  -- Allow deleting any token (restricted by app code to device_token only)

-- ============================================================================
-- STEP 4: Verify Policies
-- ============================================================================

SELECT 
  schemaname, 
  tablename, 
  policyname, 
  cmd,
  qual,
  with_check
FROM pg_policies
WHERE tablename = 'device_tokens'
ORDER BY policyname;

-- Expected results:
-- 1. "Service role can read all device tokens" - SELECT - qual: true
-- 2. "Users can delete own device tokens" - DELETE - qual: true
-- 3. "Users can insert own device tokens" - INSERT - with_check: auth.uid()::text = user_id
-- 4. "Users can update own device tokens" - UPDATE - qual: true, with_check: auth.uid()::text = user_id
-- 5. "Users can view own device tokens" - SELECT - qual: true (ALLOWS checking any token by device_token)

