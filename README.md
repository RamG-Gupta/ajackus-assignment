# Ajackus event assignment

Rails 8.1 / PostgreSQL app that imports public Billetto events and records authenticated votes as Rails Event Store facts.

## Setup

Requirements: Ruby 3.4.2, PostgreSQL, and Bundler.

```sh
bundle install
bin/rails db:prepare
bin/rails server
```

Open `/events` (or `/`) to browse the local events. The JSON listing is `/events.json`. To import events, configure `BILLETTO_API_KEYPAIR` and run `bin/rails events:sync`.

## Configuration

### Billetto

The importer calls Billetto's public events endpoint at `https://billetto.dk/api/v3/public/events`, sends the API key pair in the `Api-Keypair` header, and requests `limit=100` (the documented maximum). Set `BILLETTO_API_URL` only when pointing at a compatible endpoint, and set `BILLETTO_API_KEYPAIR` on the server. The importer maps Billetto's `id`, `title`, `description`, `startdate`, `enddate`, and `image_link` fields. Events with missing or invalid required fields are skipped and logged; valid records are upserted by provider ID. Production's Solid Queue schedule enqueues a sync every 30 minutes.

The request/normalization specs use a fixture shaped like the public-event schema in Billetto's API reference. A Billetto API key was not available for a credentialed live request during this implementation, so configure the key and run `bin/rails events:sync` against the account before deployment.

### Clerk

For the browser sign-in/sign-up and user menu, set `CLERK_PUBLISHABLE_KEY` and `CLERK_FRONTEND_API` (the Clerk frontend API domain, without `https://`). For server-side token verification, set `CLERK_JWT_KEY` to the PEM public key, `CLERK_ISSUER` to the Clerk instance issuer, and `CLERK_AUTHORIZED_PARTIES` to comma-separated allowed app origins. The server checks the session JWT signature, expiry, issuer, authorized party, and subject before accepting a vote. Never expose the verification key or Billetto API key pair in frontend code.

With Clerk configured, signed-out visitors see Clerk's sign-in component, which includes sign-up according to the Clerk instance settings. A signed-in visitor can like, dislike, switch their vote, or remove it from the event listing. The backend accepts `POST /events/:event_id/vote` with `{ "value": "up" | "down" }` and `DELETE /events/:event_id/vote` to remove a vote. Both requests require a valid Clerk session token.

## Architecture and vote rules

- `Billetto::Client` owns the HTTP call, timeout/error mapping, and response extraction. `Billetto::EventIngestor` validates provider records and upserts in a database transaction. The database's unique provider ID index makes repeated imports safe.
- The controller submits `Events::CastVote` through Arkency's command bus. `Events::CastVoteHandler` delegates to `Events::VoteService`, where the rules live. Repeating the current vote is a no-op; switching publishes the new vote fact; removing a vote publishes `Events::VoteRemoved`. A repeated removal is a no-op.
- `Events::Upvoted`, `Events::Downvoted`, and `Events::VoteRemoved` are validated facts. They are written to `Event$<id>` and linked to `User$<clerk-user-id>`. The event row lock serializes a user's changes for an event, and Rails Event Store uses `expected_version: :auto` while that lock is held. `Events::ApplyVote` projects facts into `event_votes`; the database enforces one row per event/user, a valid vote value, and a real event foreign key.
- Event counts use a grouped query. The event listing is kept deliberately small; there is no separate count query per card.

## Checks

Run the test suites and lint checks with:

```sh
bundle exec rspec
bin/rubocop
```

RSpec includes model, API client/ingestor, authenticated and unauthenticated vote requests, vote idempotency/switch/removal, and a headless browser listing spec. GitHub Actions uses Ruby from `.ruby-version`, runs RSpec (including the browser spec in its system-test job), and runs the security and lint jobs.

AI tools contributed to implementation and review. The final submission should be read and validated by the candidate, who remains responsible for understanding and presenting the design.
