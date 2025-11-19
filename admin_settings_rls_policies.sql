-- RLS Policies for admin_settings table
-- This allows admin users to manage the annual withdraw date
-- and allows all authenticated users to read it

-- Enable RLS on admin_settings table (if not already enabled)
ALTER TABLE public.admin_settings ENABLE ROW LEVEL SECURITY;

-- Policy 1: Allow all authenticated users to SELECT (read) the annual withdraw date
-- This is needed so users can check if withdrawals are allowed
CREATE POLICY "Allow authenticated users to read admin_settings"
ON public.admin_settings
FOR SELECT
TO authenticated
USING (true);

-- Policy 2: Allow admin users to INSERT into admin_settings
CREATE POLICY "Allow admin users to insert admin_settings"
ON public.admin_settings
FOR INSERT
TO authenticated
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.profiles
    WHERE profiles.id = auth.uid()::text
    AND profiles.is_admin = true
  )
);

-- Policy 3: Allow admin users to UPDATE admin_settings
CREATE POLICY "Allow admin users to update admin_settings"
ON public.admin_settings
FOR UPDATE
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.profiles
    WHERE profiles.id = auth.uid()::text
    AND profiles.is_admin = true
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.profiles
    WHERE profiles.id = auth.uid()::text
    AND profiles.is_admin = true
  )
);

-- Policy 4: Allow admin users to DELETE from admin_settings
CREATE POLICY "Allow admin users to delete admin_settings"
ON public.admin_settings
FOR DELETE
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.profiles
    WHERE profiles.id = auth.uid()::text
    AND profiles.is_admin = true
  )
);

