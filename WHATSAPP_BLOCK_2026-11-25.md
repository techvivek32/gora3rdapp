# WhatsApp replies are not being delivered — 25 Nov 2026

> **RESOLVED the same day, 07:21 UTC (12:51 IST).** ₹100 added to the WhatsApp
> Business account by UPI; Meta's health check flipped `WABA -> AVAILABLE` and
> delivery resumed about a minute later. The last failure was 07:20:51; the two
> real customer confirmations after it (07:21:39, 07:23:13) went through with no
> failed receipt. Nothing in the app was changed to fix it — the code changes
> below are what made the cause visible in the first place.
>
> Still open: business verification (141010), display name approval (the number
> is capped at TIER_250), the GST number on the billing account, and the missing
> OTP / invoice templates.

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

## Confirmed, per message

With the failed-delivery logging live (`a258e45`), one more `hii` gave Meta's
own verdict on that exact message — three lines, three seconds apart:

```
06:29:42  WhatsApp in  +916354348913: "hii"
06:29:44  WhatsApp out +916354348913 ok (wamid.HBgMOTE2MzU0MzQ4OTEzFQ…)
06:29:46  WhatsApp delivery FAILED to +916354348913 (wamid.…QjdDQTVFOEYyQjI1OUZDQUQzAA==):
          131042 Business eligibility payment issue
          Message failed to send because your WhatsApp Business account currency
          is not configured.
```

Meta even supplies the page that fixes it:

```
https://business.facebook.com/billing_hub/accounts/details/
  ?business_id=1449843836131229
  &asset_id=2166534517256689
  &wizard_name=CHANGE_COUNTRY_CURRENCY
  &account_type=whatsapp-business-account
```

So the precise cause is **not a declined card — the WABA has no country/currency
set at all**, which is what the generic 141006 "payment method" error on the
health check was standing in for. Nothing can be delivered until that wizard is
completed.

## It used to work. It stopped on 22 November.

This is not a long-standing fault that nobody noticed — Meta's own analytics for
the WABA show the number delivering perfectly, every single day, until it simply
stopped:

```
date          sent  delivered
2026-11-15     115        115
2026-11-16      31         31
2026-11-17      38         38
2026-11-18      57         57
2026-11-19      46         46
2026-11-20      49         49
2026-11-21      47         47
2026-11-22       —          —     no data point at all
2026-11-23       —          —
2026-11-24       —          —
2026-11-25       —          —
```

Over the 75 days queried: **2,030 sent, 2,030 delivered — a 100% rate, zero
failures** — and then nothing from 22 November onward. A failed message is not
counted as "sent", which is why those four days have no row rather than a row of
zeros.

So the trigger was not a code change on our side (the last backend deploy before
this was 19 November, and it touched one additive site-text key). What changed is
that the WABA had **never** had a country/currency set — the billing wizard said
"cannot be changed once set", which only appears before it has been set — and
Meta began enforcing that on 22 November. Everything the business sends has been
dropped since.

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

1. **Set the country and currency** on WABA `2166534517256689`, via the billing
   hub link Meta returns with error 131042 (above). This is the one thing
   actually stopping delivery — confirmed on a live message, not inferred.
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
