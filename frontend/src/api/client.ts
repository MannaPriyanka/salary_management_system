// Thin wrapper around fetch for the Rails JSON API (/api/v1).
// The session is a same-origin cookie, so requests send credentials automatically.
// Errors are normalised to ApiError so screens can show the server's message.

export interface ErrorDetail {
  field?: string;
  code?: string;
  message?: string;
  [key: string]: unknown;
}

export class ApiError extends Error {
  readonly status: number;
  readonly code: string;
  readonly details: ErrorDetail[];

  constructor(status: number, code: string, message: string, details: ErrorDetail[] = []) {
    super(message);
    this.name = "ApiError";
    this.status = status;
    this.code = code;
    this.details = details;
  }
}

export type Json = object;

export async function apiRequest<T>(
  path: string,
  options: { method?: string; body?: Json } = {},
): Promise<T> {
  const init: RequestInit = {
    method: options.method ?? "GET",
    headers: {
      Accept: "application/json",
      ...(options.body ? { "Content-Type": "application/json" } : {}),
    },
    credentials: "same-origin",
  };
  if (options.body) {
    init.body = JSON.stringify(options.body);
  }

  const response = await fetch(`/api/v1${path}`, init);
  if (response.status === 204) {
    return undefined as T;
  }

  const payload = await response.json().catch(() => ({}));
  if (!response.ok) {
    const error = payload?.error ?? {};
    throw new ApiError(
      response.status,
      error.code ?? "unknown_error",
      error.message ?? "Something went wrong. Please try again.",
      error.details ?? [],
    );
  }
  return payload as T;
}
