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
    if (_user == null) _fetch();
  }

  Future<void> _fetch() async {
    setState(() => _loading = true);
    try {
      final res = await getIt<ApiClient>().get('/users/card/${widget.userId}');
      setState(() {
        _user = Map<String, dynamic>.from(res.data['data'] as Map);
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Could not load profile';
        _loading = false;
      });
    }
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
    final isVerified = user['isVerified'] == true;
    final rating = (user['rating'] as num?)?.toDouble() ?? 0;
    final totalRatings = (user['totalRatings'] as num?)?.toInt() ?? 0;
    final mobile = user['mobile'] as String?;
    final vehicles = (user['vehicles'] as List?) ?? const [];
    final requirementsPosted = (user['requirementsPosted'] as num?)?.toInt() ?? 0;
    final vehiclesPosted = (user['vehiclesPosted'] as num?)?.toInt() ?? 0;
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
            padding: const EdgeInsets.only(bottom: 20),
            child: Column(
              children: [
                Container(
                  height: 120,
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(colors: [AppColors.primary, AppColors.primaryDark]),
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
                      if (agency != null && agency.isNotEmpty && name.isNotEmpty)
                        Text(name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.primaryDark)),
                      if (businessCity.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text('Business City: $businessCity',
                              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                        ),
                      const SizedBox(height: 6),
                      const Text('Premium Members can view last location of User',
                          style: TextStyle(fontSize: 11, color: AppColors.textHint)),
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
                            Column(mainAxisSize: MainAxisSize.min, children: [
                              Text(rating.toStringAsFixed(0),
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.primary)),
                              const Text('Rating', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                            ]),
                            _Action(icon: Icons.report_gmailerrorred, label: 'Report', color: Colors.grey,
                                onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Report submitted')),
                                    )),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Transform.translate(
                  offset: const Offset(0, -30),
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
                            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('$totalRatings reviews')),
                            ),
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

          // My Vehicles
          if (vehicles.isNotEmpty) ...[
            const _SectionTitle('My Vehicles'),
            ...vehicles.map((v) => _VehicleCard(vehicle: Map<String, dynamic>.from(v as Map))),
          ],

          // Stats
          const _SectionTitle('Stats'),
          Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
            child: Row(
              children: [
                Expanded(child: _Stat(label: 'Member Since', value: _memberSince(user['createdAt']))),
                Expanded(child: _Stat(label: 'No. Posts', value: '${requirementsPosted + vehiclesPosted}')),
              ],
            ),
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
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
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
