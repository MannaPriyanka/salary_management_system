import { apiRequest } from "./client";

export interface CurrentUser {
  id: number;
  email: string;
}

export function fetchCurrentUser(): Promise<CurrentUser> {
  return apiRequest<{ data: CurrentUser }>("/session").then((body) => body.data);
}

export function signIn(email: string, password: string): Promise<CurrentUser> {
  return apiRequest<{ data: CurrentUser }>("/session", {
    method: "POST",
    body: { email, password },
  }).then((body) => body.data);
}

export function signOut(): Promise<void> {
  return apiRequest<void>("/session", { method: "DELETE" });
}

export function changePassword(currentPassword: string, newPassword: string): Promise<void> {
  return apiRequest<void>("/session/password", {
    method: "PUT",
    body: { current_password: currentPassword, new_password: newPassword },
  });
}
