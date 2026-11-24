-- NIGHTFALL Operations Rooms + NPCs
-- Run this migration in Supabase SQL Editor after the existing NIGHTFALL setup.
-- Each operation owns its own membership, chat, NPC records and fictional map coordinates.

create table if not exists public.operations (
  id uuid primary key default gen_random_uuid(),
  team_id uuid not null references public.teams(id) on delete cascade,
  name text not null check (char_length(name) between 2 and 70),
  description text not null default '',
  invite_code text not null unique,
  created_by uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);

create table if not exists public.operation_members (
  operation_id uuid not null references public.operations(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null default 'member' check (role in ('admin','member')),
  joined_at timestamptz not null default now(),
  primary key(operation_id,user_id)
);

create table if not exists public.operation_npcs (
  id uuid primary key default gen_random_uuid(),
  operation_id uuid not null references public.operations(id) on delete cascade,
  created_by uuid not null references auth.users(id) on delete cascade,
  category text not null check (category in ('enemy','asset','agent')),
  callsign text not null check (char_length(callsign) between 1 and 60),
  description text not null default '',
  map_x integer check (map_x between 1 and 10),
  map_y integer check (map_y between 1 and 10),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.operation_messages (
  id uuid primary key default gen_random_uuid(),
  operation_id uuid not null references public.operations(id) on delete cascade,
  sender_id uuid not null references auth.users(id) on delete cascade,
  sender_label text not null default 'MEMBER',
  content text not null check (char_length(content) between 1 and 3000),
  message_type text not null default 'text' check (message_type in ('text','npc')),
  npc_id uuid references public.operation_npcs(id) on delete set null,
  created_at timestamptz not null default now()
);

create index if not exists operation_messages_room_time_idx
  on public.operation_messages(operation_id,created_at);
create index if not exists operation_npcs_room_idx
  on public.operation_npcs(operation_id);

create or replace function public.nightfall_is_operation_member(p_operation_id uuid)
returns boolean language sql stable security definer set search_path=public
as $$
  select exists (
    select 1 from public.operation_members
    where operation_id=p_operation_id and user_id=auth.uid()
  );
$$;

create or replace function public.nightfall_is_operation_admin(p_operation_id uuid)
returns boolean language sql stable security definer set search_path=public
as $$
  select exists (
    select 1 from public.operation_members
    where operation_id=p_operation_id and user_id=auth.uid() and role='admin'
  );
$$;

create or replace function public.nightfall_create_operation(
  p_team_id uuid, p_name text, p_description text default ''
)
returns json language plpgsql security definer set search_path=public
as $$
declare o public.operations;
begin
  if auth.uid() is null then raise exception 'Please log in first'; end if;
  if not public.nightfall_is_member(p_team_id) then raise exception 'You must be a team member'; end if;
  insert into public.operations(team_id,name,description,invite_code,created_by)
  values(p_team_id,trim(p_name),coalesce(trim(p_description),''),upper(substr(replace(gen_random_uuid()::text,'-',''),1,10)),auth.uid())
  returning * into o;
  insert into public.operation_members(operation_id,user_id,role)
  values(o.id,auth.uid(),'admin');
  return json_build_object('id',o.id,'name',o.name,'description',o.description,'invite_code',o.invite_code);
end;
$$;

create or replace function public.nightfall_join_operation(p_code text)
returns json language plpgsql security definer set search_path=public
as $$
declare o public.operations;
begin
  if auth.uid() is null then raise exception 'Please log in first'; end if;
  select * into o from public.operations where invite_code=upper(trim(p_code));
  if not found then raise exception 'Operation invite code not found'; end if;
  if not public.nightfall_is_member(o.team_id) then raise exception 'Join the operation team first'; end if;
  insert into public.operation_members(operation_id,user_id,role)
  values(o.id,auth.uid(),'member') on conflict do nothing;
  return json_build_object('id',o.id,'name',o.name,'description',o.description,'invite_code',o.invite_code);
end;
$$;

create or replace function public.nightfall_create_operation_npc(
  p_operation_id uuid, p_category text, p_callsign text, p_description text default '',
  p_map_x integer default null, p_map_y integer default null
)
returns json language plpgsql security definer set search_path=public
as $$
declare n public.operation_npcs;
begin
  if auth.uid() is null then raise exception 'Please log in first'; end if;
  if not public.nightfall_is_operation_member(p_operation_id) then raise exception 'Operation membership required'; end if;
  if p_category not in ('enemy','asset','agent') then raise exception 'Invalid NPC category'; end if;
  insert into public.operation_npcs(operation_id,created_by,category,callsign,description,map_x,map_y)
  values(p_operation_id,auth.uid(),p_category,trim(p_callsign),coalesce(trim(p_description),''),p_map_x,p_map_y)
  returning * into n;
  insert into public.operation_messages(operation_id,sender_id,sender_label,content,message_type,npc_id)
  values(p_operation_id,auth.uid(),'MEMBER',upper(n.category)||' · '||n.callsign,'npc',n.id);
  return json_build_object('id',n.id,'operation_id',n.operation_id,'category',n.category,
    'callsign',n.callsign,'description',n.description,'map_x',n.map_x,'map_y',n.map_y);
end;
$$;

alter table public.operations enable row level security;
alter table public.operation_members enable row level security;
alter table public.operation_npcs enable row level security;
alter table public.operation_messages enable row level security;

drop policy if exists "operation members can view their rooms" on public.operations;
create policy "operation members can view their rooms" on public.operations
for select to authenticated using (public.nightfall_is_operation_member(id));

drop policy if exists "members can view operation membership" on public.operation_members;
create policy "members can view operation membership" on public.operation_members
for select to authenticated using (public.nightfall_is_operation_member(operation_id));

drop policy if exists "operation members can read NPCs" on public.operation_npcs;
create policy "operation members can read NPCs" on public.operation_npcs
for select to authenticated using (public.nightfall_is_operation_member(operation_id));

drop policy if exists "operation members can add NPCs" on public.operation_npcs;
create policy "operation members can add NPCs" on public.operation_npcs
for insert to authenticated with check (
  public.nightfall_is_operation_member(operation_id) and created_by=auth.uid()
);

drop policy if exists "authors or admins can edit NPCs" on public.operation_npcs;
create policy "authors or admins can edit NPCs" on public.operation_npcs
for update to authenticated using (
  public.nightfall_is_operation_member(operation_id) and
  (created_by=auth.uid() or public.nightfall_is_operation_admin(operation_id))
) with check (public.nightfall_is_operation_member(operation_id));

drop policy if exists "authors or admins can delete NPCs" on public.operation_npcs;
create policy "authors or admins can delete NPCs" on public.operation_npcs
for delete to authenticated using (
  public.nightfall_is_operation_member(operation_id) and
  (created_by=auth.uid() or public.nightfall_is_operation_admin(operation_id))
);

drop policy if exists "operation members can read messages" on public.operation_messages;
create policy "operation members can read messages" on public.operation_messages
for select to authenticated using (public.nightfall_is_operation_member(operation_id));

drop policy if exists "operation members can send messages" on public.operation_messages;
create policy "operation members can send messages" on public.operation_messages
for insert to authenticated with check (
  public.nightfall_is_operation_member(operation_id) and sender_id=auth.uid()
);

grant select on public.operations,public.operation_members,public.operation_npcs,public.operation_messages to authenticated;
grant insert,update,delete on public.operation_npcs to authenticated;
grant insert on public.operation_messages to authenticated;
grant execute on function public.nightfall_is_operation_member(uuid) to authenticated;
grant execute on function public.nightfall_is_operation_admin(uuid) to authenticated;
grant execute on function public.nightfall_create_operation(uuid,text,text) to authenticated;
grant execute on function public.nightfall_join_operation(text) to authenticated;
grant execute on function public.nightfall_create_operation_npc(uuid,text,text,text,integer,integer) to authenticated;

-- Enable realtime for room chat and NPC/map updates without duplicating publication entries.
do $$
begin
  if not exists (select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='operation_messages') then
    alter publication supabase_realtime add table public.operation_messages;
  end if;
  if not exists (select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='operation_npcs') then
    alter publication supabase_realtime add table public.operation_npcs;
  end if;
end $$;
