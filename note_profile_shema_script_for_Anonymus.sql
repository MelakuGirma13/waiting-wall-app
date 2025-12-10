-- First, let's update the profiles table to support anonymous users
ALTER TABLE public.profiles 
ADD COLUMN IF NOT EXISTS is_anonymous boolean DEFAULT false;

-- Make email nullable for anonymous users
ALTER TABLE public.profiles 
ALTER COLUMN email DROP NOT NULL;

-- Add default value for full_name
ALTER TABLE public.profiles 
ALTER COLUMN full_name SET DEFAULT 'Anonymous User';

-- Set up Row Level Security (RLS)
ALTER TABLE profiles
  ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Public profiles are viewable by everyone." ON profiles;
DROP POLICY IF EXISTS "Users can insert their own profile." ON profiles;
DROP POLICY IF EXISTS "Users can update own profile." ON profiles;

-- Create updated policies
CREATE POLICY "Public profiles are viewable by everyone." ON profiles
  FOR SELECT USING (true);

CREATE POLICY "Users can insert their own profile." ON profiles
  FOR INSERT WITH CHECK (
    auth.uid() = id OR 
    (SELECT raw_app_meta_data->>'provider' FROM auth.users WHERE id = auth.uid()) = 'anonymous'
  );

CREATE POLICY "Users can update own profile." ON profiles
  FOR UPDATE USING (auth.uid() = id);

-- Set up Storage!
INSERT INTO storage.buckets (id, name)
  VALUES ('avatars', 'avatars')
ON CONFLICT (id) DO NOTHING;

-- Set up access controls for storage.
DROP POLICY IF EXISTS "Avatar images are publicly accessible." ON storage.objects;
DROP POLICY IF EXISTS "Anyone can upload an avatar." ON storage.objects;

CREATE POLICY "Avatar images are publicly accessible." ON storage.objects
  FOR SELECT USING (bucket_id = 'avatars');
CREATE POLICY "Anyone can upload an avatar." ON storage.objects
  FOR INSERT WITH CHECK (bucket_id = 'avatars');

-- Drop existing triggers first
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
DROP TRIGGER IF EXISTS on_auth_user_updated ON auth.users;
DROP TRIGGER IF EXISTS on_auth_user_deleted ON auth.users;

-- Drop existing functions
DROP FUNCTION IF EXISTS public.handle_new_user();
DROP FUNCTION IF EXISTS public.update_user();
DROP FUNCTION IF EXISTS public.delete_user();

-- This trigger automatically creates a profile entry when a new user signs up via Supabase Auth.
-- UPDATED: Now handles anonymous users properly
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
SECURITY DEFINER
SET search_path = ''
LANGUAGE plpgsql
AS $$
BEGIN
  -- Check if this is an anonymous user
  IF NEW.raw_app_meta_data->>'provider' = 'anonymous' OR NEW.email IS NULL THEN
    -- For anonymous users, create a profile with minimal data
    INSERT INTO public.profiles (id, full_name, email, avatar_url, is_anonymous)
    VALUES (
      NEW.id,
      COALESCE(NEW.raw_user_meta_data->>'full_name', 'Anonymous User'),
      NULL, -- Anonymous users don't have email
      COALESCE(NEW.raw_user_meta_data->>'avatar_url', ''),
      true
    )
    ON CONFLICT (id) DO NOTHING;
  ELSE
    -- For regular users
    INSERT INTO public.profiles (id, full_name, email, avatar_url, is_anonymous)
    VALUES (
      NEW.id,
      COALESCE(NEW.raw_user_meta_data->>'full_name', 'User'),
      NEW.email,
      COALESCE(NEW.raw_user_meta_data->>'avatar_url', ''),
      false
    )
    ON CONFLICT (id) DO NOTHING;
  END IF;
  
  RETURN NEW;
EXCEPTION
  WHEN OTHERS THEN
    -- Log the error but don't fail the user creation
    RAISE LOG 'Error in handle_new_user for user %: %', NEW.id, SQLERRM;
    RETURN NEW;
END;
$$;

-- Trigger to run 'handle_new_user' function after a new user is inserted into 'auth.users' table
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE PROCEDURE public.handle_new_user();

-- Function to handle the updating of a user's information in the 'profiles' table
-- UPDATED: Handles both regular and anonymous users
CREATE OR REPLACE FUNCTION public.update_user()
RETURNS TRIGGER
SECURITY DEFINER
SET search_path = ''
LANGUAGE plpgsql
AS $$
BEGIN
  -- Update the user's data in the 'profiles' table
  UPDATE public.profiles
  SET    
    full_name = COALESCE(NEW.raw_user_meta_data->>'full_name', 
                        CASE 
                          WHEN NEW.raw_app_meta_data->>'provider' = 'anonymous' THEN 'Anonymous User'
                          ELSE full_name 
                        END),
    avatar_url = COALESCE(NEW.raw_user_meta_data->>'avatar_url', avatar_url),
    email = CASE 
              WHEN NEW.raw_app_meta_data->>'provider' = 'anonymous' THEN NULL
              ELSE COALESCE(NEW.email, email)
            END,
    is_anonymous = NEW.raw_app_meta_data->>'provider' = 'anonymous'
  WHERE id = NEW.id;
  
  -- If no profile exists (shouldn't happen, but just in case)
  IF NOT FOUND THEN
    INSERT INTO public.profiles (id, full_name, email, avatar_url, is_anonymous)
    VALUES (
      NEW.id,
      COALESCE(NEW.raw_user_meta_data->>'full_name', 'User'),
      NEW.email,
      COALESCE(NEW.raw_user_meta_data->>'avatar_url', ''),
      NEW.raw_app_meta_data->>'provider' = 'anonymous'
    )
    ON CONFLICT (id) DO NOTHING;
  END IF;
  
  RETURN NEW;
END;
$$;

-- Trigger to run 'update_user' function after a user is updated in the 'auth.users' table
CREATE TRIGGER on_auth_user_updated
  AFTER UPDATE ON auth.users
  FOR EACH ROW EXECUTE PROCEDURE public.update_user();

-- Function to handle the deletion of a user from the 'profiles' table
CREATE OR REPLACE FUNCTION public.delete_user()
RETURNS TRIGGER
SECURITY DEFINER
SET search_path = ''
LANGUAGE plpgsql
AS $$
BEGIN
  -- Delete the user's data from the 'profiles' table
  DELETE FROM public.profiles
  WHERE id = OLD.id;
  
  RETURN OLD;
EXCEPTION
  WHEN OTHERS THEN
    -- Log error but continue with deletion
    RAISE LOG 'Error deleting profile for user %: %', OLD.id, SQLERRM;
    RETURN OLD;
END;
$$;

-- Trigger to run 'delete_user' function after a user is deleted from the 'auth.users' table
CREATE TRIGGER on_auth_user_deleted
  AFTER DELETE ON auth.users
  FOR EACH ROW EXECUTE PROCEDURE public.delete_user();
  
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