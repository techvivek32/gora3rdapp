import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/network/api_client.dart';

// Shown once per app launch (not on every home rebuild / tab switch).
bool _adShownThisSession = false;

/// Fetch the active popup ad and show it once per app launch.
Future<void> maybeShowAdPopup(BuildContext context, ApiClient api) async {
  if (_adShownThisSession) return;
  _adShownThisSession = true;
  try {
    final res = await api.get('/popup-ads/active');
    final ad = (res.data['data']) as Map<String, dynamic>?;
    final imageUrl = (ad?['imageUrl'] ?? '').toString().trim();
    if (imageUrl.isEmpty) return;
    if (!context.mounted) return;

    // Preload the image (with a timeout) so the popup only appears when the image
    // is actually reachable — no empty popup, and no minutes-long hang if the URL
    // is unreachable (e.g. a private-IP upload host from mobile data).
    try {
      await precacheImage(CachedNetworkImageProvider(imageUrl), context)
          .timeout(const Duration(seconds: 6));
    } catch (_) {
      return;
    }
    if (!context.mounted) return;

    final linkUrl = (ad?['linkUrl'] ?? '').toString().trim();
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => _AdDialog(imageUrl: imageUrl, linkUrl: linkUrl),
    );
  } catch (_) {}
}

Future<void> _openLink(String url) async {
  try {
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  } catch (_) {}
}

class _AdDialog extends StatelessWidget {
  final String imageUrl;
  final String linkUrl;
  const _AdDialog({required this.imageUrl, required this.linkUrl});

  @override
  Widget build(BuildContext context) {
    final hasLink = linkUrl.isNotEmpty;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      child: Container(
        // White card, like the reference popup — image on top, CTA below with
        // padding all around it.
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Stack(
              children: [
                // The ad image — fixed 4:5 (portrait), fills the card width and
                // crops to fit (like banners) so it always looks consistent.
                GestureDetector(
                  onTap: hasLink
                      ? () { Navigator.of(context).pop(); _openLink(linkUrl); }
                      : null,
                  child: AspectRatio(
                    aspectRatio: 4 / 5,
                    child: CachedNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                      placeholder: (_, __) => Container(
                        color: Colors.white,
                        child: const Center(child: CircularProgressIndicator()),
                      ),
                      errorWidget: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  ),
                ),
                // Top-right close.
                Positioned(
                  top: 8,
                  right: 8,
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                      child: const Icon(Icons.close, size: 20, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
            // Bottom CTA — inside the white card with padding all around it.
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
              child: SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    if (hasLink) _openLink(linkUrl);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF6D00),
                    foregroundColor: Colors.white,
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text(hasLink ? 'Open' : 'Got It',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
