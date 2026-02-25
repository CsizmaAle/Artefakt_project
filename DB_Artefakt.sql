create table public.conversation_members (
  conversation_id uuid not null,
  user_id uuid not null,
  role text not null default 'member'::text,
  joined_at timestamp with time zone not null default now(),
  constraint conversation_members_pkey primary key (conversation_id, user_id),
  constraint conversation_members_conversation_id_fkey foreign KEY (conversation_id) references conversations (id) on delete CASCADE,
  constraint conversation_members_user_id_fkey foreign KEY (user_id) references auth.users (id) on delete CASCADE
) TABLESPACE pg_default;


create table public.conversations (
  id uuid not null default gen_random_uuid (),
  is_group boolean not null default false,
  title text null,
  created_by uuid not null,
  created_at timestamp with time zone not null default now(),
  last_message_at timestamp with time zone null,
  constraint conversations_pkey primary key (id),
  constraint conversations_created_by_fkey foreign KEY (created_by) references auth.users (id) on delete CASCADE
) TABLESPACE pg_default;

create index IF not exists idx_conversations_last_message_at on public.conversations using btree (last_message_at desc) TABLESPACE pg_default;


create table public.follows (
  follower_id uuid not null,
  target_id uuid not null,
  created_at timestamp with time zone null default now(),
  constraint follows_pkey primary key (follower_id, target_id),
  constraint follows_follower_id_fkey foreign KEY (follower_id) references auth.users (id) on delete CASCADE,
  constraint follows_target_id_fkey foreign KEY (target_id) references auth.users (id) on delete CASCADE,
  constraint no_self_follow check ((follower_id <> target_id))
) TABLESPACE pg_default;

create index IF not exists idx_follows_follower on public.follows using btree (follower_id) TABLESPACE pg_default;

create index IF not exists idx_follows_target on public.follows using btree (target_id) TABLESPACE pg_default;


create table public.message_reads (
  conversation_id uuid not null,
  user_id uuid not null,
  last_read_message_id bigint null,
  last_read_at timestamp with time zone not null default now(),
  constraint message_reads_pkey primary key (conversation_id, user_id),
  constraint message_reads_conversation_id_fkey foreign KEY (conversation_id) references conversations (id) on delete CASCADE,
  constraint message_reads_user_id_fkey foreign KEY (user_id) references auth.users (id) on delete CASCADE
) TABLESPACE pg_default;


create table public.messages (
  id bigserial not null,
  conversation_id uuid not null,
  sender_id uuid not null,
  content text null,
  attachment_url text null,
  created_at timestamp with time zone not null default now(),
  edited_at timestamp with time zone null,
  deleted_at timestamp with time zone null,
  constraint messages_pkey primary key (id),
  constraint messages_conversation_id_fkey foreign KEY (conversation_id) references conversations (id) on delete CASCADE,
  constraint messages_sender_id_fkey foreign KEY (sender_id) references auth.users (id) on delete CASCADE
) TABLESPACE pg_default;

create index IF not exists idx_messages_conv_created_at on public.messages using btree (conversation_id, created_at desc) TABLESPACE pg_default;


create table public.post_comments (
  id uuid not null default gen_random_uuid (),
  post_id uuid not null,
  user_id uuid not null,
  parent_id uuid null,
  body text not null,
  created_at timestamp with time zone null default now(),
  updated_at timestamp with time zone null default now(),
  constraint post_comments_pkey primary key (id),
  constraint post_comments_parent_id_fkey foreign KEY (parent_id) references post_comments (id) on delete CASCADE,
  constraint post_comments_post_id_fkey foreign KEY (post_id) references posts (id) on delete CASCADE,
  constraint post_comments_user_id_fkey foreign KEY (user_id) references auth.users (id) on delete CASCADE,
  constraint post_comments_body_check check (
    (
      length(
        TRIM(
          both
          from
            body
        )
      ) > 0
    )
  )
) TABLESPACE pg_default;

create index IF not exists idx_comments_post on public.post_comments using btree (post_id, created_at desc) TABLESPACE pg_default;

create index IF not exists idx_comments_parent on public.post_comments using btree (parent_id, created_at desc) TABLESPACE pg_default;

create trigger trg_comment_counts
after INSERT
or DELETE on post_comments for EACH row
execute FUNCTION bump_comments_count ();


create table public.post_likes (
  post_id uuid not null,
  user_id uuid not null,
  created_at timestamp with time zone null default now(),
  constraint post_likes_pkey primary key (post_id, user_id),
  constraint post_likes_post_id_fkey foreign KEY (post_id) references posts (id) on delete CASCADE,
  constraint post_likes_user_id_fkey foreign KEY (user_id) references auth.users (id) on delete CASCADE
) TABLESPACE pg_default;

create index IF not exists idx_likes_post on public.post_likes using btree (post_id) TABLESPACE pg_default;

create trigger trg_like_counts
after INSERT
or DELETE on post_likes for EACH row
execute FUNCTION bump_likes_count ();


create table public.post_shares (
  post_id uuid not null,
  user_id uuid not null,
  created_at timestamp with time zone null default now(),
  constraint post_shares_pkey primary key (post_id, user_id),
  constraint post_shares_post_id_fkey foreign KEY (post_id) references posts (id) on delete CASCADE,
  constraint post_shares_user_id_fkey foreign KEY (user_id) references auth.users (id) on delete CASCADE
) TABLESPACE pg_default;

create index IF not exists idx_shares_post on public.post_shares using btree (post_id) TABLESPACE pg_default;

create trigger trg_share_counts
after INSERT
or DELETE on post_shares for EACH row
execute FUNCTION bump_shares_count ();


create table public.posts (
  id uuid not null default extensions.uuid_generate_v4 (),
  author_id uuid null,
  body text null,
  created_at timestamp with time zone null default now(),
  terms text[] null default '{}'::text[],
  image_url text null,
  likes_count integer not null default 0,
  comments_count integer not null default 0,
  shares_count integer not null default 0,
  constraint posts_pkey primary key (id),
  constraint posts_author_id_fkey foreign KEY (author_id) references auth.users (id) on delete CASCADE
) TABLESPACE pg_default;

create index IF not exists idx_posts_created on public.posts using btree (created_at desc) TABLESPACE pg_default;

create index IF not exists idx_posts_author on public.posts using btree (author_id) TABLESPACE pg_default;


create table public.profiles (
  id uuid not null,
  email text null,
  username text not null,
  display_name text null,
  bio text null,
  photo_url text null,
  created_at timestamp with time zone null default now(),
  updated_at timestamp with time zone null default now(),
  constraint profiles_pkey primary key (id),
  constraint profiles_email_key unique (email),
  constraint profiles_username_key unique (username),
  constraint profiles_id_fkey foreign KEY (id) references auth.users (id) on delete CASCADE
) TABLESPACE pg_default;

create index IF not exists profiles_username_trgm on public.profiles using gin (username gin_trgm_ops) TABLESPACE pg_default;


create table public.search_history (
  id uuid not null default gen_random_uuid (),
  user_id uuid null,
  query text not null,
  search_type text null,
  created_at timestamp with time zone null default now(),
  constraint search_history_pkey primary key (id),
  constraint search_history_user_id_fkey foreign KEY (user_id) references auth.users (id) on delete CASCADE,
  constraint search_history_search_type_check check (
    (
      search_type = any (array['post'::text, 'user'::text])
    )
  )
) TABLESPACE pg_default;


create extension if not exists pg_trgm;         -- pentru căutare text rapidă


create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text unique,
  username text unique not null,
  display_name text,
  bio text,
  photo_url text,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- index pentru căutare după username (prefix/ilike)
create index if not exists profiles_username_trgm on public.profiles using gin (username gin_trgm_ops);

alter table public.profiles enable row level security;

-- oricine poate citi profilurile (poți schimba în 'to authenticated' dacă vrei privat)
create policy "profiles_public_read"
on public.profiles
for select
to public
using (true);

-- fiecare user își poate insera/edita propriul profil
create policy "profiles_insert_own"
on public.profiles
for insert
to authenticated
with check (auth.uid() = id);

create policy "profiles_update_own"
on public.profiles
for update
to authenticated
using (auth.uid() = id)
with check (auth.uid() = id);

create table if not exists public.follows (
  follower_id uuid references auth.users(id) on delete cascade,
  target_id   uuid references auth.users(id) on delete cascade,
  created_at  timestamptz default now(),
  primary key (follower_id, target_id),
  constraint no_self_follow check (follower_id <> target_id)
);

alter table public.follows enable row level security;

-- citire (publică sau doar autentificați)
create policy "follows_read"
on public.follows
for select
to public
using (true);

-- inserare: doar ca follower propriu
create policy "follows_insert_own"
on public.follows
for insert
to authenticated
with check (auth.uid() = follower_id and follower_id <> target_id);

-- ștergere: doar follower-ul își poate anula follow-ul
create policy "follows_delete_own"
on public.follows
for delete
to authenticated
using (auth.uid() = follower_id);

create table if not exists public.posts (
  id uuid primary key default uuid_generate_v4(),
  author_id uuid references auth.users(id) on delete cascade,
  title text not null,
  body text,
  created_at timestamptz default now(),
  terms text[] default '{}'
);

alter table public.posts enable row level security;

create policy "posts_public_read"
on public.posts
for select
to public
using (true);

create policy "posts_insert_own"
on public.posts
for insert
to authenticated
with check (auth.uid() = author_id);

create policy "posts_update_own"
on public.posts
for update
to authenticated
using (auth.uid() = author_id)
with check (auth.uid() = author_id);


create extension if not exists "uuid-ossp";


-- 1) Table
create table if not exists public.follows (
  pair_id text primary key,
  follower_id uuid not null references auth.users(id) on delete cascade,
  target_id   uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  constraint follows_not_self check (follower_id <> target_id),
  unique (follower_id, target_id)
);

-- 2) Indexes (fast counts & lookups)
create index if not exists idx_follows_follower on public.follows (follower_id);
create index if not exists idx_follows_target  on public.follows (target_id);

-- 3) RLS
alter table public.follows enable row level security;

-- Anyone can read (or restrict to authenticated if you prefer)
drop policy if exists follows_select on public.follows;
create policy follows_select
on public.follows for select
to public
using (true);

-- Only the logged-in user can follow from their account
drop policy if exists follows_insert on public.follows;
create policy follows_insert
on public.follows for insert
to authenticated
with check (auth.uid() = follower_id);

-- Only the follower can delete their follow
drop policy if exists follows_delete on public.follows;
create policy follows_delete
on public.follows for delete
to authenticated
using (auth.uid() = follower_id);


-- Enable RLS if not already
alter table storage.objects enable row level security;

-- Allow anyone to read profile photos (optional)
drop policy if exists "Public read access to avatars" on storage.objects;
create policy "Public read access to avatars"
on storage.objects for select
to public
using (bucket_id = 'avatars');

-- Allow authenticated users to upload files only to their own UID folder
drop policy if exists "Users can upload to own avatar folder" on storage.objects;
create policy "Users can upload to own avatar folder"
on storage.objects for insert
to authenticated
with check (
  bucket_id = 'avatars'
  and split_part(name, '/', 1) = auth.uid()::text
);

-- Allow users to update only their own files
drop policy if exists "Users can update own avatar files" on storage.objects;
create policy "Users can update own avatar files"
on storage.objects for update
to authenticated
using (
  bucket_id = 'avatars'
  and split_part(name, '/', 1) = auth.uid()::text
)
with check (
  bucket_id = 'avatars'
  and split_part(name, '/', 1) = auth.uid()::text
);

-- Allow users to delete only their own files
drop policy if exists "Users can delete own avatar files" on storage.objects;
create policy "Users can delete own avatar files"
on storage.objects for delete
to authenticated
using (
  bucket_id = 'avatars'
  and split_part(name, '/', 1) = auth.uid()::text
);


create table if not exists public.posts (
  id uuid primary key default gen_random_uuid(),
  author_id uuid not null references auth.users(id) on delete cascade,
  content_text text,                     -- optional
  image_url text,                        -- optional (public/signed URL)
  created_at timestamptz not null default now()
);

-- Helpful index
create index if not exists idx_posts_author on public.posts(author_id);
create index if not exists idx_posts_created on public.posts(created_at desc);

-- RLS
alter table public.posts enable row level security;

-- Anyone can read posts (or change to `to authenticated` if you want private feed)
drop policy if exists posts_select on public.posts;
create policy posts_select on public.posts
for select to public using (true);

-- Only the logged-in user can create a post as themselves
drop policy if exists posts_insert on public.posts;
create policy posts_insert on public.posts
for insert to authenticated
with check (auth.uid() = author_id);

-- Only the owner can update/delete their post (optional)
drop policy if exists posts_update on public.posts;
create policy posts_update on public.posts
for update to authenticated
using (auth.uid() = author_id)
with check (auth.uid() = author_id);

drop policy if exists posts_delete on public.posts;
create policy posts_delete on public.posts
for delete to authenticated
using (auth.uid() = author_id);


alter table public.posts add column if not exists image_url text;


-- If you don't already have it:
-- create table public.posts (
--   id uuid primary key default gen_random_uuid(),
--   author_id uuid not null references auth.users(id) on delete cascade,
--   content text,
--   created_at timestamptz default now()
-- );

-- a) Likes (one like per user per post)
create table if not exists public.post_likes (
  post_id uuid not null references public.posts(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz default now(),
  primary key (post_id, user_id)
);

-- b) Comments (supports threads via parent_id)
create table if not exists public.post_comments (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references public.posts(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  parent_id uuid null references public.post_comments(id) on delete cascade,
  body text not null check (length(trim(body)) > 0),
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- c) Shares/Reposts (one share per user per post; change PK if you want multiple)
create table if not exists public.post_shares (
  post_id uuid not null references public.posts(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz default now(),
  primary key (post_id, user_id)
);

-- Helpful indexes
create index if not exists idx_comments_post on public.post_comments(post_id, created_at desc);
create index if not exists idx_comments_parent on public.post_comments(parent_id, created_at desc);
create index if not exists idx_likes_post on public.post_likes(post_id);
create index if not exists idx_shares_post on public.post_shares(post_id);


alter table public.post_likes enable row level security;
alter table public.post_comments enable row level security;
alter table public.post_shares enable row level security;

-- Likes: anyone can read; only owner can insert/delete their like
create policy "likes_select_all"
on public.post_likes for select
to public using (true);

create policy "likes_insert_own"
on public.post_likes for insert
to authenticated with check (auth.uid() = user_id);

create policy "likes_delete_own"
on public.post_likes for delete
to authenticated using (auth.uid() = user_id);

-- Comments: anyone can read; only owner can insert/update/delete their comment
create policy "comments_select_all"
on public.post_comments for select
to public using (true);

create policy "comments_insert_own"
on public.post_comments for insert
to authenticated with check (auth.uid() = user_id);

create policy "comments_update_own"
on public.post_comments for update
to authenticated using (auth.uid() = user_id)
with check (auth.uid() = user_id);

create policy "comments_delete_own"
on public.post_comments for delete
to authenticated using (auth.uid() = user_id);

-- Shares: anyone can read; only owner can insert/delete their share
create policy "shares_select_all"
on public.post_shares for select
to public using (true);

create policy "shares_insert_own"
on public.post_shares for insert
to authenticated with check (auth.uid() = user_id);

create policy "shares_delete_own"
on public.post_shares for delete
to authenticated using (auth.uid() = user_id);




alter table public.posts
add column if not exists likes_count int not null default 0,
add column if not exists comments_count int not null default 0,
add column if not exists shares_count int not null default 0;

-- Trigger helpers (security definer so they bypass RLS safely)
create or replace function public.bump_likes_count() returns trigger
language plpgsql security definer as $$
begin
  if tg_op = 'INSERT' then
    update public.posts set likes_count = likes_count + 1 where id = new.post_id;
  elsif tg_op = 'DELETE' then
    update public.posts set likes_count = greatest(likes_count - 1, 0) where id = old.post_id;
  end if;
  return null;
end; $$;

create or replace function public.bump_comments_count() returns trigger
language plpgsql security definer as $$
begin
  if tg_op = 'INSERT' then
    update public.posts set comments_count = comments_count + 1 where id = new.post_id;
  elsif tg_op = 'DELETE' then
    update public.posts set comments_count = greatest(comments_count - 1, 0) where id = old.post_id;
  end if;
  return null;
end; $$;

create or replace function public.bump_shares_count() returns trigger
language plpgsql security definer as $$
begin
  if tg_op = 'INSERT' then
    update public.posts set shares_count = shares_count + 1 where id = new.post_id;
  elsif tg_op = 'DELETE' then
    update public.posts set shares_count = greatest(shares_count - 1, 0) where id = old.post_id;
  end if;
  return null;
end; $$;

drop trigger if exists trg_like_counts on public.post_likes;
create trigger trg_like_counts
after insert or delete on public.post_likes
for each row execute function public.bump_likes_count();

drop trigger if exists trg_comment_counts on public.post_comments;
create trigger trg_comment_counts
after insert or delete on public.post_comments
for each row execute function public.bump_comments_count();

drop trigger if exists trg_share_counts on public.post_shares;
create trigger trg_share_counts
after insert or delete on public.post_shares
for each row execute function public.bump_shares_count();



create or replace function public.toggle_like(p_post_id uuid)
returns boolean
language plpgsql
security definer
as $$
declare
  v_user uuid := auth.uid();
begin
  if v_user is null then
    raise exception 'not authenticated';
  end if;

  if exists (select 1 from public.post_likes where post_id = p_post_id and user_id = v_user) then
    delete from public.post_likes where post_id = p_post_id and user_id = v_user;
    return false; -- now unliked
  else
    insert into public.post_likes(post_id, user_id) values (p_post_id, v_user);
    return true;  -- now liked
  end if;
end; $$;



create or replace function public.add_comment(p_post_id uuid, p_body text, p_parent_id uuid default null)
returns uuid
language plpgsql
security definer
as $$
declare
  v_user uuid := auth.uid();
  v_id uuid;
begin
  if v_user is null then raise exception 'not authenticated'; end if;
  insert into public.post_comments(post_id, user_id, parent_id, body)
  values (p_post_id, v_user, p_parent_id, trim(p_body))
  returning id into v_id;
  return v_id;
end; $$;




create or replace function public.share_post(p_post_id uuid)
returns boolean
language plpgsql
security definer
as $$
declare
  v_user uuid := auth.uid();
begin
  if v_user is null then raise exception 'not authenticated'; end if;

  -- idempotent: one share per user per post
  insert into public.post_shares(post_id, user_id)
  values (p_post_id, v_user)
  on conflict do nothing;

  return true;
end; $$;


-- Make sure your clients can call them:
grant usage on schema public to anon, authenticated;
grant execute on function public.toggle_like(uuid)      to authenticated;
grant execute on function public.add_comment(uuid, text, uuid) to authenticated;
grant execute on function public.share_post(uuid)       to authenticated;


create table if not exists public.search_history (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete cascade,
  query text not null,
  search_type text check (search_type in ('post', 'user')),
  created_at timestamptz default now()
);


alter table public.search_history enable row level security;

-- Each user can view only their own history
create policy "user_can_view_own_history"
on public.search_history
for select
to authenticated
using (auth.uid() = user_id);

-- Each user can insert their own searches
create policy "user_can_insert_own_history"
on public.search_history
for insert
to authenticated
with check (auth.uid() = user_id);


-- 0) UUID generator (needed for gen_random_uuid)
create extension if not exists "pgcrypto" with schema extensions;

-- 1) Tables
create table if not exists public.conversations (
  id uuid primary key default gen_random_uuid(),
  is_group boolean not null default false,
  title text,
  created_by uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  last_message_at timestamptz
);

create table if not exists public.conversation_members (
  conversation_id uuid not null references public.conversations(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null default 'member',
  joined_at timestamptz not null default now(),
  primary key (conversation_id, user_id)
);

create table if not exists public.messages (
  id bigserial primary key,
  conversation_id uuid not null references public.conversations(id) on delete cascade,
  sender_id uuid not null references auth.users(id) on delete cascade,
  content text,
  attachment_url text,
  created_at timestamptz not null default now(),
  edited_at timestamptz,
  deleted_at timestamptz
);

create table if not exists public.message_reads (
  conversation_id uuid not null references public.conversations(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  last_read_message_id bigint,
  last_read_at timestamptz not null default now(),
  primary key (conversation_id, user_id)
);

-- helpful indexes
create index if not exists idx_messages_conv_created_at
  on public.messages(conversation_id, created_at desc);
create index if not exists idx_conversations_last_message_at
  on public.conversations(last_message_at desc);

-- 2) RLS + policies required by start_dm()
alter table public.conversations enable row level security;
alter table public.conversation_members enable row level security;
alter table public.messages enable row level security;
alter table public.message_reads enable row level security;

create policy conv_select on public.conversations
for select to authenticated
using (exists (
  select 1 from public.conversation_members m
  where m.conversation_id = id and m.user_id = auth.uid()
));

create policy conv_insert on public.conversations
for insert to authenticated
with check (created_by = auth.uid());

create policy members_select on public.conversation_members
for select to authenticated
using (
  user_id = auth.uid()
  or exists (
    select 1 from public.conversation_members m
    where m.conversation_id = conversation_id and m.user_id = auth.uid()
  )
);

create policy members_insert on public.conversation_members
for insert to authenticated
with check (
  user_id = auth.uid()
  or exists (
    select 1 from public.conversation_members m
    where m.conversation_id = conversation_id and m.user_id = auth.uid()
  )
);

create policy msg_select on public.messages
for select to authenticated
using (exists (
  select 1 from public.conversation_members m
  where m.conversation_id = conversation_id and m.user_id = auth.uid()
));

create policy msg_insert on public.messages
for insert to authenticated
with check (
  sender_id = auth.uid()
  and exists (
    select 1 from public.conversation_members m
    where m.conversation_id = conversation_id and m.user_id = auth.uid()
  )
);

create policy reads_select on public.message_reads
for select to authenticated
using (user_id = auth.uid());

-- Remove the invalid combined policy
drop policy if exists reads_upsert on public.message_reads;

-- Allow INSERT only for the row owner
create policy reads_insert on public.message_reads
for insert to authenticated
with check (user_id = auth.uid());

-- Allow UPDATE only by the row owner (and keep it owned after update)
create policy reads_update on public.message_reads
for update to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());


-- 3) start_dm() (drops & recreates, includes search_path + grant)
drop function if exists public.start_dm(uuid);

create or replace function public.start_dm(other_user uuid)
returns uuid
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  conv_id uuid;
begin
  if other_user = auth.uid() then
    raise exception 'Cannot DM yourself';
  end if;

  select c.id into conv_id
  from public.conversations c
  join public.conversation_members m1
    on m1.conversation_id = c.id and m1.user_id = auth.uid()
  join public.conversation_members m2
    on m2.conversation_id = c.id and m2.user_id = other_user
  where c.is_group = false
  limit 1;

  if conv_id is null then
    insert into public.conversations (is_group, created_by, last_message_at)
    values (false, auth.uid(), now())
    returning id into conv_id;

    insert into public.conversation_members (conversation_id, user_id, role)
    values (conv_id, auth.uid(), 'admin');

    insert into public.conversation_members (conversation_id, user_id, role)
    values (conv_id, other_user, 'member');
  end if;

  return conv_id;
end;
$$;

grant execute on function public.start_dm(uuid) to authenticated;

-- 4) (Optional) Storage policies for bucket `chat-attachments`
-- Adjust bucket_id if yours is different, and ensure your upload path:
-- user_uploads/<uid>/<conversationId>/<timestamp>_<filename>
-- Storage policies (bucket: chat-attachments)

create policy "chat_insert_owner_folder"
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'chat-attachments'
  and (storage.foldername(name))[1] = 'user_uploads'
  and (storage.foldername(name))[2] = auth.uid()::text
);

create policy "chat_select_owner_or_member"
on storage.objects
for select
to authenticated
using (
  bucket_id = 'chat-attachments'
  and (
    (storage.foldername(name))[2] = auth.uid()::text
    or exists (
      select 1 from public.conversation_members m
      where m.user_id = auth.uid()
        and m.conversation_id::text = (storage.foldername(name))[3]
    )
  )
);

create policy "chat_delete_owner_only"
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'chat-attachments'
  and (storage.foldername(name))[2] = auth.uid()::text
);



create or replace function public.is_conversation_member(p_conversation_id uuid, p_user_id uuid default auth.uid())
returns boolean
language sql
security definer
set search_path = public, extensions
as $$
select exists (
select 1
from public.conversation_members
where conversation_id = p_conversation_id
and user_id = coalesce(p_user_id, auth.uid())
);
$$;

grant execute on function public.is_conversation_member(uuid, uuid) to authenticated;


drop policy if exists members_select on public.conversation_members;
create policy members_select on public.conversation_members
for select to authenticated
using (is_conversation_member(conversation_id));

drop policy if exists members_insert on public.conversation_members;
create policy members_insert on public.conversation_members
for insert to authenticated
with check (
user_id = auth.uid() or is_conversation_member(conversation_id)
);


drop policy if exists conv_select on public.conversations;
create policy conv_select on public.conversations
for select to authenticated
using (is_conversation_member(id));

drop policy if exists conv_insert on public.conversations;
create policy conv_insert on public.conversations
for insert to authenticated
with check (created_by = auth.uid());


drop policy if exists msg_select on public.messages;
create policy msg_select on public.messages
for select to authenticated
using (is_conversation_member(conversation_id));

drop policy if exists msg_insert on public.messages;
create policy msg_insert on public.messages
for insert to authenticated
with check (
sender_id = auth.uid()
and is_conversation_member(conversation_id)
);


alter publication supabase_realtime add table public.messages;
alter publication supabase_realtime add table public.conversation_members;
alter publication supabase_realtime add table public.conversations;

