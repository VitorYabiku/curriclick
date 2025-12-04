## Curriclick – AI Agent Guide

This repository is an Elixir application built with the Phoenix Framework (including LiveView) and the Ash Framework.
It already includes rich, package-specific usage rules that you should follow whenever you work in this codebase.

### Start here (required for agents)

- First, read `AGENTS_USAGE_RULES.md`. It contains links and guidance specifically curated for AI agents for many of the dependencies in this project.
- When you are about to use or modify behaviour involving a dependency (for example Ash, Phoenix, LiveView, AshPostgres, etc.), consult the corresponding section in `AGENTS_USAGE_RULES.md` before making changes.
- **Ash Framework & Extensions**: The Ash ecosystem evolves rapidly and often introduces breaking changes. Whenever you work with Ash or its extensions, you **MUST** use the `mix usage_rules.docs` and `mix usage_rules.search_docs` tools to verify the latest APIs and patterns. Do not rely solely on your training data.

### Agent Workflow & Commands

- **Running the app**: Use `mix run_app`. This command handles Ash codegen, database migrations, and starts the Phoenix server.
- **Ash Framework changes**: If you modify Ash resources:
    1. Run `mix ash.codegen --dev` to generate necessary code and migrations.
    2. Run `mix ecto.migrate` to apply the migrations.
    3. (Optional) Run `mix run_app` to verify everything works together.

### Frontend & Styling

- **DaisyUI Preference**: Always prioritize using [DaisyUI](https://daisyui.com/) components and utility classes for styling.
- **Tailwind Fallback**: Use standard [Tailwind CSS](https://tailwindcss.com/) classes ONLY if a suitable DaisyUI alternative does not exist.
- **Conventions**: Follow the existing patterns in `lib/curriclick_web` components.

### Project structure (high level)

- Core domain logic and Ash resources live under `lib/curriclick`.
- The web layer (Phoenix controllers, LiveView, components, router) lives under `lib/curriclick_web`.
- Application entrypoints and shared web helpers are defined in `lib/curriclick.ex` and `lib/curriclick_web.ex`.

### Key Locations

- **Chat Page**: `lib/curriclick_web/live/chat_live.ex`
    - LLM Definition: `lib/curriclick/chat/message/changes/respond.ex`
- **Job Application Queue Page**: `lib/curriclick_web/live/application_queue_live.ex`
    - LLM Definition (`chat_with_assistant` Ash action): `lib/curriclick/companies/job_application.ex`
- **User Profile Page**: `lib/curriclick_web/live/user_profile_live.ex`
- **User Dashboard Page (contains all confirmed job application)**: `lib/curriclick_web/live/user_dashboard_live.ex`
- **Header**: `app_header` LiveView component in `lib/curriclick_web/components/layouts.ex`

### How to use documentation effectively

- Use the usage rules and mix tasks below (`mix usage_rules.docs`, `mix usage_rules.search_docs`) to find official library documentation.
- Prefer using existing Ash resources, Phoenix modules, and helpers instead of reimplementing logic.
- Before introducing new patterns or APIs from a dependency, check both `AGENTS_USAGE_RULES.md` and the relevant usage rules document referenced below.

---

<!-- usage-rules-start -->
<!-- usage-rules-header -->
# Usage Rules

**IMPORTANT**: Consult these usage rules early and often when working with the packages listed below.
Before attempting to use any of these packages or to discover if you should use them, review their
usage rules to understand the correct patterns, conventions, and best practices.
<!-- usage-rules-header-end -->

<!-- igniter-start -->
## igniter usage
_A code generation and project patching framework_

[igniter usage rules](deps//igniter.md)
<!-- igniter-end -->
<!-- phoenix:ecto-start -->
## phoenix:ecto usage
[phoenix:ecto usage rules](deps//phoenix_ecto.md)
<!-- phoenix:ecto-end -->
<!-- phoenix:elixir-start -->
## phoenix:elixir usage
[phoenix:elixir usage rules](deps//phoenix_elixir.md)
<!-- phoenix:elixir-end -->
<!-- phoenix:html-start -->
## phoenix:html usage
[phoenix:html usage rules](deps//phoenix_html.md)
<!-- phoenix:html-end -->
<!-- phoenix:liveview-start -->
## phoenix:liveview usage
[phoenix:liveview usage rules](deps//phoenix_liveview.md)
<!-- phoenix:liveview-end -->
<!-- phoenix:phoenix-start -->
## phoenix:phoenix usage
[phoenix:phoenix usage rules](deps//phoenix_phoenix.md)
<!-- phoenix:phoenix-end -->
<!-- ash_postgres-start -->
## ash_postgres usage
_The PostgreSQL data layer for Ash Framework_

[ash_postgres usage rules](deps//ash_postgres.md)
<!-- ash_postgres-end -->
<!-- ash_events-start -->
## ash_events usage
_The extension for tracking changes to your resources via a centralized event log, with replay functionality._

[ash_events usage rules](deps//ash_events.md)
<!-- ash_events-end -->
<!-- ash_oban-start -->
## ash_oban usage
_The extension for integrating Ash resources with Oban._

[ash_oban usage rules](deps//ash_oban.md)
<!-- ash_oban-end -->
<!-- ash-start -->
## ash usage
_A declarative, extensible framework for building Elixir applications._

[ash usage rules](deps//ash.md)
<!-- ash-end -->
<!-- ash_ai-start -->
## ash_ai usage
_Integrated LLM features for your Ash application._

[ash_ai usage rules](deps//ash_ai.md)
<!-- ash_ai-end -->
<!-- ash_typescript-start -->
## ash_typescript usage
_The extension for tracking changes to your resources via a centralized event log, with replay functionality._

[ash_typescript usage rules](deps//ash_typescript.md)
<!-- ash_typescript-end -->
<!-- ash_phoenix-start -->
## ash_phoenix usage
_Utilities for integrating Ash and Phoenix_

[ash_phoenix usage rules](deps//ash_phoenix.md)
<!-- ash_phoenix-end -->
<!-- ash_authentication-start -->
## ash_authentication usage
_Authentication extension for the Ash Framework._

[ash_authentication usage rules](deps//ash_authentication.md)
<!-- ash_authentication-end -->
<!-- usage_rules-start -->
## usage_rules usage
_A dev tool for Elixir projects to gather LLM usage rules from dependencies_

## Using Usage Rules

Many packages have usage rules, which you should *thoroughly* consult before taking any
action. These usage rules contain guidelines and rules *directly from the package authors*.
They are your best source of knowledge for making decisions.

## Modules & functions in the current app and dependencies

When looking for docs for modules & functions that are dependencies of the current project,
or for Elixir itself, use `mix usage_rules.docs`

```
# Search a whole module
mix usage_rules.docs Enum

# Search a specific function
mix usage_rules.docs Enum.zip

# Search a specific function & arity
mix usage_rules.docs Enum.zip/1
```


## Searching Documentation

You should also consult the documentation of any tools you are using, early and often. The best 
way to accomplish this is to use the `usage_rules.search_docs` mix task. Once you have
found what you are looking for, use the links in the search results to get more detail. For example:

```
# Search docs for all packages in the current application, including Elixir
mix usage_rules.search_docs Enum.zip

# Search docs for specific packages
mix usage_rules.search_docs Req.get -p req

# Search docs for multi-word queries
mix usage_rules.search_docs "making requests" -p req

# Search only in titles (useful for finding specific functions/modules)
mix usage_rules.search_docs "Enum.zip" --query-by title
```


<!-- usage_rules-end -->
<!-- usage_rules:elixir-start -->
## usage_rules:elixir usage
[usage_rules:elixir usage rules](deps//usage_rules_elixir.md)
<!-- usage_rules:elixir-end -->
<!-- usage_rules:otp-start -->
## usage_rules:otp usage
[usage_rules:otp usage rules](deps//usage_rules_otp.md)
<!-- usage_rules:otp-end -->
<!-- usage-rules-end -->
