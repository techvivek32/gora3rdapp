# Emulator test report — Gora Cabs
Date: 2026-10-27 · Device: `emulator-5554` (gora_test) · Backend: local `:7001` · DB: `goracabs` (local)

App built with `--dart-define=API_BASE_URL=http://10.0.2.2:7001/api/v1` (env.dart untouched, still points at production).

---

## PASS — verified in the emulator

| # | Item | Evidence |
|---|---|---|
| 1 | App launches, no ANR | Splash → role select → login → home, all clean. The geolocator `getLastKnownPosition` fix is in place. |
| 2 | Role-select flow | Get Started → Customer / Driver-Vendor cards → login. |
| 3 | Login + dev OTP | `6354348913` / `123456` → home. |
| 4 | **Navigation arrow on booking cards** | Small, tilted, stacked directly above the date box on every card. Tapping it launched `com.google.android.apps.maps/MapsActivity` — confirmed via `dumpsys window`. |
| 5 | **Hire a Driver accept dialog** | Shows **only "Select Driver"** — no vehicle picker. Also shows "You earn ₹1080 — ₹120 (commission + GST) is held from your wallet." |
| 6 | **Wallet page** | Balance ₹31,498, On hold ₹520, Total ₹32,018. **Pay by QR** button present; it calls `POST /wallet/create-qr` correctly. |
| 7 | **Wallet ₹0 on member profile** | `GET /users/card/:id` returns `walletBalance: 31498`; `customerWalletBalance` correctly absent. |
| 8 | **Customer wallet is separate** | `GET /wallet` → 18540 with driver transactions. `GET /customer-wallet` → 0 with an empty list. Two independent ledgers. |
| 9 | **KYC — number fields gone** | Driving License section starts straight at Front Side. No "Driving License Number" field anywhere. |
| 10 | **KYC — both docs, both sides compulsory** | Aadhaar front only → `"Upload front and back photos of: Aadhaar Card and Driving License."` · Aadhaar both sides only → `"…of: Driving License."` · All four → accepted. |
| 11 | **Customer number leak** | Posted a booking with notes `"AC must work • Contact: Ramesh Patel, 9876501234 • 2 bags"`. Driver feed returned `notes: "AC must work • 2 bags"`, `contactName: ""`, `contactMobile: ""`. |
| 12 | **Wallet payment not updating** | Signed Razorpay webhook → balance 18540 → **19317** (+₹777), row flipped to `success`. Replayed 3× → still 19317 (idempotent). Bad signature → `invalid_signature`, no credit. |
| 13 | Booking advance via webhook | Same path: booking went `advanceStatus: none → paid`, amount ₹1050, percent 30, payment `success`. |
| 14 | **Chat only after recharge** | Free member (`membershipType: new`) → **403 "Buy a membership plan to chat with posters."** · Golden member → chat created. |
| 15 | **Admin default ringtone** | With no admin default: "Default". After an admin default is set, both rows read **"Default (test)"** — the app picks up the admin's choice. |
| 16 | **Duplicate vehicle / driver** | `GJ99ZZ4242` added OK; re-adding it, and `"GJ 99 zz 4242"` (different spacing + case), both refused with `"This vehicle is already in your garage."` A number owned by another account → `"…already registered in another account."` Driver phone `9000000011` added OK, repeat → `"You have already added a driver with this number."` |
| 17 | Garage approval | New vehicle and new driver both land as `approvalStatus: "pending"`. |
| 18 | **Floating logo bubble** | Appears when you go Online, is draggable, survives page changes. |
| 19 | Online / Alerts toggles | "You're Online — booking alerts will pop up." Alerts opens the My Alert filter sheet and saves. |
| 20 | **Booking history 24h** | 7-day window confirmed live: a 3-day-old EXPIRED booking **is** in the feed, a 10-day-old one **is not**. |
| 21 | **"Profile hide ho rahi hai though toggle is off"** | Secure + Hide ON → saved (`secureBooking:true, hideProfile:true`) **and the list refreshed on its own**. Secure OFF auto-clears Hide → saved (`false, false`), list refreshed again. The missing reload in `requirements_bloc._onUpdate` was the cause and it is fixed. |
| 22 | Guest booking (web flow) | `POST /customer-bookings/guest` creates a booking with name + mobile only — no token issued, no account data returned. |

---

## Could NOT be tested on this machine (environment, not code)

| Item | Why | How it was verified instead |
|---|---|---|
| **Push notification + popup card** | Local `.env` has `FIREBASE_PRIVATE_KEY="dummy-local…"`, so firebase-admin never initialises: `"Firebase credentials not configured — push notifications disabled"`. The popup is driven purely by FCM `RemoteMessage`. | Server side confirmed: `"Customer booking CB3770053748: alerted 3 drivers"`. The FCM failure is caught and logged, booking creation still succeeds. Production Firebase key handling was verified live on the server earlier (`firebase-admin init: OK`). |
| **Pay by QR end-to-end** | Local Razorpay keys are dummies (`RZP_2164…`) → `"QR could not be created: Authentication failed"`. | The app calls the right endpoint and shows a clean 400 message, no crash. |
| **Admin panel** (blacklist / reject / delete / counts) | Next.js admin runs in your own dev server; I did not touch it. | The underlying garage rules were tested through the API (row 16/17). |
| Razorpay live checkout | Needs real keys + a real payment. | Webhook and reconcile paths tested with signed payloads (rows 12/13). |

---

## Found and fixed during this pass

**The contact leak had a second, wider hole.** `notes` is copied verbatim into the push-alert payload, and the popup card and floating overlay render it — so a rider's number written into notes was broadcast to *every* eligible driver's phone, not just shown in the feed. Redacting only the feed left that path open, and the push reaches far more drivers than the feed does.

Fixed in `backend/src/modules/customer-bookings/customer-bookings.service.ts` → `notifyEligibleDrivers()`, which now redacts before handing the booking to the notification service. `tsc --noEmit` clean.

---

## Notes

- The **"Secure Member" watermark** covering a card is the membership badge, **not** the hide-profile feature. If that is what looked like "profile hide", it is unrelated to the toggle.
- The **floating bubble sits over the right edge** and intercepted taps on the "Secure this booking" switch until I dragged it away. Worth considering on small screens.
- Your local backend on `:7001` **stopped by itself** mid-session (not from any request — the push fan-out is wrapped in try/catch). I started a fresh one in the background; it is running now.
- All test data I created was removed afterwards: 6 test bookings, 1 garage vehicle, 1 garage driver, the webhook top-up (balance restored to 18540 exactly), the advance payment, the test webhook secret, the ringtone default flags, and the test user's KYC submission.

## Still uncommitted (nothing pushed or deployed)

```
M  backend/src/modules/customer-bookings/customer-bookings.module.ts
MM backend/src/modules/customer-bookings/customer-bookings.service.ts
M  backend/src/modules/payments/payments.controller.ts
M  backend/src/modules/payments/payments.module.ts
M  backend/src/modules/wallet/wallet.module.ts
M  backend/src/modules/wallet/wallet.service.ts
 M mobile/lib/features/requirements/presentation/bloc/requirements_bloc.dart
```

**Reminder:** `master` on GitHub still has the merge-conflict markers from commit `bbf5661` — that code does not compile. The resolution is in the working tree, uncommitted.

**Action needed from you:** add the Razorpay webhook in the Razorpay dashboard →
`https://backend.goracabs.com/api/v1/payments/webhook/razorpay`, events `payment.captured` and `qr_code.credited`.
