-- NIGHTFALL / INCO shared workspace setup
-- Run the entire script in Supabase SQL Editor. Uses authenticated users and team membership.
create table if not exists public.teams (
 id uuid primary key default gen_random_uuid(),
 name text not null check (char_length(name) between 2 and 60),
 invite_code text not null unique,
 created_by uuid not null references auth.users(id) on delete cascade,
 created_at timestamptz not null default now()
);
create table if not exists public.team_members (
 team_id uuid not null references public.teams(id) on delete cascade,
 user_id uuid not null references auth.users(id) on delete cascade,
 role text not null default 'member' check (role in ('owner','member')),
 joined_at timestamptz not null default now(),
 primary key(team_id,user_id)
);
create table if not exists public.team_workspace (
 team_id uuid primary key references public.teams(id) on delete cascade,
 data jsonb not null default '{"agents":[],"areas":[],"missions":[]}'::jsonb,
 updated_by uuid references auth.users(id),
 updated_at timestamptz not null default now()
);
create or replace function public.nightfall_is_member(check_team uuid)
returns boolean language sql stable security definer set search_path=public
as $$ select exists(select 1 from public.team_members where team_id=check_team and user_id=auth.uid()) $$;
create or replace function public.nightfall_create_team(p_name text)
returns json language plpgsql security definer set search_path=public
as $$
declare t public.teams;
begin
 if auth.uid() is null then raise exception 'Please log in first'; end if;
 insert into public.teams(name,invite_code,created_by)
 values(trim(p_name),upper(substr(replace(gen_random_uuid()::text,'-',''),1,10)),auth.uid()) returning * into t;
 insert into public.team_members(team_id,user_id,role) values(t.id,auth.uid(),'owner');
 insert into public.team_workspace(team_id,updated_by) values(t.id,auth.uid());
 return json_build_object('id',t.id,'name',t.name,'invite_code',t.invite_code);
end $$;
create or replace function public.nightfall_join_team(p_code text)
returns json language plpgsql security definer set search_path=public
as $$
declare t public.teams;
begin
 if auth.uid() is null then raise exception 'Please log in first'; end if;
 select * into t from public.teams where invite_code=upper(trim(p_code));
 if not found then raise exception 'Invite code not found'; end if;
 insert into public.team_members(team_id,user_id,role) values(t.id,auth.uid(),'member') on conflict do nothing;
 return json_build_object('id',t.id,'name',t.name,'invite_code',t.invite_code);
end $$;
alter table public.teams enable row level security;
alter table public.team_members enable row level security;
alter table public.team_workspace enable row level security;
drop policy if exists "members can view teams" on public.teams;
create policy "members can view teams" on public.teams for select to authenticated using (public.nightfall_is_member(id));
drop policy if exists "members can view team membership" on public.team_members;
create policy "members can view team membership" on public.team_members for select to authenticated using (public.nightfall_is_member(team_id));
drop policy if exists "members can view shared workspace" on public.team_workspace;
create policy "members can view shared workspace" on public.team_workspace for select to authenticated using (public.nightfall_is_member(team_id));
drop policy if exists "members can update shared workspace" on public.team_workspace;
create policy "members can update shared workspace" on public.team_workspace for insert to authenticated with check (public.nightfall_is_member(team_id));
create policy "members can update workspace data" on public.team_workspace for update to authenticated using (public.nightfall_is_member(team_id)) with check (public.nightfall_is_member(team_id));
grant execute on function public.nightfall_create_team(text) to authenticated;
grant execute on function public.nightfall_join_team(text) to authenticated;
grant select on public.teams,public.team_members,public.team_workspace to authenticated;
grant insert,update on public.team_workspace to authenticated;

-- Shared team chat
create table if not exists public.chat_messages (
 id uuid primary key default gen_random_uuid(),
 team_id uuid not null references public.teams(id) on delete cascade,
 sender_id uuid not null references auth.users(id) on delete cascade,
 sender_label text not null,
 content text not null check (char_length(content) between 1 and 3000),
 created_at timestamptz not null default now()
);
alter table public.chat_messages enable row level security;
drop policy if exists "team members read chat" on public.chat_messages;
create policy "team members read chat" on public.chat_messages for select to authenticated using (public.nightfall_is_member(team_id));
drop policy if exists "team members send chat" on public.chat_messages;
create policy "team members send chat" on public.chat_messages for insert to authenticated with check (public.nightfall_is_member(team_id) and sender_id=auth.uid());
grant select,insert on public.chat_messages to authenticated;
