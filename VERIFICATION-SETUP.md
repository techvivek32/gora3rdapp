# RC / DL / Aadhaar verification — setup

The app is already built for this. Nothing works until the vendor keys are in,
and until then everything falls back to manual entry — no screen breaks.

## What the user sees

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

**Add Driver** — the identity card is the form:

```
🛡  Verify identity (DL + Aadhaar)
    The driver verifies with the OTP sent to their Aadhaar-linked mobile.
    [ Open DigiLocker ]   [ I have verified ]
    Skip and enter details manually

  Name     RAJPUT MANOJBHAI KANTIBHAI
  DL       GJ0120110012345
  Aadhaar  XXXX XXXX 1012
  Address  12 Green Park Society, Rajkot
```

Name, DL, Aadhaar and address come from the record; only the last 4 of the
Aadhaar is ever stored. The phone stays an input — DigiLocker does not carry
one, and it is what matches a driver to the trips assigned to them.

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

One account covers all three — Vehicle RC, Driving Licence and DigiLocker — which
is why it was chosen over stitching two vendors together.

Pricing is **not published**. Cashfree sells it prepaid (buy credits up front) or
postpaid (billed on usage), and points to sales for rates. Ask them for the
per-call rate on *Vehicle RC* and *DigiLocker* specifically; those are the only
two the app calls.

### Sign-up

1. https://www.cashfree.com/kyc-verification/ → sign up / use the existing
   Cashfree merchant account.
2. Enable **Secure ID**, and within it the **Vehicle RC** and **DigiLocker**
   products.
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

### Aadhaar — why DigiLocker and not OTP

Direct Aadhaar OTP eKYC is no longer open to private companies, so there is no
way to send an OTP to an Aadhaar number from our own server. DigiLocker is the
supported route: the OTP happens on DigiLocker's own page, and we read the
verified result back. That also keeps us clear of holding Aadhaar numbers under
the DPDP Act — the app stores only the last 4 digits.

There is also **no way to OTP the phone number linked to a DL**. The RTO does not
expose it. The DL is proven through DigiLocker instead, which is stronger: it
proves the licence *and* that the person holds the Aadhaar-linked phone.

## Pointing it somewhere else

`VERIFY_BASE_URL` in the backend environment overrides the vendor host for both
sandbox and live. It is the hook for a staging vendor, for a mock during testing,
and the single place to change if the vendor is ever swapped. Unset in normal use.

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
| DigiLocker: start, read-too-early, read-after-completion | all correct |
| Aadhaar stored | last 4 only (`XXXX XXXX 1012`) |
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
| `mobile/.../my_garage_page.dart` | RC Fetch + banner, DigiLocker card |
| `admin/.../settings/page.tsx` | credentials card |

Endpoints: `POST /verification/rc`, `/verification/digilocker/start`,
`/verification/digilocker/fetch`. The name compared against is always taken from
the caller's own account, never from the request body.

Switching vendor means editing `verification.service.ts` only — every outbound
call goes through one `post()` helper.
