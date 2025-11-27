# User Profile & LLM Personalization – Implementation Plan
## Progress (2025-11-25)
- Added profile attrs/actions/policies on User; blank -> nil normalize
- Accounts domain now AshAi + tools get/update profile; code interface generated
- LLM Respond injects profile summary, updated prompt, tools wired
- New /profile route + LiveView form + header link
- Migrations added and applied locally (profile columns)

## Problem
The platform currently relies on ad‑hoc text input ("ideal job description") and conversational history to understand the user. There is no structured, persistent user profile capturing job interests, education, skills, job experience, remote preferences, or custom instructions. LLM agents cannot reliably reuse this information across sessions, nor can they safely read/write it via AshAi tools.
## Current State (Relevant Pieces Only)
* **User data**: `Curriclick.Accounts.User` (`lib/curriclick/accounts/user.ex`) stores only auth‑related fields (`email`, `hashed_password`, `confirmed_at`) plus authentication actions and policies. No profile attributes exist.
* **Accounts domain**: `Curriclick.Accounts` (`lib/curriclick/accounts.ex`) uses `Ash.Domain` with `AshPhoenix` and `AshAdmin.Domain` extensions; it does **not** currently use `AshAi` and exposes no tools.
* **Chat / LLM pipeline**:
    * `Curriclick.Chat` domain (`lib/curriclick/chat.ex`) uses `AshAi` and defines tools `:my_conversations` and `:message_history_for_conversation`.
    * `Curriclick.Companies` domain (`lib/curriclick/companies.ex`) uses `AshAi` and exposes `:find_suitable_job_postings_for_user` mapped to `Curriclick.Companies.JobListing :find_matching_jobs`.
    * `Curriclick.Chat.Message.Changes.Respond` (`lib/curriclick/chat/message/changes/respond.ex`) builds an `LLMChain` with `ChatOpenAI`, adds a static system prompt and prior messages, then enables AshAi tools `[:my_conversations, :message_history_for_conversation, :find_suitable_job_postings_for_user]`. It passes `custom_context: Map.new(Ash.Context.to_opts(context))` and `actor: context.actor`, but does **not** load or inject any user profile data.
* **Job search UI**:
    * `CurriclickWeb.JobsLive` (`lib/curriclick_web/live/jobs_live.ex`) takes a free‑text "ideal job description" and directly calls `JobListing :find_matching_jobs` (no LLM involved). It has a small "Preferences" UI block (Remote/Hybrid/Seniority) that is currently UI‑only (not wired to user data or the search action).
* **Authenticated UI**: `CurriclickWeb.UserDashboardLive` (`lib/curriclick_web/live/user_dashboard_live.ex`) shows job applications but there is no dedicated profile management page or link.
## Goals
1. **Persisted profile data on `User`**:
    * Job interests / target roles.
    * Education summary.
    * Skills.
    * Job experience summary.
    * Preference for remote / hybrid / on‑site work.
    * Custom instructions for the AI job assistant.
2. **Profile management UI**:
    * A new authenticated `/profile` page where a user can add, edit, and delete (clear) this information.
3. **LLM usage of profile**:
    * The respond‑chain LLM must start each conversation with access to the user's saved profile (as system/context information).
    * AshAi tools must let the LLM **read** and **update** the user's profile in a safe, actor‑scoped way.
    * System prompts must explicitly instruct the agent to use profile data when **searching and evaluating jobs**, and to opportunistically suggest saving new information (with explicit user consent).
## Proposed Changes
### 1. Data Model – Profile Fields on `Curriclick.Accounts.User`
1. ~~**Add profile attributes** to `Curriclick.Accounts.User` (`lib/curriclick/accounts/user.ex`, `attributes do` block):~~
    * `profile_job_interests` – `:string`, `public?: true`, `allow_nil?: true`.
        * Free‑text description of roles/areas the user is interested in.
    * `profile_education` – `:string`, `public?: true`, `allow_nil?: true`.
        * Summary of degrees, schools, courses, or certifications (user‑written, not structured per‑degree for now).
    * `profile_skills` – `:string`, `public?: true`, `allow_nil?: true`.
        * Comma‑separated or free‑form list of technical and soft skills.
    * `profile_experience` – `:string`, `public?: true`, `allow_nil?: true`.
        * Summary of relevant job experience, roles, and years.
    * `profile_remote_preference` – `:atom`, `public?: true`, `allow_nil?: true` with a constrained set like `[:remote_only, :remote_friendly, :hybrid, :on_site, :no_preference]`.
    * `profile_custom_instructions` – `:string`, `public?: true`, `allow_nil?: true`.
        * User‑authored instructions to the AI (tone preferences, what to prioritize/avoid, etc.).
2. ~~**Persistence** (migrations added + ash.codegen + ecto.migrate run locally).~~
### 2. User Resource Actions & Policies for Profile Access
1. ~~**New read action for the current user's profile** on `Curriclick.Accounts.User`:~~
    * `read :my_profile` (or similar)
        * `get? true`.
        * `filter expr(id == ^actor(:id))` so the action always returns the actor's user record.
        * Ensure any needed fields are loaded (profile attributes and potentially email/id) via `prepare` or `load`.
2. ~~**New update action for editing profile**:~~
    * `update :update_profile`:
        * `require_atomic? false` (to allow streaming/partial updates if needed, and match existing patterns).
        * `accept` only the profile attributes: `[:profile_job_interests, :profile_education, :profile_skills, :profile_experience, :profile_remote_preference, :profile_custom_instructions]`.
        * Restrict scope to the actor: use a filter like `expr(id == ^actor(:id))` or otherwise ensure calls cannot update arbitrary users.
        * Treat empty strings as clearing values if desired (e.g., via a small `change` that normalizes `""` to `nil`).
3. ~~**Policies**: actor self-read/update allowed; auth bypass preserved.~~
4. ~~**Code interface for forms** (`define :update_profile`, `:my_profile`).~~
### 3. Expose Profile Tools via AshAi in `Curriclick.Accounts`
1. ~~**Enable AshAi on Accounts domain**.~~
2. ~~**Define AshAi tools for profile operations** in `Curriclick.Accounts`.~~
3. ~~**Wire tools into the chat LLM** (tools list extended).~~
### 4. Inject User Profile as LLM Context
1. ~~**Load the user profile in `Respond.change/3`** and build summary.~~
2. ~~**Provide this as part of the initial system/context messages** (profile block in system prompt).~~
3. ~~**Preserve `custom_context`** with `user_profile_summary`.~~
### 5. System Prompt Updates for Profile‑Aware Behavior
~~Modify the system prompt string in `Respond` to clearly define how the agent should use the new profile data.~~
Key additions (high‑level – final wording to be done during implementation):
1. **Explicit profile usage**:
    * Add a section (or extend `<understanding_the_user>` / `<selecting_and_presenting_results>`) stating that the agent **must**:
        * Read and consider the saved profile (job interests, education, skills, experience, remote preference, custom instructions) when forming search queries and when ranking/evaluating job postings.
        * Prefer jobs aligned with saved preferences unless the user explicitly requests something different in the current conversation.
2. **Tool usage for profile**:
    * In the `<tool_usage>` section, describe when and how to use the new tools:
        * `get_user_profile`: call early in the conversation (once per session or when profile relevance matters) to understand the user's background and preferences.
        * `update_user_profile`: only call after the user has agreed to save or update specific information.
3. **Policy for missing or new information**:
    * Add instructions that when the agent infers new stable information (e.g., "I only want remote jobs", "I am a mid‑level backend engineer with 4 years of experience") and it appears missing or outdated in the profile, it should:
        * Briefly confirm and ask: whether the user wants this information saved to their profile for future use.
        * If the user says **yes**, use `update_user_profile` with the relevant fields set.
        * If the user says **no**, do not call the update tool and only use the information for the current conversation.
4. **Job search instructions**:
    * Add to the prompt that when using `find_suitable_job_postings_for_user` the agent should:
        * Incorporate profile data into the `query` text (skills, experience level, interests, remote preference, languages if captured in skills/education).
        * Respect `profile_remote_preference` by using appropriate filters (e.g., `remote_allowed` argument) and by prioritizing remote/hybrid/on‑site roles according to the saved preference.
        * Explain in the final answer **how** each recommended job matches the saved profile plus any new constraints from the current conversation.
### 6. Web UI – User Profile Management Page
1. ~~**Routing** add `/profile`.~~
2. ~~**New LiveView module** (`CurriclickWeb.UserProfileLive`) with form, validate, save, clearable fields.~~
3. ~~**Navigation** header link to profile.~~
### 7. (Optional) Use Profile in Non‑Chat Job Search UI
*Not strictly required by the prompt but synergistic with the same profile data.*
1. **JobsLive defaults**:
    * When `JobsLive.handle_params/3` receives no `"q"` parameter and the user is logged in, consider generating a default search description from the saved profile (e.g., combining interests, skills, and experience into a single text query) and auto‑running `search_jobs/2`.
2. **Sync with remote preference UI**:
    * Bind the "Remoto / Híbrido" checkboxes in `JobsLive` to the user's `profile_remote_preference` for initial state, and optionally allow updating that preference from the UI (reusing the same `update_profile` action).
### 8. Verification & Testing Plan
1. **Data & migrations**:
    * Run migrations and ensure `users` now has the new profile columns.
    * Create or update a user in `AshAdmin` to confirm attribute round‑trip.
2. **Profile page**:
    * Log in, visit `/profile`, and verify that fields load existing values (or are empty initially).
    * Edit each field, save, refresh, and confirm persistence.
    * Clear fields and confirm they are treated as "deleted" (nil or empty) and reflected in the DB.
3. **LLM profile usage**:
    * With a filled‑in profile, start a new chat conversation and ask for job recommendations:
        * Confirm that the agent's explanation references profile data (interests, skills, remote preference, custom instructions) without needing to restate everything.
        * Check that search recommendations align with saved remote preference when using `find_suitable_job_postings_for_user`.
    * With an empty or partial profile, mention new stable facts (e.g., "I only want remote backend Elixir jobs"):
        * Verify that the agent asks whether to save this to the profile.
        * If you answer yes, confirm that `profile_remote_preference` and/or other relevant fields are updated (via `/profile` or DB).
4. **Tool behavior & safety**:
    * Inspect logs or use Ash's debugging tools to confirm that `get_user_profile` and `update_user_profile` are only operating on the current user and that they are called according to the system prompt rules (not on every message, not without consent).
5. **Regression checks**:
    * Ensure authentication flows (`register_with_password`, magic link, password reset) still work after adding attributes and policies.
    * Confirm that existing chat functionality (conversation listing, message history, streaming responses) is unaffected by the added tools and prompt changes.
