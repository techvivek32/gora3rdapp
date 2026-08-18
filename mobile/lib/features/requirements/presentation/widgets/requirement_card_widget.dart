import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/constants/vehicle_types.dart';
import '../../../../core/localization/app_translations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/contact_launcher.dart';
import '../../../../core/utils/membership.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../users/presentation/widgets/user_card_sheet.dart';

class RequirementCardWidget extends StatelessWidget {
  final Map<String, dynamic> requirement;
  final VoidCallback? onTap;
  // When provided, shown in the top-right (actions menu on My Requirements).
  final Widget? menu;
  // True on the "My Bookings" list — treat as owner.
  final bool mine;

  /// Draw the BOOKED / ON HOLD / CANCELLED stamp (and the dimming that goes with
  /// it). Off on the Assigned tab: every card there is booked by definition, so
  /// the stamp would only obscure the details the driver actually needs.
  final bool showStamp;

  const RequirementCardWidget({
    super.key,
    required this.requirement,
    this.onTap,
    this.menu,
    this.mine = false,
    this.showStamp = true,
  });

  /// The driver this booking was handed to, once the owner has assigned one.
  /// Populated by the backend, so it's a map — not a bare id.
  Map<String, dynamic>? get _assignedDriver {
    final d = requirement['assignedDriver'];
    return d is Map<String, dynamic> ? d : null;
  }

  Widget _buildAssignedDriver(BuildContext context) {
    final d = _assignedDriver!;
    final name = (d['agencyName'] ?? d['fullName'] ?? '').toString().trim();
    final mobile = (d['mobile'] ?? '').toString();

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: const Color(0xFF4CAF50).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: const Color(0xFF4CAF50).withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(Icons.person_pin_circle, size: 20.sp, color: const Color(0xFF2E7D32)),
          SizedBox(width: 8.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Assigned Driver'.tr,
                  style: TextStyle(fontSize: 9.sp, color: Colors.grey[700], fontWeight: FontWeight.w600),
                ),
                Text(
                  name.isEmpty ? mobile : name,
                  style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.bold, color: Colors.black87),
                ),
              ],
            ),
          ),
          if (mobile.isNotEmpty) ...[
            InkWell(
              onTap: () => callNumber(mobile),
              child: Padding(
                padding: EdgeInsets.all(4.r),
                child: Icon(Icons.call, size: 20.sp, color: const Color(0xFF2196F3)),
              ),
            ),
            SizedBox(width: 4.w),
            InkWell(
              onTap: () => openWhatsApp(mobile),
              child: Padding(
                padding: EdgeInsets.all(4.r),
                child: FaIcon(FontAwesomeIcons.whatsapp, size: 18.sp, color: const Color(0xFF25D366)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final postedBy = requirement['postedBy'] as Map<String, dynamic>?;

    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, authState) {
        bool isCurrentUserPremium = false;
        bool isCurrentUserOwner = mine;
        String? currentUserId;
        String? currentUserName;
        String? currentMembership;
        if (authState is AuthAuthenticated) {
          final user = authState.user;
          isCurrentUserPremium = canContactPosters(user);
          currentUserId = user['_id'] as String?;
          currentUserName = user['fullName'] as String?;
          currentMembership = user['membershipType'] as String?;
          final posterId = postedBy?['_id'];
          isCurrentUserOwner = mine || (currentUserId != null && posterId != null && currentUserId == posterId);
        }

        final acceptedByList = List.from(requirement['acceptedBy'] as List? ?? []);
        final hasCurrentUserAccepted = currentUserId != null && acceptedByList.any((id) => id.toString() == currentUserId);
        final isBooked = requirement['status'] == 'accepted';
        final isCancelled = requirement['status'] == 'cancelled';
        final isOnHold = requirement['status'] == 'on_hold';
        // Set when the driver ends the trip — the stamp must come back for it.
        final isCompleted = requirement['status'] == 'completed';
        // Cancelled / booked / on-hold posts are read-only for everyone except the
        // owner (who still manages them from My Requirements via the menu).
        // On the Assigned tab (showStamp: false) the driver is not the owner, but
        // the job is theirs — so it must stay fully readable, not dimmed out.
        final bool locked =
            showStamp && (isCancelled || isBooked || isOnHold || isCompleted) && !isCurrentUserOwner;

        final memberType = (mine ? currentMembership : (postedBy?['membershipType'] as String?)) ?? 'new';
        Color topBarColor;
        String? badgeText;
        if (memberType == 'golden') {
          topBarColor = AppColors.memberGolden;
          badgeText = 'GOLDEN USER';
        } else if (memberType == 'premium') {
          topBarColor = AppColors.memberPremium;
          badgeText = 'PREMIUM USER';
        } else if (memberType == 'active') {
          topBarColor = AppColors.memberActive;
          badgeText = 'ACTIVE USER';
        } else if (memberType == 'verified') {
          topBarColor = AppColors.memberVerified;
          badgeText = 'VERIFIED USER';
        } else {
          topBarColor = AppColors.memberVerified;
          badgeText = 'NEW USER';
        }
        final Color cardBg = topBarColor.withOpacity(0.07);
        final Color badgeColor = topBarColor;
        final Color badgeBg = topBarColor.withOpacity(0.12);

        final (statusLabel, statusColor) = _statusInfo(requirement['status'] as String?);
        final num total = (requirement['totalAmount'] as num?) ?? 0;
        final num driverEarning = (requirement['fare'] as num?) ?? 0;
        final num commission = (requirement['commission'] as num?) ?? 0;
        final bool isAppSuggested = requirement['isAppSuggested'] == true;
        // Hide the fare block for app-suggested cards when the admin turned the
        // "App Suggested Fare" toggle off. Manual (driver-earning) fares still show.
        final bool hideFare = isAppSuggested && !AppConfig.appSuggestedFareEnabled;
        final notes = (requirement['notes'] as String?)?.trim() ?? '';
        final rating = (postedBy?['rating'] as num?)?.toDouble() ?? 0;
        final canContact = isCurrentUserPremium || isCurrentUserOwner;
        // WhatsApp-imported bookings carry the original customer's number in
        // `contactMobile`; the Call / WhatsApp buttons should reach that number.
        // Normal in-app bookings fall back to the poster's own mobile.
        final contactMobile = (requirement['contactMobile'] as String?)?.trim();
        final mobile = (contactMobile != null && contactMobile.isNotEmpty)
            ? contactMobile
            : postedBy?['mobile'] as String?;
        // WhatsApp-imported bookings have no real member profile (the customer
        // isn't a Gora user), so we hide the poster profile on those cards.
        final isWhatsapp = requirement['source'] == 'whatsapp';
        void openSheet() {
          if (postedBy != null) showUserCardSheet(context, Map<String, dynamic>.from(postedBy));
        }

        return GestureDetector(
          onTap: onTap == null || locked
              ? null
              : () {
                  if (isCancelled) return;
                  if (isBooked && !isCurrentUserOwner && !hasCurrentUserAccepted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: const Text('This booking is already booked'), backgroundColor: Colors.red[700], duration: const Duration(seconds: 2)),
                    );
                    return;
                  }
                  onTap!();
                },
          child: Container(
            margin: EdgeInsets.symmetric(horizontal: 2.w, vertical: 6.h),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(10.r),
              border: Border.all(color: topBarColor.withOpacity(0.3), width: 1),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 1))],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10.r),
              child: Stack(
                children: [
                  Positioned.fill(child: IgnorePointer(child: CustomPaint(painter: _WatermarkPainter()))),
                  // Dim + block interaction on read-only (cancelled/booked/hold) cards.
                  Opacity(
                    opacity: locked ? 0.2 : 1.0,
                    child: AbsorbPointer(
                      absorbing: locked,
                      child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 4.h,
                        decoration: BoxDecoration(color: topBarColor, borderRadius: BorderRadius.vertical(top: Radius.circular(10.r))),
                      ),
                      Padding(
                        padding: EdgeInsets.all(12.r),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header: status (Open) + requirement ID, trip type / secure on the right
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: EdgeInsets.only(top: 4.h),
                                  child: Icon(Icons.circle, size: 10.sp, color: statusColor),
                                ),
                                SizedBox(width: 8.w),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(statusLabel.tr, style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w700, color: statusColor)),
                                      Text('ID-${requirement['requirementId'] ?? requirement['bookingId'] ?? ''}',
                                          style: TextStyle(fontSize: 11.sp, color: Colors.grey[600], fontWeight: FontWeight.w600)),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    if (menu != null) ...[
                                      menu!,
                                      SizedBox(height: 6.h),
                                    ],
                                    _chip((requirement['tripType'] as String? ?? '').replaceAll('_', ' ').toUpperCase().tr, topBarColor, filled: true),
                                    if (requirement['tripType'] == 'round_trip')
                                      Builder(builder: (_) {
                                        final d = _roundTripDays(requirement['travelDate'], requirement['returnDate']);
                                        if (d.isEmpty) return const SizedBox.shrink();
                                        return Padding(
                                          padding: EdgeInsets.only(top: 4.h),
                                          child: Text(d, style: TextStyle(fontSize: 10.sp, fontWeight: FontWeight.w700, color: topBarColor)),
                                        );
                                      }),
                                  ],
                                ),
                              ],
                            ),
                            SizedBox(height: 10.h),
                            Divider(height: 1, color: Colors.black26),
                            SizedBox(height: 10.h),

                            // 3. Vertical route: FROM -> stops -> TO
                            Builder(builder: (context) {
                              final rawStops = requirement['stops'];
                              // Keep only well-formed stop entries (maps with an address).
                              final stops = rawStops is List
                                  ? rawStops.whereType<Map>().where((m) => (m['address'] ?? '').toString().trim().isNotEmpty).toList()
                                  : const <Map>[];

                              Widget point(IconData icon, Color color, String label, String text, {required bool showLine, String? legInfo}) {
                                return IntrinsicHeight(
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Column(
                                        children: [
                                          Icon(icon, size: 14.sp, color: color),
                                          if (showLine)
                                            Expanded(
                                              child: Container(
                                                width: 2,
                                                margin: EdgeInsets.symmetric(vertical: 2.h),
                                                color: Colors.grey.shade400,
                                              ),
                                            ),
                                        ],
                                      ),
                                      SizedBox(width: 10.w),
                                      Expanded(
                                        child: Padding(
                                          padding: EdgeInsets.only(bottom: showLine ? 10.h : 0),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              // Label line, e.g. "STOP 1 | 94 km takes 1:34 hrs".
                                              Text(legInfo == null ? label : '$label  |  $legInfo',
                                                  style: TextStyle(fontSize: 9.sp, color: Colors.grey[600], fontWeight: FontWeight.w600)),
                                              Text(text,
                                                  maxLines: 2,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.bold, color: Colors.black)),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }

                              final fromCoord = requirement['pickupCoordinates'];
                              final dropCoord = requirement['dropCoordinates'];
                              // The ROAD distance stored at creation (Google Directions) is the source of
                              // truth — it matches Google Maps. Straight-line (haversine) badly
                              // underestimates (e.g. 96 vs 154 km on the road), so only fall back
                              // to it when no road distance was stored. Per-leg labels are
                              // straight-line, so scale them by road/straight to stay consistent.
                              final roadKm = (requirement['estimatedDistance'] is num && (requirement['estimatedDistance'] as num) > 0)
                                  ? (requirement['estimatedDistance'] as num).toDouble()
                                  : null;
                              final straightSum = _straightSumKm(fromCoord, stops, dropCoord);
                              final legScale = (roadKm != null && straightSum != null && straightSum > 0)
                                  ? roadKm / straightSum
                                  : 1.0;
                              final timeline = Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  point(Icons.trip_origin, Colors.green, 'FROM', requirement['pickupCity'] as String? ?? '', showLine: true),
                                  ...stops.asMap().entries.map((e) {
                                    // Distance from the previous point (pickup or prior stop) to this stop.
                                    final prev = e.key == 0 ? fromCoord : stops[e.key - 1];
                                    return point(Icons.add_location_alt, topBarColor, 'STOP ${e.key + 1}', (e.value['address'] ?? '').toString(),
                                        showLine: true, legInfo: _legInfo(prev, e.value, scale: legScale));
                                  }),
                                  point(Icons.location_on, Colors.red, 'TO', requirement['dropCity'] as String? ?? '',
                                      showLine: false,
                                      legInfo: stops.isNotEmpty ? _legInfo(stops.last, dropCoord, scale: legScale) : null),
                                ],
                              );

                              // Prefer the stored road distance; only sum straight-line legs
                              // when there is no road distance to show.
                              final totalKm = roadKm != null
                                  ? roadKm.toStringAsFixed(0)
                                  : _totalRouteKm(fromCoord, stops, dropCoord);
                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  // Total distance, vertical, on the left of the route.
                                  if (totalKm != null) ...[
                                    RotatedBox(
                                      quarterTurns: 3,
                                      child: Text('$totalKm KM',
                                          style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.bold, color: topBarColor)),
                                    ),
                                    SizedBox(width: 8.w),
                                  ],
                                  Expanded(child: timeline),
                                ],
                              );
                            }),
                            SizedBox(height: 4.h),
                            Divider(height: 1, color: Colors.black26),
                            SizedBox(height: 4.h),

                            // 4. vehicle + date/time box
                            Row(
                              children: [
                                Icon(Icons.directions_car, size: 18.sp, color: topBarColor),
                                SizedBox(width: 8.w),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(_formatVehicleType(requirement['vehicleType']), style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.bold, color: Colors.black)),
                                      Text(_formatFuel(requirement['fuelType']), style: TextStyle(fontSize: 11.sp, color: Colors.grey[600])),
                                      Text('Carrier Does Not Matter'.tr, style: TextStyle(fontSize: 11.sp, color: Colors.grey[600])),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
                                  decoration: BoxDecoration(color: topBarColor, borderRadius: BorderRadius.circular(8.r)),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      Text(_formatDate(requirement['travelDate']), style: TextStyle(fontSize: 22.sp, fontWeight: FontWeight.bold, color: Colors.white)),
                                      Text(_formatTime12(requirement['travelTime']), style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600, color: Colors.white)),
                                    ],
                                  ),
                                ),
                              ],
                            ),

                            // 5. notes — hidden on WhatsApp cards (the "Booked via
                            // WhatsApp (+number)" note is noise there).
                            if (notes.isNotEmpty && !isWhatsapp) ...[
                              SizedBox(height: 10.h),
                              Divider(height: 1, color: Colors.black26),
                              SizedBox(height: 10.h),
                              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Icon(Icons.chat_bubble, size: 16.sp, color: topBarColor),
                                SizedBox(width: 8.w),
                                Expanded(child: Text(notes, style: TextStyle(fontSize: 13.sp, color: Colors.black87))),
                              ]),
                            ],

                            SizedBox(height: 4.h),
                            Divider(height: 1, color: Colors.black26),
                            SizedBox(height: 4.h),

                            // 6. pricing — app-suggested shows a single fare line;
                            // a custom fare shows the full 3-column breakdown.
                            // The whole block is hidden when the admin turned off
                            // "App Suggested Fare" and this is an app-suggested card.
                            if (!hideFare) ...[
                            if (isAppSuggested)
                              Padding(
                                padding: EdgeInsets.symmetric(vertical: 2.h),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text('App Suggested Fare'.tr,
                                        style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w600, color: topBarColor)),
                                    Icon(Icons.auto_awesome, size: 15.sp, color: topBarColor),
                                    SizedBox(width: 4.w),
                                    Text('₹${total.round()}', style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.bold, color: Colors.black)),
                                    SizedBox(width: 8.w),
                                  ],
                                ),
                              )
                            else
                              IntrinsicHeight(
                                child: Row(
                                  children: [
                                    Expanded(child: _priceCol(Icons.person, "Driver's Earning", driverEarning, topBarColor)),
                                    VerticalDivider(width: 1, color: Colors.black26),
                                    Expanded(child: _priceCol(Icons.percent, 'Commission', commission, topBarColor)),
                                    VerticalDivider(width: 1, color: Colors.black26),
                                    Expanded(child: _priceCol(Icons.account_balance_wallet, 'Total Amount', total, topBarColor)),
                                  ],
                                ),
                              ),
                            SizedBox(height: 6.h),
                            Divider(height: 1, color: Colors.black26),
                            SizedBox(height: 2.h),
                            ],

                            // 6b. Views — how many distinct users have seen this booking.
                            Center(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.remove_red_eye, size: 15.sp, color: Colors.grey[700]),
                                  SizedBox(width: 6.w),
                                  Text('${requirement['viewCount'] ?? 0} views',
                                      style: TextStyle(fontSize: 12.sp, color: Colors.grey[700], fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                            SizedBox(height: 2.h),
                            Divider(height: 1, color: Colors.black26),
                            SizedBox(height: 10.h),

                            // 7. poster — only shown to premium members / the owner.
                            if (canContact) ...[
                              Row(
                                children: [
                                  if (isWhatsapp) ...[
                                    Expanded(
                                      child: Text('Duty Booking',
                                          style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.bold, color: Colors.black)),
                                    ),
                                  ] else ...[
                                  GestureDetector(
                                    onTap: postedBy == null ? null : openSheet,
                                    child: CircleAvatar(
                                      radius: 20.r,
                                      backgroundColor: topBarColor.withOpacity(0.12),
                                      backgroundImage: postedBy?['profileImage'] != null ? NetworkImage(postedBy!['profileImage'] as String) : null,
                                      child: postedBy?['profileImage'] == null ? Icon(Icons.emoji_events, color: topBarColor, size: 20.sp) : null,
                                    ),
                                  ),
                                  SizedBox(width: 10.w),
                                  Expanded(
                                    child: GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onTap: postedBy == null ? null : openSheet,
                                      child: Builder(builder: (_) {
                                        final agency = (postedBy?['agencyName'] as String?)?.trim() ?? '';
                                        final full = (postedBy?['fullName'] as String?) ?? (mine ? (currentUserName ?? 'You') : 'User');
                                        // Agency name on top (bold); person's name (+ city/state) below.
                                        final topName = agency.isNotEmpty ? agency : full;
                                        final belowParts = <String>[
                                          if (agency.isNotEmpty) full,
                                          ...[postedBy?['city'], postedBy?['state']]
                                              .where((e) => e != null && (e as String).trim().isNotEmpty)
                                              .cast<String>(),
                                        ];
                                        return Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(children: [
                                              Flexible(child: Text(topName, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.bold, color: Colors.black))),
                                              if ((postedBy?['isVerified'] == true) || memberType == 'verified' || memberType == 'golden') ...[
                                                SizedBox(width: 4.w),
                                                Icon(Icons.verified, size: 14.sp, color: const Color(0xFF2196F3)),
                                              ],
                                            ]),
                                            if (belowParts.isNotEmpty)
                                              Text(
                                                belowParts.join(', '),
                                                maxLines: 1, overflow: TextOverflow.ellipsis,
                                                style: TextStyle(fontSize: 11.sp, color: Colors.grey[600]),
                                              ),
                                          ],
                                        );
                                      }),
                                    ),
                                  ),
                                  ],
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      if (_timeAgo(requirement['createdAt']).isNotEmpty)
                                        Padding(
                                          padding: EdgeInsets.only(bottom: 3.h),
                                          child: Text(_timeAgo(requirement['createdAt']),
                                              style: TextStyle(fontSize: 9.sp, color: Colors.grey[600])),
                                        ),
                                      // Member badge (ACTIVE USER etc.) — hidden on
                                      // WhatsApp cards; the poster isn't the customer.
                                      if (!isWhatsapp)
                                        Container(
                                          padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                                          decoration: BoxDecoration(color: badgeBg, borderRadius: BorderRadius.circular(4.r), border: Border.all(color: badgeColor)),
                                          child: Text(badgeText.tr, style: TextStyle(fontSize: 8.sp, color: badgeColor, fontWeight: FontWeight.w600)),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                              SizedBox(height: 12.h),
                              Divider(height: 1, color: Colors.black26),
                              SizedBox(height: 10.h),
                            ],

                            // 7b. assigned driver (owner assigned this booking to them)
                            if (_assignedDriver != null) ...[
                              _buildAssignedDriver(context),
                              SizedBox(height: 10.h),
                            ],

                            // 8. actions (gated)
                            if (canContact)
                              isWhatsapp
                                  // Duty/WhatsApp cards: big filled Call + WhatsApp buttons.
                                  ? Row(
                                      children: [
                                        Expanded(
                                          child: _filledContactButton(
                                            const Icon(Icons.call, color: Colors.white, size: 20),
                                            'Call',
                                            topBarColor,
                                            (mobile != null && mobile.isNotEmpty) ? () => callNumber(mobile) : null,
                                          ),
                                        ),
                                        SizedBox(width: 10.w),
                                        Expanded(
                                          child: _filledContactButton(
                                            const FaIcon(FontAwesomeIcons.whatsapp, color: Colors.white, size: 20),
                                            'WhatsApp',
                                            topBarColor,
                                            (mobile != null && mobile.isNotEmpty)
                                                ? () => openWhatsApp(mobile, message: _buildWhatsAppMessage())
                                                : null,
                                          ),
                                        ),
                                      ],
                                    )
                                  : Row(
                                      children: [
                                        _action(const Icon(Icons.call, color: Color(0xFF2196F3), size: 28), 'Phone', () {
                                          if (mobile != null && mobile.isNotEmpty) {
                                            callNumber(mobile);
                                          } else {
                                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Contact number not available'.tr)));
                                          }
                                        }),
                                        _action(const FaIcon(FontAwesomeIcons.whatsapp, color: Color(0xFF25D366), size: 28), 'Whatsapp', () {
                                          if (mobile != null && mobile.isNotEmpty) {
                                            openWhatsApp(mobile, message: _buildWhatsAppMessage());
                                          } else {
                                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Contact number not available'.tr)));
                                          }
                                        }),
                                        _action(Icon(Icons.notifications_active, color: Colors.amber.shade700, size: 28), 'Advice',
                                            () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Don't pay without reference!")))),
                                        _ratingAction(rating),
                                        _action(Icon(Icons.report, color: Colors.red.shade400, size: 28), 'Report',
                                            postedBy?['_id'] == null
                                                ? null
                                                : () => context.push('/users/${postedBy!['_id']}', extra: {...postedBy, '__openReport': true})),
                                      ],
                                    )
                            else
                              GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () => context.push('/subscriptions'),
                                child: SizedBox(
                                  width: double.infinity,
                                  child: Text('Become a premium member to contact immediately'.tr,
                                      textAlign: TextAlign.center, style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w600, color: Colors.red)),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                      ),
                    ),
                  ),
                  if (showStamp && (isBooked || isCancelled || isOnHold || isCompleted))
                    Positioned.fill(
                      child: IgnorePointer(
                        child: Center(
                          child: Transform.rotate(
                            angle: -0.2,
                            child: _buildStampBadge(
                              text: isCancelled
                                  ? 'CANCELLED'
                                  : isCompleted
                                      ? 'COMPLETED'
                                      : isOnHold
                                          ? 'ON HOLD'
                                          : hasCurrentUserAccepted
                                              ? 'ACCEPTED'
                                              : 'BOOKED',
                              color: isCancelled
                                  ? Colors.grey[600]!
                                  : isCompleted
                                      ? Colors.green[700]!
                                      : isOnHold
                                          ? Colors.orange[800]!
                                          : hasCurrentUserAccepted
                                              ? Colors.green[700]!
                                              : Colors.red[700]!,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _chip(String text, Color color, {bool filled = false}) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: filled ? color.withOpacity(0.12) : Colors.grey[100],
        borderRadius: BorderRadius.circular(8.r),
        border: filled ? Border.all(color: color.withOpacity(0.5)) : null,
      ),
      child: Text(text, style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w700, color: filled ? color : Colors.grey[700])),
    );
  }

  Widget _priceCol(IconData icon, String label, num amount, Color color) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('₹${amount.round()}', style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.bold, color: Colors.black)),
        SizedBox(height: 2.h),
        Text(label.tr, textAlign: TextAlign.center, style: TextStyle(fontSize: 10.sp, color: Colors.grey[600])),
      ],
    );
  }

  // Big filled Call / WhatsApp button used on Duty (WhatsApp) cards.
  Widget _filledContactButton(Widget icon, String label, Color bg, VoidCallback? onTap) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: icon,
      label: Text(label,
          style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w700, color: Colors.white, fontFamily: 'Poppins')),
      style: ElevatedButton.styleFrom(
        backgroundColor: onTap == null ? Colors.grey : bg,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: EdgeInsets.symmetric(vertical: 11.h),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
      ),
    );
  }

  Widget _action(Widget icon, String label, VoidCallback? onTap) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            icon,
            SizedBox(height: 5.h),
            Text(label.tr, style: TextStyle(fontSize: 12.sp, color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }

  Widget _ratingAction(double rating) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.star, size: 22.sp, color: Colors.amber),
            SizedBox(width: 2.w),
            Text(rating > 0 ? rating.toStringAsFixed(1) : '—', style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold, color: Colors.black)),
          ]),
          SizedBox(height: 5.h),
          Text('Rating', style: TextStyle(fontSize: 12.sp, color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  (String, Color) _statusInfo(String? status) {
    switch (status) {
      case 'accepted':
        return ('Booked', Colors.red.shade600);
      case 'completed':
        return ('Completed', Colors.green.shade700);
      case 'on_hold':
        return ('On Hold', Colors.orange.shade700);
      case 'cancelled':
        return ('Cancelled', Colors.grey.shade600);
      default:
        return ('Open', Colors.green.shade600);
    }
  }

  // Inclusive day count between travel and return dates, e.g. 30 Jun -> 2 Jul = "3 days".
  String _roundTripDays(dynamic travel, dynamic ret) {
    final t = DateTime.tryParse(travel?.toString() ?? '');
    final r = DateTime.tryParse(ret?.toString() ?? '');
    if (t == null || r == null) return '';
    final days = DateTime(r.year, r.month, r.day).difference(DateTime(t.year, t.month, t.day)).inDays + 1;
    if (days < 1) return '';
    return '$days day${days == 1 ? '' : 's'}';
  }

  Widget _buildStampBadge({required String text, required Color color}) {
    // No background fill — the stamp reads as ink pressed straight onto the card.
    return SizedBox(
      width: 150.w,
      height: 150.w,
      child: CustomPaint(
        painter: _StampRingPainter(color: color, topText: text, bottomText: 'GORA TAXI PARTNER'),
        // Keep the whole centre block inside the inner circle, whatever the status
        // word's length ("CANCELLED" is much wider than "BOOKED").
        child: Center(
          child: SizedBox(
            width: 94.w,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.star, color: color, size: 12.sp),
                    SizedBox(width: 3.w),
                    Icon(Icons.star, color: color, size: 12.sp),
                    SizedBox(width: 3.w),
                    Icon(Icons.star, color: color, size: 12.sp),
                  ]),
                  SizedBox(height: 4.h),
                  Text(text, style: TextStyle(color: color, fontSize: 19.sp, fontWeight: FontWeight.w900, letterSpacing: 2)),
                  SizedBox(height: 4.h),
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.star, color: color, size: 12.sp),
                    SizedBox(width: 3.w),
                    Icon(Icons.star, color: color, size: 12.sp),
                    SizedBox(width: 3.w),
                    Icon(Icons.star, color: color, size: 12.sp),
                  ]),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _formatVehicleType(String? type) => type == null ? '' : vehicleTypeLabel(type);

  String _tripLabel(dynamic t) {
    switch ((t ?? '').toString()) {
      case 'one_way':
        return 'One Way Trip';
      case 'round_trip':
        return 'Round Trip';
      default:
        return '${(t ?? '').toString().replaceAll('_', ' ').split(' ').where((w) => w.isNotEmpty).map((w) => '${w[0].toUpperCase()}${w.substring(1)}').join(' ')} Trip';
    }
  }

  /// "2026-07-16" → "16-07-26"
  String _shortDate(dynamic date) {
    if (date == null) return '';
    final raw = date.toString();
    final datePart = raw.contains('T') ? raw.split('T').first : raw;
    final p = datePart.split('-');
    if (p.length == 3 && p[0].length == 4) return '${p[2]}-${p[1]}-${p[0].substring(2)}';
    return datePart;
  }

  /// "154 KMs / 3 Hrs" — sums the pickup→stops→drop legs, falling back to the
  /// stored estimatedDistance when coordinates are missing.
  String? _routeSummary(dynamic from, List stops, dynamic to) {
    // Prefer the stored road distance (Google Directions); only fall back to the
    // straight-line sum when no road distance is available.
    final est = requirement['estimatedDistance'];
    final sum = (est is num && est > 0) ? est.toDouble() : _straightSumKm(from, stops, to);
    if (sum == null || sum <= 0) return null;
    final hrs = (sum / 50).round(); // same ~50 km/h estimate the card's leg labels use
    return '${sum.toStringAsFixed(0)} KMs / $hrs Hrs';
  }

  /// The whole requirement, formatted for sharing over WhatsApp.
  String _buildWhatsAppMessage() {
    final postedBy = requirement['postedBy'] as Map<String, dynamic>?;
    final rawStops = requirement['stops'];
    final stops = rawStops is List
        ? rawStops.whereType<Map>().where((m) => (m['address'] ?? '').toString().trim().isNotEmpty).toList()
        : const <Map>[];

    final b = StringBuffer();
    b.writeln('📢 *Booking*');
    b.writeln('*Gora Taxi Partner App*');
    b.writeln();

    final id = requirement['requirementId'] ?? requirement['bookingId'];
    if (id != null) b.writeln('🆔 *ID:* $id');
    b.writeln('🚖 *Trip:* ${_tripLabel(requirement['tripType'])}');
    b.writeln('🚗 *Vehicle:* ${_formatVehicleType(requirement['vehicleType'] as String?)}');
    b.writeln('⛽ *Fuel:* ${_formatFuel(requirement['fuelType'])}');
    b.writeln();

    b.writeln('*📍Location point*');
    b.writeln(' *From:* ${requirement['pickupCity'] ?? ''}');
    for (var i = 0; i < stops.length; i++) {
      b.writeln(' *Stop ${i + 1}:* ${stops[i]['address']}');
    }
    b.writeln(' *To:* ${requirement['dropCity'] ?? ''}');
    b.writeln();

    b.writeln('📅 *Date:* ${_shortDate(requirement['travelDate'])}');
    b.writeln('🕒 *Time:* ${_formatTime12(requirement['travelTime'])}');
    if (requirement['tripType'] == 'round_trip' && requirement['returnDate'] != null) {
      b.writeln('🔁 *Return:* ${_shortDate(requirement['returnDate'])} ${_formatTime12(requirement['returnTime'])}');
    }
    final route = _routeSummary(requirement['pickupCoordinates'], stops, requirement['dropCoordinates']);
    if (route != null) b.writeln('⌛ *Distance:* $route');
    b.writeln();

    final num total = (requirement['totalAmount'] as num?) ?? 0;
    if (total > 0) {
      b.writeln('💰 *Fare:* ₹${total.round()}');
      b.writeln();
    }

    final notes = (requirement['notes'] as String?)?.trim() ?? '';
    if (notes.isNotEmpty) {
      b.writeln('📝 *Other Information:*');
      b.writeln(notes);
      b.writeln();
    }

    // WhatsApp/Duty bookings have no real poster profile (the customer isn't a
    // Gora member), so skip the "Posted By" section for them.
    if (postedBy != null && requirement['source'] != 'whatsapp') {
      b.writeln('📞 *Posted By*');
      final agency = (postedBy['agencyName'] as String?)?.trim() ?? '';
      final name = (postedBy['fullName'] as String?)?.trim() ?? '';
      final phone = (postedBy['mobile'] as String?)?.trim() ?? '';
      if (agency.isNotEmpty) b.writeln('🏢 $agency');
      if (name.isNotEmpty) b.writeln('👤 *$name*');
      if (phone.isNotEmpty) b.writeln('📱 *$phone*');
      if (postedBy['isVerified'] == true) b.writeln('✅ Verified Gora Taxi PARTNER Member');
      b.writeln();
    }

    b.writeln('You can also book your taxi from Gora Taxi Partner App and register your vehicle from the below link');
    b.write('https://play.google.com/store/apps/details?id=com.taxi.call_taxi_partner');
    return b.toString();
  }

  double? _coordLat(dynamic m) => m is Map ? (m['lat'] as num?)?.toDouble() : null;
  double? _coordLng(dynamic m) => m is Map ? (m['lng'] as num?)?.toDouble() : null;

  /// Straight-line (Haversine) km between two coord maps, or null if missing.
  double? _haversineKm(dynamic a, dynamic b) {
    final la = _coordLat(a), lna = _coordLng(a), lb = _coordLat(b), lnb = _coordLng(b);
    if (la == null || lna == null || lb == null || lnb == null) return null;
    const r = 6371.0;
    final dLat = (lb - la) * (pi / 180);
    final dLng = (lnb - lna) * (pi / 180);
    final h = sin(dLat / 2) * sin(dLat / 2) +
        cos(la * (pi / 180)) * cos(lb * (pi / 180)) * sin(dLng / 2) * sin(dLng / 2);
    return 2 * r * atan2(sqrt(h), sqrt(1 - h));
  }

  /// Total route distance = sum of pickup→stops→drop legs, so it always matches
  /// the per-leg labels. Falls back to the stored estimatedDistance when the
  /// coordinates needed to sum the legs aren't available.
  String? _totalRouteKm(dynamic from, List stops, dynamic to) {
    return _straightSumKm(from, stops, to)?.toStringAsFixed(0);
  }

  /// Straight-line (haversine) total across pickup→stops→drop in km. Null if any
  /// coordinate is missing so the sum can't be trusted.
  double? _straightSumKm(dynamic from, List stops, dynamic to) {
    final points = <dynamic>[from, ...stops, to];
    double sum = 0;
    for (var i = 0; i < points.length - 1; i++) {
      final leg = _haversineKm(points[i], points[i + 1]);
      if (leg == null) return null;
      sum += leg;
    }
    return sum > 0 ? sum : null;
  }

  /// Straight-line (Haversine) distance + estimated drive time between two coord
  /// maps, formatted as "94 km takes 1:34 hrs". Null if coords are missing.
  String? _legInfo(dynamic a, dynamic b, {double scale = 1.0}) {
    final la = _coordLat(a), lna = _coordLng(a), lb = _coordLat(b), lnb = _coordLng(b);
    if (la == null || lna == null || lb == null || lnb == null) return null;
    const r = 6371.0; // earth radius km
    final dLat = (lb - la) * (pi / 180);
    final dLng = (lnb - lna) * (pi / 180);
    final h = sin(dLat / 2) * sin(dLat / 2) +
        cos(la * (pi / 180)) * cos(lb * (pi / 180)) * sin(dLng / 2) * sin(dLng / 2);
    // Straight-line km, scaled to approximate the road distance so the per-leg
    // labels sum to the same road total shown for the whole trip.
    final km = 2 * r * atan2(sqrt(h), sqrt(1 - h)) * scale;
    // Estimated drive time at ~50 km/h average.
    const avgSpeed = 50.0;
    final totalMin = (km / avgSpeed * 60).round();
    final hrs = totalMin ~/ 60;
    final mins = totalMin % 60;
    return '${km.toStringAsFixed(0)} km takes $hrs:${mins.toString().padLeft(2, '0')} hrs';
  }

  String _formatFuel(dynamic type) {
    final t = (type ?? 'any').toString().toLowerCase();
    switch (t) {
      case 'diesel':
        return 'Diesel';
      case 'petrol':
        return 'Petrol';
      case 'cng':
        return 'CNG';
      default:
        return 'Any Fuel';
    }
  }

  // "14:44" → "02:44 pm"
  String _formatTime12(dynamic t) {
    final s = (t as String?)?.trim() ?? '';
    if (s.isEmpty) return '';
    // Handles both "HH:MM" (24h, app posts) and "hh:MM AM/PM" (12h, WhatsApp
    // posts) — the AM/PM suffix used to be ignored, showing 2 PM as 2 am.
    final match = RegExp(r'(\d{1,2}):(\d{2})\s*(AM|PM)?', caseSensitive: false).firstMatch(s);
    if (match == null) return s;
    int h = int.tryParse(match.group(1)!) ?? 0;
    final m = int.tryParse(match.group(2)!) ?? 0;
    final ap = (match.group(3) ?? '').toUpperCase();
    if (ap == 'PM' && h < 12) h += 12;
    if (ap == 'AM' && h == 12) h = 0;
    final period = h >= 12 ? 'pm' : 'am';
    int h12 = h % 12;
    if (h12 == 0) h12 = 12;
    return '${h12.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')} $period';
  }

  // How long ago the requirement was posted, e.g. "3 hours ago".
  String _timeAgo(dynamic createdAt) {
    if (createdAt == null) return '';
    try {
      final d = DateTime.parse(createdAt.toString());
      final diff = DateTime.now().difference(d);
      if (diff.inMinutes < 1) return 'just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes} minute${diff.inMinutes == 1 ? '' : 's'} ago';
      if (diff.inHours < 24) return '${diff.inHours} hour${diff.inHours == 1 ? '' : 's'} ago';
      return '${diff.inDays} day${diff.inDays == 1 ? '' : 's'} ago';
    } catch (_) {
      return '';
    }
  }

  String _formatDate(dynamic date) {
    if (date == null) return '';
    try {
      final raw = date.toString();
      // Use only the calendar date part (before 'T') so the day never shifts
      // because of the time-of-day or the device timezone.
      final datePart = raw.contains('T') ? raw.split('T').first : raw;
      final p = datePart.split('-');
      if (p.length == 3) {
        final m = int.parse(p[1]);
        final d = int.parse(p[2]);
        return '$d ${_monthName(m)}';
      }
      final dt = DateTime.parse(raw);
      return '${dt.day} ${_monthName(dt.month)}';
    } catch (_) {
      return date.toString();
    }
  }

  String _monthName(int m) {
    const months = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[m];
  }
}

class _WatermarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const text = 'Secure Member';
    const angle = -0.5;
    const rowGap = 36.0;
    const colGap = 120.0;

    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.grey.withOpacity(0.2), letterSpacing: 1.2),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width, size.height));

    final rows = (size.height / rowGap).ceil() + 4;
    final cols = (size.width / colGap).ceil() + 4;

    for (int row = -2; row < rows; row++) {
      for (int col = -2; col < cols; col++) {
        canvas.save();
        canvas.translate(col * colGap, row * rowGap);
        canvas.rotate(angle);
        tp.paint(canvas, Offset.zero);
        canvas.restore();
      }
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Two concentric circles with curved text running around the ring between them:
/// [topText] arcs over the top, [bottomText] arcs along the bottom (both upright).
class _StampRingPainter extends CustomPainter {
  final Color color;
  final String topText;
  final String bottomText;
  _StampRingPainter({required this.color, required this.topText, required this.bottomText});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final rOuter = size.width / 2 - 2;
    final rInner = rOuter - 22; // wide enough ring to seat the text
    final rText = (rOuter + rInner) / 2;

    final outerPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;
    final innerPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    // Round outer edge (was a saw-tooth path) + the inner circle.
    canvas.drawCircle(center, rOuter, outerPaint);
    canvas.drawCircle(center, rInner, innerPaint);

    final style = TextStyle(
      color: color,
      fontSize: 9,
      fontWeight: FontWeight.w800,
      letterSpacing: 1.2,
      height: 1.0,
    );
    _drawArcText(canvas, center, topText, rText, style, top: true);
    _drawArcText(canvas, center, bottomText, rText, style, top: false);
  }

  /// Lays each glyph out individually and rotates it to sit tangent to the circle.
  /// On the bottom arc the glyphs are flipped so the text still reads left-to-right.
  void _drawArcText(Canvas canvas, Offset center, String text, double radius, TextStyle style, {required bool top}) {
    if (text.isEmpty || radius <= 0) return;

    final painters = <TextPainter>[];
    double totalWidth = 0;
    for (final ch in text.split('')) {
      final tp = TextPainter(text: TextSpan(text: ch, style: style), textDirection: TextDirection.ltr)..layout();
      painters.add(tp);
      totalWidth += tp.width;
    }

    final span = totalWidth / radius; // arc the whole string occupies, in radians
    final centerAngle = top ? -pi / 2 : pi / 2;
    double consumed = 0;

    for (final tp in painters) {
      final charSpan = tp.width / radius;
      final offset = consumed + charSpan / 2 - span / 2;
      // Going left→right means increasing angle on top, decreasing on the bottom.
      final theta = top ? centerAngle + offset : centerAngle - offset;

      canvas.save();
      canvas.translate(center.dx, center.dy);
      if (top) {
        canvas.rotate(theta + pi / 2); // glyph "up" points away from the centre
        canvas.translate(0, -radius);
      } else {
        canvas.rotate(theta - pi / 2); // glyph "up" points toward the centre
        canvas.translate(0, radius);
      }
      tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
      canvas.restore();

      consumed += charSpan;
    }
  }

  @override
  bool shouldRepaint(covariant _StampRingPainter old) =>
      old.color != color || old.topText != topText || old.bottomText != bottomText;
}
