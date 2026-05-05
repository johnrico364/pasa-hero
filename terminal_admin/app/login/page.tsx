"use client";

import Image from "next/image";
import { useState } from "react";
import { LuEye, LuEyeOff } from "react-icons/lu";
import logoName from "@/public/PasaHero-name.png";
import { useLogin } from "@/app/login/_hooks/useLogin";
import useAuthToken from "@/app/_public_hooks/useAuthToken";

export default function Login() {
  const { register, errors, isSubmitting, serverError, submitForm } =
    useLogin();
  const [showPassword, setShowPassword] = useState(false);
  useAuthToken({ redirectOnSuccess: "/admin/dashboard" });

  const inputBase =
    "w-full px-4 py-3 rounded-xl border bg-white/80 dark:bg-slate-800/80 text-slate-900 dark:text-slate-100 placeholder-slate-400 dark:placeholder-slate-500 focus:outline-none focus:ring-2 focus:border-transparent transition-all duration-200";
  const inputError =
    "border-red-400 dark:border-red-500 focus:ring-red-400/50 dark:focus:ring-red-500/50";
  const inputNormal =
    "border-slate-200 dark:border-slate-600 focus:ring-[#0062CA]/30 dark:focus:ring-[#0062CA]/30 focus:border-[#0062CA] dark:focus:border-[#0062CA]";

  return (
    <div className="min-h-screen flex items-center justify-center relative overflow-hidden bg-linear-to-br from-slate-50 via-[#0062CA]/6 to-slate-100 dark:from-slate-900 dark:via-slate-900 dark:to-[#0062CA]/10 p-4">
      {/* Decorative background elements */}
      <div className="absolute inset-0 overflow-hidden pointer-events-none">
        <div className="absolute -top-40 -right-40 w-80 h-80 rounded-full bg-[#0062CA]/20 dark:bg-[#0062CA]/10 blur-3xl" />
        <div className="absolute -bottom-40 -left-40 w-96 h-96 rounded-full bg-slate-300/30 dark:bg-slate-600/10 blur-3xl" />
        <div className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-[600px] h-[600px] rounded-full border border-slate-200/40 dark:border-slate-700/40" />
        <div className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-[400px] h-[400px] rounded-full border border-slate-200/30 dark:border-slate-700/30" />
      </div>

      <div className="w-full max-w-[420px] relative z-10">
        <div className="bg-white/90 dark:bg-slate-800/90 backdrop-blur-xl rounded-3xl shadow-2xl shadow-slate-200/50 dark:shadow-slate-950/50 border border-slate-200/60 dark:border-slate-700/60 p-8 md:p-10">
          {/* Logo / Brand */}
          <div className="text-center mb-8">
            <div className="flex justify-center mb-4">
              <Image
                src={logoName}
                alt="Logo"
                className="h-32 w-auto max-w-full object-contain"
                priority
              />
            </div>
            <p className="text-slate-500 dark:text-slate-400 text-sm mt-1">
              Sign in to Terminal Admin
            </p>
          </div>

          <form onSubmit={submitForm} className="space-y-5">
            {serverError && (
              <p
                role="alert"
                className="rounded-xl border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-700 dark:border-red-900/50 dark:bg-red-950/40 dark:text-red-300"
              >
                {serverError}
              </p>
            )}
            <div>
              <label
                htmlFor="email"
                className="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-2"
              >
                Email
              </label>
              <input
                id="email"
                type="email"
                placeholder="you@example.com"
                {...register("email")}
                className={`${inputBase} ${errors.email ? inputError : inputNormal}`}
              />
              {errors.email && (
                <p className="mt-1.5 text-sm text-red-600 dark:text-red-400 flex items-center gap-1">
                  <span aria-hidden>•</span>
                  {errors.email.message}
                </p>
              )}
            </div>

            <div>
              <label
                htmlFor="password"
                className="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-2"
              >
                Password
              </label>
              <div className="relative">
                <input
                  id="password"
                  type={showPassword ? "text" : "password"}
                  placeholder="••••••••"
                  {...register("password")}
                  className={`${inputBase} pr-12 ${errors.password ? inputError : inputNormal}`}
                />
                <button
                  type="button"
                  onClick={() => setShowPassword((v) => !v)}
                  className="absolute right-3 top-1/2 -translate-y-1/2 p-1.5 rounded-lg text-slate-500 hover:text-slate-700 dark:text-slate-400 dark:hover:text-slate-200 focus:outline-none focus-visible:ring-2 focus-visible:ring-[#0062CA]/40"
                  aria-label={showPassword ? "Hide password" : "Show password"}
                >
                  {showPassword ? (
                    <LuEyeOff className="w-5 h-5" aria-hidden />
                  ) : (
                    <LuEye className="w-5 h-5" aria-hidden />
                  )}
                </button>
              </div>
              {errors.password && (
                <p className="mt-1.5 text-sm text-red-600 dark:text-red-400 flex items-center gap-1">
                  <span aria-hidden>•</span>
                  {errors.password.message}
                </p>
              )}
            </div>

            <button
              type="submit"
              disabled={isSubmitting}
              className="w-full py-3.5 px-4 rounded-xl bg-linear-to-r from-[#0062CA] to-[#004a99] dark:from-[#0062CA] dark:to-[#004a99] text-white font-semibold shadow-lg shadow-[#0062CA]/25 hover:shadow-[#0062CA]/30 hover:from-[#1a75e0] hover:to-[#0062CA] focus:outline-none focus:ring-2 focus:ring-[#0062CA] focus:ring-offset-2 dark:focus:ring-offset-slate-800 transition-all duration-200 disabled:opacity-60 disabled:cursor-not-allowed disabled:hover:shadow-[#0062CA]/25"
            >
              {isSubmitting ? "Signing in…" : "Sign in"}
            </button>
          </form>

          <p className="mt-6 text-center text-xs text-slate-400 dark:text-slate-500">
            Secure access for administrators only.
          </p>
        </div>
      </div>
    </div>
  );
}
