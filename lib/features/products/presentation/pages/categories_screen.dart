import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/routes.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/network_image_widget.dart';
import '../../../../injection.dart';
import '../../../../l10n/app_strings.dart';
import '../../../../shared/models/category.dart';
import '../../domain/repositories/category_repository.dart';

/// شاشة الفئات
///
/// ⚠️ تُقرأ الفئات من Firestore عبر [CategoryRepository] (نفس المستودع
/// المستخدَم في قسم "تسوّق حسب احتياجك" بالشاشة الرئيسية) — كانت هذه
/// الشاشة سابقاً تعرض قائمة ثابتة في الكود (DemoData.categories) بمعرّفات
/// وهمية لا تطابق أي فئة حقيقية يديرها المدير؛ الإصلاح يجعل أي فئة
/// يضيفها المدير من لوحة التحكم تظهر هنا فوراً بلا تحديث للتطبيق.
class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  late final Future<List<Category>> _future =
      sl<CategoryRepository>().getCategories();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.categories)),
      body: FutureBuilder<List<Category>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final categories = snapshot.data ?? const <Category>[];
          if (categories.isEmpty) {
            return const Center(child: Text(AppStrings.noData));
          }
          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 1.3,
            ),
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final category = categories[index];
              return InkWell(
                onTap: () => context.push(
                  AppRoutes.productsByCategoryLink(category.id),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.secondary, AppColors.secondaryDark],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ClipOval(
                        child: SizedBox(
                          width: 56,
                          height: 56,
                          child: category.image.isNotEmpty
                              ? NetworkImageWidget(imageUrl: category.image)
                              : Container(
                                  color: Colors.white.withValues(alpha: 0.15),
                                  child: const Icon(
                                    Icons.diamond_outlined,
                                    color: Colors.white,
                                    size: 28,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          category.name,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
