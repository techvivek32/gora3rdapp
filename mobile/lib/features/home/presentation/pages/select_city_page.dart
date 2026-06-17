import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_theme.dart';
import '../bloc/home_bloc.dart';

class SelectCityPage extends StatefulWidget {
  const SelectCityPage({super.key});

  @override
  State<SelectCityPage> createState() => _SelectCityPageState();
}

class _SelectCityPageState extends State<SelectCityPage> {
  final TextEditingController _searchController = TextEditingController();
  List<String> _filteredCities = [];
  bool _isSaving = false;
  bool _justSaved = false;

  @override
  void initState() {
    super.initState();
    _filteredCities = HomeBloc.availableCities;
  }

  void _filterCities(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredCities = HomeBloc.availableCities;
      } else {
        _filteredCities = HomeBloc.availableCities
            .where((city) => city.toLowerCase().contains(query.toLowerCase()))
            .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<HomeBloc, HomeState>(
      listener: (ctx, state) {
        if (state is HomeError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: AppColors.error,
            ),
          );
          setState(() {
            _isSaving = false;
            _justSaved = false;
          });
        } else if (state is HomeSavingCities) {
          setState(() {
            _isSaving = true;
            _justSaved = true;
          });
        } else if (state is HomeLoaded && _justSaved) {
          Navigator.of(context).pop();
        }
      },
      builder: (context, state) {
        final isLoading = state is HomeLoading || state is HomeSavingCities;
        return Scaffold(
          backgroundColor: const Color(0xFFF8F8F8),
          appBar: AppBar(
            backgroundColor: AppColors.primary,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: Text(
              'Select Your Cities',
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
          body: Column(
            children: [
              // Search bar
              Container(
                padding: EdgeInsets.all(16.w),
                color: Colors.white,
                child: TextField(
                  controller: _searchController,
                  onChanged: _filterCities,
                  decoration: InputDecoration(
                    hintText: 'Search cities...',
                    hintStyle: TextStyle(
                      color: const Color(0xFFAAAAAA),
                      fontSize: 14.sp,
                    ),
                    prefixIcon: Icon(
                      Icons.search,
                      color: AppColors.primary,
                      size: 22.sp,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14.r),
                      borderSide: BorderSide(color: AppColors.primary, width: 2),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14.r),
                      borderSide: BorderSide(color: AppColors.primary, width: 2),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14.r),
                      borderSide: BorderSide(color: AppColors.primary, width: 2),
                    ),
                    contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
                  ),
                ),
              ),

              // Selected cities section
              BlocBuilder<HomeBloc, HomeState>(
                builder: (context, state) {
                  final selectedCities = state is HomeLoaded ? state.selectedCities : <String>[];
                  if (selectedCities.isNotEmpty) {
                    return Container(
                      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Selected Cities (${selectedCities.length})',
                            style: TextStyle(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w700,
                              color: Colors.black,
                            ),
                          ),
                          SizedBox(height: 12.h),
                          Wrap(
                            spacing: 10.w,
                            runSpacing: 10.h,
                            children: selectedCities
                                .map(
                                  (city) => Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 14.w,
                                      vertical: 8.h,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(8.r),
                                      border: Border.all(
                                        color: AppColors.primary,
                                        width: 1.5,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          city,
                                          style: TextStyle(
                                            fontSize: 14.sp,
                                            color: AppColors.primary,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        SizedBox(width: 6.w),
                                        GestureDetector(
                                          onTap: () {
                                            context.read<HomeBloc>().add(ToggleCityEvent(city));
                                          },
                                          child: Container(
                                            width: 18.w,
                                            height: 18.w,
                                            decoration: BoxDecoration(
                                              color: AppColors.primary,
                                              shape: BoxShape.circle,
                                            ),
                                            child: Icon(
                                              Icons.close,
                                              color: Colors.white,
                                              size: 12.sp,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        ],
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),

              // Divider
              Container(
                height: 1,
                color: const Color(0xFFEEEEEE),
              ),

              // Cities list
              Expanded(
                child: BlocBuilder<HomeBloc, HomeState>(
                  builder: (context, state) {
                    final selectedCities = state is HomeLoaded ? state.selectedCities : <String>[];
                    return Container(
                      color: const Color(0xFFF8F8F8),
                      child: ListView.separated(
                        padding: EdgeInsets.symmetric(vertical: 4.h),
                        itemCount: _filteredCities.length,
                        separatorBuilder: (context, index) =>
                            Container(height: 1, color: const Color(0xFFEEEEEE)),
                        itemBuilder: (context, index) {
                          final city = _filteredCities[index];
                          final isSelected = selectedCities.contains(city);
                          return GestureDetector(
                            onTap: () {
                              context.read<HomeBloc>().add(ToggleCityEvent(city));
                            },
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 16.w,
                                vertical: 14.h,
                              ),
                              color: isSelected
                                  ? const Color(0xFFF0F0F0)
                                  : Colors.transparent,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    city,
                                    style: TextStyle(
                                      fontSize: 16.sp,
                                      color: Colors.black,
                                      fontWeight: isSelected
                                          ? FontWeight.w600
                                          : FontWeight.w400,
                                    ),
                                  ),
                                  Container(
                                    width: 24.w,
                                    height: 24.w,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: isSelected
                                          ? AppColors.primary
                                          : Colors.transparent,
                                      border: Border.all(
                                        color: isSelected
                                            ? AppColors.primary
                                            : const Color(0xFFAAAAAA),
                                        width: 2,
                                      ),
                                    ),
                                    child: isSelected
                                        ? Icon(
                                            Icons.check,
                                            color: Colors.white,
                                            size: 16.sp,
                                          )
                                        : null,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
              ),

              // Save button
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: 16.w,
                  vertical: 16.h,
                ),
                color: Colors.white,
                child: ElevatedButton(
                  onPressed: isLoading
                      ? null
                      : () {
                          context.read<HomeBloc>().add(const SaveSelectedCitiesEvent());
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    disabledBackgroundColor: AppColors.primary.withOpacity(0.5),
                    padding: EdgeInsets.symmetric(vertical: 16.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    minimumSize: Size(double.infinity, 50.h),
                  ),
                  child: isLoading
                      ? SizedBox(
                          width: 20.w,
                          height: 20.w,
                          child: const CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          'Save & Continue',
                          style: TextStyle(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
