import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/vehicle_types.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/contact_launcher.dart';
import '../widgets/user_card_sheet.dart';

class UserProfilePage extends StatefulWidget {
  final String userId;
  final Map<String, dynamic>? user;
  const UserProfilePage({super.key, required this.userId, this.user});

  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
  Map<String, dynamic>? _user;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _user = widget.user;
    // Always refresh from the server so we have complete data (mobile, vehicles,
    // etc.) — the data passed in via `extra` can be partial (e.g. a requirement's
    // postedBy has no phone number).
    _fetch();
    // Auto-open the rating popup when navigated here from the "Rate" action.
    if (widget.user?['__openRating'] == true) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) openRatingFlow(context, {...?_user, '_id': widget.userId});
      });
    }
    // Auto-open the report form when navigated here from a "Report" action.
    if (widget.user?['__openReport'] == true) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) openReportFlow(context, widget.userId);
      });
    }
  }

  Future<void> _fetch() async {
    // Only show the full-screen loader when we have nothing to paint yet.
    if (_user == null) setState(() => _loading = true);
    try {
      final res = await getIt<ApiClient>().get('/users/card/${widget.userId}');
      if (!mounted) return;
      setState(() {
        _user = Map<String, dynamic>.from(res.data['data'] as Map);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        if (_user == null) _error = 'Could not load profile';
        _loading = false;
      });
    }
  }

  Future<void> _showReviews(BuildContext context, String userId) async {
    List<Map<String, dynamic>> reviews = [];
    bool failed = false;
    try {
      final res = await getIt<ApiClient>().get('/users/$userId/reviews');
      reviews = ((res.data['data'] as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {
      failed = true;
    }
    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('Reviews', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  const Spacer(),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close), padding: EdgeInsets.zero, constraints: const BoxConstraints()),
                ],
              ),
              const SizedBox(height: 8),
              if (reviews.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: Text(failed ? "Couldn't load reviews" : 'No reviews yet', style: const TextStyle(color: AppColors.textSecondary))),
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: reviews.length,
                    separatorBuilder: (_, __) => const Divider(height: 16),
                    itemBuilder: (_, i) {
                      final r = reviews[i];
                      final rater = r['rater'] as Map?;
                      final stars = (r['stars'] as num?)?.toInt() ?? 0;
                      final raterImg = rater?['profileImage'] as String?;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 16,
                                backgroundColor: AppColors.primaryLight,
                                backgroundImage: (raterImg != null && raterImg.isNotEmpty) ? NetworkImage(raterImg) : null,
                                child: (raterImg == null || raterImg.isEmpty)
                                    ? Text(((rater?['fullName'] as String?)?.isNotEmpty == true ? rater!['fullName'][0] : '?').toString().toUpperCase(),
                                        style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold))
                                    : null,
                              ),
                              const SizedBox(width: 10),
                              Expanded(child: Text(rater?['fullName'] as String? ?? 'User', style: const TextStyle(fontWeight: FontWeight.bold))),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: List.generate(5, (s) => Icon(s < stars ? Icons.star : Icons.star_border, size: 14, color: Colors.amber)),
                              ),
                            ],
                          ),
                          if ((r['review'] as String?)?.trim().isNotEmpty == true) ...[
                            const SizedBox(height: 6),
                            Text((r['review'] as String).trim(), style: const TextStyle(fontSize: 13, color: AppColors.textPrimary)),
                          ],
                        ],
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _user;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(user != null ? membershipLabel(user) : 'Profile'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: AppColors.textSecondary)))
              : user == null
                  ? const SizedBox.shrink()
                  : _buildBody(user),
    );
  }

  Widget _buildBody(Map<String, dynamic> user) {
    final name = (user['fullName'] ?? '') as String;
    final agency = user['agencyName'] as String?;
    final city = user['city'] as String?;
    final state = user['state'] as String?;
    final profileImage = user['profileImage'] as String?;
    final coverImage = user['coverImage'] as String?;
    final isVerified = user['isVerified'] == true;
    final rating = (user['rating'] as num?)?.toDouble() ?? 0;
    final mobile = user['mobile'] as String?;
    final vehicles = (user['vehicles'] as List?) ?? const [];
    // "No. Posts" is derived from the live (non-deleted) totals so it always
    // reconciles with the Booking + Availability sections below. (The user's
    // `requirementsPosted`/`vehiclesPosted` counters are lifetime totals that also
    // include deleted posts, which is why they read higher.)
    final bookingTotal = ((user['bookingStats'] as Map?)?['total'] as num?)?.toInt() ?? 0;
    final availTotal = ((user['availabilityStats'] as Map?)?['total'] as num?)?.toInt() ?? 0;
    final walletBalance = (user['walletBalance'] as num?) ?? 0;
    final title = (agency != null && agency.isNotEmpty) ? agency : name;
    final businessCity = [city, state].where((e) => e != null && e.isNotEmpty).join(', ');

    // Contact is only available to members with an active plan.
    final isPremium = currentUserIsPremium(context);
    final canContact = isPremium && mobile != null && mobile.isNotEmpty;

    return SingleChildScrollView(
      child: Column(
        children: [
          // Header
          Container(
            width: double.infinity,
            color: Colors.white,
            padding: const EdgeInsets.only(bottom: 4),
            child: Column(
              children: [
                Container(
                  height: 120,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: coverImage == null
                        ? const LinearGradient(colors: [AppColors.primary, AppColors.primaryDark])
                        : null,
                    image: coverImage != null
                        ? DecorationImage(image: NetworkImage(coverImage), fit: BoxFit.cover)
                        : null,
                  ),
                ),
                Transform.translate(
                  offset: const Offset(0, -45),
                  child: Column(
                    children: [
                      Stack(
                        children: [
                          CircleAvatar(
                            radius: 48,
                            backgroundColor: Colors.white,
                            child: CircleAvatar(
                              radius: 44,
                              backgroundColor: AppColors.primaryLight,
                              backgroundImage:
                                  (profileImage != null && profileImage.isNotEmpty) ? NetworkImage(profileImage) : null,
                              child: (profileImage == null || profileImage.isEmpty)
                                  ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                                      style: const TextStyle(fontSize: 34, fontWeight: FontWeight.bold, color: AppColors.primary))
                                  : null,
                            ),
                          ),
                          if (isVerified)
                            const Positioned(
                              right: 2,
                              bottom: 2,
                              child: CircleAvatar(
                                radius: 12,
                                backgroundColor: Colors.white,
                                child: Icon(Icons.verified, color: Color(0xFF2196F3), size: 20),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(title,
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.primary)),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: (isVerified ? AppColors.success : AppColors.error).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: (isVerified ? AppColors.success : AppColors.error).withValues(alpha: 0.5)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(isVerified ? Icons.verified : Icons.gpp_bad, size: 14, color: isVerified ? AppColors.success : AppColors.error),
                            const SizedBox(width: 5),
                            Text(isVerified ? 'Verified' : 'Not Verified',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: isVerified ? AppColors.success : AppColors.error)),
                          ],
                        ),
                      ),
                      if (agency != null && agency.isNotEmpty && name.isNotEmpty)
                        Text(name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.primaryDark)),
                      if (businessCity.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text('Business City: $businessCity',
                              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                        ),
                      const SizedBox(height: 6),
                      Builder(builder: (_) {
                        final ago = _lastLoginText(user['lastActive']);
                        final addr = (user['lastLocationAddress'] as String?)?.trim();
                        // No login time and no address → nothing captured yet.
                        if (ago.isEmpty && (addr == null || addr.isEmpty)) {
                          return const Text('Premium Members can view last location of User',
                              style: TextStyle(fontSize: 11, color: AppColors.textHint));
                        }
                        final hasAddr = addr != null && addr.isNotEmpty;
                        return Column(
                          children: [
                            // "Last Login: <time>  <address>" on one line (address is
                            // premium-gated on the backend, so it's only present for premium viewers).
                            Text.rich(
                              TextSpan(children: [
                                if (ago.isNotEmpty)
                                  TextSpan(
                                    text: 'Last Login: $ago',
                                    style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                                  ),
                                if (hasAddr)
                                  TextSpan(
                                    text: ago.isNotEmpty ? '  $addr' : addr,
                                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                                  ),
                              ]),
                              textAlign: TextAlign.center,
                            ),
                            if (!hasAddr && !isPremium)
                              const Padding(
                                padding: EdgeInsets.only(top: 2),
                                child: Text('Premium Members can view last location of User',
                                    style: TextStyle(fontSize: 11, color: AppColors.textHint)),
                              ),
                          ],
                        );
                      }),
                      const SizedBox(height: 14),
                      // Action row
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _Action(icon: Icons.phone, label: 'Phone', color: AppColors.primary,
                                onTap: canContact ? () => callNumber(mobile) : null),
                            _Action(iconWidget: const FaIcon(FontAwesomeIcons.whatsapp, color: Color(0xFF25D366), size: 24), label: 'WhatsApp', color: const Color(0xFF25D366),
                                onTap: canContact ? () => openWhatsApp(mobile) : null),
                            InkWell(
                              onTap: () {
                                if (!isPremium) {
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Become a premium member to rate')));
                                  return;
                                }
                                openRatingFlow(context, {...user, '_id': widget.userId});
                              },
                              child: Column(mainAxisSize: MainAxisSize.min, children: [
                                Text(rating.toStringAsFixed(0),
                                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.primary)),
                                const Text('Rate', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                              ]),
                            ),
                            _Action(icon: Icons.report_gmailerrorred, label: 'Report', color: Colors.grey,
                                onTap: () => openReportFlow(context, widget.userId)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Transform.translate(
                  offset: const Offset(0, -14),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: canContact ? () => callNumber(mobile) : null,
                            icon: const Icon(Icons.person_add_alt, size: 18),
                            label: const Text('Save Contact'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _showReviews(context, widget.userId),
                            icon: const Icon(Icons.star_outline, size: 18),
                            label: const Text('View Reviews'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (!isPremium)
                  GestureDetector(
                    onTap: () => context.push('/subscriptions'),
                    child: const Padding(
                      padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: Text(
                        'Become a premium member to contact immediately',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.red, fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
              ],
            ),
          ),

         

          // Stats
          const _SectionTitle('Statics'),
          Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
            child: Row(
              children: [
                Expanded(child: _Stat(label: 'Member Since', value: _memberSince(user['createdAt']))),
                Expanded(child: _Stat(label: 'No. Posts', value: '${bookingTotal + availTotal}')),
                Expanded(child: _Stat(label: 'Wallet', value: '₹${walletBalance.toStringAsFixed(0)}')),
              ],
            ),
          ),

          // Booking statistics — Total / Booked / Cancelled / Expired
          // (Expired = the travel date has already passed).
          _StatSection(
            title: 'Booking Statics',
            stats: (user['bookingStats'] as Map?) ?? const {},
            columns: const [
              ['Total', 'total'],
              ['Booked', 'booked'],
              ['Cancelled', 'cancelled'],
              ['Expired', 'expired'],
            ],
          ),

          // Availability statistics — Total / Booked / Available / Expired
          _StatSection(
            title: 'Availability Statics',
            stats: (user['availabilityStats'] as Map?) ?? const {},
            columns: const [
              ['Total', 'total'],
              ['Booked', 'booked'],
              ['Available', 'available'],
              ['Expired', 'expired'],
            ],
          ),
        ],
      ),
    );
  }

  String _memberSince(dynamic createdAt) {
    if (createdAt == null) return '—';
    final date = DateTime.tryParse(createdAt.toString());
    if (date == null) return '—';
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  /// Relative "last login" label from a lastActive timestamp, e.g. "21 min ago".
  String _lastLoginText(dynamic iso) {
    if (iso == null) return '';
    final dt = DateTime.tryParse(iso.toString())?.toLocal();
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} hr ago';
    if (diff.inDays < 30) return '${diff.inDays} day${diff.inDays == 1 ? '' : 's'} ago';
    final months = (diff.inDays / 30).floor();
    if (months < 12) return '$months month${months == 1 ? '' : 's'} ago';
    return '${(diff.inDays / 365).floor()} yr ago';
  }
}

class _Action extends StatelessWidget {
  final IconData? icon;
  final Widget? iconWidget;
  final String label;
  final Color color;
  final VoidCallback? onTap;
  const _Action({this.icon, this.iconWidget, required this.label, required this.color, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        iconWidget ?? Icon(icon, color: onTap == null ? Colors.grey : color, size: 26),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
      ]),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
      child: Center(
        child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.primary)),
      ),
    );
  }
}

class _VehicleCard extends StatelessWidget {
  final Map<String, dynamic> vehicle;
  const _VehicleCard({required this.vehicle});

  @override
  Widget build(BuildContext context) {
    final type = (vehicle['vehicleType'] ?? '').toString();
    final number = (vehicle['vehicleNumber'] ?? '').toString();
    final status = (vehicle['status'] ?? '').toString();
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Text(vehicleTypeLabel(type),
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(number, style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(status == 'available' ? Icons.check_circle : Icons.info,
                  color: status == 'available' ? AppColors.memberVerified : Colors.grey, size: 16),
              const SizedBox(width: 4),
              Text(status.isNotEmpty ? '${status[0].toUpperCase()}${status.substring(1)}' : '—',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            ],
          ),
        ],
      ),
    );
  }
}

// A titled card with a row of stat columns, driven by [label, key] pairs read
// from a stats map (Booking / Availability statistics).
class _StatSection extends StatelessWidget {
  final String title;
  final Map stats;
  final List<List<String>> columns;
  const _StatSection({required this.title, required this.stats, required this.columns});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _SectionTitle(title),
        Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
          child: Row(
            children: [
              for (final c in columns)
                Expanded(child: _Stat(label: c[0], value: '${stats[c[1]] ?? 0}')),
            ],
          ),
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  const _Stat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: AppColors.primary, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 14, color: AppColors.textPrimary)),
      ],
    );
  }
}
