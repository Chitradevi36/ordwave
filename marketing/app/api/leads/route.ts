import { NextRequest, NextResponse } from "next/server";

type TurnstileVerificationResponse = {
  success: boolean;
  "error-codes"?: string[];
};

async function verifyCaptcha(req: NextRequest, token: unknown) {
  const secret = process.env.TURNSTILE_SECRET_KEY;

  if (!secret || typeof token !== "string" || !token) {
    return false;
  }

  const forwardedFor = req.headers.get("x-forwarded-for");
  const remoteIp = req.headers.get("cf-connecting-ip") || forwardedFor?.split(",")[0]?.trim();
  const formData = new FormData();
  formData.append("secret", secret);
  formData.append("response", token);

  if (remoteIp) {
    formData.append("remoteip", remoteIp);
  }

  const response = await fetch("https://challenges.cloudflare.com/turnstile/v0/siteverify", {
    method: "POST",
    body: formData,
  });

  const result = (await response.json().catch(() => ({}))) as TurnstileVerificationResponse;

  return response.ok && result.success;
}

export async function POST(req: NextRequest) {
  try {
    const body = await req.json();
    const { captchaToken, ...leadPayload } = body;

    const isCaptchaValid = await verifyCaptcha(req, captchaToken);

    if (!isCaptchaValid) {
      return NextResponse.json(
        { errors: ["Captcha verification failed. Please try again."] },
        { status: 400 }
      );
    }

    const backendUrl =
      process.env.BACKEND_API_URL ||
      process.env.NEXT_PUBLIC_API_URL ||
      "http://localhost:3000";

    const response = await fetch(`${backendUrl}/api/v1/leads/demo_request`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(leadPayload),
    });

    const data = await response.json().catch(() => ({}));

    return NextResponse.json(data, { status: response.status });
  } catch (err) {
    console.error("[leads/route] proxy error:", err);
    return NextResponse.json(
      { error: "Failed to submit. Please try again." },
      { status: 500 }
    );
  }
}
