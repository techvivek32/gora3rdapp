# RC / DL / Aadhaar verification — setup

The app is already built for this. Nothing works until the vendor keys are in,
and until then everything falls back to manual entry — no screen breaks.

## What the user sees

Both forms open as a **centred dialog**, sized to their content and scrolling
inside the box when they outgrow the screen. They do not close on a stray tap
outside — a half-filled form is easy to lose that way — so each has an X.

**Add Vehicle** — the registration number is the only field on the form:

```
Registration Number *
[ GJ01AB1234        ]  [ Fetch ]
  ✓ RC owner: RAJPUT MANOJBHAI K
    Vehicle details fetched — owner name matches

  Type    Sedan Car
  Model   MARUTI SWIFT DZIRE VDI
  Fuel    Petrol
  Seats   5
  Colour  WHITE
  Something wrong? Edit manually
```

Type, model, fuel, seats and colour are not inputs — they are read back from the
RC. If the owner name is not the account holder's, the banner turns red and
**Add Vehicle is refused**, in the app and again on the server.

**Add Driver** — the licence number, and nothing else:

```
🪪  Verify driving licence
    Driving Licence (DL) Number *  [ GJ0120110012345 ]
    [ Fetch ]
    Skip and enter details manually

  Name        RAJPUT MANOJBHAI KANTIBHAI
  Valid till  2031-04-21
  Can drive   LMV, MCWG, TRANS
  RTO         RAJKOT RTO (GJ-03)
  Address     12 Green Park Society, Rajkot, Gujarat 360005
```

Name, address, validity, licence classes and RTO come from the RTO record. An
expired licence turns the card red and says so plainly — it is a warning, not a
block, since admin approval still stands between the driver and a trip.

**About the date of birth.** The RTO lookup keys on licence number *and* date of
birth together — no provider in the market verifies on the number alone, and
that pairing is exactly what stops anyone pulling a stranger's record from a
licence number they happened to see. So it is not a second field on the form:
tapping Fetch opens the date picker once, and from then on the card shows
`Date of birth: 1991-04-22 · Change` as a one-line note.

The phone stays an input: a licence record does not carry one, and it is what
matches a driver to the trips assigned to them.

**Why not DigiLocker.** It needed the driver to have a DigiLocker account, hold
the phone, open a hosted page and clear an OTP. Most drivers do not have one, so
it stalled before it started. The licence lookup asks nothing of the driver — the
vendor types the number and date of birth, the same as the RC.

### When the lookup cannot serve

No keys yet, no record for that number, or the vendor is down: the editable
fields appear with a line saying why, and the form is filled in by hand as
before. There is also a "Skip and enter details manually" link on both forms, so
nobody is ever stuck on a form they cannot finish. Editing an already-saved
vehicle or driver always shows the fields — no one has to re-fetch to fix a
colour.

Until a lookup has run (or manual entry is chosen) the save button stays
disabled, so a vehicle can never be saved as nothing but a number.

## Vendor: Cashfree Secure ID (Verification Suite)

One account covers all three — Vehicle RC, Driving Licence and Smart OCR — which
is why it was chosen over stitching vendors together.

Pricing is **not published**. Cashfree sells it prepaid (buy credits up front) or
postpaid (billed on usage), and points to sales for rates. Ask them for the
per-call rate on *Vehicle RC*, *Driving Licence* and *Smart OCR* specifically;
those are the only three the app calls.

### Sign-up

1. https://www.cashfree.com/kyc-verification/ → sign up / use the existing
   Cashfree merchant account.
2. Enable **Secure ID**, and within it the **Vehicle RC**, **Driving Licence**
   and **Smart OCR** products.
3. Dashboard → Developers → API Keys. Copy the **Client ID** and **Client Secret**.
   Sandbox keys are separate from live keys.

### Put the keys in

Admin → **Settings** → *Vehicle & Driver Verification*:

| Field | Note |
|---|---|
| Client ID | from the dashboard |
| Client Secret | write-only; blank on save keeps the stored one |
| Sandbox mode | leave **on** for test keys, turn **off** for live keys |
| Block name mismatch | leave **off** until tested on real RCs, then turn on |

### Aadhaar — read off the photo, by OCR

The form already asked for an Aadhaar photo, so that photo is now read
automatically the moment it is uploaded. Nothing extra is asked of the driver:

```
  Aadhaar Front  [photo]      Aadhaar Back  [ + ]
  ✓ Aadhaar read - name matches the licence
```

What it does:

- fills the Aadhaar number as `XXXX XXXX 1012` — **only the last 4 are ever
  stored**, the full number is dropped on the server and never reaches the app;
- compares the name on the Aadhaar against the name from the **licence** and
  says so plainly if they are different people;
- flags a photo of a screen, a digitally edited image, blur and glare. That
  fraud check is the real value here — it catches the forged card that a human
  reviewer would wave through.

Both are warnings rather than hard blocks: a bad OCR read on a creased card
should not stop a legitimate driver, and admin approval still stands between
them and a trip.

**Why not eKYC.** There is no low-friction, legal route to *authenticated*
Aadhaar verification for an app like this. **OTP eKYC** needs an AUA/KUA licence,
and since the Supreme Court struck down Section 57 a private company needs a
statutory basis (such as PMLA) to use it at all — a taxi platform does not have
one. **Offline XML / QR** is open to anyone with consent, but the driver has to
download a file from the myAadhaar portal and share a passphrase: the same
friction that sank DigiLocker, for the same reason. OCR asks nothing of the
driver, is legal with consent, and keeps no Aadhaar number on file.

The DL remains the document that is actually verified against a government
database; the Aadhaar OCR is the cross-check on top of it.

There is also **no way to OTP the phone number linked to a DL** — the RTO does
not expose it. The licence is proven by matching the number against the date of
birth instead, which is what stops anyone pulling a stranger's record from a
licence number alone.

## Pointing it somewhere else

`VERIFY_BASE_URL` in the backend environment overrides the vendor host for both
sandbox and live. It is the hook for a staging vendor, for a mock during testing,
and the single place to change if the vendor is ever swapped. Unset in normal use.

## What actually gets billed

Every vendor call costs money, so the same answer is never bought twice. Lookups
are cached for 15 minutes by what identifies them — the registration number, or
the licence number plus date of birth — so:

| The user does | Vendor calls |
|---|---|
| Taps Fetch five times on one registration number | **1** |
| Adds a vehicle with name-match enforcement on | **1** (the server's own check reuses the app's lookup) |
| Taps Fetch repeatedly on one licence | **1** |
| Changes the date of birth and fetches again | 1 more — a different date is a different lookup |
| Uploads an Aadhaar photo | 1 OCR call, each upload (a new image has nothing to reuse) |

So in normal use: **one vehicle = 1 call**, **one driver = 1 DL call + 1 OCR
call** if an Aadhaar photo is attached. These fire when a vehicle or driver is
*added*, not per booking or per trip, so the volume tracks new sign-ups and not
ride traffic.

Before the cache, adding one vehicle cost two RC calls — the app's Fetch and
then the server's owner check on the same number seconds later.

## Name matching

Government records and signup names rarely agree character for character
("RAJPUT MANOJBHAI K" vs "Mj Rajput"), so the comparison is fuzzy by design:
`backend/src/common/utils/name-match.util.ts`. It strips titles, stems the
-bhai/-ben/-kumar suffixes, accepts initials and abbreviations, and allows
transliteration wobble ("rajput"/"rajpoot"). It scores on the shorter name's
words, so an account name that is a subset of the official name passes.

Tested on 13 real-world name shapes — 13/13 correct, including rejecting
"Suresh Kumar" vs "Ramesh Kumar".

## Fail-open, on purpose

If the keys are missing, the vendor is down, or there is no RC record, adding a
vehicle is **allowed**. Treating a failed lookup as a mismatch would lock every
user out of their own garage the moment the vendor had a bad day. Verified by
unit test — 6/6 branches.

## What was tested

Run against a mock vendor shaped like the real API (`VERIFY_BASE_URL` pointed at
it), end to end through the app on an emulator:

| | |
|---|---|
| Name matcher, 13 real-world name shapes | 13/13 |
| Gate branches (enforce on/off x match/mismatch/no-keys/no-record/vendor-down) | 6/6 |
| RC lookup: own vehicle, someone else's, unknown number | all correct |
| Messy input `gj 01 ab 1234` | normalised, matched |
| DL lookup: valid, expired, wrong date of birth, missing date of birth | all correct |
| Licence classes as objects or strings | both flattened correctly |
| Aadhaar OCR: clean read, someone else's card, edited image, photo of a screen, unreadable, no file | all correct |
| Aadhaar number kept | last 4 only — full number never leaves the server |
| Server refuses a mismatched vehicle (enforce on) | HTTP 400 |
| Server allows when vendor is down / no record | HTTP 201 |
| Admin page: loads keys, secret never sent to browser, blank keeps stored, wrong secret rejected | all correct |
| App: one registration number fills type/model/fuel/seats/colour and saves | verified on emulator |

Three defects were found this way and fixed:

1. An unreachable vendor surfaced as "Internal server error" to the driver. Now a
   15-second timeout and a plain "enter the details manually" message.
2. A name mismatch refused the save **silently** - the snackbar does not render
   over the bottom sheet. The Add button is now disabled with the reason, naming
   the actual RC owner, printed directly above it.
3. A failed lookup left the previous vehicle's model, seats and colour in the
   form, showing one car's details under another car's number. Those fields are
   now cleared before each lookup.

## Files

| | |
|---|---|
| `backend/src/modules/verification/` | service, controller, module |
| `backend/src/common/utils/name-match.util.ts` | fuzzy name comparison |
| `backend/src/modules/garage/garage.service.ts` | `assertRcOwnedByUser` server-side gate |
| `backend/src/database/schemas/settings.schema.ts` | `verifyClientId` / `verifyClientSecret` / `verifySandbox` / `verifyEnforceNameMatch` |
| `mobile/.../my_garage_page.dart` | RC Fetch + banner, licence lookup card |
| `admin/.../settings/page.tsx` | credentials card |

Endpoints: `POST /verification/rc`, `POST /verification/dl` and
`POST /verification/ocr` (multipart). For the RC, the
name compared against is always taken from the caller's own account, never from
the request body. The DL has no name gate — the driver is a different person from
the account holder by design.

Switching vendor means editing `verification.service.ts` only — every outbound
call goes through one `post()` helper.
