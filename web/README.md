# Gora Cabs — Customer Website

The customer-facing website. Same booking flow as the Customer mode of the
mobile app, against the same backend: no new API was added for it.

    admin/    staff panel        (Next.js, :7000)
    backend/  API                (NestJS,  :7001)
    web/      customer website   (Next.js, :7002)   <- this
    mobile/   driver + customer app (Flutter)

## Run

    npm install
    npm run dev          # http://localhost:7002

`NEXT_PUBLIC_API_URL` overrides the API host; it defaults to the live backend so
a build with no env can never silently point at localhost.

## What it does

**There is no sign-in at all.** A visitor searches, sees fares, and books with
a name + mobile number. No account, no OTP, no password — anywhere on the site.

| Flow | Pages |
|---|---|
| Cab booking | `/book/cab` -> `/cabs` (fares) -> `/confirm` (pay) -> `/booked` |
| Hire a driver | `/book/hire_driver` — priced per day, books directly |
| Car pool | `/pool`, `/pool/[id]` |
| Help | `/support` — phone + WhatsApp, no account needed |

Tracking a trip, trip history and complaints live in the **mobile app**: a
customer opens it with the same number and the booking is already there. That is
deliberate — showing someone's bookings on an unauthenticated website would mean
anyone could read them by typing a number.

## The fare engine

`src/lib/fare.ts` is a 1:1 port of the mobile app's `cab_results_page.dart`.
It MUST stay identical: a customer who prices a trip in the app and books the
same trip here has to see the same number, and the `estimatedFare` this sends is
what the driver is later paid against. **Change the two together.**

Order of operations:

    base   = billable km x per-km rate     (or the Local package price)
    + toll = admin toll/tax per-km x km    (All-Inclusive mode only)
    net    = (base + toll) after the cab's discount%
    + allow= driver allowance              (AFTER the discount — the driver keeps it whole)
    + gst   = gstPercent of (net + allowance)

## Guest booking (no OTP)

`POST /customer-bookings/guest` and `POST /car-pool/:id/guest-book` are public
and take a name + an **unverified** mobile number. Both go through
`resolveGuestUser`, which reuses an existing account with that number or creates
a password-less one.

**The rule that keeps this safe: these endpoints issue no tokens and return no
account data.** If they did, typing a stranger's number would be a full
authentication bypass. Never "helpfully" return the user or a session from them.

Two accepted costs of skipping OTP, both deliberate:
- a mistyped number files the booking under someone else's account;
- spam is bounded only by the global per-IP throttler, so it must stay enabled.

`/places/route` and `/places/details` had to be made public too (a guest has to
price a trip before identifying themselves). Those are the billed Google calls —
watch the billing dashboard.

## Payment

Razorpay web checkout, the same contract the app uses: the server creates the
order, and `/customer-bookings/advance/verify` checks the HMAC. The browser
never decides a payment succeeded. A cancelled or failed payment cancels the
pending booking so no live ₹0 booking is left behind.

**Online advance requires signing in** — the order endpoint ties the payment to
the booking's owner, which a guest has no session to prove. Guests book at ₹0
and pay the driver directly.

## Deploying

CORS is an allow-list on the backend (`CORS_ORIGINS` in its `.env`), so the
website's origin has to be added there before it can call the API in production.
