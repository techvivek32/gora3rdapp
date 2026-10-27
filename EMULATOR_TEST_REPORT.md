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

---
---

# Round 2 — camera picker + document duplicate rules
Date: 2026-10-27 (later) · Same emulator, same local backend. APK rebuilt and reinstalled 3×.

## PASS — seen working in the emulator

### Camera option (the gallery-only complaint)
| Where | Result |
|---|---|
| **Vehicle** — RC Front | Sheet "Add photo → Take Photo / Choose from Gallery". **Take Photo launched `com.android.camera2/CaptureActivity`**, photo captured → uploaded → thumbnail in the slot with a remove ×. Full round trip. |
| **Vehicle** — RC Back | "Choose from Gallery" opened the Android photo picker — the old path still works, no regression. |
| **Driver** — Driver Photo | Sheet shown (the exact form from the screenshot). |
| **Driver KYC** — Aadhaar Front | Sheet titled **"Aadhaar Card — Front"**. |
| **Create Account** — Aadhaar Front | Sheet titled **"Aadhaar Card — Front"**. |
| **Profile** — change photo | Sheet titled **"Profile photo"**. |

Camera permission was already in the manifest; the AVD has camera hardware, so this was a real camera launch, not a stub.

### Document duplicate rules
| Case | Result |
|---|---|
| Aadhaar `123456789012` vs existing `1234 5678 9012` | ❌ Blocked — "You have already added a driver with this Aadhaar number." |
| DL `1234567890` already in the garage | ❌ Blocked — "You have already added a driver with this licence number." |
| Fresh Aadhaar `9999 8888 7777` | ✅ Saved, "Pending admin approval" — no false blocking |

(Cross-account and lowercase/hyphen variants were covered by API tests in the same round: `9413-4584-9688` and `mh0920070270222` both blocked from a second account.)

### KYC
- "Submit for Verification" with nothing uploaded → **"Upload front and back photos of: Aadhaar Card and Driving License"**.

## Two defects found during this round, both fixed

**1. Server rejections landed on the wrong field.** `my_garage_page` classified any message containing the word "number" as a phone error — and the new messages say "Aadhaar **number**" / "licence **number**". So a duplicate Aadhaar put a red border on the *Phone* field, and the text was cut off at one line: *"You have already added a driver with this A…"*. The user would have edited a phone number that was perfectly fine.
Fixed: the message now routes to the field it names (Aadhaar → Aadhaar field, licence → DL field, phone last since the document messages also contain "number"), and `errorMaxLines: 3` lets the full sentence wrap. Re-tested: DL error on the DL field, Aadhaar error on the Aadhaar field, Phone clean in both cases.

**2. Stale KYC copy.** The page still said *"Add your document number and a clear photo"* after the number field was removed. Now reads *"Upload clear front and back photos of both documents, then submit for verification."*

## Minor, not fixed (tell me if you want these)
- The floating logo bubble **stays on screen after sign-out**, and even over the launcher.
- The bubble sits over the right edge and **intercepts taps** on controls underneath (it blocked the "Secure this booking" switch until dragged away).

## Cleanup
Test garage drivers removed. The emulator is signed back in as `6354348913`, where you left it.

---
---

# Round 3 — the two bubble defects, fixed and retested
Date: 2026-10-27 (later) · Same emulator + local backend.

## What was wrong

**1. Bubble survived sign-out.** `hideOnlineBubble()` was only wired to the online toggle. The online flag lives in SharedPreferences, not in the session, so after signing out the bubble stayed over the login screen and the launcher — and the next person to sign in on that phone started "online" without ever saying so.

**2. Bubble swallowed taps on the app's own UI.** Two causes:
   - The overlay WINDOW was a fixed `200 x 200`, while the circle is 58dp. The plugin takes device pixels, the widget is drawn in logical ones, so a chunk of invisible window sat over the app and ate touches.
   - More fundamentally, the bubble was being shown **while Gora itself was in the foreground** — where it has no purpose at all. It exists to get back into the app from *somewhere else*.

## The fixes
- Window is now sized from the bubble (`(58 + 6) * devicePixelRatio`), so the two always match. The widget and the window share one constant.
- `AuthBloc._onLogout` clears the online flag and takes the bubble down. Every route out — both profile pages and the 401 handler — funnels through that event.
- The bubble is now tied to app lifecycle: **hidden on `resumed`, shown on `paused`**. It is no longer raised by the online toggle or at app start, because both of those happen while we are the app on screen.

## Retest — 8 checks, all pass

| # | Check | Result |
|---|---|---|
| 1 | App in foreground, Online ON | **No bubble.** Clean screen. |
| 2 | Press Home (background) | **Bubble appears** over the launcher — a tight circle now, no grey box. |
| 3 | Tap the bubble | App opens, **bubble disappears** on resume. |
| 4 | Edit Booking → tap "Secure this booking" **at the exact spot that was dead before** | **Toggles ON. Tapped again → OFF.** Reliable both ways. |
| 5 | Sign out | **No bubble** on the role-select screen. |
| 6 | Sign out, then press Home | **No bubble** over the launcher. |
| 7 | Log back in | Starts **Offline** — the shift ended with the session. |
| 8 | Go Online → background | No bubble in-app, **bubble appears** once backgrounded. |

Regression check: the camera/gallery chooser still opens correctly after all three rebuilds.

## Cleanup
No stray data: booking `REQ28952905` untouched (`secureBooking: false`), garage back to its original 2 drivers. Emulator signed in as `6354348913`, Online.

Mobile `flutter analyze` — 0 errors, 0 warnings. Backend and admin `tsc --noEmit` — clean.

---
---

# Round 4 — real-flow pass (no seeded data)
Date: 2026-10-27 (later). Every step below was done by driving the app like a user. Nothing was written into MongoDB, no fake rows, no forged webhooks, no role flips.

## Today's uncommitted changes under test
Backend: push-alert note redaction · Aadhaar/DL duplicate guard · admin duplicate-accounts endpoint.
Admin: duplicate warning panel on the Documents tab.
Mobile: camera/gallery chooser (7 screens) · driver-form error routing · KYC copy · requirements reload · bubble lifecycle.
(The wallet/webhook work is already committed as `b32e612`.)

## PASS

**1. Customer number leak — end to end, two real accounts.**
Switched to Customer mode, booked Rajkot → Jamnagar through the normal flow (Places autocomplete, cab list, Review page, Confirm). Booking `CB8757969965` created under Mj Rajput / 6354348913. Signed out, signed in as a *different* real driver (8547963210), opened the Booking feed: the booking shows as **"CUSTOMER · Cabs Booking"** with **no name and no phone number** anywhere on the card.
Also confirmed on the Review page that name and mobile are now their own fields — there is no free-text notes box in the cab flow for a number to leak into.

**2. Aadhaar duplicate — genuinely across two accounts.**
Mj Rajput's garage already held driver "manoj" with Aadhaar `1234 5678 9012` (pre-existing real data). As driver 8547963210, adding a driver with that same Aadhaar was refused:
> *A driver with this Aadhaar number is already registered in another account. Contact support if they work for you.*
The error sat on the **Aadhaar field** (red border) and wrapped across three lines — both of the defects found in round 2 stay fixed.
Changing it to a fresh number cleared the error as soon as typing started, and the driver saved ("Pending admin approval") — no false blocking. The test driver was then **removed through the app's own Remove button**, not the database.

**3. Full KYC journey with the camera.**
On a real unverified account: corrected copy (*"Upload clear front and back photos of both documents…"*), no number fields.
- Submitting with only one photo → *"Upload front and back photos of: Aadhaar Card and Driving License"*.
- Then all **four photos taken with the device camera** (Take Photo → shutter → accept → upload) for Aadhaar front/back and Licence front/back.
- Submit → **"Pending Review — Your documents are under review by our team"**, form locked.

**4. Customer wallet is its own balance.** Customer mode header shows ₹0 while the driver wallet holds ₹31,498, and the customer Settings row reads *"Separate customer balance"*.

**5. Membership gate in real use.** The free-plan driver sees *"Golden membership required to accept"* on the customer booking instead of an Accept button.

**6. Fresh session starts Offline.** After signing in as the second driver the toggle read Offline and no bubble appeared — the round-3 logout fix holding up in a normal sign-in.

## NOT tested — needs your admin login
The **duplicate-accounts warning** on the admin Documents tab is the one change I could not exercise honestly. It needs a real admin session at `localhost:7000`, and I don't have that password. The endpoint itself is in place and correctly guarded (401 without a token, 403 for a non-admin).

You can check it yourself right now: the account **8547963210 ("test")** has a KYC submission **pending review** from step 3 above. Open it in the admin panel → Documents tab.

## Left behind (real records, from real flows)
- Customer booking `CB8757969965` (Rajkot → Jamnagar) — cancel it from My Bookings if you don't want it.
- A pending KYC on 8547963210 — approve or reject it from the admin panel.

Nothing else. The test driver was deleted in-app, and no database rows were written by hand.

---
---

# Round 5 — full service sweep, both sides
Date: 2026-10-27 (later). Driven through the app as a user; nothing written into the database by hand.
Driver account: Mj Rajput / 6354348913 (Golden). Customer side: same account via Switch to Customer.

## DRIVER SIDE

| Service | Result |
|---|---|
| Home | Loads, Offline by default, no bubble, banners + ad carousel, partner phone search |
| **Booking feed** | Loads, vehicle-type filter chips, nav arrow, customer bookings with no contact shown |
| **Available Car — post** | Posted Rajkot → Any, Sedan, 29 Oct through the real form. Appeared in the feed instantly with Call / WhatsApp / User Detail and a GOLDEN USER badge |
| **Available Car — feed** | Empty state before the post, populated after. Ad slot renders |
| **Hire a Driver** | Available + My Offers tabs. Accepted state greyed correctly |
| **My Offers** | PENDING / COMPLETED / CANCELLED, wallet hold shown per card, **View Bill & Invoice** on completed |
| **Car Pooling** | My Pool Rides, Active/Past, seats booked, ₹/seat, Post Ride |
| **Recharge Plans** | Current plan (Golden, valid till 26 Jan 2027, 90 days left), Active + Golden tiers with savings, Feature Comparison |
| **Notifications** | Full lifecycle inbox: vehicle blocked, booking assigned, commission received, trip started/completed, OTP to start and end |
| **My Bookings** | Running / Booked / Assigned, KM badge, nav arrow, earnings split (earning / commission / total), Phone / WhatsApp / Advice / Rating / Report |
| **Chat** | Grouped per booking with unread counts + Direct messages. Thread opens with trip summary, the auto-posted **Driver & Vehicle Details** cards with Share, **and a sent message went through** |
| **Wallet** | ₹31,498 available, ₹520 on hold, Add Money / Pay by QR / Withdraw / Transfer, transaction list |
| **Withdraw** | Bank Account + UPI ID tabs, full form, "held until an admin reviews" note |
| **Transfer** | Recipient lookup by mobile |
| **Post Booking** | Form renders complete (route, stops, trip/vehicle/fuel, date-time, notes, secure toggles) |
| **My Garage** | Vehicles + Drivers tabs with counts, add / edit / remove, approval badges |
| **KYC** | Corrected copy, camera upload, both-documents validation, submits to Pending Review |

## CUSTOMER SIDE

| Service | Result |
|---|---|
| Home | City hero image, wallet chip, notification bell, Cab Booking / Car Pool / Book a Driver, offers carousel |
| **Cab — One Way** | Places autocomplete live, cab list, Cab Details with fuel choice + fare breakdown, Review page, Confirm → booking created |
| **Cab — Round Trip** | Trip Start + **Trip End** both shown, same flow |
| **Cab — Local** | Hourly packages 6 / 8 / 10 / 12 hrs; search returned cabs with "8 hrs · 80 km", extra ₹/km, discount, Fare breakup |
| **Car Pool** | Search by from/to/date. **Found the pool ride posted from the driver side** (Rajkot → Surat, 2 seats, ₹700/seat) — cross-role data flows correctly |
| **Book a Driver** | One Way / Round Trip, start+end date-time, Manual / Automatic, Sedan / SUV, price, Post Request |
| **My Bookings** | Upcoming / Ongoing / History. Upcoming shows Cancel / Edit / Track per booking |
| **Wallet** | ₹0, labelled *"This is your customer wallet — separate from your driver / vendor wallet"*. Withdraw and Transfer correctly disabled at zero balance |
| **Notifications** | Opens and lists |
| Switch roles | Driver ⇄ Customer both ways, no re-login |

## Two things worth a look (neither is from today's changes)

**1. Local package km does not match between the two screens.** The package selector offers *"8 hrs — 96 km"*, but the cab results for that same package say *"8 hrs · 80 km"*. The selector seems to use a flat 12 km/hr estimate while each cab category carries its own included km. A customer picking "96 km" and then being shown 80 km will read that as a bait-and-switch. Worth aligning the selector to the real category figure.

**2. The customer Notifications inbox shows driver notifications.** On an account that is both, the customer side lists "Commission received", "Vehicle blocked", "OTP to start trip" and so on. Harmless for a dual-role user, but if a pure customer ever ends up with driver rows it would be confusing. The inbox is not filtered by role.

## Left behind
One Available Car listing (Rajkot, 29 Oct) posted during this sweep, and one chat message ("test message") in the Rajkot → Mumbai thread. Both are normal records — delete them from the app if you don't want them.

---
---

# Round 6 — driver-switch form + payment check
Date: 2026-10-27 (later).

## 1. Customer → Driver switch now asks what Registration asks

**Before:** someone switching to Driver Mode gave only a city (and an optional business name). They became a driver with **no account type and no KYC at all** — a weaker account than one created through Register, for the same job.

**Now** the form asks for everything Registration does, minus name/mobile (already verified on the account) and the OTP (already signed in):

| Field | Register | Switch (before) | Switch (now) |
|---|---|---|---|
| Profile picture | optional | — | optional |
| Full name / Mobile | typed | read-only | read-only |
| **Account Type** (Driver / Travel Agency) | yes | **—** | **yes** |
| Agency name | only for Travel Agency | always shown | only for Travel Agency |
| **Referral code** | optional | **—** | **optional** |
| City | required | required | required |
| **State** | yes | hidden | **yes** |
| **Aadhaar + Licence, front & back** | **required** | **—** | **required** |

The two forms now share one widget — `mobile/lib/core/widgets/kyc_doc_fields.dart` — and `register_page.dart` was moved onto it as well, so they cannot drift apart again.

**Backend** (`auth.service.switchToDriver`) now also takes `referralCode`. It is applied **only** when the account has never been referred and the code is not their own — switching roles does not make someone a new person, and a referrer is credited once. A bad code is ignored rather than refused, so it can never block the switch.

### Verified through the API on the real account `6777777777` ("Fff")
- `role: customer → travel_agency`, `city`, `state`, `agencyName` all saved, `driverOnboarded: true`.
- Referral applied: `referredBy` set, referrer's `referralCount` 9 → 10.
- **Switching again with a different code did NOT re-credit** — `referredBy` unchanged, count still 10.
- The account was then **restored to customer-only** (role, driverOnboarded, city/state/agency/referredBy cleared, referrer count back to 9) so you can walk the new form yourself.

**Not seen on screen.** The emulator's `adb input text` kept dropping a digit from the OTP (the boxes showed `1 3 4 5 6`), so I could not get that account signed in inside the app to screenshot the form. The code analyzes clean and the APK is installed — open it yourself: sign in as `6777777777` → role screen → **Driver / Vendor**.

## 2. Payment check

| Path | Result |
|---|---|
| Checkout signature — wallet, booking advance, subscription | All three use the correct `HMAC(orderId\|paymentId, keySecret)`. All three are **idempotent** (conditional PENDING→SUCCESS claim) and the wallet one is **ownership-bound** (you cannot verify someone else's order into your wallet) |
| Razorpay **webhook** | Credits wallet top-ups, booking advances and subscriptions. Tested earlier: ₹777 credited once, replayed 3× with no double credit, bad signature rejected |
| Wallet **Add Money** / **Pay by QR** / customer wallet / subscription / booking advance | Order creation all fail locally with *"Authentication failed"* — the local DB holds dummy keys (`RZP_2164…`). Code path is correct; needs real keys to exercise |
| Amount validation | Fires **before** Razorpay: *"Minimum amount to add is ₹100"* |
| **Withdraw** | *"Minimum withdrawal is ₹500"*; *"You can withdraw at most ₹18540."* Bank + UPI forms both present; amount held until an admin reviews |
| **Transfer** | Unknown number → *"No user found with this number"*; self → *"You cannot transfer money to yourself"*; over balance → *"Insufficient balance. You have ₹18540."* |
| **Transfer, real money** | Sent ₹100 between two real accounts: sender 18540 → 18440, recipient 31498 → 31598, both ledger rows written. **Transferred back**, balances restored exactly |

### Still outstanding (not a code problem)
The **Razorpay webhook is not configured in your dashboard**. Until it is, a top-up whose app-side verify call never lands is only rescued by the self-heal on wallet open. Add:
`https://backend.goracabs.com/api/v1/payments/webhook/razorpay` — events `payment.captured` and `qr_code.credited`.

---
---

# Round 7 — cross-check / mismatch audit
Date: 2026-10-27 (later). Compared mobile ↔ backend ↔ admin ↔ web for drift: API paths, fare rules, enums, validation constants.

## Method
- Extracted all 130 API paths the app calls and all 269 backend routes, normalised the `:id`/`${}` segments and diffed them. Same for admin (119 paths) and web.
- Read the web fare engine and the mobile fare engine side by side, rule for rule.
- Grouped the real DB by every enum-ish field to see what is actually stored.
- Compared client-side and server-side validation constants.

## FIXED — 2 real defects

**1. Local package km disagreed between the two screens.**
The package chips showed *"8 hrs — 96 km"* while the results screen priced *"8 hrs · 80 km"*. The customer picked one number and was quoted another.

Cause: `_localKmByHours` (the admin's km table from `/settings`) is filled by `_loadHireRate()`, and that was called **only when `serviceType == 'hire_driver'`**. On the Cab → Local tab it never ran, so the chips fell back to *hours × the cab's km/hour* — 12 × 8 = 96 — while the results page read the real table (8 → 80).

Fixed in `customer_booking_form_page.dart`: the settings fetch now runs for Cab as well as Hire a Driver.
**Verified on screen:** chips now read 60 / 80 / 100 / 120 km, and the results page for the 8-hour package says 80 km. They agree.

**2. The app asked for a subscription route that does not exist.**
`subscription_bloc` called `GET /subscriptions/my`; the backend route is `GET /subscriptions/my-subscription`. Live check: old path **404**, corrected path **200**. Nothing currently dispatches that event, so it was dormant — but it would have 404'd the moment anyone wired it up.
Also removed `approveManualPayment` from `admin/src/lib/api.ts`: it pointed at `/admin/payments/:id/approve`, which the backend does not have (404) and no admin screen used.

## Checked and CLEAN
- **Fare engine, web vs mobile** — every rule matches 1:1: included km, package price, discount, allowance (local 0 / round days×daily / one-way threshold), min km (round dailyKmLimit×days else minBillKm), per-km rate (state → fuel → flat), base fare, toll (never on Best Price or Local), and GST on (net + allowance).
- **API paths** — every other mobile, admin and web path resolves to a real backend route.
- **Phone validation** — `^[6-9]\d{9}$` identically in login, register, customer login, customer register, garage driver, and on the server.
- **Wallet minimums** — deposit / withdrawal / transfer all read the same `/settings` values on both sides, same wording.
- **KYC document keys** — `aadhar` / `drivingLicense` with the same labels in the shared widget, the KYC page and the server's `REQUIRED_DOCS`.
- **Vehicle-type values** — `requirements` and `availableVehicles` are consistently the lowercase enum, and the feed filter matches on it exactly.

## RISKS worth knowing (not fixed — they need your call)

**A. `subType` is free text that four code paths exact-match against display strings.**
The DB already holds six formats for `customerBookings.subType`: `One Way`(48), `Round Trip`(17), `Local`(12), `one_way`(5), `6 Hours`(3), `Hourly`(1), `Sedan`(1), `""`(1).
Meanwhile the web fare engine (`subType === 'Round Trip'` / `'Local'`), the mobile one (same), the backend (`booking.subType === 'Local'`) and the invoice builder all compare against the exact display string, and the DTO validates it only as `@IsString()`.
Today this is harmless — the odd values are all one-way-ish, and one-way is the fall-through. But if any writer ever stores `round_trip`, the fare engine will silently price it as a one-way. Worth either an enum on the DTO or a shared constant both ends import.

**B. `customerBookings.vehicleType` holds cab *category names*, not the vehicle enum** — `Sedan`(35), `sedan`(13), `SRT`(25), `Luxury Sedan`, `Swift`, `SUV`, `""`(10). This is deliberate and documented in `notifyNewCustomerBooking`, and nothing filters on it, so it only affects display. Mentioned so it isn't mistaken for drift later.

**C. Cosmetic:** the web fare engine excludes Local trips from the "minimum km applied" flag; the mobile one does not, so a Local card can show a minimum-applied note that means nothing there.

**D.** `kyc_page.dart` still carries its own copy of the document list and tiles. Its UI genuinely differs (it shows stored images, per-document approval state and locked documents), so it was left alone — but the document list is now defined in three places.
