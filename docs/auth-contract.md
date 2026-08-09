# UnivAI — Auth Interface Contract (Dev A ⇄ Dev B)

**Status:** v1 (day-1 contract) · **Companion to:** [`auth-plan.md`](./auth-plan.md)
· **Stack:** Better Auth · Next.js 16 App Router · React 19 · MUI · TypeScript strict

> **Why this file exists.** Dev A (backend/auth core) and Dev B (auth UI/profile)
> work in parallel. This file is the frozen boundary between them: the exact
> **session shape**, **actions**, **routes**, **validation rules**, and **error model**.
> Dev B builds every page against *this document* (and a mock, §10) without waiting
> for Dev A. When Dev A's backend lands, the pages work unchanged.
>
> **Rule:** neither side changes anything in §3–§9 without the other's sign-off and a
> version bump (§11). Everything here is the contract; everything else is
> implementation detail either side may change freely.

---

## 1. Ownership

| | Dev A (you + Claude) | Dev B |
|---|---|---|
| Owns | `lib/auth.ts` (server config), `lib/auth-client.ts` (shared client), `lib/session.ts` (server helpers), `middleware.ts`, DB schema, roles/admin plugin, email sending, `registrationNumber` generation, securing existing API routes, RAG/LiveKit identity threading | Every page in §5, all MUI forms, client validation, error rendering, redirects, `NavBar` auth state |
| Never touches | Dev B's pages | `lib/auth.ts`, `lib/session.ts`, `middleware.ts`, any auth internals |

**The single seam:** Dev B imports **only** from `lib/auth-client.ts`. That file is
Dev A's; it re-exports a fully configured client so B never imports `better-auth` directly.
If Better Auth's API drifts, Dev A fixes it in that one file and B's pages don't change.

```ts
// lib/auth-client.ts  — OWNED BY DEV A, IMPORTED BY DEV B
import { createAuthClient } from "better-auth/react";
import { adminClient } from "better-auth/client/plugins";

export const authClient = createAuthClient({
  baseURL: "", // same-origin /api/auth
  plugins: [adminClient()],
});

// Re-exported for convenience so B has one import site:
export const { signIn, signUp, signOut, useSession } = authClient;
export type { SessionUser } from "./auth-types"; // §3
```

---

## 2. The auth model in one paragraph

Session lives in an **HTTP-only cookie** (Dev A configures `Secure`/`SameSite=Lax`).
Dev B never reads or writes cookies. In **client components** B reads the session with
`useSession()`. In **server components / server actions** B calls the server helper
from §4. Email verification is **required**: a freshly registered user is *unverified*
and must click the emailed link before they can sign in. `role` and `registrationNumber` are
**server-assigned** — B displays them but never sends them.

---

## 3. Canonical types (frozen)

```ts
// lib/auth-types.ts
export type Role = "student" | "admin" | "super_admin";

export type SessionUser = {
  id: string;              // Better Auth user UUID (opaque)
  name: string;
  email: string;
  emailVerified: boolean;
  phone: string | null;    // E.164, e.g. "+201234567890" — stored, NOT verified
  role: Role;              // server-assigned; default "student"
  registrationNumber: string;       // server-generated, e.g. "S-2026-000042" (RAG/LiveKit key)
  image: string | null;
  createdAt: string;       // ISO 8601
};

export type Session = {
  user: SessionUser;
  session: { id: string; expiresAt: string /* ISO */ };
} | null;

// Every action returns this shape (Better Auth's convention):
export type Result<T> = { data: T; error: null } | { data: null; error: AuthError };
export type AuthError = { code: string; message: string; status: number };
```

**B may rely on every field above always being present** on a signed-in user. If Dev A
adds a field later, it is additive and requires a version bump.

---

## 4. Reading the session

**Client component:**
```ts
const { data: session, isPending } = authClient.useSession();
const user = session?.user;                 // SessionUser | undefined
const isAdmin = user?.role !== "student";   // admin or super_admin
```

**Server component / route (helper owned by Dev A, `lib/session.ts`):**
```ts
export async function getSessionUser(): Promise<SessionUser | null>;
export async function requireUser(): Promise<SessionUser>;   // throws→redirect /login
export async function requireAdmin(): Promise<SessionUser>;  // throws→403
```

**Redirects Dev A guarantees via `middleware.ts` (B builds pages assuming these):**

| Situation | Result |
|---|---|
| Unauthenticated hits a protected route | 302 → `/login?redirect=<original-path>` |
| Authenticated hits `/login` or `/register` | 302 → `/dashboard` |
| Non-admin hits `/admin/*` | 302 → `/dashboard` (and API returns 403) |
| Unverified user after login attempt | stays on `/verify-email` notice (see §6.6) |

After a successful login, B redirects to the `redirect` query param if present, else `/dashboard`.

---

## 5. Page inventory (Dev B's build list)

| Route | Auth level | Purpose | On success |
|---|---|---|---|
| `/register` | public | name, email, phone, password, confirm, terms | → `/verify-email?email=…` (see §6.6) |
| `/login` | public | email, password, "remember me" | → `redirect` param or `/dashboard` |
| `/forgot-password` | public | email → send reset link | → confirmation screen (§6.4) |
| `/reset-password` | public (`?token=`) | new password, confirm | → `/login?reset=1` |
| `/verify-email` | public | "check your inbox" + resend button; also the post-click landing | → `/login?verified=1` |
| `/profile` | user | view/edit name+phone, change email, change password, sessions | inline success toasts |
| `/admin/users` | **super_admin** | user table: search, change role, ban/unban | inline row updates |
| `NavBar` | all | reflect logged-out / student / admin states | — |

All pages use **MUI only** and obey the purity rule: **no `sx=`, no `style=`, no
`styled(`, no `.css`, no `createTheme`** (see `ACCEPTANCE.md`). Style via MUI component
props and the theme.

---

## 6. Action catalog (frozen call signatures)

Every call returns `Result<T>` (§3). Pattern B uses everywhere:

```ts
const { data, error } = await authClient.signIn.email({ email, password });
if (error) showError(error.code);  // map via §8
else router.push(redirect ?? "/dashboard");
```

### 6.1 Register
```ts
authClient.signUp.email({
  name: string,
  email: string,
  password: string,
  phone: string,           // E.164; additional field, input allowed
});
```
- **B sends only these four.** `role` and `registrationNumber` are server-set — sending them is ignored/rejected.
- **Success:** account created, verification email sent automatically. Session is **not** usable until verified. → route to `/verify-email?email=<email>`.
- **Errors:** `USER_ALREADY_EXISTS`, `INVALID_EMAIL`, `PASSWORD_TOO_SHORT` (see §8).

### 6.2 Login
```ts
authClient.signIn.email({ email, password, rememberMe?: boolean });
```
- **Success:** session cookie set → redirect (§4).
- **Errors:** `INVALID_EMAIL_OR_PASSWORD` (generic — do **not** reveal which), `EMAIL_NOT_VERIFIED` (→ push to `/verify-email`), `USER_BANNED`.

### 6.3 Logout
```ts
authClient.signOut();   // then router.push("/login")
```

### 6.4 Forgot password (request reset)
```ts
authClient.requestPasswordReset({ email, redirectTo: "/reset-password" });
// (older Better Auth name: authClient.forgetPassword — Dev A guarantees the working name in lib/auth-client.ts)
```
- **Always renders the same success screen** regardless of whether the email exists (enumeration resistance). B must **not** branch UI on "user found".
- Success copy: *"If an account exists for that email, we've sent a reset link."*

### 6.5 Reset password
```ts
authClient.resetPassword({ newPassword: string, token: string /* from ?token= */ });
```
- **Success:** → `/login?reset=1` with a success banner.
- **Errors:** `INVALID_TOKEN`, `TOKEN_EXPIRED` → show "link expired, request a new one" with a link back to `/forgot-password`.

### 6.6 Email verification
```ts
authClient.sendVerificationEmail({ email, callbackURL: "/login?verified=1" });  // "resend" button
```
- The email link is a **GET** handled by Dev A's server; it verifies then redirects to `callbackURL`. B does not implement the token check.
- `/verify-email` page states: (a) "We sent a link to <email>. Check your inbox." (b) a **Resend** button (rate-limited server-side; B just shows a cooldown after click). (c) if arrived with `?verified=1` on `/login`, show a success banner.

### 6.7 Profile — update name & phone
```ts
authClient.updateUser({ name?: string, phone?: string });
```
- **Success:** session's user refreshes; show a saved toast. `email`, `role`, `registrationNumber` are **not** editable here.

### 6.8 Profile — change email (re-verify)
```ts
authClient.changeEmail({ newEmail: string, callbackURL: "/profile?email_changed=1" });
```
- Sends a verification to the **new** email; the change applies only after the link is clicked. B shows "verification sent to new address."

### 6.9 Profile — change password
```ts
authClient.changePassword({
  currentPassword: string,
  newPassword: string,
  revokeOtherSessions?: boolean,   // offer as a checkbox
});
```
- **Errors:** `INVALID_PASSWORD` (current wrong), `PASSWORD_TOO_SHORT`.

### 6.10 Profile — sessions / log out everywhere
```ts
authClient.listSessions();          // → array of { id, createdAt, userAgent, current: boolean }
authClient.revokeOtherSessions();   // "Log out of all other devices"
```

### 6.11 Admin — user management (`/admin/users`, super_admin)
```ts
authClient.admin.listUsers({ query: { limit?, offset?, searchValue?, searchField?: "email"|"name" } });
// → { users: SessionUser[] & { banned: boolean; banReason: string|null; banExpires: string|null }[], total: number }

authClient.admin.setRole({ userId: string, role: Role });   // student ⇄ admin (super_admin only)
authClient.admin.banUser({ userId: string, banReason?: string, banExpiresIn?: number /* seconds */ });
authClient.admin.unbanUser({ userId: string });
```
- **Guardrails Dev A enforces server-side** (B may still hide the controls for good UX):
  - only `super_admin` may `setRole` to/from `admin`;
  - nobody can change their own role or ban themselves;
  - the last `super_admin` cannot be demoted.
- B renders these as a table with per-row role dropdown + ban toggle; on `error` show the message and revert the row.

---

## 7. Validation rules (shared — client must match server)

Dev A enforces all of these server-side; Dev B mirrors them client-side so users get
instant feedback. **If a rule changes, it changes here first.**

| Field | Rule |
|---|---|
| `name` | required, trimmed, 2–80 chars |
| `email` | required, valid email; lowercased server-side |
| `phone` | required, **E.164** `+<country><number>`, 8–15 digits total; UI defaults country to `+20` (Egypt) |
| `password` | required, **min 8**, max 128 chars (Better Auth defaults; strength meter optional) |
| `confirmPassword` | client-only; must equal `password` |
| `terms` | client-only; must be checked to submit register |

RTL/Arabic: the product is Arabic-branded ("Jamieh"). Build forms RTL-friendly
(logical alignment, no hardcoded left/right) — not blocking, but cheaper to do now.

---

## 8. Error model (code → what B renders)

Errors arrive as `{ code, message, status }`. **Prefer mapping `code` to your own copy**
(localizable) rather than showing `message` raw. Unknown codes → generic
"Something went wrong, please try again."

| `code` | Where | B renders |
|---|---|---|
| `USER_ALREADY_EXISTS` | register | field error on email: "An account with this email already exists." |
| `INVALID_EMAIL` | register | field error on email |
| `PASSWORD_TOO_SHORT` | register/reset/change | field error on password |
| `INVALID_EMAIL_OR_PASSWORD` | login | **form-level** (never say which was wrong) |
| `EMAIL_NOT_VERIFIED` | login | banner + button → `/verify-email` |
| `USER_BANNED` | login | form-level: "This account is suspended." |
| `INVALID_TOKEN` / `TOKEN_EXPIRED` | reset/verify | "This link is invalid or expired" + link to restart |
| `INVALID_PASSWORD` | change password | field error on current password |
| rate-limit (`status: 429`) | any | "Too many attempts. Please wait a moment." |

Field-level vs form-level placement above is part of the contract so error UX is consistent.

---

## 9. NavBar states (frozen)

| State (`user`, `role`) | NavBar shows |
|---|---|
| no session | app name · **Login** · **Register** |
| `student` | app name · Dashboard · Schedule · Upload · **avatar menu** (Profile, Logout) |
| `admin` / `super_admin` | student items · **Admin** link · avatar menu (Profile, Logout) |
| `super_admin` | admin items · Admin ▸ Users |

The avatar menu shows `name` and `registrationNumber`. B reads all of this from `useSession()`.

---

## 10. Unblocking Dev B on day 1 (mock mode)

Dev B does not wait for Dev A. Ship a mock behind an env flag so `lib/auth-client.ts`
resolves to a fake that returns the §3 shapes:

```ts
// lib/auth-client.mock.ts  (temporary; deleted when real backend lands)
const fakeUser: SessionUser = {
  id: "u_mock", name: "Test Student", email: "test@univai.dev",
  emailVerified: true, phone: "+201234567890", role: "student",
  registrationNumber: "S-2026-000001", image: null, createdAt: new Date().toISOString(),
};
// each action returns { data, error } after a small delay; toggle error/verify
// states with query params or a dev-only switch so B can build every branch.
```

- Gate with `NEXT_PUBLIC_AUTH_MOCK=1`; `lib/auth-client.ts` picks mock vs real from it.
- B builds **every branch** (success, each error code, unverified, banned) by making the
  mock return them — no real backend needed for the whole UI.
- When Dev A's Phase 1 lands, flip the flag off; because both implement §3–§8, pages work unchanged.

---

## 11. Change control & handshake

- **This contract is frozen at v1.** Any change to §3–§9 needs both devs to agree and a
  version bump at the top (v1 → v1.1) plus a one-line changelog entry below.
- Additive changes (new optional field) → minor bump. Breaking changes (renamed/removed
  field, changed redirect) → both devs review before merge.

**Ready-to-integrate checklist (end of week 1):**
- [ ] `lib/auth-client.ts` exports the real client (Dev A) — mock flag removed
- [ ] `SessionUser` matches §3 exactly, including `phone`/`role`/`registrationNumber`
- [ ] register → verification email delivered → login works end-to-end
- [ ] forgot → reset email delivered → reset works end-to-end
- [ ] `/admin/users` `setRole` / `banUser` reflect in the DB and re-render the row
- [ ] middleware redirects behave exactly as §4

**Changelog**
- v1 (2026-07-24) — initial contract.
