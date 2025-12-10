"use server";

import { createClient } from "@/lib/supabase/server";
import { redirect } from "next/navigation";

//OAuth
const signInWith = (provider: "google" | "github") => async () => {
const supabase = await createClient();

  const auth_callback_url = `${process.env.SITE_URL}/auth/callback`;

  const { data, error } = await supabase.auth.signInWithOAuth({
    provider,
    options: {
      redirectTo: auth_callback_url,
    },
  });

  console.log(data);

  if (error) console.log(error);
  
  redirect(data.url ?? "/"); //redirect to googl's consent screeen.
};
const signinWithGoogle = await signInWith("google");

//Magic Link OTP
const signinWithMagicLink = async (email: string) => {
  const supabase = await createClient();

  const { data, error } = await supabase.auth.signInWithOtp({
    email,
    options: {
      emailRedirectTo: `${process.env.SITE_URL}/auth/callback`,
    },
  });
  console.log(data);
  if (error) {
    console.log(error);
    return { success: null, error: error.message };
  }
  return { success: "please check your email", error: null };
};



//Anonymous 
// Create anonymous user if not logged in , signinAnonymously 
 const getOrCreateAnonymousUser = async () => {
  const supabase = await createClient();
  
  // Check if we have a session
  const { data: { session } } = await supabase.auth.getSession();
  
  if (session) {
    return { user: session.user, session };
  }  
  // Create anonymous user
  const { data, error } = await supabase.auth.signInAnonymously({
    options: {
      data: {
        // These fields will be available in raw_user_meta_data
        full_name: 'Anonymous User',
        avatar_url: ''
      }
    }
  });
  
  if (error) {
    console.error('Error creating anonymous user:', error);
    throw error;
  }  
  return { user: data.user, session: data.session };
};

// Get current user (works for both authenticated and anonymous)
 const getCurrentUser = async () => {
  const supabase = await createClient();
  
  try {
    const { data: { user }, error } = await supabase.auth.getUser();
    
    if (error) {
      // Try to create anonymous user
      return await getOrCreateAnonymousUser();
    }
    
    if (!user) {
      return await getOrCreateAnonymousUser();
    }
    
    return { user };
  } catch (error) {
    // Fallback to anonymous user
    return await getOrCreateAnonymousUser();
  }
};

// Regular auth check (for pages that require real authentication)(not anonymous).
 const getAuthUser = async () => {
  const supabase = await createClient();
  const { data: { user }, error } = await supabase.auth.getUser();
  
  if (error || !user) {
    throw new Error('User not authenticated');
  }
  
  return user;
};
// Check if user is authenticated (not anonymous)
 const isUserAuthenticated = async (): Promise<boolean> => {
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();
  
  if (!user) return false;
  
  // Check if user is anonymous (anonymous users have specific metadata)
  return !user.is_anonymous;
};

// Convert anonymous user to permanent account
 const convertAnonymousToPermanent = async (email: string, password: string) => {
  const supabase = await createClient();
  
  // First, get current anonymous user
  const { data: { user } } = await supabase.auth.getUser();
  
  if (!user || !user.is_anonymous) {
    throw new Error('User is not anonymous');
  }
  
  // Update user with email and password
  const { data, error } = await supabase.auth.updateUser({
    email,
    password,
  });
  
  if (error) {
    console.error('Error updating user:', error)
    throw error;
  }
  
  return data;
};

const signOut = async () => {
  const supabase = await createClient();
  const { error } = await supabase.auth.signOut();
  
  if (error) {
    throw error;
  }
  
  // After sign out, create a new anonymous user for guest shopping
  await getOrCreateAnonymousUser();  
  return true;
};

export { signinWithGoogle, signOut, signinWithMagicLink,
   getOrCreateAnonymousUser, getCurrentUser ,getAuthUser, isUserAuthenticated, convertAnonymousToPermanent};


