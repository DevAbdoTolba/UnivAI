# UnivAI — Auth & Multi-Tenancy Plan

**Status:** proposed · **Owner module:** `UnivAI-app` (the Face) · **Last updated:** 2026-07-24

> This plan covers a **production-ready authentication system** *and* the
> **multi-tenant data refactor** it forces. UnivAI is currently single-student:
> there is no `users` table, no sessions, and every data table assumes exactly
> one learner. Adding "students only see their own courses/material" is
> therefore two intertwined jobs, not one.

---

## 1. Locked decisions

| # | Decision | Choice | Consequence |
|---|----------|--------|-------------|
| D1 | Data model | **Full multi-tenant** | Each student uploads their own textbook and owns their own courses, lectures, grades, RAG namespace. Every data table gains an owner. |
| D2 | Auth stack | **Better Auth** (self-hosted) | Runs on the existing Postgres via the `pg` pool. Built-in email+password, verification, reset, sessions, and an admin/roles plugin. We own all user data. |
| D3 | Reset/verify email | **Real provider** (Resend or SES) | Needs one provider account + a sending domain. No console-only fallback in production. |
| D4 | Phone | **Store only, not verified** | Collected at registration, editable on profile, no SMS/OTP, no SMS provider cost. |

---

## 2. Current state (what we're building on)

- **No auth anywhere.** No `users` table, no `session`, no `middleware.ts`, no login page.
- **Identity is hardcoded in 3 places** and all must become the real signed-in user:
  - `STUDENT_NAME` env var (`UnivAI-app/lib/env.ts`)
  - LiveKit token `identity: "student"` (`UnivAI-app/app/api/lecture/[id]/token/route.ts`)
  - `RAG_USER_ID = "student"` (`services/common/rag_client.py:38`)
- **RAG is already per-user.** `rag_client.py`: *"every call needs a user_id."* The whole permission requirement rides on replacing the constant with the authenticated student's ID. **This is the single most important seam in the plan.**
- **Schema is single-tenant** (`infra/schema.sql`): `books`, `lectures`, `attendance`, `grades`, `qa_log` have **no owner column**, and constraints like `UNIQUE (week)` and `UNIQUE (lecture_id)` bake in "one student."
- **Stack:** Next.js 16 (App Router) · React 19 · TypeScript strict · MUI · Postgres via raw `pg` (no ORM) · self-hosted.
- **MUI purity rule (enforced, see `ACCEPTANCE.md`):** no `sx=`, no `style=`, no `styled(`, no `.css`, no `createTheme`. **All auth UI must obey this** — use MUI components + theme props only.
- **Env is read from the root `.env` one level above `UnivAI-app`** (`lib/env.ts` reads `../​.env`). All new secrets go there.

---

## 3. Target architecture

```
Browser ──▶ middleware.ts (edge)         ── redirects unauthenticated users to /login,
   │           gates /admin to admins        gates /admin, /sudo to admin/super_admin
   ▼
Next.js App Router
   ├─ /login /register /forgot /reset /verify   (public)
   ├─ /profile  /dashboard  /schedule  /upload   (auth required, scoped to owner)
   ├─ /admin                                     (admin+)
   ├─ api/auth/[...all]      ── Better Auth handler (sessions, reset, verify, admin)
   └─ every other api route  ── getSession() → scope all SQL by user.id
        │
        ├─ Postgres (pg pool)   users/session/account/verification  +  owner_id on all data tables
        ├─ RAG (MCP)            user_id = session registrationNumber   (per-student namespace)
        ├─ LiveKit              token identity = registrationNumber
        └─ Exam system (:3200)  webhook payloads carry userId
```

**Session flow:** Better Auth issues an HTTP-only, `Secure`, `SameSite=Lax` cookie.
Server components and API routes call `auth.api.getSession({ headers })`. Client
components read session via Better Auth's React client. `middleware.ts` does the
coarse redirect; **every API route re-checks server-side** (middleware alone is
not an authorization boundary).

---

## 4. Data model

### 4.1 Better Auth tables (it generates/migrates these)
`user`, `session`, `account`, `verification`. We extend `user` with **additional fields**:

| Field | Type | Notes |
|-------|------|-------|
| `id` | uuid | hidden primary key used by authentication relations |
| `name` | text | built-in |
| `email` | text unique | built-in, verification required |
| `emailVerified` | bool | built-in |
| `phone` | text | additional field, **stored only** (D4). Store with country code. |
| `role` | enum `student\|admin\|super_admin` | default `student`; **server-set only**, never from client |
| `registrationNumber` | text unique | generated at signup (e.g. `S-2026-000042`); the RAG namespace key |
| `banned` / `banReason` / `banExpires` | — | from admin plugin |
| `createdAt`/`updatedAt` | ts | built-in |

### 4.2 Ownership migration (the multi-tenant part)
Add to `infra/schema.sql` (kept idempotent, matching the file's existing style):

```sql
-- Learner-owned rows use the displayed registration number as their tenant key.
ALTER TABLE books       ADD COLUMN IF NOT EXISTS user_id TEXT;
ALTER TABLE lectures    ADD COLUMN IF NOT EXISTS user_id TEXT;
ALTER TABLE attendance  ADD COLUMN IF NOT EXISTS user_id TEXT;
ALTER TABLE grades      ADD COLUMN IF NOT EXISTS user_id TEXT;
ALTER TABLE qa_log      ADD COLUMN IF NOT EXISTS user_id TEXT;

-- Single-student uniqueness becomes per-student uniqueness.
-- (Drop UNIQUE(week) on lectures, UNIQUE(lecture_id) on attendance, and re-add
--  as composite keys. Do this as an explicit migration, not a bare ADD.)
--   lectures:   UNIQUE (user_id, week)
--   attendance: UNIQUE (user_id, lecture_id)
```

- **`clock_state` is the open question — see §9.1.** It is a global singleton today; multi-tenant probably needs it per-user/per-course.
- **Settings**: decide global vs per-user for every new operational key.
- Once every data row has an owner, add `NOT NULL` + FKs to `user(id)` and backfill/clear the demo data.

### 4.3 Row scoping helper
Add a tiny helper so no route forgets the filter:

```ts
// lib/session.ts
export async function requireUser(req) { /* getSession or 401 */ }
export async function requireAdmin(req) { /* getSession + role check or 403 */ }
```
Every existing data query gets `WHERE user_id = $sessionUserId` (admin views can opt out explicitly). This is mechanical but touches every route in `app/api/**`.

---

## 5. Registration fields (with the critical additions)

You asked for **name, email, phone, password**. Add these — they're load-bearing:

| Field | Source | Why |
|-------|--------|-----|
| `registrationNumber` | **server-generated** | RAG namespacing + LiveKit identity. Never user-supplied. |
| `role` | **server-set** (`student`) | Privilege escalation risk if ever client-controlled. |
| `emailVerified` | flow | Gate access until verified (or allow limited access pre-verify). |
| password confirmation | client-only | UX; not stored. |
| terms/consent checkbox | client | Optional but standard for "production-ready". |

**Note (i18n):** the product is Arabic-branded ("Jamieh"). Consider RTL support and
storing phone with an explicit country code (default `+20`) — flag for design, not blocking.

---

## 6. Roles & permissions

Three roles via Better Auth's **admin plugin**:

| Capability | student | admin | super_admin |
|---|:--:|:--:|:--:|
| Register / login / reset own password | ✅ | ✅ | ✅ |
| See & edit own profile | ✅ | ✅ | ✅ |
| Access **own** courses / lectures / grades / RAG material | ✅ | ✅ | ✅ |
| Access **another user's** data | ❌ | ✅ (read, for support/proctoring) | ✅ |
| Virtual-clock / course-size / restart (`/admin`) | ❌ | ✅ | ✅ |
| View proctoring reports / flagged exams | ❌ | ✅ | ✅ |
| **Escalate a user student→admin / demote** | ❌ | ❌ | ✅ |
| Ban / unban users | ❌ | ✅ | ✅ |
| Create/replace another super_admin | ❌ | ❌ | ✅ |

- **Super-admin bootstrap:** seed from `SUPER_ADMIN_EMAIL` in root `.env`. The first
  account matching it is promoted on signup (or a one-off `make seed-superadmin` script).
- **Escalation UI** lives under `/admin/users` (super_admin only): list users, change role, ban.
- **Audit log** (`auth_audit` table): record every role change / ban with actor, target, timestamp. Non-negotiable for a super-admin system.
- **The existing `/admin` panel is currently unprotected** — gating it is a concrete task, not a nicety.

---

## 7. RAG / student-ID scoping (the integration seam)

Today the student ID is the constant `RAG_USER_ID`. Multi-tenant requires the
**authenticated student's ID to travel to every downstream service**:

1. **Ingestion (`/upload`)** — tag the uploaded book + its chunks with `registrationNumber` so retrieval is namespaced per owner. Spawned generation must receive `--user-id`.
2. **Course generation (Brain)** — the app spawns generation per user; pass the owner's `registrationNumber` through so lectures/quizzes land against the right owner.
3. **Live lecture (Mouth)** — LiveKit token `identity` becomes the real `registrationNumber`; the voice worker and its RAG Q&A use that identity instead of the env constant.
4. **Live Q&A retrieval** — `rag_client.retrieve_context(..., user_id=registrationNumber)` per request, not from env.
5. **Exam system (`:3200`)** — webhook payloads and question-bank sync must carry `userId` so results route to the right owner's `grades`.

> **Risk:** the Python services currently read `RAG_USER_ID` from env at import time.
> Threading a per-request user id through `services/common/rag_client.py`, the
> generation entrypoints, and the live worker is real cross-repo work touching
> **three submodules** (`UnivAI-Agent`, `UnivAI-live`, `UnivAI-exam_system`).
> Budget for it explicitly — it is where "just build auth" stops being just the app.

---

## 8. Production-readiness security checklist

Better Auth covers most of this; verify each is actually on:

- [ ] Password hashing = **argon2id** (override Better Auth's default if needed) + min-length/strength rules.
- [ ] **Rate limiting** on login, register, forgot-password (Better Auth built-in — enable + tune).
- [ ] **Email-enumeration resistance**: generic "if that email exists, we sent a link" messaging.
- [ ] Reset & verification tokens: single-use, short TTL (≤30 min), hashed at rest.
- [ ] Cookies: `HttpOnly` + `Secure` + `SameSite=Lax`; HTTPS enforced in prod.
- [ ] Session expiry + rotation; **"log out all sessions"** on the profile page.
- [ ] CSRF: covered for Better Auth endpoints; audit any custom mutating routes.
- [ ] Account lockout / brute-force protection on repeated failures.
- [ ] Input validation with **zod** on every auth endpoint (server-side).
- [ ] `role` and `registrationNumber` never accepted from the client on register/update.
- [ ] Audit log for admin actions (role change, ban).
- [ ] Secrets (`BETTER_AUTH_SECRET`, provider keys, `SUPER_ADMIN_EMAIL`) in root `.env`, never committed.
- [ ] Run `/security-review` on the branch before merge.

---

## 9. Open decisions — **RESOLVED (2026-07-24)**

### 9.1 Per-user virtual clock → **RESOLVED: keep ONE shared clock**
All students share a single global clock for the demo (real wall-clock time comes
later). `clock_state` stays the global singleton — **no per-user clock change**, and
the clock code in `lib/clock.ts` / `services/common/clock.py` is untouched by this work.

### 9.2 Course lifecycle per user → **RESOLVED: fully per-student**
Upload and course generation are **owned per student**. Each user sees only their own
books and their own generated courses. `/upload` becomes "replace **my** book"; the
global course-clearing logic must be scoped to the owner (Phase 5).

### 9.3 Admin cross-tenant views → **RESOLVED: admin-scoped queries, NOT impersonation**
Admins read student data through **admin-scoped queries** from their own admin context.
No impersonation. The admin plugin's `impersonateUser` is **not** used; the auth
contract's admin surface stays list/`setRole`/`ban` only (contract §6.11 unchanged).

---

## 10. Implementation phases

Each phase ends with acceptance checks in the `ACCEPTANCE.md` style.

### Phase 0 — Setup (0.5 day)
Provider accounts (Resend/SES), `SUPER_ADMIN_EMAIL`, `BETTER_AUTH_SECRET`, DB reachable.
**Done when:** secrets in root `.env`, `better-auth` installed, health check passes.

### Phase 1 — Auth foundation (backend)
Better Auth config on the existing `pg` pool; generate `user/session/account/verification`;
additional fields (`phone`, `role`, `registrationNumber`); `api/auth/[...all]` handler; `middleware.ts`;
`lib/session.ts` (`requireUser`/`requireAdmin`).
**Done when:** a user can be created via API, gets a session cookie, and a protected test route 401s without it.

### Phase 2 — Core flows (UI + API)
Register, login, logout, forgot-password, reset-password, verify-email pages (MUI, purity-compliant)
wired to Better Auth. Real emails sending. NavBar reflects auth state.
**Done when:** full register→verify→login→reset loop works end-to-end with delivered emails.

### Phase 3 — Roles & admin ✅ **DONE (backend, 2026-07-25)**
Super-admin seed; `/admin/users` escalation + ban UI (super_admin only); gate the existing
`/admin` panel and all admin APIs; `auth_audit` log.
**Done when:** a super_admin can promote a student to admin; a student is 403'd from `/admin`; role changes are logged. — *All verified live.*
- Escalation is **super_admin-only** declaratively: `admin` role lacks the `user:set-role` statement (`lib/auth-ac.ts`), so the plugin's `/admin/set-role` returns 403 for admins.
- `auth_audit` table + `lib/auth-audit.ts` (global `hooks.after`) log set-role/ban/unban/remove with actor+target; read via `GET /api/admin/audit` (admin+).
- `/admin/*` gated by server layout (`app/admin/layout.tsx` → `requireAdmin`); admin APIs + clock POST gated by `requireAdminApi`.
- **Remaining for Phase 3:** the `/admin/users` UI is Dev B's (super_admin-gated via `requireSuperAdmin`); all backend it needs is live.

### Phase 4 — Profile
View/edit name + phone; change email (re-verify); change password; "log out all sessions".
**Done when:** each profile action works and is scoped to the signed-in user only.

### Phase 5 — Multi-tenant scoping (**serialize under one owner**)
Ownership columns + composite uniqueness migration; scope every `app/api/**` query by `user_id`;
thread `registrationNumber` into RAG / LiveKit / generation / exam webhooks; resolve §9 decisions.
**Done when:** two users each upload a book and each sees only their own courses, lectures, grades, and RAG answers; no query returns another user's rows.

### Phase 6 — Hardening & sign-off
Complete §8 checklist; add tests (auth flows + a scoping test that proves user A can't read user B);
`/security-review`; update `ACCEPTANCE.md`.
**Done when:** checklist green, scoping test passes, security review clean.

---

## 11. One developer or two?

**Two is viable and faster — but only split along the front/back seam, never by flow.**

Do **not** give "login" to one person and "reset password" to another: they share
cookies, middleware, the session shape, and the user table, so you'd get two people
editing the same security-critical plumbing and stepping on each other.

Instead:

| | **Dev A — Auth core & scoping** | **Dev B — Auth UX & profile** |
|---|---|---|
| Owns | Better Auth config, schema/migrations, `middleware.ts`, `lib/session.ts`, roles/admin plugin, super-admin seed, RAG/LiveKit/exam identity threading, securing existing routes, **all of Phase 5** | All MUI pages: register/login/forgot/reset/verify/profile + `/admin/users` table, client validation, error/redirect states, NavBar auth state |
| Nature | Backend, security-critical | Frontend, UX |
| Risk | Owns the boundary — one brain on security | Consumes session + endpoints only, never touches auth internals |

**Coordination contract (write it day 1 — this is what makes the split safe):**
a short `docs/auth-contract.md` fixing the **API surface** (endpoint paths, request/response
shapes) and the **session/user shape** (`{ id, name, email, phone, role, registrationNumber, emailVerified }`).
Dev B builds against that contract with stubbed responses while Dev A implements it.

**Sequencing:** Phases 1–4 parallelize cleanly (A backend, B UI). **Phase 5 is a
shared-schema refactor and must be a single owner (Dev A)** while Dev B polishes
profile/admin UX; both converge on Phase 6.

**Estimate (rough):** one dev ≈ 2.5–3.5 weeks; two devs on this seam ≈ 1.5–2 weeks
wall-clock. For a graduation project where *understanding the security* is graded,
one owner gives more coherent mastery — but two along this seam is a defensible,
faster split.

---

## 12. Spec-kit — needed?

**No — skip it.** This is a well-trodden module with a library (Better Auth) doing the
heavy lifting, and this document plus the one-page `docs/auth-contract.md` already gives
two developers everything Spec Kit's `/specify → /plan → /tasks` would produce, with less
ceremony. Adopt Spec Kit only if the team is *already* using it elsewhere and wants the
task board generated the same way — don't introduce a new workflow tool just for auth.
(This matches your own guidance: if it works seamlessly without it, don't use it.)

---

## 13. First-week task board

**Dev A**
1. Install + configure Better Auth on the `pg` pool; generate core tables.
2. Add `phone`/`role`/`registrationNumber` fields + `registrationNumber` generator.
3. `middleware.ts` + `lib/session.ts` (`requireUser`/`requireAdmin`).
4. Wire Resend/SES for reset + verification callbacks.
5. Write `docs/auth-contract.md` (with Dev B).

**Dev B**
1. Auth layout + MUI form primitives (purity-compliant).
2. Register + login pages against stubbed contract.
3. Forgot + reset + verify pages.
4. NavBar auth state (logged-out vs student vs admin).
5. Co-author `docs/auth-contract.md`.

**Together, end of week 1:** register → verify → login → reset works end-to-end
against real Better Auth + real emails. Then split into Phases 3/4, and Dev A leads Phase 5.

> ⚠️ Verify Better Auth's exact plugin/API names against the current docs before
> coding — it moves fast. The architecture here is stable regardless of minor API drift.
