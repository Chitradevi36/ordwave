"use client";
import { useEffect } from "react";
import { useRouter } from "next/navigation";

export default function RedirectPage() {
  const router = useRouter();
  useEffect(() => { router.replace("/compliance?tab=gstr3b"); }, [router]);
  return null;
}