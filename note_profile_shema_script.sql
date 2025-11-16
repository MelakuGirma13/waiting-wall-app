--NB: create profiles table from prisma

-- Set up Row Level Security (RLS)
-- See https://supabase.com/docs/guides/auth/row-level-security for more details.
alter table profiles
  enable row level security;

create policy "Public profiles are viewable by everyone." on profiles
  for select using (true);

create policy "Users can insert their own profile." on profiles
  for insert with check ((select auth.uid()) = id);

create policy "Users can update own profile." on profiles
  for update using ((select auth.uid()) = id);

-- This trigger automatically creates a profile entry when a new user signs up via Supabase Auth.
-- See https://supabase.com/docs/guides/auth/managing-user-data#using-triggers for more details.
create function public.handle_new_user()
returns trigger
set search_path = ''
as $$
begin
  insert into public.profiles (id, full_name, avatar_url)
  values (new.id, new.raw_user_meta_data->>'full_name', new.raw_user_meta_data->>'avatar_url');
  return new;
end;
$$ language plpgsql security definer;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- Set up Storage!
insert into storage.buckets (id, name)
  values ('avatars', 'avatars');

-- Set up access controls for storage.
-- See https://supabase.com/docs/guides/storage#policy-examples for more details.
create policy "Avatar images are publicly accessible." on storage.objects
  for select using (bucket_id = 'avatars');

create policy "Anyone can upload an avatar." on storage.objects
  for insert with check (bucket_id = 'avatars');

--=================== to use profiles with prisma ORM=================
--refer => https://supabase.com/docs/guides/database/prisma/prisma-troubleshooting#cross-schema-references-are-only-allowed-when-the-target-schema-is-listed-in-the-schemas-property-of-your-data-source
-- Function to handle the insertion of a new user into the 'profiles' table
create function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = ''
as $$
begin

  -- Insert the new user's data into the 'profiles' table
  insert into public.profiles  (id, username,full_name,avatar_url,email,bio)
  values (new.id, new.username, new.full_name, new.avatar_url, new.email, new.bio);

  return new;     -- Return the new record
end;
$$;

-- Function to handle the updating of a user's information in the 'profiles' table
create function public.update_user()
returns trigger
language plpgsql
security definer set search_path = ''
as
$$
begin
  -- Update the user's data in the 'profiles' table
  update public.profiles
  set username = new.username,     
   full_name = new.full_name,
   avatar_url = new.avatar_url,
   email = new.email,
   bio = new.bio
  where id = new.id;        -- Match the 'id' field with the new record

  return new;  -- Return the new record
end;
$$;

-- Function to handle the deletion of a user from the 'profiles' table
create function public.delete_user()
returns trigger
language plpgsql
security definer set search_path = ''
as
$$
begin
  -- Delete the user's data from the 'profiles' table
  delete from public.profiles
  where id = old.id;  -- Match the 'id' field with the old record

  return old;  -- Return the old record
end;
$$;

-- Trigger to run 'handle_new_user' function after a new user is inserted into 'auth.users' table
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- Trigger to run 'update_user' function after a user is updated in the 'auth.users' table
create trigger on_auth_user_updated
  after update on auth.users
  for each row execute procedure public.update_user();

-- Trigger to run 'delete_user' function after a user is deleted from the 'auth.users' table
create trigger on_auth_user_deleted
  after delete on auth.users
  for each row execute procedure public.delete_user();