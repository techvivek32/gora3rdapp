import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../bloc/requirements_bloc.dart';

class RequirementDetailPage extends StatefulWidget {
  final String requirementId;
  final Map<String, dynamic>? requirement;
  const RequirementDetailPage({super.key, required this.requirementId, this.requirement});

  @override
  State<RequirementDetailPage> createState() => _RequirementDetailPageState();
}

class _RequirementDetailPageState extends State<RequirementDetailPage> {
  Map<String, dynamic>? _requirement;

  @override
  void initState() {
    super.initState();
    if (widget.requirement != null) {
      _requirement = widget.requirement;
    } else {
      context.read<RequirementsBloc>().add(LoadRequirementDetailEvent(widget.requirementId));
    }
  }

  IconData _getTripTypeIcon(String? tripType) {
    switch (tripType) {
      case 'one_way': return Icons.arrow_forward;
      case 'round_trip': return Icons.loop;
      case 'airport_transfer': return Icons.flight;
      case 'local': return Icons.location_city;
      case 'outstation': return Icons.map;
      default: return Icons.route;
    }
  }

  String _formatDate(dynamic date) {
    if (date == null) return '-';
    try {
      final d = DateTime.parse(date.toString());
      const months = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${d.day} ${months[d.month]} ${d.year}';
    } catch (_) {
      return date.toString();
    }
  }

  String _formatVehicleType(String? type) {
    if (type == null) return '';
    return type.split('_').map((w) => w[0].toUpperCase() + w.substring(1)).join(' ') + ' Car';
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<RequirementsBloc, RequirementsState>(
      listener: (context, state) {
        if (state is RequirementDetailLoaded) {
          setState(() => _requirement = state.requirement);
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.primary,
          elevation: 4,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => context.pop(),
          ),
          title: _requirement != null
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_formatDate(_requirement!['travelDate']), style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold, color: Colors.white)),
                    Text(_requirement!['travelTime'] as String? ?? '', style: TextStyle(fontSize: 12.sp, color: Colors.white70)),
                  ],
                )
              : Text('Requirement Detail', style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold, color: Colors.white)),
        ),
        body: _requirement == null
            ? const Center(child: CircularProgressIndicator())
            : _buildBody(_requirement!),
        bottomNavigationBar: _requirement != null
            ? SafeArea(
                child: Padding(
                  padding: EdgeInsets.all(16.r),
                  child: ElevatedButton.icon(
                    onPressed: () => context.read<RequirementsBloc>().add(AcceptRequirementEvent(widget.requirementId)),
                    icon: const Icon(Icons.check_circle_outline, color: Colors.white),
                    label: const Text('Accept Requirement', style: TextStyle(color: Colors.white, fontSize: 15)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: EdgeInsets.symmetric(vertical: 14.h),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
                    ),
                  ),
                ),
              )
            : null,
      ),
    );
  }

  Widget _buildBody(Map<String, dynamic> req) {
    final postedBy = req['postedBy'] as Map<String, dynamic>?;
    final isPremiumUser = postedBy != null && postedBy['mobile'] != null;

    return SingleChildScrollView(
      padding: EdgeInsets.all(16.r),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Route card
          _card(
            title: 'Route',
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Column(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(width: 12.w, height: 12.h, decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle)),
                            Container(width: 2.w, height: 30.h, color: Colors.grey[400]),
                            Container(width: 12.w, height: 12.h, decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle)),
                          ],
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(req['pickupCity'] as String? ?? '', style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold, color: Colors.black)),
                              if (req['pickupState'] != null)
                                Text(req['pickupState'] as String, style: TextStyle(fontSize: 12.sp, color: Colors.grey[600])),
                              SizedBox(height: 16.h),
                              Text(req['dropCity'] as String? ?? '', style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold, color: Colors.black)),
                              if (req['dropState'] != null)
                                Text(req['dropState'] as String, style: TextStyle(fontSize: 12.sp, color: Colors.grey[600])),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (req['estimatedDistance'] != null)
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('${req['estimatedDistance']}', style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.bold, color: Colors.green)),
                        Text('KM', style: TextStyle(fontSize: 10.sp, color: Colors.grey[600])),
                      ],
                    ),
                ],
              ),
            ),
          ),
          SizedBox(height: 12.h),

          // Trip details card
          _card(
            title: 'Trip Details',
            child: Column(
              children: [
                _infoRow(Icons.directions_car, 'Vehicle', _formatVehicleType(req['vehicleType'])),
                _infoRow(Icons.confirmation_number_outlined, 'Vehicles Needed', '${req['numberOfVehicles'] ?? 1}'),
                _infoRow(Icons.calendar_today_outlined, 'Travel Date', _formatDate(req['travelDate'])),
                _infoRow(Icons.access_time, 'Travel Time', req['travelTime'] as String? ?? '-'),
                _infoRow(_getTripTypeIcon(req['tripType']), 'Trip Type', (req['tripType'] as String? ?? '').replaceAll('_', ' ').toUpperCase()),
                if (req['notes'] != null && (req['notes'] as String).isNotEmpty)
                  _infoRow(Icons.notes, 'Notes', req['notes'] as String),
              ],
            ),
          ),
          SizedBox(height: 12.h),

          // Posted By card
          _card(
            title: 'Posted By',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 24.r,
                      backgroundColor: AppColors.primary.withOpacity(0.1),
                      backgroundImage: postedBy?['profileImage'] != null ? NetworkImage(postedBy!['profileImage'] as String) : null,
                      child: postedBy?['profileImage'] == null ? Icon(Icons.person, color: AppColors.primary) : null,
                    ),
                    SizedBox(width: 12.w),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(postedBy?['fullName'] as String? ?? 'Hidden', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.sp, color: Colors.black)),
                        if (postedBy?['agencyName'] != null)
                          Text(postedBy!['agencyName'] as String, style: TextStyle(fontSize: 12.sp, color: Colors.grey[600])),
                      ],
                    ),
                  ],
                ),
                if (!isPremiumUser) ...[
                  SizedBox(height: 12.h),
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(12.r),
                    decoration: BoxDecoration(
                      color: Colors.amber[50],
                      borderRadius: BorderRadius.circular(8.r),
                      border: Border.all(color: Colors.amber.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.lock_outline, color: Colors.amber[700]),
                        SizedBox(width: 8.w),
                        Expanded(child: Text('Upgrade to Premium to view contact details', style: TextStyle(fontSize: 12.sp, color: Colors.amber[800]))),
                      ],
                    ),
                  ),
                  SizedBox(height: 8.h),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => context.push('/subscriptions'),
                      icon: const Icon(Icons.star, color: Colors.amber),
                      label: const Text('Upgrade to Premium'),
                    ),
                  ),
                ] else ...[
                  SizedBox(height: 12.h),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                      onPressed: () {},
                      icon: const Icon(Icons.call, color: Colors.white),
                      label: Text('Call ${postedBy!['mobile']}', style: const TextStyle(color: Colors.white)),
                    ),
                  ),
                ],
              ],
            ),
          ),
          SizedBox(height: 32.h),
        ],
      ),
    );
  }

  Widget _card({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: Colors.black26, width: 1),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 1))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 4.h,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.only(topLeft: Radius.circular(8.r), topRight: Radius.circular(8.r)),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(14.r),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.bold, color: AppColors.primary)),
                Divider(height: 12.h, thickness: 1, color: Colors.black26),
                child,
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 5.h),
      child: Row(
        children: [
          Icon(icon, size: 16.sp, color: AppColors.primary),
          SizedBox(width: 10.w),
          Text('$label: ', style: TextStyle(fontSize: 13.sp, color: Colors.grey[600])),
          Expanded(child: Text(value, style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.bold, color: Colors.black))),
        ],
      ),
    );
  }
}
