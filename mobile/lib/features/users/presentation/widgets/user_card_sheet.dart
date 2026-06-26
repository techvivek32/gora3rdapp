import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
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

class _UserCardSheet extends StatelessWidget {
  final Map<String, dynamic> user;
  const _UserCardSheet({required this.user});

  @override
  Widget build(BuildContext context) {
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

    // Contact is only available to members with an active plan.
    final isPremium = currentUserIsPremium(context);
    final canContact = isPremium && mobile != null && mobile.isNotEmpty;

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
              ),
              _ActionItem(
                iconWidget: const FaIcon(FontAwesomeIcons.whatsapp, color: Color(0xFF25D366), size: 24),
                label: 'WhatsApp',
                color: const Color(0xFF25D366),
                onTap: canContact ? () => openWhatsApp(mobile) : null,
              ),
              _ActionItem(
                icon: Icons.notifications_active,
                label: 'Advice',
                color: Colors.amber.shade700,
                topText: "Don't pay without reference!",
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(rating.toStringAsFixed(0),
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.primary)),
                  _Stars(rating: rating),
                  Text('($totalRatings)', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                ],
              ),
            ],
          ),
          if (!isPremium) ...[
            const SizedBox(height: 14),
            GestureDetector(
              onTap: () {
                Navigator.pop(context);
                context.push('/subscriptions');
              },
              child: const SizedBox(
                width: double.infinity,
                child: Text(
                  'Become a premium member to contact immediately',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.red, fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
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
  const _ActionItem({this.icon, this.iconWidget, required this.label, required this.color, this.onTap, this.topText});

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
