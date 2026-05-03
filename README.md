# Wik

Wik = community software that wants your attention for as little time as possible.

This project exists to help groups coordinate with less noise, less screen time, and more real-life connection by moving durable knowledge out of chaotic chat and into quality shared memory.

👉 See also: [deepwiki/wik2](https://deepwiki.com/danielres/wik2)

## About This Repo

This repository is home to **Wik version 2** 

**Wik version 1** can be found at: https://github.com/danielres/wik

## Mission

The dream outcome is simple: people find what they need, improve it together, close the tab, and save time which can now be spent together in real life, in more valuable and meaningful ways.

This project is unapologetically built against attention-extractive software:

- resolution over retention
- structure over feed noise
- shared memory over repeated explanations
- retrieval over scrolling
- calm coordination over constant engagement

This helps projects reduce considerably screen time and notifications for their members.

For more on the mission, see [MISSION.md](https://github.com/danielres/wik2/blob/main/MISSION.md)

## Example Use Cases

- Local communities
- Neighborhoods
- Student groups
- Hobby groups
- Support groups
- Small companies

## Access and Identity

A person can prove who they are through an external identity, a group can define trusted access sources, and Wik turns that into grants and memberships inside the space.

The result is access that feels lighter than traditional account admin, but still gives groups clear control over who belongs and what role they hold. 

External participation can become internal access, in a way the group can verify and control.

This allows groups to manage access without heavy admin work.

If a person is already recognized through a channel the group trusts, Wik can use that to unlock the right space for them.

The conceptual model:

- External Identity = how a person shows up in an external system (Telegram group, Discord server, SSO provider, etc)
- Access source = a group-controlled place or channel that Wik can trust
- Grant = the connection that says “this person has verified access here”
- Membership = what role they hold inside the group once access exists

So instead of:

- "invite users, manage passwords, approve everyone by hand"

Wik can say:

- "if this group already knows you through a trusted channel (ex: Telegram group, Discord server), that trust can carry over"


## Built With

Wik v2 is built with:

- [Elixir](https://elixir-lang.org/)
- [Phoenix](https://www.phoenixframework.org/)
- [Ash Framework](https://ash-hq.org/)
- [PostgreSQL](https://www.postgresql.org/)

## What Wik Includes

Wik is organized around the **group** as the main unit. 

Every group is a private space designed for knowledge sharing and efficient coordination amongst its members.

Right now, that includes:

- A group wiki 
- Modular content blocks
- Group memberships with owner/admin/member roles
- Pluggable access and identity flows
- Superadmin and admin tooling for development and operations

### Planned features

- Polls
- Resources library (videos, articles, files, ...)
- Event scheduling
- Community announcements
- Advanced member profiles with structured skills and interests

## Local Development Quickstart

This repo is intended to be run in dev with [devenv](https://devenv.sh).

Note: `Qblog` is just the internal name for Wik v2. (You may see that name in code, configs, and commit history.)

### Primary Flow

```bash
devenv up
mix setup
mix phx.server
```

Then open:

- `http://localhost:4000`

`devenv up` provides the local development environment, including:

- Elixir
- Erlang
- Node.js
- pnpm
- PostgreSQL
- Admin UI at `http://localhost:4000/admin`
- Adminer (database GUI at `http://localhost:8086`)

It also provisions local Postgres databases for:

- `qblog_dev`
- `qblog_test`

After that, `mix setup` handles the app bootstrap:

- fetches dependencies
- runs Ash/Postgres setup
- builds assets
- runs `priv/repo/seeds.exs`

### Development Database Defaults

When running through `devenv`, local Postgres is configured on port `5432` and the development app config still defaults to:

- database: `qblog_dev`
- username: `postgres`
- password: `postgres`
- port: `5432`
- host: `localhost`

If `PGHOST` is set:

- if it starts with `/`, it is treated as a Postgres socket directory
- otherwise it is treated as the hostname

`PGUSER`, `PGPASSWORD`, `PGPORT`, and `PGDATABASE` are also respected.

## Local Sign-In And Seeded Data

In development, the sign-in page includes a **Local dev** section that lets you:

- sign in as a superadmin
- sign in as any existing local user

The superadmin shortcut uses `Qblog.DevAuth` and creates the local dev superadmin on demand if needed.

### Seeded Demo Data

`priv/repo/seeds.exs` currently creates:

- user `seed-owner@example.com`
- user `seed-member@example.com`
- group `seed-group-two-members`

The seeds also create Telegram-backed demo access data so you can exercise:

- group membership flows
- the currently implemented Telegram-based access flow
- identity / source relationships

So after `devenv up` and `mix setup`, you can usually:

1. open `http://localhost:4000/sign-in`
2. sign in as superadmin or one of the seeded users
3. start exploring the seeded group immediately

## Optional Telegram Integration

Telegram is the only access type currently implemented in production, but it is **not** the long-term limit of the model and it is **not required** for basic local development.

You can boot the app, sign in locally, and explore the main flows without touching Telegram at all. If you do want the full Telegram-flavored experience, you will need at least:

- `TELEGRAM_BOT_TOKEN`

## Common Commands

Useful workflow notes:

- `devenv up` is the normal environment entrypoint
- `mix setup`
- `mix test.interactive --trace`
- `mix precommit` - the expected final verification command

## Production Notes

At minimum, production expects:

- `DATABASE_URL`
- `SECRET_KEY_BASE`
- `TOKEN_SIGNING_SECRET`
- optionally `PHX_SERVER`, `PHX_HOST`, `PORT`, `POOL_SIZE`, and `DNS_CLUSTER_QUERY`
