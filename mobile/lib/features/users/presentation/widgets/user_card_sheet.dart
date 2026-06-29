import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/contact_launcher.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';

const _premiumTypes = ['active', 'verified', 'premium', 'golden'];

bool currentUserIsPremium(BuildContext context) {
  final auth = context.read<AuthBloc>().state;
  final me = auth is AuthAuthenticated ? auth.user as Map<String, dynamic>? : null;
  return _premiumTypes.contains(me?['membershipType']);
}

String membershipLabel(Map<String, dynamic> user) {
  if (user['isVerified'] == true) return 'Verified Member';
  switch (user['membershipType']) {
    case 'golden':
      return 'Golden Member';
    case 'premium':
      return 'Premium Member';
    case 'verified':
      return 'Verified Member';
    case 'active':
      return 'Active Member';
    default:
      return 'Member';
  }
}

/// Shows the searched user's mini profile card as a centered dialog.
Future<void> showUserCardSheet(BuildContext context, Map<String, dynamic> user) {
  return showDialog(
    context: context,
    builder: (_) => Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SingleChildScrollView(child: _UserCardSheet(user: user)),
    ),
  );
}

class _UserCardSheet extends StatefulWidget {
  final Map<String, dynamic> user;
  const _UserCardSheet({required this.user});

  @override
  State<_UserCardSheet> createState() => _UserCardSheetState();
}

class _UserCardSheetState extends State<_UserCardSheet> {
  late Map<String, dynamic> _user;

  @override
  void initState() {
    super.initState();
    _user = Map<String, dynamic>.from(widget.user);
    // Passed-in data (e.g. a requirement's postedBy) can be partial and miss the
    // phone number — fetch the full profile so contact actions work.
    final mobile = _user['mobile'];
    if ((mobile == null || (mobile is String && mobile.isEmpty)) && _user['_id'] != null) {
      _enrich();
    }
  }

  Future<void> _enrich() async {
    try {
      final res = await getIt<ApiClient>().get('/users/card/${_user['_id']}');
      final data = Map<String, dynamic>.from(res.data['data'] as Map);
      if (mounted) setState(() => _user = {..._user, ...data});
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final user = _user;
    final name = (user['fullName'] ?? '') as String;
    final agency = user['agencyName'] as String?;
    final city = user['city'] as String?;
    final state = user['state'] as String?;
    final profileImage = user['profileImage'] as String?;
    final isVerified = user['isVerified'] == true;
    final rating = (user['rating'] as num?)?.toDouble() ?? 0;
    final totalRatings = (user['totalRatings'] as num?)?.toInt() ?? 0;
    final mobile = user['mobile'] as String?;
    final title = (agency != null && agency.isNotEmpty) ? agency : name;
    final subtitle = [name, city].where((e) => e != null && e.isNotEmpty).join(', ');

    // Contact is available to members with an active plan, or to the owner
    // viewing their own card.
    final auth = context.read<AuthBloc>().state;
    final me = auth is AuthAuthenticated ? auth.user as Map<String, dynamic>? : null;
    final isOwner = me != null && me['_id'] != null && me['_id'] == user['_id'];
    final canView = currentUserIsPremium(context) || isOwner;
    final canContact = canView && mobile != null && mobile.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(membershipLabel(user),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              const Spacer(),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close, color: Colors.red),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 4),
          if (city != null && city.isNotEmpty)
            Text([city, state].where((e) => e != null && e.isNotEmpty).join(' '),
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          const SizedBox(height: 16),

          // Identity row
          Row(
            children: [
              _Avatar(image: profileImage, name: name, isVerified: isVerified, radius: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.primary)),
                    if (subtitle.isNotEmpty)
                      Text(subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Actions
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _ActionItem(
                icon: Icons.phone,
                label: 'Phone',
                color: AppColors.primary,
                onTap: canContact ? () => callNumber(mobile) : null,
                locked: !canView,
              ),
              _ActionItem(
                iconWidget: const FaIcon(FontAwesomeIcons.whatsapp, color: Color(0xFF25D366), size: 24),
                label: 'WhatsApp',
                color: const Color(0xFF25D366),
                onTap: canContact ? () => openWhatsApp(mobile) : null,
                locked: !canView,
              ),
              _ActionItem(
                icon: Icons.notifications_active,
                label: 'Advice',
                color: Colors.amber.shade700,
                topText: "Don't pay without reference!",
              ),
              InkWell(
                onTap: () {
                  if (isOwner) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("You can't rate yourself")));
                    return;
                  }
                  if (!canView) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Become a premium member to rate')));
                    return;
                  }
                  // Open the full profile first, then auto-open the rating popup there.
                  Navigator.pop(context);
                  context.push('/users/${user['_id']}', extra: {...user, '__openRating': true});
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(rating.toStringAsFixed(0),
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.primary)),
                    _Stars(rating: rating),
                    Text('Rate ($totalRatings)', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
          if (!canView)
            // No plan: lock contact + viewing, prompt to upgrade.
            GestureDetector(
              onTap: () {
                Navigator.pop(context);
                context.push('/subscriptions');
              },
              child: const Padding(
                padding: EdgeInsets.only(top: 14),
                child: SizedBox(
                  width: double.infinity,
                  child: Text(
                    'Become a premium member to contact immediately',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.red, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            )
          else ...[
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  context.push('/users/${user['_id']}', extra: user);
                },
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                child: const Text('View Full Profile', style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String? image;
  final String name;
  final bool isVerified;
  final double radius;
  const _Avatar({required this.image, required this.name, required this.isVerified, this.radius = 28});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        CircleAvatar(
          radius: radius,
          backgroundColor: AppColors.primaryLight,
          backgroundImage: (image != null && image!.isNotEmpty) ? NetworkImage(image!) : null,
          child: (image == null || image!.isEmpty)
              ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: TextStyle(fontSize: radius * 0.7, fontWeight: FontWeight.bold, color: AppColors.primary))
              : null,
        ),
        if (isVerified)
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
              child: const Icon(Icons.verified, color: Color(0xFF2196F3), size: 18),
            ),
          ),
      ],
    );
  }
}

class _ActionItem extends StatelessWidget {
  final IconData? icon;
  final Widget? iconWidget;
  final String label;
  final Color color;
  final VoidCallback? onTap;
  final String? topText;
  final bool locked;
  const _ActionItem({this.icon, this.iconWidget, required this.label, required this.color, this.onTap, this.topText, this.locked = false});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                iconWidget ?? Icon(icon, color: (onTap == null && topText == null) ? Colors.grey : color, size: 26),
                // Red "blocked" overlay for locked (non-plan) actions.
                if (locked) const Icon(Icons.block, color: Colors.red, size: 30),
                // Floating warning that overlays above the icon (doesn't take layout space).
                if (topText != null)
                  Positioned(
                    bottom: 14,
                    child: SizedBox(
                      width: 84,
                      child: Text(
                        topText!,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.red.shade700, height: 1.1),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}

/// Checks if the user already rated, then shows the rating dialog and submits.
Future<void> openRatingFlow(BuildContext context, Map<String, dynamic> user) async {
  final api = getIt<ApiClient>();
  final userId = user['_id'];
  if (userId == null) return;

  try {
    final res = await api.get('/users/$userId/rating-status');
    if (res.data['data']?['hasRated'] == true) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('You have already rated this user')));
      }
      return;
    }
  } catch (_) {}

  if (!context.mounted) return;
  final result = await showDialog<Map<String, dynamic>>(
    context: context,
    builder: (_) => _RatingDialog(name: (user['fullName'] ?? 'this user') as String),
  );
  if (result == null || !context.mounted) return;

  try {
    await api.dio.post('/users/$userId/rate', data: {'stars': result['stars'], 'review': result['review']});
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Thanks for your rating!'), backgroundColor: AppColors.success),
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_rateError(e)), backgroundColor: AppColors.error),
      );
    }
  }
}

String _rateError(Object e) {
  final s = e.toString();
  if (s.contains('already')) return 'You have already rated this user';
  return 'Could not submit rating';
}

/// Shows a report form and submits it for the given user.
Future<void> openReportFlow(BuildContext context, String userId) async {
  final text = await showDialog<String>(
    context: context,
    builder: (_) => const _ReportDialog(),
  );
  if (text == null || text.trim().isEmpty || !context.mounted) return;
  try {
    await getIt<ApiClient>().dio.post('/reports', data: {
      'targetId': userId,
      'targetType': 'user',
      'reason': 'other',
      'description': text.trim(),
    });
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Report submitted. Thank you.'), backgroundColor: AppColors.success),
      );
    }
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not submit report'), backgroundColor: AppColors.error),
      );
    }
  }
}

class _ReportDialog extends StatefulWidget {
  const _ReportDialog();

  @override
  State<_ReportDialog> createState() => _ReportDialogState();
}

class _ReportDialogState extends State<_ReportDialog> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      title: const Text('Report User'),
      content: SizedBox(
        width: double.maxFinite,
        child: TextField(
          controller: _ctrl,
          maxLines: 4,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Describe the issue...',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, _ctrl.text),
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
          child: const Text('Submit'),
        ),
      ],
    );
  }
}

class _RatingDialog extends StatefulWidget {
  final String name;
  const _RatingDialog({required this.name});

  @override
  State<_RatingDialog> createState() => _RatingDialogState();
}

class _RatingDialogState extends State<_RatingDialog> {
  int _stars = 0;
  final _reviewCtrl = TextEditingController();

  @override
  void dispose() {
    _reviewCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      title: Text('Rate ${widget.name}'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) {
              final filled = i < _stars;
              return IconButton(
                onPressed: () => setState(() => _stars = i + 1),
                padding: const EdgeInsets.symmetric(horizontal: 2),
                constraints: const BoxConstraints(),
                icon: Icon(filled ? Icons.star : Icons.star_border, color: Colors.amber, size: 32),
              );
            }),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _reviewCtrl,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Write a review (optional)',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: _stars == 0
              ? null
              : () => Navigator.pop(context, {'stars': _stars, 'review': _reviewCtrl.text.trim()}),
          child: const Text('Submit'),
        ),
      ],
    );
  }
}

class _Stars extends StatelessWidget {
  final double rating;
  const _Stars({required this.rating});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        return Icon(
          i < rating.round() ? Icons.star : Icons.star_border,
          size: 12,
          color: Colors.amber,
        );
      }),
    );
  }
}
