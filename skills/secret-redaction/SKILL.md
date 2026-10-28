---
name: secret-redaction
description: Never write a secret value, prefix or masked string; reference every secret by name and location, and grep every write for value shapes (database URIs, JWT, Stripe, PostHog, Intercom, AWS). Load in any session that reads repos, env file listings, bundles or infra docs, or writes notes, prompts or PRs.
---

# Skill: Secret Redaction

> A note, prompt, PR or log may say that a secret exists and where it lives. It never says what the
> secret is: no value, no prefix, no last four, no masked string. The canonical form is
> `<name> (<location>): value redacted`. The reviewer grep below runs on every write and any hit
> blocks until it is removed.

## When this applies

Every session that reads a repo, an environment file listing, a production bundle, or infra docs.
Applies to notes, task briefs, contracts, plans, PR bodies and anything pasted into a prompt. Deny
reads of `.env*`, `*.pem`, `*.key`, `secrets/` and `credentials.json` in your agent settings; this
skill covers what slips through anyway.

## Rules

1. **Never write a value.** Record that the secret exists and where it is configured.
   - ✅ Do: `the MongoDB connection string (api server environment, variable name unknown): value redacted`
   - ❌ Don't: paste the URI with the user and password in it, even "just for the local one".

2. **Use the canonical form.** `<name> (<location>): value redacted`. The name is the variable or key
   name when you saw it in code; the location is where it is configured (env file of which repo, CI
   secret store, provider dashboard), never a pointer to the line holding the value.
   - ✅ Do: `the Stripe webhook signing secret (api server environment; Stripe dashboard, webhook settings): value redacted`
   - ❌ Don't: `Stripe webhook secret: see line 12 of the api .env`

3. **No partial values.** No prefix, suffix, last four, masked middle or "example that looks like the
   real one". Name the provider and the kind instead.
   - ✅ Do: `the PostHog project key (frontend environment config)`
   - ❌ Don't: the key with its middle replaced by asterisks, or its first eight characters.

4. **Client-side keys are still not written.** Analytics project keys, the Stripe publishable key and
   chat widget app ids ship in the public bundle, and they are still referenced by name only.
   - ✅ Do: `the Intercom app id (frontend environment config)`
   - ❌ Don't: "it is public anyway" followed by the value.

5. **Do not invent names.** If you have not seen the variable name in code, write the kind of secret
   and the location, and say the name is unknown.
   - ✅ Do: `the JWT signing secret (api server environment, name unknown)`
   - ❌ Don't: a plausible-looking variable name you never saw in the code.

6. **Unconfirmed means `(inferred)`.** Only record secrets you saw referenced in a source. A secret
   you deduce (an AWS key because downloads come from S3) gets `(inferred)`.
   - ✅ Do: `AWS credentials for the downloads bucket (api server environment) (inferred): value redacted`
   - ❌ Don't: state where it is stored as a fact when you only guessed.

7. **Logs and prompts count.** Never paste a request log with an `Authorization` header, a database URI
   in an error stack, or a webhook payload with its signature header into a note, PR or agent prompt.
   - ✅ Do: quote the error message and the file, drop the header and the URI.
   - ❌ Don't: hand a subagent a stack trace that still holds the connection string.

8. **A leaked value is an incident, not an edit.** If a value reached a commit, a PR or a pushed note,
   stop, tell the developer, and rotate it. Deleting the line does not remove it from git history.
   - ✅ Do: report which secret, where it appeared, and that it needs rotation.
   - ❌ Don't: quietly amend and move on.

## Reviewer grep (run on every file you wrote or changed)

```bash
cd <repo or notes root> || exit 1
# `command grep` skips any shell function named grep, so the patterns run on the system grep.
g() { command grep -rInE --exclude-dir=.git --exclude-dir=secret-redaction "$@" .; }
# Key names assigned a value: FOO_SECRET=..., token: ..., password = ...
g -i '(secret|token|passw(or)?d|api[_-]?key|access[_-]?key|private[_-]?key|client[_-]?secret|bearer|conn(ection)?[_-]?string|jwt)[a-z_]*[[:space:]]*[:=][[:space:]]*.?[A-Za-z0-9+/_.-]{12,}'
# Connection strings with inline credentials (MongoDB and any scheme://user:pass@host)
g '(mongodb(\+srv)?|postgres(ql)?|redis|amqps?|https?)://[^/[:space:]:@]+:[^/[:space:]@]+@'
# Provider value shapes: Stripe secret, restricted and webhook keys; PostHog keys
g '(sk|rk)_(live|test)_[A-Za-z0-9]{8,}|whsec_[A-Za-z0-9]{8,}|ph[cx]_[A-Za-z0-9]{20,}'
# AWS access keys and secret keys; JWTs; PEM private keys
g '(AKIA|ASIA)[0-9A-Z]{16}|aws_secret_access_key[[:space:]]*[:=]'
g 'eyJ[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}|-----BEGIN [A-Z ]*PRIVATE KEY-----'
# Intercom tokens have no fixed prefix: look for the word next to a long blob
g -i 'intercom[a-z_]*[[:space:]]*[:=][[:space:]]*.?[A-Za-z0-9=_-]{20,}'
# Long base64-like blobs in notes: review each hit by hand
g --include='*.md' '[A-Za-z0-9+/=]{40,}'
```

Run the same patterns on a repo diff before a PR: `git diff <trunk>... | grep -nE '<pattern>'`.
This skill's own folder is excluded because it holds the patterns.

## Checklist (for reviewers)

- [ ] Every grep above prints nothing, or only hits you confirmed are not values.
- [ ] Every secret reference uses `<name> (<location>): value redacted`.
- [ ] No prefix, suffix, masked or "example" value anywhere.
- [ ] Client-side keys (analytics, Stripe publishable, chat widget app ids) appear by name only.
- [ ] No invented variable names; unknown names are marked unknown, deduced secrets are `(inferred)`.
- [ ] No log, stack trace or header dump with credentials in notes, briefs or prompts.
- [ ] Any value that reached git was reported for rotation.

## Adapt to your repo

- Add value patterns for the providers your project uses that are not listed above.
- Add the env file and secrets paths your agent settings should deny.

## Notes

The value is the only dangerous part. The name and location are what an engineer needs to operate the
system, so a redacted note stays useful. Personal and customer data follow the same restraint in
`customer-data-protection`.
