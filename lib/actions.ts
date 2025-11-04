"use server";

import { createClient } from "@/lib/supabase/server";
import { redirect } from "next/navigation";

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

  if (error) {
    console.log(error);
  }

  redirect(data.url ?? "/"); //redirect to googl's consent screeen.
};
const signinWithGoogle = await signInWith("google");

//Magic Link
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

const signOut = async () => {
  const supabase = await createClient();
  await supabase.auth.signOut();
};

export { signinWithGoogle, signOut,signinWithMagicLink };
