"use client";

import { useState, useEffect } from "react";

interface PincodeLookupResult {
  city: string;
  state: string;
  loading: boolean;
}

export function usePincodeLookup(pincode: string): PincodeLookupResult {
  const [city, setCity]       = useState("");
  const [state, setState]     = useState("");
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    if (!/^\d{6}$/.test(pincode)) {
      setCity(""); setState("");
      return;
    }

    let cancelled = false;
    setLoading(true);

    fetch(`https://api.postalpincode.in/pincode/${pincode}`)
      .then((r) => r.json())
      .then(([data]: [{ Status: string; PostOffice?: { District: string; State: string }[] }]) => {
        if (cancelled) return;
        if (data.Status === "Success" && data.PostOffice?.length) {
          setCity(data.PostOffice[0].District);
          setState(data.PostOffice[0].State);
        } else {
          setCity(""); setState("");
        }
      })
      .catch(() => { if (!cancelled) { setCity(""); setState(""); } })
      .finally(() => { if (!cancelled) setLoading(false); });

    return () => { cancelled = true; };
  }, [pincode]);

  return { city, state, loading };
}
