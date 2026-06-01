-- ============================================================
-- Memory Maker Admin App SQL Migration
-- Creates/updates admin RPCs used by the Flutter Admin App.
-- Safe to run multiple times.
-- ============================================================

create extension if not exists pgcrypto;

-- ---------- base tables ----------
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text,
  phone text,
  avatar_url text,
  avatar_base64 text,
  avatar_content_type text,
  role text default 'user',
  is_super_admin boolean default false,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

alter table public.profiles
  add column if not exists full_name text,
  add column if not exists phone text,
  add column if not exists avatar_url text,
  add column if not exists avatar_object_key text,
  add column if not exists avatar_base64 text,
  add column if not exists avatar_content_type text,
  add column if not exists profile_picture_url text,
  add column if not exists profile_photo_url text,
  add column if not exists image_url text,
  add column if not exists photo_url text,
  add column if not exists role text default 'user',
  add column if not exists is_super_admin boolean default false,
  add column if not exists last_seen_at timestamptz,
  add column if not exists created_at timestamptz default now(),
  add column if not exists updated_at timestamptz default now();

create table if not exists public.events (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid references auth.users(id) on delete cascade,
  user_id uuid references auth.users(id) on delete cascade,
  title text,
  name text,
  slug text,
  event_kind text default 'Event',
  event_type text default 'Event',
  status text default 'active',
  beta_free_access boolean default true,
  gallery_cover_url text,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

alter table public.events
  add column if not exists owner_id uuid references auth.users(id) on delete cascade,
  add column if not exists user_id uuid references auth.users(id) on delete cascade,
  add column if not exists title text,
  add column if not exists name text,
  add column if not exists slug text,
  add column if not exists event_kind text default 'Event',
  add column if not exists event_type text default 'Event',
  add column if not exists event_start_at timestamptz,
  add column if not exists beta_free_access boolean default true,
  add column if not exists gallery_cover_url text,
  add column if not exists public_beta_notes text,
  add column if not exists plan_code text default 'beta',
  add column if not exists duration_code text default 'beta',
  add column if not exists duration_days int default 30,
  add column if not exists max_guests int default 50,
  add column if not exists max_total_bytes bigint default 1073741824,
  add column if not exists max_photos_per_guest int default 50,
  add column if not exists used_total_bytes bigint default 0,
  add column if not exists paid_at timestamptz,
  add column if not exists stripe_payment_status text default 'beta_free',
  add column if not exists status text default 'active',
  add column if not exists created_at timestamptz default now(),
  add column if not exists updated_at timestamptz default now();

create table if not exists public.event_guests (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references public.events(id) on delete cascade,
  user_id uuid references auth.users(id) on delete cascade,
  email text,
  display_name text,
  status text default 'invited',
  invited_at timestamptz,
  accepted_at timestamptz,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

alter table public.event_guests
  add column if not exists user_id uuid references auth.users(id) on delete cascade,
  add column if not exists email text,
  add column if not exists display_name text,
  add column if not exists status text default 'invited',
  add column if not exists invited_at timestamptz,
  add column if not exists accepted_at timestamptz,
  add column if not exists created_at timestamptz default now(),
  add column if not exists updated_at timestamptz default now();

create table if not exists public.media_uploads (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references public.events(id) on delete cascade,
  guest_id uuid references public.event_guests(id) on delete set null,
  uploader_id uuid references auth.users(id) on delete set null,
  user_id uuid references auth.users(id) on delete set null,
  uploader_email text,
  media_type text default 'photo',
  title text,
  caption text,
  status text default 'approved',
  file_url text,
  thumbnail_url text,
  object_key text,
  storage_key text,
  original_filename text,
  content_type text,
  byte_size bigint default 0,
  width integer,
  height integer,
  print_count integer default 0,
  share_count integer default 0,
  download_count integer default 0,
  deleted_at timestamptz,
  uploaded_at timestamptz default now(),
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

alter table public.media_uploads
  add column if not exists guest_id uuid references public.event_guests(id) on delete set null,
  add column if not exists uploader_id uuid references auth.users(id) on delete set null,
  add column if not exists user_id uuid references auth.users(id) on delete set null,
  add column if not exists uploader_email text,
  add column if not exists title text,
  add column if not exists caption text,
  add column if not exists status text default 'approved',
  add column if not exists file_url text,
  add column if not exists thumbnail_url text,
  add column if not exists object_key text,
  add column if not exists storage_key text,
  add column if not exists original_filename text,
  add column if not exists content_type text,
  add column if not exists byte_size bigint default 0,
  add column if not exists width integer,
  add column if not exists height integer,
  add column if not exists print_count integer default 0,
  add column if not exists share_count integer default 0,
  add column if not exists download_count integer default 0,
  add column if not exists deleted_at timestamptz,
  add column if not exists uploaded_at timestamptz default now(),
  add column if not exists created_at timestamptz default now(),
  add column if not exists updated_at timestamptz default now();

create table if not exists public.media_blobs (
  upload_id uuid primary key references public.media_uploads(id) on delete cascade,
  event_id uuid not null references public.events(id) on delete cascade,
  owner_id uuid not null references auth.users(id) on delete cascade,
  original_filename text not null default 'upload.jpg',
  original_content_type text not null default 'image/jpeg',
  original_byte_size bigint not null default 0,
  compressed_content_type text not null default 'image/jpeg',
  compressed_byte_size bigint not null default 0,
  compressed_base64 text,
  width integer,
  height integer,
  created_at timestamptz not null default now()
);

create table if not exists public.support_tickets (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  subject text not null,
  message text,
  admin_reply text,
  status text default 'open',
  priority text default 'normal',
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

alter table public.support_tickets
  add column if not exists user_id uuid references auth.users(id) on delete cascade,
  add column if not exists subject text,
  add column if not exists message text,
  add column if not exists admin_reply text,
  add column if not exists status text default 'open',
  add column if not exists priority text default 'normal',
  add column if not exists created_at timestamptz default now(),
  add column if not exists updated_at timestamptz default now();

create table if not exists public.user_notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  event_id uuid references public.events(id) on delete cascade,
  title text not null,
  body text,
  status text not null default 'unread',
  created_at timestamptz not null default now(),
  read_at timestamptz
);

alter table public.user_notifications
  add column if not exists event_id uuid references public.events(id) on delete cascade,
  add column if not exists title text,
  add column if not exists body text,
  add column if not exists status text default 'unread',
  add column if not exists created_at timestamptz default now(),
  add column if not exists read_at timestamptz;

-- indexes
create index if not exists profiles_role_idx on public.profiles(role);
create index if not exists events_owner_id_idx on public.events(owner_id);
create index if not exists events_user_id_idx on public.events(user_id);
create index if not exists media_uploads_event_id_idx on public.media_uploads(event_id);
create index if not exists support_tickets_user_id_idx on public.support_tickets(user_id);
create index if not exists support_tickets_status_idx on public.support_tickets(status);
create index if not exists user_notifications_user_id_idx on public.user_notifications(user_id);

-- RLS on, app reads through secure RPCs
alter table public.profiles enable row level security;
alter table public.events enable row level security;
alter table public.event_guests enable row level security;
alter table public.media_uploads enable row level security;
alter table public.media_blobs enable row level security;
alter table public.support_tickets enable row level security;
alter table public.user_notifications enable row level security;

-- profile trigger
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, full_name, role, is_super_admin, created_at, updated_at)
  values (new.id, coalesce(new.raw_user_meta_data->>'full_name', split_part(new.email, '@', 1)), 'user', false, now(), now())
  on conflict (id) do update set full_name = coalesce(public.profiles.full_name, excluded.full_name), updated_at = now();
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users for each row execute function public.handle_new_user();

insert into public.profiles (id, full_name, role, is_super_admin, created_at, updated_at)
select u.id, coalesce(u.raw_user_meta_data->>'full_name', split_part(u.email, '@', 1)), 'user', false, now(), now()
from auth.users u
left join public.profiles p on p.id = u.id
where p.id is null;

-- admin helpers
create or replace function public.app_is_admin()
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1 from public.profiles p
    where p.id = auth.uid()
      and (coalesce(p.is_super_admin,false)=true or lower(coalesce(p.role::text,'')) in ('super_admin','sub_admin','admin'))
  );
$$;
grant execute on function public.app_is_admin() to authenticated;

create or replace function public.app_is_super_admin()
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1 from public.profiles p
    where p.id = auth.uid()
      and (coalesce(p.is_super_admin,false)=true or lower(coalesce(p.role::text,''))='super_admin')
  );
$$;
grant execute on function public.app_is_super_admin() to authenticated;

create or replace function public.app_admin_me()
returns jsonb
language sql
security definer
set search_path = public
stable
as $$
  select coalesce(jsonb_build_object(
    'allowed', public.app_is_admin(),
    'id', p.id,
    'email', u.email,
    'full_name', p.full_name,
    'role', coalesce(p.role::text,'user'),
    'is_super_admin', coalesce(p.is_super_admin,false),
    'avatar_url', p.avatar_url,
    'avatar_base64', p.avatar_base64,
    'profile_picture_url', p.profile_picture_url,
    'profile_photo_url', p.profile_photo_url,
    'image_url', p.image_url,
    'photo_url', p.photo_url
  ), jsonb_build_object('allowed', false))
  from public.profiles p
  left join auth.users u on u.id = p.id
  where p.id = auth.uid();
$$;
grant execute on function public.app_admin_me() to authenticated;

create or replace function public.app_admin_overview()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.app_is_admin() then raise exception 'Admin access required'; end if;
  return jsonb_build_object(
    'users_count', (select count(*) from auth.users),
    'events_count', (select count(*) from public.events),
    'uploads_count', (select count(*) from public.media_uploads where deleted_at is null),
    'tickets_count', (select count(*) from public.support_tickets),
    'open_tickets_count', (select count(*) from public.support_tickets where lower(coalesce(status::text,'')) in ('open','pending','new')),
    'notifications_count', (select count(*) from public.user_notifications)
  );
end;
$$;
grant execute on function public.app_admin_overview() to authenticated;

create or replace function public.app_admin_list_tickets()
returns table(id uuid, user_id uuid, user_email text, user_name text, subject text, message text, admin_reply text, status text, priority text, created_at timestamptz, updated_at timestamptz)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.app_is_admin() then raise exception 'Admin access required'; end if;
  return query
  select t.id, t.user_id, u.email::text, p.full_name, t.subject, t.message, t.admin_reply,
         coalesce(t.status::text,'open')::text, coalesce(t.priority::text,'normal')::text, t.created_at, t.updated_at
  from public.support_tickets t
  left join auth.users u on u.id = t.user_id
  left join public.profiles p on p.id = t.user_id
  order by t.created_at desc nulls last;
end;
$$;
grant execute on function public.app_admin_list_tickets() to authenticated;

create or replace function public.app_admin_reply_ticket(p_ticket_id uuid, p_reply text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare v_user uuid;
begin
  if not public.app_is_admin() then raise exception 'Admin access required'; end if;
  select user_id into v_user from public.support_tickets where id = p_ticket_id;
  if v_user is null then raise exception 'Ticket not found'; end if;
  update public.support_tickets set admin_reply = coalesce(p_reply,''), status = 'answered', updated_at = now() where id = p_ticket_id;
  insert into public.user_notifications (user_id, title, body, status, created_at)
  values (v_user, 'Support reply received', coalesce(p_reply,'Your support request has been replied to.'), 'unread', now());
  return jsonb_build_object('ok', true, 'ticket_id', p_ticket_id);
end;
$$;
grant execute on function public.app_admin_reply_ticket(uuid, text) to authenticated;

create or replace function public.app_admin_list_users()
returns table(id uuid, email text, full_name text, phone text, role text, is_super_admin boolean, avatar_url text, avatar_base64 text, profile_picture_url text, profile_photo_url text, image_url text, photo_url text, created_at timestamptz, last_sign_in_at timestamptz, events_count bigint, uploads_count bigint, tickets_count bigint)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.app_is_admin() then raise exception 'Admin access required'; end if;
  return query
  select u.id, u.email::text, p.full_name, p.phone, coalesce(p.role::text,'user')::text, coalesce(p.is_super_admin,false),
         p.avatar_url, p.avatar_base64, p.profile_picture_url, p.profile_photo_url, p.image_url, p.photo_url,
         u.created_at, u.last_sign_in_at,
         (select count(*) from public.events e where e.owner_id = u.id or e.user_id = u.id)::bigint,
         (select count(*) from public.media_uploads m where m.uploader_id = u.id or m.user_id = u.id)::bigint,
         (select count(*) from public.support_tickets t where t.user_id = u.id)::bigint
  from auth.users u
  left join public.profiles p on p.id = u.id
  order by u.created_at desc;
end;
$$;
grant execute on function public.app_admin_list_users() to authenticated;

create or replace function public.app_admin_set_user_role(p_user_id uuid, p_role text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare v_role text := lower(coalesce(nullif(trim(p_role),''),'user'));
begin
  if not public.app_is_super_admin() then raise exception 'Super admin access required'; end if;
  if v_role not in ('user','sub_admin','super_admin','admin') then v_role := 'user'; end if;
  insert into public.profiles (id, role, is_super_admin, created_at, updated_at)
  values (p_user_id, v_role, v_role = 'super_admin', now(), now())
  on conflict (id) do update set role = excluded.role, is_super_admin = excluded.is_super_admin, updated_at = now();
  return jsonb_build_object('ok', true, 'user_id', p_user_id, 'role', v_role);
end;
$$;
grant execute on function public.app_admin_set_user_role(uuid, text) to authenticated;

create or replace function public.app_admin_list_events()
returns table(id uuid, title text, name text, slug text, event_kind text, event_type text, status text, owner_id uuid, owner_email text, gallery_cover_url text, created_at timestamptz, media_count bigint, guests_count bigint)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.app_is_admin() then raise exception 'Admin access required'; end if;
  return query
  select e.id, coalesce(e.title,e.name,'Memory Gallery')::text, coalesce(e.name,e.title,'Memory Gallery')::text, coalesce(e.slug,e.id::text)::text,
         coalesce(e.event_kind::text,e.event_type::text,'Event')::text, coalesce(e.event_type::text,e.event_kind::text,'Event')::text,
         coalesce(e.status::text,'active')::text, coalesce(e.owner_id,e.user_id), u.email::text, e.gallery_cover_url, e.created_at,
         (select count(*) from public.media_uploads m where m.event_id = e.id and m.deleted_at is null)::bigint,
         (select count(*) from public.event_guests g where g.event_id = e.id)::bigint
  from public.events e
  left join auth.users u on u.id = coalesce(e.owner_id,e.user_id)
  order by e.created_at desc nulls last;
end;
$$;
grant execute on function public.app_admin_list_events() to authenticated;

-- Make Bill super admin if the Auth user already exists.
-- Create bill@abp.ca in Supabase Authentication if it does not exist.
insert into public.profiles (id, full_name, role, is_super_admin, created_at, updated_at)
select id, 'Bill Admin', 'super_admin', true, now(), now()
from auth.users
where lower(email) = lower('bill@abp.ca')
on conflict (id) do update set full_name = 'Bill Admin', role = 'super_admin', is_super_admin = true, updated_at = now();

-- Also keep your existing account as super admin if present.
insert into public.profiles (id, full_name, role, is_super_admin, created_at, updated_at)
select id, coalesce(raw_user_meta_data->>'full_name','Admin'), 'super_admin', true, now(), now()
from auth.users
where lower(email) = lower('areebwebzards@gmail.com')
on conflict (id) do update set role = 'super_admin', is_super_admin = true, updated_at = now();

-- DONE
