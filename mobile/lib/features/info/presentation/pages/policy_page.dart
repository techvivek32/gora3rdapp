import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

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
  'about': PolicyContent(
    title: 'About Us',
    icon: Icons.local_taxi_rounded,
    subtitle: 'About Gora Cabs',
    sections: [
      PolicySection(paragraphs: [
        'Welcome to Gora Cabs — your trusted partner for taxi requirement and available-cab networking. We connect travel agencies, fleet owners and drivers on one platform to make transportation operations smooth and reliable.',
        'Our mission is to simplify business by offering transparent pricing, verified members and a secure way to find and post requirements across India.',
        'We pride ourselves on trust and safety. Verified KYC, a security wallet system and clear policies help keep every deal fair for both sides.',
        'Thank you for choosing Gora Cabs. Made in India, crafted in Rajasthan.',
      ]),
    ],
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
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(content?.title ?? 'Policy'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: content == null
          ? const Center(child: Text('Not found'))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
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
                          Text(content.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                          const SizedBox(height: 2),
                          Text(content.subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ...content.sections.map(_buildSection),
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
            Text(s.heading!, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.primary)),
            const Divider(height: 16, color: AppColors.border),
          ],
          ...s.paragraphs.map((p) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(p, style: const TextStyle(fontSize: 13.5, color: AppColors.textSecondary, height: 1.5)),
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
                    Expanded(child: Text(b, style: const TextStyle(fontSize: 13.5, color: AppColors.textPrimary, height: 1.5))),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}
