-- CreateSchema
CREATE SCHEMA IF NOT EXISTS "public";

-- CreateTable
CREATE TABLE "public"."profiles" (
    "id" UUID NOT NULL,
    "updated_at" TIMESTAMPTZ(6),
    "username" TEXT,
    "full_name" TEXT,
    "avatar_url" TEXT,
    "website" TEXT,

    CONSTRAINT "profiles_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "public"."todos" (
    "id" SERIAL NOT NULL,
    "task" TEXT,
    "user_id" UUID,

    CONSTRAINT "todos_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "public"."Post" (
    "id" SERIAL NOT NULL,
    "title" TEXT NOT NULL,
    "content" TEXT,
    "published" BOOLEAN NOT NULL DEFAULT false,
    "authorId" UUID,

    CONSTRAINT "Post_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "public"."User" (
    "id" UUID NOT NULL,
    "email" TEXT NOT NULL,
    "name" TEXT,

    CONSTRAINT "User_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "profiles_username_key" ON "public"."profiles"("username");

-- CreateIndex
CREATE UNIQUE INDEX "User_email_key" ON "public"."User"("email");

-- AddForeignKey
ALTER TABLE "public"."Post" ADD CONSTRAINT "Post_authorId_fkey" FOREIGN KEY ("authorId") REFERENCES "public"."User"("id") ON DELETE SET NULL ON UPDATE CASCADE;

