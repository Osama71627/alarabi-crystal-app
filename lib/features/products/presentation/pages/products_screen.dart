import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/routes.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/shimmer_loading.dart';
import '../../../../injection.dart';
import '../../../../l10n/app_strings.dart';
import '../../../../shared/services/currency_formatter.dart';
import '../../../../shared/models/product.dart';
import '../../../../shared/widgets/favorite_aware_card.dart';
import '../../domain/product_filtering.dart';
import '../../domain/repositories/product_repository.dart';
import '../bloc/product_bloc.dart';

/// شاشة عرض المنتجات مع بحث وفلاتر متقدمة
class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key, this.categoryId, this.initialQuery = ''});

  final String? categoryId;
  final String initialQuery;

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  bool _isGrid = true;

  // الفلاتر
  SortOption _sortOption = SortOption.latest;
  double _minPrice = 0;
  double _maxPrice = 10000;
  double _minRating = 0;
  List<String> _selectedCategories = [];

  @override
  void initState() {
    super.initState();
    _searchController.text = widget.initialQuery;
    _query = widget.initialQuery;
    if (widget.categoryId != null && widget.categoryId!.isNotEmpty) {
      _selectedCategories = [widget.categoryId!];
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.search),
        actions: [
          IconButton(
            icon: const Icon(Icons.compare_arrows),
            tooltip: AppStrings.compare,
            onPressed: () => context.go(AppRoutes.compare),
          ),
          IconButton(
            icon: const Icon(Icons.filter_list_rounded),
            tooltip: AppStrings.filter,
            onPressed: _openFilters,
          ),
        ],
      ),
      body: BlocProvider(
        create: (_) => ProductBloc(repository: sl<ProductRepository>())
          ..add(LoadProducts()),
        child: BlocBuilder<ProductBloc, ProductState>(
          builder: (context, state) {
            return Column(
              children: [
                // شريط البحث
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextField(
                    controller: _searchController,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (value) {
                      setState(() => _query = value.trim());
                    },
                    decoration: InputDecoration(
                      hintText: AppStrings.search,
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _query.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _query = '');
                              },
                            )
                          : null,
                    ),
                  ),
                ),
                // شريط العد + الترتيب + تبديل العرض
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Text(
                        '${_getFilteredProducts(state).length} ${AppStrings.productsCount}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const Spacer(),
                      // قائمة الترتيب
                      PopupMenuButton<SortOption>(
                        initialValue: _sortOption,
                        tooltip: AppStrings.sortBy,
                        onSelected: (value) {
                          setState(() => _sortOption = value);
                        },
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            value: SortOption.latest,
                            child: Text(AppStrings.latest),
                          ),
                          PopupMenuItem(
                            value: SortOption.topRated,
                            child: Text(AppStrings.topRated),
                          ),
                          PopupMenuItem(
                            value: SortOption.priceLowToHigh,
                            child: Text(AppStrings.priceLowToHigh),
                          ),
                          PopupMenuItem(
                            value: SortOption.priceHighToLow,
                            child: Text(AppStrings.priceHighToLow),
                          ),
                        ],
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _sortLabel(_sortOption),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            const Icon(Icons.sort, size: 20),
                          ],
                        ),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        onPressed: () => setState(() => _isGrid = !_isGrid),
                        icon: Icon(
                          _isGrid
                              ? Icons.view_list
                              : Icons.grid_view_rounded,
                        ),
                        tooltip: _isGrid
                            ? AppStrings.all
                            : AppStrings.filter,
                      ),
                    ],
                  ),
                ),
                Expanded(child: _buildBody(context, state)),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, ProductState state) {
    if (state is ProductLoading) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: ProductGridShimmer(),
      );
    }

    if (state is ProductError) {
      return Center(child: Text(state.message));
    }

    final products = _getFilteredProducts(state);
    if (products.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 12),
            Text(
              AppStrings.noData,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
      );
    }

    if (_isGrid) {
      return GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          // أُنقص النسبة (بطاقة أطول) لإفساح مجال لزر "أضف إلى السلة"
          // الجديد أسفل كل بطاقة (يطابق تصميم موقع الشركة)
          childAspectRatio: 0.56,
        ),
        itemCount: products.length,
        itemBuilder: (context, index) => FavoriteAwareCard(product: products[index]),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: products.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) => _ProductListTile(
        product: products[index],
      ),
    );
  }

  /// تطبيق الفلاتر والبحث والترتيب
  List<Product> _getFilteredProducts(ProductState state) {
    if (state is! ProductLoaded) return const [];
    return ProductFiltering.apply(
      state.products,
      ProductFilterOptions(
        query: _query,
        categories: _selectedCategories,
        minPrice: _minPrice,
        maxPrice: _maxPrice,
        minRating: _minRating,
        sort: _sortOption,
      ),
    );
  }

  String _sortLabel(SortOption option) {
    switch (option) {
      case SortOption.latest:
        return AppStrings.latest;
      case SortOption.topRated:
        return AppStrings.topRated;
      case SortOption.priceLowToHigh:
        return AppStrings.priceLowToHigh;
      case SortOption.priceHighToLow:
        return AppStrings.priceHighToLow;
    }
  }

  /// نافذة الفلاتر المتقدمة
  Future<void> _openFilters() async {
    final result = await showModalBottomSheet<_FilterResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => _FilterSheet(
        currentMinPrice: _minPrice,
        currentMaxPrice: _maxPrice,
        currentMinRating: _minRating,
        currentCategories: _selectedCategories,
      ),
    );

    if (result == null) return;
    setState(() {
      _minPrice = result.minPrice;
      _maxPrice = result.maxPrice;
      _minRating = result.minRating;
      _selectedCategories = result.categories;
    });
  }
}

/// نتيجة الفلاتر
class _FilterResult {
  const _FilterResult({
    required this.minPrice,
    required this.maxPrice,
    required this.minRating,
    required this.categories,
  });

  final double minPrice;
  final double maxPrice;
  final double minRating;
  final List<String> categories;
}

/// ورقة الفلاتر السفلية
class _FilterSheet extends StatefulWidget {
  const _FilterSheet({
    required this.currentMinPrice,
    required this.currentMaxPrice,
    required this.currentMinRating,
    required this.currentCategories,
  });

  final double currentMinPrice;
  final double currentMaxPrice;
  final double currentMinRating;
  final List<String> currentCategories;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  /// حدود المدى السعري المعروض بالمنزلق
  static const double _priceFloor = 0;
  static const double _priceCeiling = 10000;

  late double _minPrice;
  late double _maxPrice;
  late double _minRating;
  late List<String> _categories;

  static const List<(String, String, String)> _allCategories = [
    ('cat_italian_crystal', 'الكريستال الإيطالي', 'diamond'),
    ('cat_cutlery', 'أدوات المائدة', 'restaurant'),
    ('cat_decor', 'ديكور المنزل', 'home'),
    ('cat_gifts', 'هدايا فاخرة', 'card_giftcard'),
    ('cat_crystal_vases', 'مزهريات', 'local_florist'),
    ('cat_trophies', 'جوائز وتذكارات', 'emoji_events'),
  ];

  @override
  void initState() {
    super.initState();
    _minPrice = widget.currentMinPrice.clamp(_priceFloor, _priceCeiling);
    // maxPrice قد تكون لا نهائية (بلا حد) فنعرضها عند سقف المنزلق
    _maxPrice = widget.currentMaxPrice.isFinite
        ? widget.currentMaxPrice.clamp(_priceFloor, _priceCeiling)
        : _priceCeiling;
    if (_maxPrice < _minPrice) _maxPrice = _priceCeiling;
    _minRating = widget.currentMinRating;
    _categories = [...widget.currentCategories];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              AppStrings.filter,
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 24),

            // نطاق السعر (من — إلى)
            Text(AppStrings.priceRange,
                style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              '${CurrencyFormatter.formatClean(_minPrice)}  —  '
              '${CurrencyFormatter.formatClean(_maxPrice)}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
            RangeSlider(
              values: RangeValues(_minPrice, _maxPrice),
              min: _priceFloor,
              max: _priceCeiling,
              divisions: 40,
              labels: RangeLabels(
                _minPrice.toStringAsFixed(0),
                _maxPrice.toStringAsFixed(0),
              ),
              onChanged: (values) => setState(() {
                _minPrice = values.start;
                _maxPrice = values.end;
              }),
            ),
            const SizedBox(height: 12),

            // الحد الأدنى للتقييم
            Text(AppStrings.minRating,
                style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            SegmentedButton<double>(
              segments: const [
                ButtonSegment(value: 0, label: Text('الكل')),
                ButtonSegment(value: 3, label: Text('3+')),
                ButtonSegment(value: 4, label: Text('4+')),
                ButtonSegment(value: 4.5, label: Text('4.5+')),
              ],
              selected: {_minRating},
              onSelectionChanged: (values) {
                setState(() => _minRating = values.first);
              },
            ),
            const SizedBox(height: 20),

            // الفئات
            Text(AppStrings.categories,
                style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _allCategories.map((cat) {
                final (id, name, _) = cat;
                final isSelected = _categories.contains(id);
                return FilterChip(
                  label: Text(name),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _categories = [..._categories, id];
                      } else {
                        _categories =
                            _categories.where((e) => e != id).toList();
                      }
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 28),

            // الأزرار
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      setState(() {
                        _minPrice = _priceFloor;
                        _maxPrice = _priceCeiling;
                        _minRating = 0;
                        _categories = [];
                      });
                    },
                    child: Text(AppStrings.resetFilters),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(
                        context,
                        _FilterResult(
                          minPrice: _minPrice,
                          maxPrice: _maxPrice,
                          minRating: _minRating,
                          categories: _categories,
                        ),
                      );
                    },
                    child: Text(AppStrings.applyFilters),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

/// عنصر منتج بنمط قائمة
class _ProductListTile extends StatelessWidget {
  const _ProductListTile({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          children: [
            SizedBox(
              width: 100,
              height: 100,
              child: product.images.isNotEmpty
                  ? Image.network(product.images.first, fit: BoxFit.cover)
                  : Container(
                      color: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest,
                      child: const Icon(Icons.image_outlined, size: 40),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.star_rounded,
                        size: 14,
                        color: AppColors.secondary,
                      ),
                      Text(' ${product.rating.toStringAsFixed(1)}'),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    CurrencyFormatter.formatClean(product.effectivePrice),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
