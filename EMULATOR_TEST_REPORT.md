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
