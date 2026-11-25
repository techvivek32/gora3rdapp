# Full-system test — 2026-11-23

Everything below ran against a **local** backend (`localhost:7001`), the local
Next.js build of the website (`localhost:7002`) and the Android emulator
(`emulator-5554`, Android 14), on both the **customer** and the **driver** side.
**Production was not touched.** The emulator's app points at `10.0.2.2` (the
host's localhost), verified by reading the installed APK, so nothing it did could
reach the live server either.

Local `backend/.env` already had `WHATSAPP_ACCESS_TOKEN` and `SMS_API_URL` blank,
so no SMS and no WhatsApp message left the machine during any of this.

**Six defects were found and fixed.** Three of them put a different number in
front of the customer than the one on their bill — which is what the client
reported.

---

## 1. The invoice, checked on all 406 of them

The client said the invoices disagree with the bookings, so every completed
booking's PDF was generated through the real API and parsed — not a sample, and
not re-derived from the renderer's own maths.

| | |
|---|---|
| invoices generated | **406** (every completed booking) |
| checks | **6,773** |
| failures, before the fixes | **41** |
| failures, after | **0** |

Three separate defects came out of it.

### 1a. The GST rate printed did not produce the GST amount printed

Straight off booking `CB4172869207`:

```
Driver allowance                                                 500.00
CGST                       6%                                    512.50
SGST                       6%                                    512.50
Total                                                         21,575.00
```

6% of the taxable 20,500 is **1,230**, not 512.50. The tax actually charged was
1,025 — i.e. **5%**, the rate that applied when the booking was made.

The amount came from the booking's own `gstAmount`; the rate label came from
`applyTaxRates()`, which overwrites it with **today's** Pricing Config GST%. GST
was later changed to 12, so every older invoice printed "6% + 6%" over an amount
worked out at 5%. The total was always right; only the rate column lied — and
that is the cell an accountant checks first.

**Fixed** by deriving the printed rate from the tax the invoice states, so the
two columns agree by construction and an old booking keeps printing the rate it
was actually taxed at.

### 1b. Extra km and extra hours were billed below what the driver charged

Two invoices for the same kind of charge:

| booking | on the bill | what the driver charged |
|---|---|---|
| `CB8432224826` (GST recorded) | `Extra 60 km  Rs. 20/km  1,200.00` | 1,200 ✅ |
| `CB1503667681` (no GST recorded) | `Extra 14 km  —  250.00` | 14 × 20 = **280** ❌ |
| `CB4208263333` | `Extra 15 km 200.89` · `Extra 2 hr 267.86` | 225 · 300 ❌ |

On a booking that recorded no GST, the invoice treats the fare as tax-inclusive
and divides **every** taxable line by 1.12 to pull the tax back out. Extra km and
extra hours are measured at trip end and carry **no GST** — the fare engine only
ever taxes the agreed fare — so dividing them understated them, and the same
charge printed two different ways depending on a field the rider never sees. It
also swallowed the per-unit rate, so the rider could not check the row.

**Fixed** by marking the trip-end extras untaxed, like toll and parking already
are. One change, two results: the extras now bill at face value with their rate
shown, and the tax rate goes back to a clean 6% + 6% (it had been printing
5.85% on bookings where the stated GST was being spread across untaxed extras).

```
Extra 14 km   Rs. 20/km     280.00      ← was "250.00" with no rate
Extra 15 km   Rs. 15/km     225.00
Extra 2 hr    Rs. 150/hr    300.00
CGST 6% · SGST 6%                       ← was 5.85% on some bills
```

### 1c. A printed per-km rate that did not multiply out

`CB4894370234` billed `737 km` at `Rs. 99.95/km` for `73,660.00`. 737 × 99.95 is
**73,663.15** — out by ₹3.15 to anyone with a calculator. The guard that is
supposed to prevent exactly this checked the *exact* rate (99.9457) and then
printed the *rounded* one.

**Fixed** by checking the rate as it will be printed. Where it no longer
multiplies out the rate cell is left empty — but the gross and the discount row
stay, so the rider still sees the reduction they were given. (85 invoices show a
discount row; all of them still do.)

---

## 2. The customer and the driver were told different amounts to settle

The largest find, and the most directly customer-facing. One booking,
`CB7596383357`, three screens:

| where | says |
|---|---|
| **Driver** — trip summary | *Amount collected (cash)* **₹12,496** |
| **Customer** — booking details | *Pay **₹11,296** to the driver in cash. GST ₹1,200 is billed by Gora separately* |
| **Invoice** PDF | Total **₹12,496** |

A **₹1,200 gap between what the rider is told to hand over and what the driver
is told to collect**, on every completed booking that carries GST.

The customer screen was still on the old model:

```dart
// The driver collects the GST-free amount in cash; GST goes to Gora separately.
final driverCash = (fare - gst - paid) < 0 ? 0 : (fare - gst - paid);
```

That stopped being true when the GST moved to being taken from the **driver's**
wallet at assignment. The backend, the driver's screen and the invoice were all
updated; this screen was not. The rider pays ₹1,200 short, and the driver — who
already paid that GST out of their own wallet — is the one left out of pocket.

**Fixed**: the customer screen now states the full fare, matching the driver and
the bill.

```
Total Fare        ₹12,496
Cash to driver    ₹12,496
Pay ₹12,496 to the driver in cash. That is the full fare, GST included.
```

Confirmed on the emulator, on the same booking, before and after.

---

## 3. The website never told the rider the extra-km / extra-hour rate

A round trip booked on the site stores `includedKm: 750` and
`extraKmPrice: 20`, and the driver bills past that allowance at trip end. The
site showed "750 km billed" and nothing else — so a rider could agree to
₹77,449, drive 900 km, and meet an `Extra 150 km  Rs. 20/km  3,000.00` line for
the first time on their invoice.

The **app** has said this all along, in its exclusions list
(*"Pay ₹20/km after 750 km"*). The website had not.

**Fixed** on both the fare list and the confirm page:

```
Beyond 750 km: ₹20/km extra.                         (fare list, per cab)
750 km are included. Past that, ₹20/km is added
at the end of the trip, measured by GPS.             (confirm page)
```

---

## 4. A login bug that locks real users out — and then duplicates them

Typing `9876543210` on the app's login screen returned **"This number is not
registered. Please sign up."** for an account that exists.

Accounts created through **Firebase phone auth** are stored as `+919876543210`
(Firebase hands back E.164); accounts created through the **SMS flow** are stored
as the ten digits typed. `sendLoginOtp` matched the string **exactly**, and the
app sends ten digits — so a Firebase-created user could never sign in. In the
local database **600 of 1,026 accounts** are in the `+91` form.

Worse: `ensureUnique` also matched exactly, so the user told to "sign up" **can**
— and ends up with a second account, their wallet and history stranded on the
first. There is already one such duplicate in the local data (`7249000661`).

**Fixed** with one `mobileVariants()` helper used by login, OTP verification, the
duplicate guard and the Firebase path. The emulator confirms it: the exact number
that returned "not registered" now reaches the OTP screen and signs in.

> **Worth checking on production** (read-only, safe) — whether any number already
> has two accounts. The fix stops new ones; it cannot merge existing ones.
> ```js
> db.users.aggregate([
>   {$match:{mobile:{$type:'string',$ne:''}}},
>   {$project:{mobile:1,role:1,walletBalance:1,
>     last10:{$substrBytes:['$mobile',{$subtract:[{$strLenBytes:'$mobile'},10]},10]}}},
>   {$group:{_id:'$last10',n:{$sum:1},docs:{$push:'$$ROOT'}}},
>   {$match:{n:{$gt:1}}}
> ])
> ```

---

## 5. The driver's card contradicted itself (bug #2 on your list)

The booking card showed a bare **₹10000** with, directly beneath it, *"All
Inclusive — Toll, State tax, Car parking, Driver allowance & GST included"*.

₹10000 is the fare **minus** GST (the driver's take-home). The sentence says GST
is **in**. And the customer hands over the full ₹11,200.

**Fixed** — the amount now carries its meaning, on both driver screens:

```
₹ 30838
you keep · collect ₹34539 cash
```

---

## 6. "Add money to accept" (bug #3) — two more holes, found on the device

The earlier fix sends the exact shortfall, labels the button "Add ₹X" and
pre-fills the wallet box. Driving it on the emulator showed it never fired on the
screen drivers actually use:

* **The dialog** — the fix was only wired into the *requirements* feed. The
  *customer-booking* feed has its own copy and still said a plain "Add Money".
* **The server** — `acceptDirect` has *two* wallet gates. The minimum-balance one
  sent the structured error; the one that actually fires (the hold on commission
  + GST) still threw a plain sentence with no `errors` object, so even a patched
  app had nothing to read.

Both fixed. On the emulator the dialog now reads **"Add ₹3201"** (₹3,701 needed,
₹500 held) and the wallet page opens with **3201 already in the box**.

---

## 7. Booking alerts (bug #6) — measured, and it needs your decision

Why some bookings "come to the home screen" and others do not: the **feed** has
no city filter and shows everyone everything, but the **push alert** has three
gates. Counting the local database:

| | drivers / vendors / fleet |
|---|---|
| total | 462 |
| …with the **Alerts** switch on | **17** |
| …**and** an FCM token registered | **4** |

**4 accounts out of 462** can receive a booking alert at all.
`notificationsEnabled` defaults to `false` and the schema comment says that is
deliberate. A driver who never finds that switch sees bookings appear in the
list, hears nothing, and reports it as broken. Being offline is **not** a factor
— the audience query never looks at online status.

**Your call:** default Alerts **ON** for new accounts (and optionally backfill
existing drivers), or keep it opt-in but make the OFF state loud — a banner on
the feed: *"Alerts are off — you will not hear new bookings."* I have not changed
it, because the default is documented as intentional.

---

## What was actually run

| suite | covers | result |
|---|---|---|
| `pull_all.js` + `audit_all.py` | **every** completed booking's invoice vs its booking | **406 invoices, 6,773 checks, 0 fail** |
| `extras_live.js` | a round trip driven 72 km over its package, and a Local run 3 h over its hours — posted, accepted, started, tracked, completed, charged | **25 checks, 0 fail** |
| `audit_extras.py` | those two trips' PDFs: km/hours, rate, amount, tax | **22 checks, 0 fail** |
| `lifecycle.js` | post → accept → wallet hold → select → settle → OTP start → OTP end → trip charges → invoice | **55 checks, 0 fail** |
| `audit_lifecycle.py` | that booking's PDF, customer copy vs driver copy | **13 checks, 0 fail** |
| `accept_gate.js` | both wallet gates return the exact shortfall, and a refusal takes nothing | **12 checks, 0 fail** |
| `login_formats.js` | +91 / plain login, duplicate-signup guard | **10 checks, 0 fail** |
| `web_trips.js` | Round Trip and Local booked on the site, incl. the extra-km / extra-hour fields | **27 checks, 0 fail** |
| `web_booking.js` | homepage → fare list → confirm → booking stored | **20 checks, 0 fail** |
| `flow.js` | homepage cab-only booking box | **17 checks, 0 fail** |
| `prompt_check.js` | app-download prompt | **19 checks, 0 fail** |
| `appmlinks_check.js` | store links on every page | **57 checks, 0 fail** |
| `lightonly_check.js` | light theme on every page | **86 checks, 0 fail** |

### The money, followed end to end

```
website fare list   34,539
confirm page        34,539   (ride 30,000 + toll 334 + allowance 504 + GST 3,701)
stored on booking   34,539
customer app        34,539   ← the web booking shows in My Bookings
driver's card       30,838 you keep · collect 34,539 cash
```

Round trip driven 372 km on a 300 km package at ₹18/km:

```
Extra 72 km   Rs. 18/km   1,296.00     invoice
Extra 72 km @ ₹18/km        ₹1296      customer app
Total Fare                 ₹12,496  =  Cash to driver  ₹12,496  =  invoice total
```

Local 4-hour package run for 7 hours at ₹150/hr — billed as 8 hours, because a
part-hour is charged as a whole hour. That is the documented rule and it matches
how hourly rentals normally bill, but it is worth knowing that **one minute over
costs a full hour**; a grace period would be a product decision, not a bug fix.

Also confirmed along the way: a wrong trip OTP is rejected and the OTP is burned
after use; a toll cannot be added to an All Inclusive fare; trip-end charges
cannot be edited twice; the customer never sees a driver's wallet balance; an
unrelated driver cannot download someone else's invoice; and the customer app's
**Download Invoice** works end to end (`invoice-link` → `invoice-file`, both 200).

---

## Config, not code — worth 2 minutes in the admin panel

* **The company's phone and email are blank on every invoice.** The default
  template ships `phone: ''` and `email: ''`, so a tax invoice goes out with
  "Phone: -". Admin → Invoice Design fixes it.
* **`platformCommissionPercent` is 0** in the local database, so customer
  bookings collect only GST and no commission. `commissionPercent: 19` is a
  *different* setting (the requirements flow). Worth confirming the live value.
* The invoice can also print "Payment Mode" — the backend already composes
  *"Cash Rs. 12,496 — paid directly to the driver"* — but the field is not in the
  default layout, so it never appears. Add it in Invoice Design if you want it.

## Smaller things noticed, not changed

* On a completed booking the customer's only button is **Track**, which is what
  opens the page holding the invoice. A rider looking for their bill would not
  press "Track"; "Details" or "Invoice" would read better.
* The green **COMPLETED** stamp is drawn over the card's route and date, so the
  text under it is hard to read.

## Still open

* **#1 — WhatsApp duty post for 9694991963.** Still not reproducible: 899
  requirements exist and the newest arrived via WhatsApp. Needs one failing
  message with its timestamp.
* **#4 — website account / booking history / booking OTP.** The site is
  guest-only by design; accounts and history are a feature build, not a fix. The
  trip-OTP part is config: `WHATSAPP_OTP_TEMPLATE` and
  `WHATSAPP_INVOICE_TEMPLATE` are missing in production.
* **#6** — the decision in section 7.

## Emulator note

The emulator runs a **debug** build (needed to see the fixes; the release build
predates them). The signed release APK is still at
`mobile/build/app/outputs/flutter-apk/app-release.apk` and can be put back with
`adb uninstall com.taxi.call_taxi_partner` then `adb install`.

Nothing has been committed.
