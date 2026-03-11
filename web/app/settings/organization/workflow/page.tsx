import { redirect } from "next/navigation";

export default function WorkflowRedirectPage() {
  redirect("/settings/organization?tab=workflow");
}

