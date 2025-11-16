--NB: create profiles table from prisma
-- https://supabase.com/docs/guides/database/prisma/prisma-troubleshooting#cross-schema-references-are-only-allowed-when-the-target-schema-is-listed-in-the-schemas-property-of-your-data-source
-- https://supabase.com/docs/guides/auth/row-level-security for more details.
-- https://supabase.com/docs/guides/auth/managing-user-data#using-triggers

-- Set up Row Level Security (RLS)
alter table profiles
  enable row level security;

create policy "Public profiles are viewable by everyone." on profiles
  for select using (true);

create policy "Users can insert their own profile." on profiles
  for insert with check ((select auth.uid()) = id);

create policy "Users can update own profile." on profiles
  for update using ((select auth.uid()) = id);

-- Set up Storage!
insert into storage.buckets (id, name)
  values ('avatars', 'avatars');
-- Set up access controls for storage.
create policy "Avatar images are publicly accessible." on storage.objects
  for select using (bucket_id = 'avatars');
create policy "Anyone can upload an avatar." on storage.objects
  for insert with check (bucket_id = 'avatars');


-- This trigger automatically creates a profile entry when a new user signs up via Supabase Auth.
create or replace function public.handle_new_user()
returns trigger
set search_path = ''
as $$
begin
  insert into public.profiles (id, full_name,email, avatar_url)
  values (new.id, 
  new.raw_user_meta_data->>'full_name', 
   new.email, 
  new.raw_user_meta_data->>'avatar_url');
  return new;
end;
$$ language plpgsql security definer;

-- Trigger to run 'handle_new_user' function after a new user is inserted into 'auth.users' table
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();


-- Function to handle the updating of a user's information in the 'profiles' table
create or replace function public.update_user()
returns trigger
language plpgsql
security definer set search_path = ''
as
$$
begin
  -- Update the user's data in the 'profiles' table from 'auth.users' table
  update public.profiles
  set    
   full_name = new.raw_user_meta_data->>'full_name',
   avatar_url = new.raw_user_meta_data->>'avatar_url',
   email = new.email
  where id = new.id;      
  return new;  -- Return the new record
end;
$$;
-- Trigger to run 'update_user' function after a user is updated in the 'auth.users' table
create trigger on_auth_user_updated
  after update on auth.users
  for each row execute procedure public.update_user();

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
-- Trigger to run 'delete_user' function after a user is deleted from the 'auth.users' table
create trigger on_auth_user_deleted
  after delete on auth.users
  for each row execute procedure public.delete_user();




