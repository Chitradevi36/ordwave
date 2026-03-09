"use client";

import { useRouter } from "next/navigation";
import { useEffect } from "react";

export default function CompliancePage() {
  const router = useRouter();
  useEffect(() => { router.replace("/compliance/gstr1"); }, [router]);
  return null;
}
