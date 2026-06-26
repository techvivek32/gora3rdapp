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
  String? existingImage; // URL already on the server
  Uint8List? newBytes; // freshly picked image
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

  Future<void> _pickImage(_KycDoc doc) async {
    final picked = await _picker.pickImage(source: ImageSource.gallery, maxWidth: 1200, imageQuality: 80);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    setState(() => doc.newBytes = bytes);
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
        final image = d.newBytes != null ? await _uploadImage(d.newBytes!, key) : d.existingImage;
        if (!hasNumber && image == null) continue;
        final entry = <String, dynamic>{};
        if (hasNumber) entry['number'] = d.numberCtrl.text.trim();
        if (image != null) entry['image'] = image;
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
                  const Text(
                    'Add your document number and a clear photo, then submit for verification.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 12),
                  ..._visibleKeys.map((k) => _buildDocTile(_docs[k]!)),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _submitting ? null : _submit,
                    style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                    child: _submitting
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text(_status == 'verified' ? 'Update Documents' : 'Submit for Verification',
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

  Widget _buildDocTile(_KycDoc doc) {
    final hasData = doc.newBytes != null || (doc.existingImage != null) || doc.numberCtrl.text.trim().isNotEmpty;
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
          title: Text(doc.label, style: const TextStyle(fontWeight: FontWeight.w600)),
          trailing: hasData
              ? const Icon(Icons.check_circle, color: Colors.green, size: 20)
              : const Icon(Icons.keyboard_arrow_down),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          children: [
            TextField(
              controller: doc.numberCtrl,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: '${doc.label} Number',
                isDense: true,
                prefixIcon: const Icon(Icons.badge_outlined),
              ),
            ),
            const SizedBox(height: 10),
            InkWell(
              onTap: () => _pickImage(doc),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                height: 140,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                clipBehavior: Clip.antiAlias,
                child: doc.newBytes != null
                    ? _imageWithEdit(Image.memory(doc.newBytes!, fit: BoxFit.cover))
                    : (doc.existingImage != null
                        ? _imageWithEdit(Image.network(doc.existingImage!, fit: BoxFit.cover))
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.cloud_upload_outlined, color: Colors.grey.shade500, size: 28),
                              const SizedBox(height: 6),
                              Text('Upload ${doc.label} photo', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                            ],
                          )),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _imageWithEdit(Widget image) {
    return Stack(
      fit: StackFit.expand,
      children: [
        image,
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
