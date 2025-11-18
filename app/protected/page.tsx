import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { InfoIcon } from "lucide-react";
import { FetchDataSteps } from "@/components/tutorial/fetch-data-steps";
import { Avatar, AvatarFallback, AvatarImage } from "@/components/ui/avatar"; // Adjust import path as needed

export default async function ProtectedPage() {
  const supabase = await createClient();

  const { data, error } = await supabase.auth.getUser();
  if (error || !data?.user) {
    redirect("/auth/login");
  }

  const { name, email, avatar_url } = data.user.user_metadata;
  const app_metadata = data.user.app_metadata;

  const { data: todos, error: todosError } = await supabase
    .from("todos")
    .select();
  console.log(todos);

  return (
    <div className="flex-1 w-full flex flex-col gap-12">
      <div className="w-full">
        <div className="bg-accent text-sm p-3 px-5 rounded-md text-foreground flex gap-3 items-center">
          <InfoIcon size="16" strokeWidth={2} />
          This is a protected page that you can only see as an authenticated user
        </div>
      </div>
      <div className="flex flex-col gap-2 items-start">
        <h2 className="font-bold text-2xl mb-4">Your user details</h2>
        
        {/* Fixed Avatar Section */}
        <div className="flex items-center gap-4 mb-4">
          {avatar_url && (
            <Avatar className="h-20 w-20 rounded-full border-2 border-gray-300">
              <AvatarImage 
                src={avatar_url} 
                alt={`${name}'s avatar`}
                className="rounded-full object-cover"
              />
              <AvatarFallback 
                delayMs={600}
                className="rounded-full bg-blue-100 text-blue-800 flex items-center justify-center text-xl font-bold"
              >
                {name ? name.charAt(0).toUpperCase() : 'U'}
              </AvatarFallback>
            </Avatar>
          )}
          <div>
            <h1 className="text-4xl font-bold">{name}</h1>
            <p className="text-xl text-gray-600">Email: {email}</p>
            <p className="text-xl text-gray-600">Created with: {app_metadata.provider}</p>
          </div>
        </div>

        <pre className="text-xs font-mono p-3 rounded border max-h-32 overflow-auto bg-gray-50">
          {JSON.stringify(data.user, null, 2)}
        </pre>
        <pre className="text-xs font-mono p-3 rounded border max-h-32 overflow-auto bg-gray-50">
          {JSON.stringify(todos, null, 2)}
        </pre>
      </div>
      <div>
        <h2 className="font-bold text-2xl mb-4">Next steps</h2>
        <FetchDataSteps />
      </div>
    </div>
  );
}