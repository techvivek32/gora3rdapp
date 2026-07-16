# Quick Reference: What Blocks Profile Editing?

## ✅ FIXED - These NOW Block Profile Editing:

### 1. Account is INACTIVE
```
isActive = false
↓
Error: "Your account is inactive. Please contact support."
```

### 2. Account is BLOCKED
```
isBlocked = true
↓
Error: "Your account is blocked. Please contact support."
```

### 3. Pending Deletion Request
```
deletionRequest.status = "pending"
↓
Error: "Your account deletion is pending. You cannot modify your profile."
```

---

## ❌ These DO NOT Block Profile Editing:

| Field | Value | Can Edit? |
|-------|-------|-----------|
| **Role** | driver, travel_agency, fleet_owner, admin | ✅ YES |
| **Membership** | new, active, verified, premium, golden | ✅ YES |
| **Verification** | none, pending, verified, rejected | ✅ YES |
| **Membership Expired** | membershipExpiresAt < now | ✅ YES |
| **Wallet Balance** | Any amount | ✅ YES |
| **Login Attempts** | Any count | ✅ YES |

---

## How to Check Account Status in Database

```javascript
// Check if account can edit profile
db.users.findOne({ _id: userId }, {
  isActive: 1,
  isBlocked: 1,
  role: 1,
  membershipType: 1,
  verificationStatus: 1
})

// Check for pending deletion
db.accountdeletionrequests.findOne({ 
  userId: userId, 
  status: "pending" 
})
```

---

## Mobile App Error Handling

The mobile app (`profile_page.dart`) already handles these errors:

```dart
if (state is AuthError) {
  setState(() => _loading = false);
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(state.message), backgroundColor: AppColors.error),
  );
}
```

Users will see the error message in a red SnackBar at the bottom of the screen.

---

## Admin Actions to Unblock Users

To allow a blocked/inactive user to edit their profile:

```javascript
// Unblock user
db.users.updateOne(
  { _id: userId },
  { $set: { isBlocked: false, isActive: true } }
)

// Cancel pending deletion
db.accountdeletionrequests.updateOne(
  { userId: userId, status: "pending" },
  { $set: { status: "cancelled" } }
)
```
