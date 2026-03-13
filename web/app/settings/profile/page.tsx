import { redirect } from "next/navigation";

// /settings/profile is aliased to /settings/account
export default function ProfileRedirectPage() {
  redirect("/settings/account");
}
