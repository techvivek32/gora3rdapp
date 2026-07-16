# Account Restrictions - Visual Guide

## Account Status Flow

```
┌─────────────────────────────────────────────────────────────┐
│                    USER ACCOUNT                             │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌──────────────────────────────────────────────────────┐  │
│  │ Account Status Flags                                 │  │
│  ├──────────────────────────────────────────────────────┤  │
│  │ • isActive: true/false                               │  │
│  │ • isBlocked: true/false                              │  │
│  │ • Pending Deletion: true/false                       │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                              │
│  ┌──────────────────────────────────────────────────────┐  │
│  │ Account Type (NO RESTRICTIONS)                       │  │
│  ├──────────────────────────────────────────────────────┤  │
│  │ • Role: driver, travel_agency, fleet_owner, admin   │  │
│  │ • Membership: new, active, verified, premium, golden│  │
│  │ • Verification: none, pending, verified, rejected   │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

---

## Profile Edit Permission Decision Tree

```
                    ┌─────────────────────┐
                    │  Edit Profile       │
                    │  Request Received   │
                    └──────────┬──────────┘
                               │
                    ┌──────────▼──────────┐
                    │ Check: isActive?    │
                    └──────────┬──────────┘
                               │
                ┌──────────────┴──────────────┐
                │                             │
         ┌──────▼──────┐            ┌────────▼────────┐
         │ isActive    │            │ isActive        │
         │ = false     │            │ = true          │
         └──────┬──────┘            └────────┬────────┘
                │                           │
         ┌──────▼──────────────┐    ┌───────▼────────┐
         │ ❌ REJECT           │    │ Check: isBlocked?
         │ "Account inactive"  │    └───────┬────────┘
         └─────────────────────┘            │
                                ┌───────────┴───────────┐
                                │                       │
                         ┌──────▼──────┐      ┌────────▼────────┐
                         │ isBlocked   │      │ isBlocked       │
                         │ = true      │      │ = false         │
                         └──────┬──────┘      └────────┬────────┘
                                │                     │
                         ┌──────▼──────────────┐  ┌───▼──────────────┐
                         │ ❌ REJECT           │  │ Check: Deletion? │
                         │ "Account blocked"   │  └───┬──────────────┘
                         └─────────────────────┘      │
                                            ┌─────────┴─────────┐
                                            │                   │
                                    ┌───────▼────────┐  ┌───────▼────────┐
                                    │ Deletion       │  │ Deletion       │
                                    │ Pending        │  │ Not Pending    │
                                    └───────┬────────┘  └───────┬────────┘
                                            │                   │
                                    ┌───────▼──────────────┐  ┌─▼──────────────┐
                                    │ ❌ REJECT            │  │ ✅ ALLOW       │
                                    │ "Deletion pending"   │  │ Update Profile │
                                    └──────────────────────┘  └────────────────┘
```

---

## Account Type Matrix

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    CAN EDIT PROFILE?                                    │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  USER ROLE                                                              │
│  ├─ driver                    ✅ YES                                    │
│  ├─ travel_agency             ✅ YES                                    │
│  ├─ fleet_owner               ✅ YES                                    │
│  ├─ admin                      ✅ YES                                    │
│  └─ super_admin                ✅ YES                                    │
│                                                                          │
│  MEMBERSHIP TYPE                                                        │
│  ├─ new (Free)                ✅ YES                                    │
│  ├─ active                     ✅ YES                                    │
│  ├─ verified                   ✅ YES                                    │
│  ├─ premium                    ✅ YES                                    │
│  └─ golden                     ✅ YES                                    │
│                                                                          │
│  VERIFICATION STATUS                                                    │
│  ├─ none                       ✅ YES                                    │
│  ├─ pending                    ✅ YES                                    │
│  ├─ verified                   ✅ YES                                    │
│  └─ rejected                   ✅ YES                                    │
│                                                                          │
│  ACCOUNT STATUS                                                         │
│  ├─ isActive = true            ✅ YES                                    │
│  ├─ isActive = false           ❌ NO (Error message shown)              │
│  ├─ isBlocked = false          ✅ YES                                    │
│  ├─ isBlocked = true           ❌ NO (Error message shown)              │
│  ├─ No pending deletion        ✅ YES                                    │
│  └─ Pending deletion           ❌ NO (Error message shown)              │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## Error Message Flow

```
┌──────────────────────────────────────────────────────────────┐
│                  PROFILE UPDATE REQUEST                      │
└────────────────────┬─────────────────────────────────────────┘
                     │
        ┌────────────▼────────────┐
        │ Validation Check 1      │
        │ isActive = false?       │
        └────────────┬────────────┘
                     │
        ┌────────────▼────────────────────────────────────┐
        │ YES: Return Error                              │
        │ {                                              │
        │   "success": false,                            │
        │   "statusCode": 400,                           │
        │   "message": "Your account is inactive.        │
        │              Please contact support."          │
        │ }                                              │
        └────────────────────────────────────────────────┘
                     │
        ┌────────────▼────────────┐
        │ NO: Continue to Check 2 │
        │ isBlocked = true?       │
        └────────────┬────────────┘
                     │
        ┌────────────▼────────────────────────────────────┐
        │ YES: Return Error                              │
        │ {                                              │
        │   "success": false,                            │
        │   "statusCode": 400,                           │
        │   "message": "Your account is blocked.         │
        │              Please contact support."          │
        │ }                                              │
        └────────────────────────────────────────────────┘
                     │
        ┌────────────▼────────────┐
        │ NO: Continue to Check 3 │
        │ Deletion Pending?       │
        └────────────┬────────────┘
                     │
        ┌────────────▼────────────────────────────────────┐
        │ YES: Return Error                              │
        │ {                                              │
        │   "success": false,                            │
        │   "statusCode": 400,                           │
        │   "message": "Your account deletion is         │
        │              pending. You cannot modify        │
        │              your profile."                    │
        │ }                                              │
        └────────────────────────────────────────────────┘
                     │
        ┌────────────▼────────────────────────────────────┐
        │ NO: All Checks Passed                          │
        │ Update Profile & Return Success                │
        │ {                                              │
        │   "success": true,                             │
        │   "statusCode": 200,                           │
        │   "message": "Profile updated",                │
        │   "data": { ... updated user data ... }        │
        │ }                                              │
        └────────────────────────────────────────────────┘
```

---

## Mobile App Error Handling

```
┌─────────────────────────────────────────────────────────┐
│              MOBILE APP (Flutter)                       │
├─────────────────────────────────────────────────────────┤
│                                                          │
│  User clicks "Save Changes"                             │
│         │                                               │
│         ▼                                               │
│  ┌──────────────────────────────────────────────────┐  │
│  │ _EditProfileSheetState._save()                   │  │
│  │ • Validates form                                 │  │
│  │ • Uploads images if needed                       │  │
│  │ • Dispatches UpdateProfileEvent                  │  │
│  └──────────────────────────────────────────────────┘  │
│         │                                               │
│         ▼                                               │
│  ┌──────────────────────────────────────────────────┐  │
│  │ AuthBloc._onUpdateProfile()                      │  │
│  │ • Calls repository.updateProfile()               │  │
│  │ • Listens for response                           │  │
│  └──────────────────────────────────────────────────┘  │
│         │                                               │
│    ┌────┴────┐                                          │
│    │          │                                         │
│    ▼          ▼                                         │
│  SUCCESS    ERROR                                       │
│    │          │                                         │
│    │    ┌─────▼──────────────────────────────────┐    │
│    │    │ AuthError state emitted                │    │
│    │    │ • state.message contains error text    │    │
│    │    └─────┬──────────────────────────────────┘    │
│    │          │                                        │
│    │    ┌─────▼──────────────────────────────────┐    │
│    │    │ BlocListener catches error             │    │
│    │    │ • Shows SnackBar with error message    │    │
│    │    │ • Red background (AppColors.error)     │    │
│    │    └─────┬──────────────────────────────────┘    │
│    │          │                                        │
│    │    ┌─────▼──────────────────────────────────┐    │
│    │    │ User sees error at bottom of screen:   │    │
│    │    │ "Your account is inactive.             │    │
│    │    │  Please contact support."              │    │
│    │    └──────────────────────────────────────┘    │
│    │                                                   │
│    ▼                                                   │
│  ┌──────────────────────────────────────────────────┐  │
│  │ AuthAuthenticated state emitted                  │  │
│  │ • Profile updated in local state                 │  │
│  │ • Shows success SnackBar                         │  │
│  │ • Closes edit sheet                              │  │
│  │ • Refreshes profile display                      │  │
│  └──────────────────────────────────────────────────┘  │
│                                                          │
└─────────────────────────────────────────────────────────┘
```

---

## Database Query Flow

```
┌─────────────────────────────────────────────────────────┐
│              BACKEND (Node.js/NestJS)                   │
├─────────────────────────────────────────────────────────┤
│                                                          │
│  PUT /users/profile                                     │
│  ├─ userId: "507f1f77bcf86cd799439011"                │
│  └─ dto: { fullName, email, agencyName, ... }         │
│         │                                               │
│         ▼                                               │
│  ┌──────────────────────────────────────────────────┐  │
│  │ Query 1: Get user status                         │  │
│  │ db.users.findById(userId)                        │  │
│  │   .select('isActive isBlocked')                  │  │
│  │                                                   │  │
│  │ Result: { isActive: true, isBlocked: false }    │  │
│  └──────────────────────────────────────────────────┘  │
│         │                                               │
│         ▼                                               │
│  ┌──────────────────────────────────────────────────┐  │
│  │ Query 2: Check deletion request                  │  │
│  │ db.accountdeletionrequests.findOne({             │  │
│  │   userId: userId,                                │  │
│  │   status: 'pending'                              │  │
│  │ })                                                │  │
│  │                                                   │  │
│  │ Result: null (no pending deletion)               │  │
│  └──────────────────────────────────────────────────┘  │
│         │                                               │
│         ▼                                               │
│  ┌──────────────────────────────────────────────────┐  │
│  │ Query 3: Update profile                          │  │
│  │ db.users.findByIdAndUpdate(userId, {             │  │
│  │   $set: dto                                       │  │
│  │ }, { new: true })                                │  │
│  │                                                   │  │
│  │ Result: { updated user document }                │  │
│  └──────────────────────────────────────────────────┘  │
│         │                                               │
│         ▼                                               │
│  ┌──────────────────────────────────────────────────┐  │
│  │ Return Success Response                          │  │
│  │ {                                                 │  │
│  │   "success": true,                               │  │
│  │   "message": "Profile updated",                  │  │
│  │   "data": { ... }                                │  │
│  │ }                                                 │  │
│  └──────────────────────────────────────────────────┘  │
│                                                          │
└─────────────────────────────────────────────────────────┘
```

---

## Summary Table

```
┌──────────────────────────────────────────────────────────────────┐
│                    QUICK REFERENCE                               │
├──────────────────────────────────────────────────────────────────┤
│                                                                   │
│  RESTRICTION TYPE          │  BLOCKS EDIT?  │  ERROR MESSAGE    │
│  ─────────────────────────────────────────────────────────────  │
│  isActive = false          │  ✅ YES        │  "Account         │
│                            │                │   inactive"       │
│  ─────────────────────────────────────────────────────────────  │
│  isBlocked = true          │  ✅ YES        │  "Account         │
│                            │                │   blocked"        │
│  ─────────────────────────────────────────────────────────────  │
│  Pending deletion          │  ✅ YES        │  "Deletion        │
│                            │                │   pending"        │
│  ─────────────────────────────────────────────────────────────  │
│  User role                 │  ❌ NO         │  N/A              │
│  ─────────────────────────────────────────────────────────────  │
│  Membership type           │  ❌ NO         │  N/A              │
│  ─────────────────────────────────────────────────────────────  │
│  Verification status       │  ❌ NO         │  N/A              │
│  ─────────────────────────────────────────────────────────────  │
│  Membership expired        │  ❌ NO         │  N/A              │
│  ─────────────────────────────────────────────────────────────  │
│  Wallet balance            │  ❌ NO         │  N/A              │
│                                                                   │
└──────────────────────────────────────────────────────────────────┘
```
