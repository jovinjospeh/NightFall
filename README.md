# NIGHTFALL // INCO

A fictional, user-managed workspace with a map, agent roster, training scenarios, photo masking, a simulated green camera filter, team accounts and shared team chat.

## Setup the shared backend

1. Create a free project at https://supabase.com.
2. Open the Supabase **SQL Editor** and run the full contents of [supabase_setup.sql](./supabase_setup.sql).
3. In Supabase **Project Settings → API**, copy the Project URL and the publishable key (or legacy anon public key).
4. In `index.html`, replace:
   - `PASTE_YOUR_SUPABASE_PROJECT_URL`
   - `PASTE_YOUR_SUPABASE_PUBLISHABLE_OR_ANON_KEY`
5. In Supabase **Authentication → URL Configuration**, add your deployed GitHub Pages URL to the allowed Site URL / Redirect URLs.
6. For live team chat updates, enable Realtime for the `chat_messages` table in Supabase Database → Replication / Publications (the exact menu label may vary).
7. Enable GitHub Pages: repository **Settings → Pages → Deploy from a branch → main → /(root)**.

## Team use

- Register with email and password, then log in.
- Create a team to receive an invite code.
- Teammates register their own accounts and join using that invite code.
- Team members share the team workspace and chat. Team data is protected by Supabase Row Level Security membership policies.

## Important

- Do not put a Supabase `service_role` or secret key in this website. Only use the publishable/anon public key.
- The shared workspace stores the team roster, map drawings and training scenarios as one team document. For a larger team with frequent simultaneous edits, this should later be migrated to separate records with conflict-safe updates.
- The NVG camera is only a visual filter, not real night vision. The app does not track people or provide real-world operational surveillance.
- Nightfall is a fictional personal project, not an official government or intelligence service.
