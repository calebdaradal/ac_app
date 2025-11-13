# ac_app

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Admin User Creation (Supabase Edge Function)

This app calls a Supabase Edge Function to create users with admin privileges securely, instead of using `auth.admin.*` from the client.

Steps to deploy the `create-user` function:

- Install the Supabase CLI and log in.
- Link your project: `supabase link --project-ref <YOUR_PROJECT_REF>`.
- Create the function: `supabase functions new create-user`.
- Replace `supabase/functions/create-user/index.ts` with your implementation that:
  - Verifies the caller’s session and checks they are an admin.
  - Uses `SUPABASE_SERVICE_ROLE_KEY` to call `auth.admin.createUser`.
  - Inserts a row into `profiles` for the new user.
- Set required secrets:
  - `supabase secrets set SUPABASE_SERVICE_ROLE_KEY=<your_service_role_key>`
  - Optionally: `SUPABASE_URL` and `SUPABASE_ANON_KEY` if not already available in the function environment.
- Deploy: `supabase functions deploy create-user`.

Flutter will invoke the function via:

```
await Supabase.instance.client.functions.invoke('create-user', body: {
  'email': ..., 'password': ..., 'first_name': ..., 'last_name': ..., 'avatar_url': ..., 'is_admin': ...,
});
```

Note: Do not expose the service role key in the Flutter app; keep it only in the Edge Function environment.
