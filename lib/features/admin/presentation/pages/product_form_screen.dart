import 'dart:async';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/network_image_widget.dart';
import '../../../../injection.dart';
import '../../../../l10n/app_strings.dart';
import '../../../../shared/models/category.dart';
import '../../../../shared/models/product.dart';
import '../../../../shared/services/push_trigger_service.dart';
import '../../../../shared/services/storage_service.dart';
import '../../../products/domain/repositories/category_repository.dart';
import '../../../products/domain/repositories/product_repository.dart';
import '../../domain/repositories/admin_repository.dart';
import '../widgets/admin_widgets.dart';

/// نموذج إضافة/تعديل منتج
class ProductFormScreen extends StatefulWidget {
  const ProductFormScreen({super.key, this.product});

  final Product? product;

  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _name;
  late final TextEditingController _description;
  late final TextEditingController _price;
  late final TextEditingController _discountPrice;
  late final TextEditingController _stock;
  late final TextEditingController _sku;
  late final TextEditingController _brand;
  late final TextEditingController _weight;

  String? _categoryId;
  bool _isFeatured = false;
  final List<String> _images = [];
  bool _uploading = false;
  bool _saving = false;

  bool get _isEdit => widget.product != null;

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _name = TextEditingController(text: p?.name ?? '');
    _description = TextEditingController(text: p?.description ?? '');
    _price = TextEditingController(
      text: p != null ? p.price.toStringAsFixed(2) : '',
    );
    _discountPrice = TextEditingController(
      text: p?.discountPrice?.toStringAsFixed(2) ?? '',
    );
    _stock = TextEditingController(text: p?.stock.toString() ?? '0');
    _sku = TextEditingController(text: p?.sku ?? '');
    _brand = TextEditingController(text: p?.brand ?? '');
    _weight = TextEditingController(text: p?.weight?.toString() ?? '');
    _categoryId = p?.categoryId;
    _isFeatured = p?.isFeatured ?? false;
    if (p != null) _images.addAll(p.images);
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _price.dispose();
    _discountPrice.dispose();
    _stock.dispose();
    _sku.dispose();
    _brand.dispose();
    _weight.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final picker = ImagePicker();
    final files = await picker.pickMultiImage(limit: 6);
    if (files.isEmpty) return;
    setState(() => _uploading = true);
    try {
      final productId = widget.product?.id ??
          'p-${DateTime.now().millisecondsSinceEpoch}';
      for (final file in files) {
        final bytes = await file.readAsBytes();
        final result = await StorageService.instance.uploadProductImage(
          productId: productId,
          bytes: bytes,
          extension: file.name.split('.').last.toLowerCase(),
        );
        setState(() => _images.add(result.url));
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(AppStrings.imagesUploaded)),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(AppStrings.uploadFailed)),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_categoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.selectCategory)),
      );
      return;
    }
    setState(() => _saving = true);

    final id = widget.product?.id ??
        'p-${DateTime.now().millisecondsSinceEpoch}';
    final product = Product(
      id: id,
      name: _name.text.trim(),
      description: _description.text.trim(),
      price: double.tryParse(_price.text) ?? 0,
      discountPrice: _discountPrice.text.trim().isEmpty
          ? null
          : double.tryParse(_discountPrice.text),
      images: _images,
      categoryId: _categoryId!,
      stock: int.tryParse(_stock.text) ?? 0,
      rating: widget.product?.rating ?? 0,
      reviewCount: widget.product?.reviewCount ?? 0,
      specifications: widget.product?.specifications ?? const {},
      isFeatured: _isFeatured,
      sku: _sku.text.trim(),
      brand: _brand.text.trim(),
      weight: _weight.text.trim().isEmpty
          ? null
          : double.tryParse(_weight.text),
      createdAt: widget.product?.createdAt ?? DateTime.now(),
      views: widget.product?.views ?? 0,
      soldCount: widget.product?.soldCount ?? 0,
    );

    final repo = sl<ProductRepository>();
    try {
      if (_isEdit) {
        await repo.updateProduct(product);
      } else {
        await repo.addProduct(product);
        // إشعار المستخدمين عند نشر منتج جديد (لا يمنع فشله حفظ المنتج)
        unawaited(_sendNewProductNotification(product));
      }
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(AppStrings.saveFailed)),
        );
      }
    }
  }

  /// تسجيل إشعار "منتج جديد" لكل المستخدمين — إشعار داخل التطبيق فوري
  /// (بلا خادم) + محاولة إرسال Push فعلي عبر push-server/ إن كان مُعدّاً
  Future<void> _sendNewProductNotification(Product product) async {
    final title = AppStrings.newProductNotifTitle;
    final body =
        AppStrings.newProductNotifBody.replaceFirst('{name}', product.name);
    try {
      await sl<AdminRepository>().sendNotification(
        AdminNotification(
          id: 'n-${DateTime.now().millisecondsSinceEpoch}',
          title: title,
          body: body,
          target: NotificationTarget.all,
          type: 'product',
          linkId: product.id,
          createdAt: DateTime.now(),
        ),
      );
    } catch (_) {
      // تجاهل — فشل الإشعار لا يمنع نشر المنتج
    }
    unawaited(PushTriggerService.instance.notify(
      title: title,
      body: body,
      type: 'product',
      linkId: product.id,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? AppStrings.editProduct : AppStrings.addProduct),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            AdminSectionCard(
              title: AppStrings.productImages,
              icon: Icons.image_outlined,
              child: SizedBox(
                height: 90,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    for (final image in _images)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: SizedBox(
                                width: 80,
                                height: 80,
                                child: NetworkImageWidget(imageUrl: image),
                              ),
                            ),
                            Positioned(
                              top: 0,
                              right: 0,
                              child: InkWell(
                                onTap: () =>
                                    setState(() => _images.remove(image)),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.black54,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const Icon(
                                    Icons.close,
                                    size: 16,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: InkWell(
                        onTap: _uploading ? null : _pickImages,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Theme.of(context).colorScheme.outlineVariant,
                            ),
                          ),
                          child: _uploading
                              ? const Padding(
                                  padding: EdgeInsets.all(16),
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(
                                  Icons.add_photo_alternate_outlined,
                                  color: AppColors.primary,
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            AdminSectionCard(
              title: 'المعلومات الأساسية',
              icon: Icons.info_outline,
              child: Column(
                children: [
                  TextFormField(
                    controller: _name,
                    decoration:
                        const InputDecoration(labelText: AppStrings.productName),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? AppStrings.required
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _description,
                    maxLines: 3,
                    decoration:
                        const InputDecoration(labelText: AppStrings.description),
                  ),
                  const SizedBox(height: 12),
                  _CategoryDropdown(
                    initialValue: _categoryId,
                    onChanged: (v) => setState(() => _categoryId = v),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            AdminSectionCard(
              title: 'السعر والمخزون',
              icon: Icons.payments_outlined,
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _price,
                          keyboardType:
                              const TextInputType.numberWithOptions(decimal: true),
                          decoration:
                              const InputDecoration(labelText: AppStrings.price),
                          validator: (v) {
                            final value = double.tryParse(v ?? '');
                            return (value == null || value <= 0)
                                ? AppStrings.invalidPrice
                                : null;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _discountPrice,
                          keyboardType:
                              const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            labelText: AppStrings.discountPrice,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _stock,
                          keyboardType: TextInputType.number,
                          decoration:
                              const InputDecoration(labelText: AppStrings.stock),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _weight,
                          keyboardType:
                              const TextInputType.numberWithOptions(decimal: true),
                          decoration:
                              const InputDecoration(labelText: AppStrings.weight),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            AdminSectionCard(
              title: 'تفاصيل إضافية',
              icon: Icons.more_horiz,
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _sku,
                          decoration: const InputDecoration(labelText: 'SKU'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _brand,
                          decoration:
                              const InputDecoration(labelText: AppStrings.brand),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(AppStrings.featured),
                    value: _isFeatured,
                    onChanged: (v) => setState(() => _isFeatured = v),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(_isEdit ? AppStrings.saveChanges : AppStrings.addProduct),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// قائمة اختيار الفئة من Firestore
class _CategoryDropdown extends StatefulWidget {
  const _CategoryDropdown({required this.onChanged, this.initialValue});

  final ValueChanged<String?> onChanged;
  final String? initialValue;

  @override
  State<_CategoryDropdown> createState() => _CategoryDropdownState();
}

class _CategoryDropdownState extends State<_CategoryDropdown> {
  String? _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialValue;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: sl<CategoryRepository>().getCategories(),
      builder: (context, snapshot) {
        final categories = snapshot.data ?? const <Category>[];
        return DropdownButtonFormField<String>(
          initialValue: _selected,
          decoration: const InputDecoration(labelText: AppStrings.category),
          items: [
            for (final c in categories)
              DropdownMenuItem(value: c.id, child: Text(c.name)),
          ],
          onChanged: (v) {
            setState(() => _selected = v);
            widget.onChanged(v);
          },
        );
      },
    );
  }
}
