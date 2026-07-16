import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/contact_launcher.dart';
import '../../../../core/utils/membership.dart';
import '../../../../core/utils/ring_player.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';

/// Full-screen-style popup shown when a "new requirement" push arrives while the
/// app is open (or when the user taps the notification).
Future<void> showRequirementAlert(BuildContext context, Map<String, dynamic> data) {
  return showDialog(
    context: context,
    barrierDismissible: true,
    barrierColor: Colors.black54,
    builder: (_) => _RequirementAlert(data: data),
    // Cut the ring short once the user has seen (and dismissed) the alert.
  ).whenComplete(stopRequirementRing);
}

class _RequirementAlert extends StatelessWidget {
  final Map<String, dynamic> data;
  const _RequirementAlert({required this.data});

  String _str(String key) => (data[key] ?? '').toString();

  String _cap(String s) => s.isEmpty ? s : s.replaceAll('_', ' ').split(' ').map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}').join(' ');

  /// Travel date + time shown in place of the agent name, e.g. "16 Jul • 02:24 pm".
  String _dateTimeLabel() {
    const months = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final rawDate = _str('travelDate');
    String datePart = '';
    if (rawDate.isNotEmpty) {
      final d = rawDate.contains('T') ? rawDate.split('T').first : rawDate;
      final p = d.split('-');
      if (p.length == 3) {
        final m = int.tryParse(p[1]) ?? 0;
        datePart = '${int.tryParse(p[2]) ?? p[2]} ${(m >= 1 && m <= 12) ? months[m] : ''}'.trim();
      }
    }
    String timePart = '';
    final tp = _str('travelTime').split(':');
    if (tp.length >= 2) {
      final h = int.tryParse(tp[0]) ?? 0;
      final mm = tp[1].padLeft(2, '0');
      final ampm = h >= 12 ? 'pm' : 'am';
      final h12 = h % 12 == 0 ? 12 : h % 12;
      timePart = '${h12.toString().padLeft(2, '0')}:$mm $ampm';
    }
    return [datePart, timePart].where((e) => e.isNotEmpty).join(' • ');
  }

  List<String> _stops() =>
      _str('stops').split('\n').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

  /// Same membership check the requirement card uses.
  bool _userCanContact(BuildContext context) {
    try {
      final state = context.read<AuthBloc>().state;
      if (state is AuthAuthenticated) return canContactPosters(state.user);
    } catch (_) {}
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final dateTime = _dateTimeLabel();
    final mobile = _str('posterMobile');
    final bookingId = _str('bookingId');
    final vehicle = _cap(_str('vehicleType'));
    final trip = _cap(_str('tripType'));
    final from = _str('pickupCity');
    final to = _str('dropCity');
    final note = _str('notes');

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 40),
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: travel date/time + booking id
              Row(
                children: [
                  const CircleAvatar(radius: 16, backgroundColor: AppColors.primaryLight, child: Icon(Icons.access_time_rounded, size: 18, color: AppColors.primary)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: AppColors.primaryLight.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(20)),
                      child: Text(
                        dateTime.isEmpty ? 'New Requirement' : dateTime,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.primary),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (bookingId.isNotEmpty)
                    Flexible(
                      child: Text(
                        '#$bookingId',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.memberPremium),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),

              // Vehicle row
              Row(
                children: [
                  const Icon(Icons.directions_car, color: AppColors.primary, size: 22),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      vehicle.isEmpty ? 'Vehicle' : vehicle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (trip.isNotEmpty) Flexible(child: _tag(trip)),
                ],
              ),
              const Divider(height: 16),

              // From → (stops) → To
              _routePoint(Colors.green, 'A', from.isEmpty ? '—' : from),
              for (final stop in _stops()) ...{
                const SizedBox(height: 4),
                _routePoint(AppColors.primary, '•', stop),
              },
              Padding(
                padding: const EdgeInsets.only(left: 11, top: 2, bottom: 2),
                child: Row(children: [
                  Container(width: 2, height: 16, color: Colors.grey.shade300),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Text(
                      trip.isEmpty ? '' : trip,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                    ),
                  ),
                ]),
              ),
              _routePoint(Colors.red, 'B', to.isEmpty ? '—' : to),

              if (note.isNotEmpty) ...{
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Icon(Icons.chat_bubble_outline, size: 18, color: Colors.grey.shade600),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        note,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13, height: 1.4),
                      ),
                    ),
                  ],
                ),
              },

              const SizedBox(height: 6),
              Text('just now', style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
              const SizedBox(height: 12),

              // Actions — Call & WhatsApp (only enabled if user has active plan).
              Builder(
                builder: (ctx) {
                  final canContact = mobile.isNotEmpty && _userCanContact(ctx);
                  return Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: canContact ? () => callNumber(mobile) : null,
                          icon: const Icon(Icons.call, size: 16, color: Colors.white),
                          label: const Text('Call', style: TextStyle(fontSize: 13)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: Colors.green.withValues(alpha: 0.4),
                            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: canContact ? () => openWhatsApp(mobile) : null,
                          icon: const Icon(Icons.chat, size: 16, color: Colors.white),
                          label: const Text('WhatsApp', style: TextStyle(fontSize: 13)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF25D366),
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: const Color(0xFF25D366).withValues(alpha: 0.4),
                            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  child: const Text('Close', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tag(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.border)),
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      );

  Widget _routePoint(Color color, String label, String text) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(radius: 11, backgroundColor: color, child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold))),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      );
}
