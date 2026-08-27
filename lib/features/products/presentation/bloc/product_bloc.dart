import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../shared/models/product.dart';
import '../../domain/repositories/product_repository.dart';

/// حالات المنتجات
sealed class ProductState {
  const ProductState();
}

class ProductInitial extends ProductState {
  const ProductInitial();
}

class ProductLoading extends ProductState {
  const ProductLoading();
}

class ProductLoaded extends ProductState {
  const ProductLoaded({
    required this.products,
    this.featured = const [],
    this.newArrivals = const [],
    this.bestSellers = const [],
  });

  final List<Product> products;
  final List<Product> featured;
  final List<Product> newArrivals;
  final List<Product> bestSellers;
}

class ProductError extends ProductState {
  const ProductError(this.message);

  final String message;
}

/// أحداث المنتجات
sealed class ProductEvent {
  const ProductEvent();
}

class LoadProducts extends ProductEvent {
  const LoadProducts();
}

class LoadFeaturedProducts extends ProductEvent {
  const LoadFeaturedProducts();
}

class SearchProducts extends ProductEvent {
  const SearchProducts(this.query);

  final String query;
}

/// إدارة حالة المنتجات
class ProductBloc extends Bloc<ProductEvent, ProductState> {
  ProductBloc({required ProductRepository repository})
      : _repository = repository,
        super(const ProductInitial()) {
    on<LoadProducts>(_onLoadProducts);
    on<LoadFeaturedProducts>(_onLoadFeaturedProducts);
    on<SearchProducts>(_onSearchProducts);
  }

  final ProductRepository _repository;

  Future<void> _onLoadProducts(
    LoadProducts event,
    Emitter<ProductState> emit,
  ) async {
    emit(const ProductLoading());
    try {
      final results = await Future.wait([
        _repository.getProducts(),
        _repository.getFeaturedProducts(),
        _repository.getNewArrivals(),
        _repository.getBestSellers(),
      ]);
      emit(ProductLoaded(
        products: results[0],
        featured: results[1],
        newArrivals: results[2],
        bestSellers: results[3],
      ));
    } catch (e) {
      emit(ProductError(e.toString()));
    }
  }

  Future<void> _onLoadFeaturedProducts(
    LoadFeaturedProducts event,
    Emitter<ProductState> emit,
  ) async {
    emit(const ProductLoading());
    try {
      final featured = await _repository.getFeaturedProducts();
      emit(ProductLoaded(products: featured, featured: featured));
    } catch (e) {
      emit(ProductError(e.toString()));
    }
  }

  Future<void> _onSearchProducts(
    SearchProducts event,
    Emitter<ProductState> emit,
  ) async {
    emit(const ProductLoading());
    try {
      final results = await _repository.searchProducts(event.query);
      emit(ProductLoaded(products: results));
    } catch (e) {
      emit(ProductError(e.toString()));
    }
  }
}
