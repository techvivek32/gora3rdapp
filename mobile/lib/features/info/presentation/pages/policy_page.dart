import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/localization/app_translations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/contact_launcher.dart';
import '../../../../core/widgets/app_logo.dart';

class PolicySection {
  final String? heading;
  final List<String> paragraphs;
  final List<String> bullets;
  const PolicySection({this.heading, this.paragraphs = const [], this.bullets = const []});
}

class PolicyContent {
  final String title;
  final IconData icon;
  final String subtitle;
  final List<PolicySection> sections;
  const PolicyContent({required this.title, required this.icon, required this.subtitle, required this.sections});
}

/// All static policy / about content keyed by id.
const Map<String, PolicyContent> kPolicies = {
  // About Us renders _AboutFooter only (logo → contact → legal); it has no header
  // row and no body sections. Only `title` is used, for the app bar.
  'about': PolicyContent(
    title: 'About Us',
    icon: Icons.local_taxi_rounded,
    subtitle: 'About Gora Cabs',
    sections: [],
  ),
  'terms': PolicyContent(
    title: 'Terms & Conditions',
    icon: Icons.description_outlined,
    subtitle: 'Please read these terms carefully.',
    sections: [
      PolicySection(paragraphs: [
        'By using this application you agree to comply with and be bound by the following terms and conditions of use:',
      ]),
      PolicySection(bullets: [
        'The app content is for general information and use only and is subject to change without notice.',
        'Your use of any information or materials on this app is entirely at your own risk, for which we shall not be liable.',
        'This app contains material owned by or licensed to us, including the design, layout, look, appearance and graphics.',
        'Unauthorized use of this app may give rise to a claim for damages and/or be a criminal offense.',
        'The app may include links to other services, provided for your convenience; they do not signify endorsement.',
        'By using this app, you agree to the terms and conditions outlined above.',
      ]),
      PolicySection(heading: 'Penalty Policy', paragraphs: [
        'Please read these penalty rules carefully to avoid any deductions:',
      ], bullets: [
        'If a driver accepts a duty but fails to provide the vehicle, a penalty of ₹500 will be charged.',
        'If a booking is cancelled 5 minutes after acceptance, a ₹100 penalty will apply. If cancelled 15 minutes or 30 minutes after acceptance, a ₹500 penalty will be charged.',
        'For Urgent bookings, cancelling within 15 minutes of acceptance will incur a ₹500 penalty, cancelling within 30 minutes will also incur a ₹500 penalty, and cancelling after 30 minutes will result in a ₹1,500 penalty.',
        'If the customer reports that you arrived late for pickup, a penalty may be imposed based on the complaint.',
        'Only send the driver and vehicle details that were provided in the booking. If there is any change, you must inform the company or the booking poster. Sending a different driver or vehicle without prior notice may result in a penalty.',
        'For CAT bookings, the first 45 minutes from the scheduled pickup time are free. After that, waiting charges will apply per hour: Hatchback – ₹120, Sedan – ₹150, SUV – ₹200.',
      ]),
    ],
  ),
  'privacy': PolicyContent(
    title: 'Privacy Policy',
    icon: Icons.privacy_tip_outlined,
    subtitle: 'How we protect your data, wallet and platform trust.',
    sections: [
      PolicySection(heading: 'Your Privacy', paragraphs: [
        'Gora Cabs respects your privacy. We collect only the information needed to verify members and operate the platform — such as your name, mobile number, KYC documents and city. This information is used solely to run the service and is never sold to third parties.',
        'Your contact number is shared with other members only as required to complete a booking. Contact details are gated by membership to protect you from spam and misuse.',
      ]),
      // ── Security Wallet System ──────────────────────────────────────────────
      PolicySection(heading: 'Security Wallet System 🔒', paragraphs: [
        'The Security Wallet reduces fraud between drivers and agents while building trust on the platform.',
      ]),
      PolicySection(heading: 'Wallet Rules', bullets: [
        'Both drivers and agents must maintain a minimum wallet balance of ₹500.',
        'If the wallet balance falls below ₹500: Calling, WhatsApp, and Booking Confirmation features will be disabled.',
        'If a fraud complaint is found to be valid, a penalty of ₹100 to ₹500 may be deducted from the wallet.',
        'Users who file false or misleading complaints may also face appropriate action.',
      ]),
      PolicySection(heading: 'Fraud Examples', bullets: [
        'Fake Duty Post',
        'Booking Confirm karke Cancel karna',
        'Wrong Information dena',
        'Advance Payment Fraud',
        'No Response After Confirmation',
      ]),
      PolicySection(heading: 'Goal', paragraphs: [
        'To ensure each user keeps a security amount on the platform, reducing fake users and fraud activities while building trust for both drivers and agents.',
      ]),
      // ── Service & Copyright policies ────────────────────────────────────────
      PolicySection(heading: 'About Service', paragraphs: [
        'Gora Cabs is a platform dedicated to taxi-service availability and creation. We connect service providers with requirements to facilitate smooth transportation operations. By using this application, you acknowledge that we are a service aggregator and facilitator.',
      ]),
      PolicySection(heading: 'Copyright & Intellectual Property', paragraphs: [
        'All content included in this application — text, graphics, logos, button icons, images and software — is the property of Gora Cabs and is protected by copyright laws.',
        'Prohibition on Copying: You may not copy, reproduce, republish, upload, post, transmit or distribute any material from this application without prior written permission from us. Unauthorized use may violate copyright laws, trademark laws and other regulations.',
      ]),
      PolicySection(heading: 'General Terms of Use', paragraphs: [
        'By accessing this application, you agree to use it only for lawful purposes. You are prohibited from posting or transmitting any material that constitutes or encourages conduct that would be a criminal offense or give rise to civil liability.',
        'We reserve the right to modify these terms at any time. Your continued use of the application following any changes indicates your acceptance of the new terms.',
      ]),
    ],
  ),
  'policies': PolicyContent(
    title: 'Policies',
    icon: Icons.policy_outlined,
    subtitle: 'Service, copyright and general terms.',
    sections: [
      PolicySection(heading: 'About Service', paragraphs: [
        'Gora Cabs is a platform dedicated to taxi-service availability and creation. We connect service providers with requirements to facilitate smooth transportation operations. By using this application, you acknowledge that we are a service aggregator and facilitator.',
      ]),
      PolicySection(heading: 'Copyright & Intellectual Property', paragraphs: [
        'All content included in this application — text, graphics, logos, button icons, images and software — is the property of Gora Cabs and is protected by copyright laws.',
        'Prohibition on Copying: You may not copy, reproduce, republish, upload, post, transmit or distribute any material from this application without prior written permission from us. Unauthorized use may violate copyright laws, trademark laws and other regulations.',
      ]),
      PolicySection(heading: 'General Terms of Use', paragraphs: [
        'By accessing this application, you agree to use it only for lawful purposes. You are prohibited from posting or transmitting any material that constitutes or encourages conduct that would be a criminal offense or give rise to civil liability.',
        'We reserve the right to modify these terms at any time. Your continued use of the application following any changes indicates your acceptance of the new terms.',
      ]),
    ],
  ),
  'penalty': PolicyContent(
    title: 'Penalty Policy',
    icon: Icons.gavel_rounded,
    subtitle: 'Please read these penalty policies carefully to avoid any deductions.',
    sections: [
      PolicySection(bullets: [
        'If a driver accepts a duty but fails to provide the vehicle, a penalty of ₹500 will be charged.',
        'If a booking is cancelled 5 minutes after acceptance, a ₹100 penalty will apply. If cancelled 15 minutes or 30 minutes after acceptance, a ₹500 penalty will be charged.',
        'For Urgent bookings, cancelling within 15 minutes of acceptance will incur a ₹500 penalty, cancelling within 30 minutes will also incur a ₹500 penalty, and cancelling after 30 minutes will result in a ₹1,500 penalty.',
        'If the customer reports that you arrived late for pickup, a penalty may be imposed based on the complaint.',
        'Only send the driver and vehicle details that were provided in the booking. If there is any change, you must inform the company or the booking poster. Sending a different driver or vehicle without prior notice may result in a penalty.',
        'For CAT bookings, the first 45 minutes from the scheduled pickup time are free. After that, waiting charges will apply per hour: Hatchback – ₹120, Sedan – ₹150, SUV – ₹200.',
      ]),
    ],
  ),
  'wallet': PolicyContent(
    title: 'Security Wallet System',
    icon: Icons.account_balance_wallet_outlined,
    subtitle: '🔒 Fraud Protection',
    sections: [
      PolicySection(heading: 'Purpose', paragraphs: [
        'Reduce fraud between drivers and agents while building trust.',
      ]),
      PolicySection(heading: 'Rules', bullets: [
        'Both drivers and agents must maintain a minimum wallet balance of ₹500.',
        'If the wallet balance falls below ₹500: Calling, WhatsApp, and Booking Confirmation features will be disabled.',
        'If a fraud complaint is found to be valid, a penalty of ₹100 to ₹500 may be deducted from the wallet.',
        'Users who file false or misleading complaints may also face appropriate action.',
      ]),
      PolicySection(heading: 'Fraud Examples', bullets: [
        'Fake Duty Post',
        'Booking Confirm karke Cancel karna',
        'Wrong Information dena',
        'Advance Payment Fraud',
        'No Response After Confirmation',
      ]),
      PolicySection(heading: 'Goal', paragraphs: [
        'To ensure each user has a security amount on the platform, reducing fake users and fraud activities while building trust for both drivers and agents.',
      ]),
    ],
  ),
};

class PolicyPage extends StatelessWidget {
  final String id;
  const PolicyPage({super.key, required this.id});

  @override
  Widget build(BuildContext context) {
    final content = kPolicies[id];
    // About Us is just the brand mark, contact details and legal links — no header
    // row and no body copy. The other policy pages keep both.
    final isAbout = id == 'about';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text((content?.title ?? 'Policy').tr),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: content == null
          ? const Center(child: Text('Not found'))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (!isAbout) ...[
                  // Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.12), shape: BoxShape.circle),
                        child: Icon(content.icon, color: AppColors.primary, size: 26),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(content.title.tr, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                            const SizedBox(height: 2),
                            Text(content.subtitle.tr, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ...content.sections.map(_buildSection),
                ],
                if (isAbout) const _AboutFooter(),
                const SizedBox(height: 24),
              ],
            ),
    );
  }

  Widget _buildSection(PolicySection s) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (s.heading != null) ...[
            Text(s.heading!.tr, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.primary)),
            const Divider(height: 16, color: AppColors.border),
          ],
          ...s.paragraphs.map((p) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(p.tr, style: const TextStyle(fontSize: 13.5, color: AppColors.textSecondary, height: 1.5)),
              )),
          ...s.bullets.map((b) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 6),
                      child: Icon(Icons.circle, size: 6, color: AppColors.primary),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Text(b.tr, style: const TextStyle(fontSize: 13.5, color: AppColors.textPrimary, height: 1.5))),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}

/// About Us footer: brand mark, Contact Us (phone + email pulled from the admin
/// panel's platform settings) and the legal links.
class _AboutFooter extends StatefulWidget {
  const _AboutFooter();

  @override
  State<_AboutFooter> createState() => _AboutFooterState();
}

class _AboutFooterState extends State<_AboutFooter> {
  String _phone = '';
  String _phone2 = '';
  String _email = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      // Public settings endpoint — the admin edits these under Settings →
      // Contact Us Details, so support numbers change without an app release.
      final res = await getIt<ApiClient>().get('/settings');
      final s = (res.data['data'] ?? {}) as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        _phone = (s['supportPhone'] ?? '').toString().trim();
        _phone2 = (s['supportPhone2'] ?? '').toString().trim();
        _email = (s['supportEmail'] ?? '').toString().trim();
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _mail(String email) async {
    await launchUrl(Uri(scheme: 'mailto', path: email), mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final hasContact = _phone.isNotEmpty || _phone2.isNotEmpty || _email.isNotEmpty;

    return Column(
      children: [
        const SizedBox(height: 24),
        const AppLogo(size: 124, radius: 20),
        const SizedBox(height: 24),
        Text(
          "India's Trusted Taxi Requirement Network".tr,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 18),

        // Contact Us — hidden entirely when the admin hasn't set anything, rather
        // than showing an empty card.
        if (_loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2)),
          )
        else if (hasContact)
          _card(
            child: Column(
              children: [
                Text(
                  'Contact Us'.tr,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 12),
                if (_phone.isNotEmpty)
                  _contactTile(
                    icon: Icons.phone_rounded,
                    label: _phone,
                    onTap: () => callNumber(_phone),
                  ),
                // Fallback line — call this if the first is busy.
                if (_phone2.isNotEmpty) ...[
                  if (_phone.isNotEmpty) const SizedBox(height: 8),
                  _contactTile(
                    icon: Icons.phone_rounded,
                    label: _phone2,
                    onTap: () => callNumber(_phone2),
                  ),
                ],
                if ((_phone.isNotEmpty || _phone2.isNotEmpty) && _email.isNotEmpty) const SizedBox(height: 8),
                if (_email.isNotEmpty)
                  _contactTile(
                    icon: Icons.email_rounded,
                    label: _email,
                    onTap: () => _mail(_email),
                  ),
              ],
            ),
          ),

        const SizedBox(height: 4),
        _card(
          child: Column(
            children: [
              Text(
                'Legal'.tr,
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 4),
              _legalLink(context, 'Terms & Conditions', 'terms'),
              _legalLink(context, 'Privacy Policy', 'privacy'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: child,
    );
  }

  Widget _contactTile({required IconData icon, required String label, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: AppColors.primary),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                label,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _legalLink(BuildContext context, String label, String id) {
    return InkWell(
      // pushReplacement, not push: /policy/:id is the same route, so pushing would
      // stack About Us under itself and the back button would walk through copies.
      onTap: () => context.pushReplacement('/policy/$id'),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, size: 16, color: AppColors.textHint),
          ],
        ),
      ),
    );
  }
}
