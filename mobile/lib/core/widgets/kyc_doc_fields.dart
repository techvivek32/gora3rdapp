import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../network/api_client.dart';
import '../utils/image_source_picker.dart';

/// One KYC document being filled in: the front and back photos the user picked,
/// held in memory until the form is submitted.
///
/// Shared by registration AND the customer→driver switch, so the two forms ask
/// for exactly the same thing. Keeping one definition is the point: when these
/// drifted apart, someone switching to Driver Mode skipped the KYC that a new
/// driver signing up had to complete, and arrived unverified.
class KycDocField {
  KycDocField(this.key, this.label);

  final String key;
  final String label;
  Uint8List? bytes;
  Uint8List? backBytes;

  bool get isComplete => bytes != null && backBytes != null;
}

/// The documents every driver must provide. (PAN and Vehicle RC were dropped.)
List<KycDocField> defaultKycDocs() => [
      KycDocField('aadhar', 'Aadhaar Card'),
      KycDocField('drivingLicense', 'Driving License'),
    ];

/// The documents still missing a side, by label — empty when the set is complete.
List<String> missingKycDocLabels(List<KycDocField> docs) =>
    docs.where((d) => !d.isComplete).map((d) => d.label).toList();

/// Upload every document's two sides and submit them for verification.
///
/// Mirrors what registration does: each image goes to storage first, then the
/// resulting URLs are posted together so the admin sees one submission.
Future<void> submitKycDocs(ApiClient api, List<KycDocField> docs) async {
  Future<String> upload(Uint8List bytes, String name) async {
    // FormData streams are consumed on first use, so build a fresh one for each
    // attempt — otherwise the auth interceptor's token-refresh retry fails.
    FormData form() => FormData.fromMap({
          'file': MultipartFile.fromBytes(bytes, filename: '$name.jpg'),
          'folder': 'documents',
        });
    Response res;
    try {
      res = await api.dio.post('/storage/upload', data: form());
    } catch (_) {
      res = await api.dio.post('/storage/upload', data: form());
    }
    return res.data['data'] as String;
  }

  final body = <String, dynamic>{};
  for (final d in docs) {
    if (d.bytes == null || d.backBytes == null) continue;
    body[d.key] = {
      'image': await upload(d.bytes!, '${d.key}_front'),
      'backImage': await upload(d.backBytes!, '${d.key}_back'),
    };
  }
  if (body.isNotEmpty) await api.dio.post('/users/verification', data: body);
}

/// Expandable card for one document, with a full-width upload box per side.
class KycDocTile extends StatelessWidget {
  const KycDocTile({super.key, required this.doc, required this.onChanged});

  final KycDocField doc;

  /// Called after a photo is picked so the parent can rebuild (the bytes live
  /// on [doc], which this widget mutates in place).
  final VoidCallback onChanged;

  Future<void> _pick(BuildContext context, {required bool back}) async {
    final picked = await pickImageFromCameraOrGallery(
      context,
      maxWidth: 1200,
      title: '${doc.label} — ${back ? 'Back' : 'Front'}',
    );
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    if (back) {
      doc.backBytes = bytes;
    } else {
      doc.bytes = bytes;
    }
    onChanged();
  }

  Widget _sideBox(BuildContext context, {required bool back}) {
    final Uint8List? bytes = back ? doc.backBytes : doc.bytes;
    final label = back ? 'Back Side' : 'Front Side';
    final primary = Theme.of(context).primaryColor;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(back ? Icons.flip_to_back : Icons.flip_to_front, size: 14, color: Colors.grey.shade600),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
          ],
        ),
        const SizedBox(height: 6),
        InkWell(
          onTap: () => _pick(context, back: back),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            height: 150,
            width: double.infinity,
            decoration: BoxDecoration(
              color: bytes != null ? Colors.grey.shade100 : primary.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: bytes != null ? Colors.grey.shade300 : primary.withValues(alpha: 0.35),
                width: 1.2,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: bytes != null
                ? Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.memory(bytes, fit: BoxFit.cover),
                      Positioned(
                        right: 8,
                        top: 8,
                        child: Container(
                          padding: const EdgeInsets.all(5),
                          decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                          child: const Icon(Icons.edit, color: Colors.white, size: 16),
                        ),
                      ),
                    ],
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_a_photo_outlined, color: primary, size: 28),
                      const SizedBox(height: 8),
                      Text('Tap to upload $label', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        // Hide the default ExpansionTile top/bottom dividers.
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          key: PageStorageKey('doc_${doc.key}'),
          maintainState: true,
          tilePadding: const EdgeInsets.symmetric(horizontal: 14),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          leading: const Icon(Icons.description_outlined),
          title: Text(doc.label, style: const TextStyle(fontWeight: FontWeight.w600)),
          trailing: doc.isComplete
              ? const Icon(Icons.check_circle, color: Colors.green, size: 20)
              : const Icon(Icons.keyboard_arrow_down),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text('Upload clear photos of both sides (required).',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            ),
            const SizedBox(height: 12),
            _sideBox(context, back: false),
            const SizedBox(height: 12),
            _sideBox(context, back: true),
          ],
        ),
      ),
    );
  }
}
