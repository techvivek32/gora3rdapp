import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../theme/app_theme.dart';
import 'app_translations.dart';
import 'locale_controller.dart';

/// Language picker. Selecting a language persists it and rebuilds the whole app
/// (MaterialApp listens to LocaleController), so the change is instant.
class LanguagePage extends StatefulWidget {
  const LanguagePage({super.key});

  @override
  State<LanguagePage> createState() => _LanguagePageState();
}

class _LanguagePageState extends State<LanguagePage> {
  @override
  Widget build(BuildContext context) {
    final current = LocaleController.instance.lang;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Language'.tr, style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold, fontSize: 18.sp)),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: ListView.separated(
        padding: EdgeInsets.symmetric(vertical: 8.h),
        itemCount: kSupportedLanguages.length,
        separatorBuilder: (_, __) => Divider(height: 1, color: AppColors.border, indent: 16.w, endIndent: 16.w),
        itemBuilder: (_, i) {
          final l = kSupportedLanguages[i];
          final selected = l.code == current;
          return ListTile(
            onTap: () async {
              await LocaleController.instance.setLanguage(l.code);
              if (context.mounted) Navigator.pop(context);
            },
            title: Text(l.native,
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                  color: selected ? AppColors.primary : AppColors.textPrimary,
                  fontFamily: 'Poppins',
                )),
            subtitle: Text(l.english, style: TextStyle(fontSize: 12.sp, color: AppColors.textSecondary, fontFamily: 'Poppins')),
            trailing: selected ? const Icon(Icons.check_circle, color: AppColors.primary) : null,
          );
        },
      ),
    );
  }
}
