import { config } from "../config";

type UscisTokenResponse = {
  access_token: string;
  token_type: string;
  expires_in: number;
};

export type UscisCaseStatus = {
  receiptNumber: string;
  status: string;
  raw: unknown;
};

let cachedToken: { token: string; expiresAt: number } | null = null;

async function getAccessToken(): Promise<string> {
  if (!config.USCIS_CLIENT_ID || !config.USCIS_CLIENT_SECRET) {
    throw new Error("USCIS API credentials are not configured.");
  }

  if (cachedToken && cachedToken.expiresAt > Date.now() + 60_000) {
    return cachedToken.token;
  }

  const body = new URLSearchParams({
    grant_type: "client_credentials",
    client_id: config.USCIS_CLIENT_ID,
    client_secret: config.USCIS_CLIENT_SECRET
  });

  const response = await fetch(config.USCIS_TOKEN_URL, {
    method: "POST",
    headers: { "content-type": "application/x-www-form-urlencoded" },
    body
  });

  if (!response.ok) {
    throw new Error(`USCIS token request failed with ${response.status}.`);
  }

  const token = (await response.json()) as UscisTokenResponse;
  cachedToken = {
    token: token.access_token,
    expiresAt: Date.now() + token.expires_in * 1000
  };

  return cachedToken.token;
}

export async function fetchUscisCaseStatus(receiptNumber: string): Promise<UscisCaseStatus> {
  const token = await getAccessToken();
  const response = await fetch(`${config.USCIS_CASE_STATUS_URL}/${encodeURIComponent(receiptNumber)}`, {
    headers: {
      authorization: `Bearer ${token}`,
      accept: "application/json"
    }
  });

  if (!response.ok) {
    throw new Error(`USCIS case status failed with ${response.status}.`);
  }

  const raw = (await response.json()) as Record<string, unknown>;

  return {
    receiptNumber,
    status: String(raw.status ?? raw.caseStatus ?? "unknown"),
    raw
  };
}
