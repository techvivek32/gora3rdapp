# Profile Editing Issue - Root Cause & Fix

## Problem Summary
Some user accounts could change profile details while others couldn't, with no clear error message or reason.

## Root Cause
The backend `updateProfile` endpoint in `users.service.ts` was **missing permission validation**. It would accept profile update requests from ANY account without checking:
- If the account is **active** (`isActive`)
- If the account is **blocked** (`isBlocked`)
- If the account has a **pending deletion request**

This meant:
- **Blocked accounts** could still modify their profile (shouldn't be allowed)
- **Inactive accounts** could still modify their profile (shouldn't be allowed)
- **Accounts pending deletion** could still modify their profile (shouldn't be allowed)

## Solution Applied
Added three validation checks in the `updateProfile` method before allowing any updates:

```typescript
async updateProfile(userId: string, dto: UpdateProfileDto) {
  // 1. Check if user exists
  const user = await this.userModel.findById(userId).select('isActive isBlocked');
  if (!user) throw new NotFoundException('User not found');
  
  // 2. Check if account is active
  if (!user.isActive) 
    throw new BadRequestException('Your account is inactive. Please contact support.');
  
  // 3. Check if account is blocked
  if (user.isBlocked) 
    throw new BadRequestException('Your account is blocked. Please contact support.');

  // 4. Check if there's a pending deletion request
  const deletionRequest = await this.deletionRequestModel.findOne({ userId, status: 'pending' }).lean();
  if (deletionRequest) {
    throw new BadRequestException('Your account deletion is pending. You cannot modify your profile.');
  }

  // Only then allow the update
  const updated = await this.userModel.findByIdAndUpdate(
    userId,
    { $set: dto },
    { new: true, runValidators: true },
  ).select('-password -refreshToken -fcmTokens');

  return { message: 'Profile updated', data: updated };
}
```

## Files Modified
- `backend/src/modules/users/users.service.ts` - Added permission checks to `updateProfile` method

## Testing
To verify the fix works:

1. **Test with active account** - Should allow profile updates ✓
2. **Test with blocked account** - Should show "Your account is blocked" error
3. **Test with inactive account** - Should show "Your account is inactive" error
4. **Test with pending deletion** - Should show "Your account deletion is pending" error

## Mobile App Impact
The mobile app already handles errors gracefully:
- `profile_page.dart` shows error messages from the backend in a SnackBar
- Users will now see clear messages explaining why they can't edit their profile

## Additional Notes
- The fix is minimal and focused on the actual issue
- Error messages are user-friendly and actionable
- No changes needed to the mobile app - it already handles these error responses
