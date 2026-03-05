"use client";

import React, { useEffect, useState } from "react";
import { Modal } from "@/components/ui/modal";
import { Loader2 } from "lucide-react";

interface User {
  id: number;
  name: string;
  email: string;
}

interface Props {
  beatId: string;
  open: boolean;
  onClose: () => void;
  onCreated: () => void;
  token: string;
  orgId: string;
  branchId: string;
}

const WEEKDAYS = [
  { value: 0, label: "Monday" },
  { value: 1, label: "Tuesday" },
  { value: 2, label: "Wednesday" },
  { value: 3, label: "Thursday" },
  { value: 4, label: "Friday" },
  { value: 5, label: "Saturday" },
  { value: 6, label: "Sunday" },
];

export function AddScheduleModal({
  beatId,
  open,
  onClose,
  onCreated,
  token,
  orgId,
  branchId,
}: Props) {
  const [weekday, setWeekday] = useState<number>(0);
  const [repId, setRepId] = useState("");
  const [users, setUsers] = useState<User[]>([]);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState("");

  useEffect(() => {
    if (!open || !token || !orgId) return;
    fetch(`/api/v1/users?per_page=100&status=active`, {
      headers: {
        Authorization: `Bearer ${token}`,
        "X-Organization-Id": orgId,
      },
    })
      .then((r) => r.json())
      .then((d) => setUsers(d.data ?? []));
  }, [open, token, orgId]);

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setError("");
    if (!repId) { setError("Please select a sales rep."); return; }

    setSaving(true);
    try {
      const res = await fetch(`/api/v1/beats/${beatId}/schedules`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${token}`,
          "X-Organization-Id": orgId,
        },
        body: JSON.stringify({
          beat_schedule: {
            weekday,
            sales_rep_id: Number(repId),
            branch_id: branchId || undefined,
            active: true,
          },
        }),
      });
      const data = await res.json();
      if (res.ok) {
        onCreated();
      } else {
        setError((data.errors ?? []).join(", ") || "Failed to create schedule.");
      }
    } finally {
      setSaving(false);
    }
  }

  return (
    <Modal open={open} onClose={onClose} title="Add Beat Schedule" size="sm">
      <form onSubmit={handleSubmit} className="space-y-4 mt-3">
        <div>
          <label className="block text-sm font-medium mb-2">Day of week</label>
          <div className="flex flex-wrap gap-2">
            {WEEKDAYS.map((d) => (
              <button
                type="button"
                key={d.value}
                onClick={() => setWeekday(d.value)}
                className={`px-3 py-1.5 rounded-md text-sm font-medium transition-colors border ${
                  weekday === d.value
                    ? "bg-primary text-white border-primary"
                    : "bg-background text-text-secondary border-border hover:bg-muted"
                }`}
              >
                {d.label.slice(0, 3)}
              </button>
            ))}
          </div>
        </div>

        <div>
          <label className="block text-sm font-medium mb-1">Sales Rep *</label>
          <select
            className="w-full border border-border rounded-md px-3 py-2 text-sm bg-background focus:outline-none focus:ring-2 focus:ring-primary"
            value={repId}
            onChange={(e) => setRepId(e.target.value)}
            required
          >
            <option value="">— Select rep —</option>
            {users.map((u) => (
              <option key={u.id} value={u.id}>
                {u.name} ({u.email})
              </option>
            ))}
          </select>
        </div>

        {error && <p className="text-sm text-destructive">{error}</p>}

        <div className="flex justify-end gap-3 pt-2">
          <button
            type="button"
            onClick={onClose}
            className="px-4 py-2 text-sm rounded-md border border-border hover:bg-muted"
          >
            Cancel
          </button>
          <button
            type="submit"
            disabled={saving}
            className="inline-flex items-center gap-2 px-4 py-2 text-sm rounded-md bg-primary text-white hover:bg-primary/90 disabled:opacity-50"
          >
            {saving && <Loader2 className="h-3.5 w-3.5 animate-spin" />}
            {saving ? "Adding…" : "Add Schedule"}
          </button>
        </div>
      </form>
    </Modal>
  );
}
