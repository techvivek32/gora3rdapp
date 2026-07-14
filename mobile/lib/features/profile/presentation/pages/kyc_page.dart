import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_theme.dart';

class _KycDoc {
  final String key; // backend: aadhar, pan, drivingLicense, vehicleRc
  final String label;
  final TextEditingController numberCtrl = TextEditingController();
  String? existingImage; // front URL already on the server
  String? existingBackImage; // back URL already on the server
  Uint8List? newBytes; // freshly picked front image
  Uint8List? newBackBytes; // freshly picked back image

  /// Per-document review state from the admin: 'pending' | 'approved' | 'rejected'.
  /// The admin can approve the Aadhaar and reject only the PAN, so each document
  /// carries its own verdict — an approved one is final and can't be re-uploaded.
  String status = 'pending';
  String? rejectionReason;

  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';

  _KycDoc(this.key, this.label);
}

class KycPage extends StatefulWidget {
  const KycPage({super.key});

  @override
  State<KycPage> createState() => _KycPageState();
}

class _KycPageState extends State<KycPage> {
  final _apiClient = getIt<ApiClient>();
  final _picker = ImagePicker();

  bool _loading = true;
  bool _submitting = false;
  String _status = 'none';
  String? _rejectionReason;
  String _role = 'driver';

  final Map<String, _KycDoc> _docs = {
    'aadhar': _KycDoc('aadhar', 'Aadhaar Card'),
    'pan': _KycDoc('pan', 'PAN Card'),
    'drivingLicense': _KycDoc('drivingLicense', 'Driving License'),
    'vehicleRc': _KycDoc('vehicleRc', 'Vehicle RC'),
  };

  List<String> get _visibleKeys => _role == 'driver'
      ? ['aadhar', 'pan', 'drivingLicense', 'vehicleRc']
      : ['aadhar', 'pan', 'drivingLicense'];

  // Documents can only be edited/submitted when the verification hasn't been sent
  // yet or was rejected. Pending & verified are read-only.
  bool get _locked => _status == 'pending' || _status == 'verified';

  /// A single document is locked when the whole form is, OR when this particular
  /// document has already been approved — the user only needs to redo the ones
  /// the admin actually rejected.
  bool _docLocked(_KycDoc doc) => _locked || doc.isApproved;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final d in _docs.values) {
      d.numberCtrl.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final res = await _apiClient.get('/users/profile');
      final user = Map<String, dynamic>.from(res.data['data'] as Map);
      final documents = (user['documents'] as Map?) ?? {};
      for (final key in _docs.keys) {
        final entry = documents[key] as Map?;
        if (entry != null) {
          _docs[key]!.numberCtrl.text = (entry['number'] ?? '').toString();
          _docs[key]!.existingImage = entry['image'] as String?;
          _docs[key]!.existingBackImage = entry['backImage'] as String?;
          // Older rows have no status — treat them as pending.
          _docs[key]!.status = (entry['status'] as String?) ?? 'pending';
          _docs[key]!.rejectionReason = entry['rejectionReason'] as String?;
        }
      }
      if (mounted) {
        setState(() {
          _role = (user['role'] as String?) ?? 'driver';
          _status = (user['verificationStatus'] as String?) ?? 'none';
          _rejectionReason = user['verificationRejectionReason'] as String?;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickImage(_KycDoc doc, {required bool back}) async {
    final picked = await _picker.pickImage(source: ImageSource.gallery, maxWidth: 1200, imageQuality: 80);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    setState(() {
      if (back) {
        doc.newBackBytes = bytes;
      } else {
        doc.newBytes = bytes;
      }
    });
  }

  Future<String> _uploadImage(Uint8List bytes, String name) async {
    FormData buildForm() => FormData.fromMap({
          'file': MultipartFile.fromBytes(bytes, filename: '$name.jpg'),
          'folder': 'documents',
        });
    Response res;
    try {
      res = await _apiClient.dio.post('/storage/upload', data: buildForm());
    } catch (_) {
      res = await _apiClient.dio.post('/storage/upload', data: buildForm());
    }
    return res.data['data'] as String;
  }

  void _snack(String msg, {bool error = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: error ? AppColors.error : AppColors.success),
    );
  }

  Future<void> _submit() async {
    // Require at least one document with both a number and an image.
    final hasAny = _visibleKeys.any((k) {
      final d = _docs[k]!;
      return d.numberCtrl.text.trim().isNotEmpty && (d.newBytes != null || d.existingImage != null);
    });
    if (!hasAny) {
      _snack('Add at least one document (number + photo) to submit');
      return;
    }

    setState(() => _submitting = true);
    try {
      // Send ALL provided documents (the backend replaces the whole set).
      final body = <String, dynamic>{};
      for (final key in _visibleKeys) {
        final d = _docs[key]!;
        final hasNumber = d.numberCtrl.text.trim().isNotEmpty;
        final image = d.newBytes != null ? await _uploadImage(d.newBytes!, '${key}_front') : d.existingImage;
        final backImage = d.newBackBytes != null ? await _uploadImage(d.newBackBytes!, '${key}_back') : d.existingBackImage;
        if (!hasNumber && image == null && backImage == null) continue;
        final entry = <String, dynamic>{};
        if (hasNumber) entry['number'] = d.numberCtrl.text.trim();
        if (image != null) entry['image'] = image;
        if (backImage != null) entry['backImage'] = backImage;
        body[key] = entry;
      }

      await _apiClient.dio.post('/users/verification', data: body);
      if (!mounted) return;
      _snack('Documents submitted for verification.', error: false);
      await _load();
    } catch (_) {
      _snack('Could not submit documents. Please try again.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('KYC Verification'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _statusBanner(),
                  const SizedBox(height: 16),
                  const Text('Documents', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(
                    _locked
                        ? (_status == 'verified'
                            ? 'Your documents are verified and can no longer be changed.'
                            : 'Your documents are under review. You can\'t change them until the review is complete.')
                        : 'Add your document number and a clear photo, then submit for verification.',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 12),
                  ..._visibleKeys.map((k) => _buildDocTile(_docs[k]!)),
                  const SizedBox(height: 16),
                  // Only submittable before first submission or after a rejection.
                  if (!_locked)
                    ElevatedButton(
                      onPressed: _submitting ? null : _submit,
                      style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                      child: _submitting
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Text(_status == 'rejected' ? 'Re-submit Documents' : 'Submit for Verification',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  Widget _statusBanner() {
    late Color color;
    late IconData icon;
    late String title;
    late String subtitle;
    switch (_status) {
      case 'verified':
        color = AppColors.success;
        icon = Icons.verified;
        title = 'Verified';
        subtitle = 'Your documents have been verified.';
        break;
      case 'pending':
        color = Colors.amber.shade700;
        icon = Icons.hourglass_top;
        title = 'Pending Review';
        subtitle = 'Your documents are under review by our team.';
        break;
      case 'rejected':
        color = AppColors.error;
        icon = Icons.cancel;
        title = 'Rejected';
        subtitle = _rejectionReason ?? 'Please re-upload valid documents.';
        break;
      default:
        color = AppColors.textHint;
        icon = Icons.info_outline;
        title = 'Not Submitted';
        subtitle = 'Upload your documents to get verified.';
    }
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontWeight: FontWeight.w700, color: color)),
                Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusChip(_KycDoc doc) {
    final approved = doc.isApproved;
    final color = approved ? AppColors.success : AppColors.error;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        approved ? 'Approved' : 'Rejected',
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color),
      ),
    );
  }

  Widget _buildDocTile(_KycDoc doc) {
    final hasData = doc.newBytes != null ||
        doc.existingImage != null ||
        doc.newBackBytes != null ||
        doc.existingBackImage != null ||
        doc.numberCtrl.text.trim().isNotEmpty;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          key: PageStorageKey('kyc_${doc.key}'),
          maintainState: true,
          leading: const Icon(Icons.description_outlined),
          title: Row(
            children: [
              Flexible(child: Text(doc.label, style: const TextStyle(fontWeight: FontWeight.w600))),
              // Each document carries its own verdict from the admin.
              if (doc.isApproved || doc.isRejected) ...[
                const SizedBox(width: 8),
                _statusChip(doc),
              ],
            ],
          ),
          // The icon shows the admin's verdict, not merely "something was filled in":
          // approved → green tick, rejected → red cross, otherwise pending/empty.
          trailing: doc.isApproved
              ? const Icon(Icons.check_circle, color: AppColors.success, size: 20)
              : doc.isRejected
                  ? const Icon(Icons.cancel, color: AppColors.error, size: 20)
                  : hasData
                      ? const Icon(Icons.schedule, color: AppColors.warning, size: 20)
                      : const Icon(Icons.keyboard_arrow_down),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          children: [
            if (doc.isRejected && (doc.rejectionReason ?? '').isNotEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Rejected: ${doc.rejectionReason}\nPlease upload this document again.',
                  style: const TextStyle(fontSize: 12, color: AppColors.error),
                ),
              ),
            ],
            if (doc.isApproved) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Approved — this document is verified and cannot be changed.',
                  style: TextStyle(fontSize: 12, color: AppColors.success),
                ),
              ),
            ],
            TextField(
              controller: doc.numberCtrl,
              enabled: !_docLocked(doc),
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: '${doc.label} Number',
                isDense: true,
                prefixIcon: const Icon(Icons.badge_outlined),
              ),
            ),
            const SizedBox(height: 12),
            _sideBox(doc, back: false),
            const SizedBox(height: 12),
            _sideBox(doc, back: true),
          ],
        ),
      ),
    );
  }

  // One full-width upload box for a document side (front or back).
  Widget _sideBox(_KycDoc doc, {required bool back}) {
    final Uint8List? newBytes = back ? doc.newBackBytes : doc.newBytes;
    final String? existing = back ? doc.existingBackImage : doc.existingImage;
    final label = back ? 'Back Side' : 'Front Side';
    final hasImage = newBytes != null || existing != null;

    final locked = _docLocked(doc); // approved documents can't be replaced

    Widget content;
    if (newBytes != null) {
      content = _imageWithEdit(Image.memory(newBytes, fit: BoxFit.cover), locked: locked);
    } else if (existing != null) {
      content = _imageWithEdit(Image.network(existing, fit: BoxFit.cover), locked: locked);
    } else {
      content = Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.add_a_photo_outlined, color: AppColors.primary, size: 28),
          const SizedBox(height: 8),
          Text('Tap to upload $label', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
        ],
      );
    }

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
          onTap: locked ? null : () => _pickImage(doc, back: back),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            height: 150,
            width: double.infinity,
            decoration: BoxDecoration(
              color: hasImage ? Colors.grey.shade100 : AppColors.primary.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: hasImage ? Colors.grey.shade300 : AppColors.primary.withValues(alpha: 0.35),
                width: 1.2,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: content,
          ),
        ),
      ],
    );
  }

  Widget _imageWithEdit(Widget image, {bool locked = false}) {
    return Stack(
      fit: StackFit.expand,
      children: [
        image,
        if (!locked)
          Positioned(
            right: 8,
            top: 8,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
              child: const Icon(Icons.edit, color: Colors.white, size: 16),
            ),
          ),
      ],
    );
  }
}
