# WhatsApp replies are not being delivered — 25 Nov 2026

**The app is not at fault. Meta has the number in a blocked state.**

Three `hii` messages were sent to +91 94620 60407 (10:48, 11:46, 11:48 IST).
The server answered all three within three seconds and Meta accepted every one,
returning a message id. None of them arrived.

```
06:16:48 UTC  WhatsApp in  +916354348913: "hii"
06:16:51 UTC  WhatsApp out +916354348913 ok (wamid.HBgMOTE2MzU0MzQ4OTEzFQ…)
06:18:31 UTC  WhatsApp in  +916354348913: "hii"
06:18:34 UTC  WhatsApp out +916354348913 ok (wamid.HBgMOTE2MzU0MzQ4OTEzFQ…)
```

## What Meta says about the number

`GET /{phone-number-id}?fields=health_status`:

```
OVERALL can_send_message: BLOCKED

- PHONE_NUMBER 1287877527744012 -> LIMITED
    note : Your display name has not been approved yet. Your message limit
           will increase after the display name is approved.

- WABA 2166534517256689 -> BLOCKED
    141006 : There is an error with the payment method. This will block
             business initiated conversations.
    fix    : Add a new payment method to the account.

- BUSINESS 1449843836131229 -> LIMITED
    141010 : The Business has not passed business verification.
    fix    : Visit business settings and resolve the verification request.

- APP 1938861683475701 -> AVAILABLE
```

Also: `messaging_limit_tier: TIER_250`, `is_official_business_account: false`,
`code_verification_status: EXPIRED`, `quality_rating: GREEN`.

The only entity reading **BLOCKED** is the WABA, and the only error on it is the
payment method. Meta's note on 141006 says *business-initiated* conversations —
a reply inside the 24-hour window is user-initiated and should in theory still
go — but Meta's own rollup for the number is `BLOCKED`, and empirically nothing
is being delivered. Fix the payment method first, then re-test: the per-message
reason will now be in the log (see "Code changes" below).

## What else this silently breaks

Inbound is **unaffected** — bookings are still being created normally (2,666 so
far, the latest today at 08:48 IST). That is exactly why this went unnoticed.
Everything the business *sends* is affected:

| | |
|---|---|
| `✅ Booking posted!` confirmation | never arrives — the customer posts a booking and hears nothing |
| `Sorry, I couldn't read that…` help reply | never arrives |
| Trip start / end OTP over WhatsApp | never arrives |
| Invoice PDF over WhatsApp | never arrives |

## A second, independent problem: no templates

The WABA has exactly one template, `hello_world` (Meta's sample). There is no
OTP template and no invoice template, and neither `WHATSAPP_OTP_TEMPLATE` nor
`WHATSAPP_INVOICE_TEMPLATE` is set in the production `.env`.

Without them the OTP and the invoice go as **free-form** messages, which Meta
only delivers inside the 24-hour window that opens when the customer last
messaged the business. For a trip booked days earlier that window is shut, so
those two will still not arrive **even after the payment block is cleared**.

## What has to be done in Meta (cannot be done from the code)

1. **Add a working payment method** on WABA `2166534517256689`. This is the one
   thing currently marked BLOCKED.
2. **Complete business verification** (error 141010) — clears the BUSINESS limit.
3. **Get the display name approved** — raises the number above TIER_250.
4. Create and get approved an **AUTHENTICATION** template for the trip OTP and a
   **UTILITY** template for the invoice, then set `WHATSAPP_OTP_TEMPLATE` and
   `WHATSAPP_INVOICE_TEMPLATE` in `backend/.env` and restart.

## Code changes

**Deployed** — `8a51583`, live since 05:50 UTC:

* `LOG_LEVELS` env (default unchanged; production set to `error,warn,log`).
  Production kept only `error`/`warn`, so every `logger.log` was discarded —
  which is why 2,666 WhatsApp bookings produced **zero** log lines and this was
  undiagnosable.
* Inbound text, outbound reply (with Meta's message id), and a warning on each
  path where the sender gets nothing: rejected signature, non-text message,
  empty body.
* OpenAI client bounded to 15s with no retries. It was on the library default of
  **ten minutes × two retries, per model** — one stalled call meant the sender
  never got an answer.
* The SMS gateway URL is no longer logged with its `authkey` and the OTP in it.
  Harmless only while production dropped `log` lines, which is what was just
  turned on.

**Committed, not yet pushed** — `a258e45`:

* A `failed` delivery receipt now logs at **warn** with Meta's error code and
  explanation; `sent`/`delivered`/`read` stay at debug. Until now Meta accepting
  a message and then refusing to deliver it looked exactly like success, which
  is how an account-level block hid behind `200 OK` and a message id.

Tested in process against the compiled build with `fetch` stubbed: **32 checks,
0 failures**.

## Snapshots taken before each change

```
/root/backups/pre-walogging-deploy-20261125-054918.gz   14M mongodump, --dryRun verified
/root/backups/backend-dist-20261125-054918.tgz          previous build
/root/backups/backend-env-20261125-054918.bak           .env before the LOG_LEVELS line
```

Rollback: `git reset --hard 1deda1f`, extract the dist tarball, `pm2 restart backend`.
