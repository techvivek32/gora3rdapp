import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  static const _membershipConfig = {
    'new': {'label': 'New Member', 'color': Color(0xFF6B7280), 'icon': Icons.person},
    'active': {'label': 'Active', 'color': Color(0xFF3B82F6), 'icon': Icons.verified_user},
    'verified': {'label': 'Verified', 'color': Color(0xFF10B981), 'icon': Icons.verified},
    'premium': {'label': 'Premium', 'color': Color(0xFFF59E0B), 'icon': Icons.star},
    'golden': {'label': 'Golden', 'color': Color(0xFFEF4444), 'icon': Icons.workspace_premium},
  };

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        final user = state is AuthAuthenticated ? state.user : null;
        final membership = user?['membershipType'] as String? ?? 'new';
        final config = _membershipConfig[membership] ?? _membershipConfig['new']!;
        final color = config['color'] as Color;

        return Scaffold(
          body: CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 200,
                pinned: true,
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [color.withOpacity(0.8), color],
                      ),
                    ),
                    child: SafeArea(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircleAvatar(
                            radius: 44,
                            backgroundColor: Colors.white,
                            backgroundImage: user?['profileImage'] != null ? NetworkImage(user!['profileImage'] as String) : null,
                            child: user?['profileImage'] == null ? Icon(Icons.person, size: 44, color: color) : null,
                          ),
                          const SizedBox(height: 8),
                          Text(user?['fullName'] as String? ?? 'User',
                              style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(config['icon'] as IconData, color: Colors.white, size: 16),
                              const SizedBox(width: 4),
                              Text(config['label'] as String,
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _InfoCard(
                        title: 'Account Information',
                        children: [
                          _InfoRow(Icons.phone, 'Mobile', user?['mobile'] as String? ?? '-'),
                          _InfoRow(Icons.email, 'Email', user?['email'] as String? ?? '-'),
                          if (user?['agencyName'] != null)
                            _InfoRow(Icons.business, 'Agency', user!['agencyName'] as String),
                          _InfoRow(Icons.location_city, 'City', user?['city'] as String? ?? '-'),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _InfoCard(
                        title: 'Activity',
                        children: [
                          _InfoRow(Icons.post_add, 'Requirements Posted', '${user?['requirementsPosted'] ?? 0}'),
                          _InfoRow(Icons.directions_car, 'Vehicles Posted', '${user?['vehiclesPosted'] ?? 0}'),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _ProfileAction(
                        icon: Icons.workspace_premium,
                        label: 'Upgrade Membership',
                        color: Colors.amber,
                        onTap: () => context.push('/subscriptions'),
                      ),
                      _ProfileAction(
                        icon: Icons.notifications_outlined,
                        label: 'Notifications',
                        onTap: () => context.push('/notifications'),
                      ),
                      _ProfileAction(
                        icon: Icons.chat_outlined,
                        label: 'Messages',
                        onTap: () => context.push('/chats'),
                      ),
                      _ProfileAction(
                        icon: Icons.settings_outlined,
                        label: 'Settings',
                        onTap: () {},
                      ),
                      const SizedBox(height: 12),
                      _ProfileAction(
                        icon: Icons.logout,
                        label: 'Sign Out',
                        color: Colors.red,
                        onTap: () {
                          showDialog(
                            context: context,
                            builder: (_) => AlertDialog(
                              title: const Text('Sign Out'),
                              content: const Text('Are you sure you want to sign out?'),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                                TextButton(
                                  onPressed: () {
                                    Navigator.pop(context);
                                    context.read<AuthBloc>().add(AuthLogoutEvent());
                                  },
                                  child: const Text('Sign Out', style: TextStyle(color: Colors.red)),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _InfoCard({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const Divider(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoRow(this.icon, this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey),
          const SizedBox(width: 12),
          Text('$label: ', style: TextStyle(color: Colors.grey.shade600)),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }
}

class _ProfileAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;
  const _ProfileAction({required this.icon, required this.label, required this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: color ?? Theme.of(context).primaryColor),
        title: Text(label, style: color != null ? TextStyle(color: color) : null),
        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
        onTap: onTap,
      ),
    );
  }
}
