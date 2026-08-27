import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../shared/models/offer.dart';
import '../../domain/repositories/offer_repository.dart';

/// حالات العروض
sealed class OfferState {
  const OfferState();
}

class OfferInitial extends OfferState {
  const OfferInitial();
}

class OfferLoading extends OfferState {
  const OfferLoading();
}

class OfferLoaded extends OfferState {
  const OfferLoaded({required this.offers, this.flashOffers = const []});

  final List<Offer> offers;
  final List<Offer> flashOffers;
}

class OfferError extends OfferState {
  const OfferError(this.message);

  final String message;
}

/// أحداث العروض
sealed class OfferEvent {
  const OfferEvent();
}

class LoadOffers extends OfferEvent {
  const LoadOffers();
}

/// إدارة حالة العروض
class OfferBloc extends Bloc<OfferEvent, OfferState> {
  OfferBloc({required OfferRepository repository})
      : _repository = repository,
        super(const OfferInitial()) {
    on<LoadOffers>(_onLoadOffers);
  }

  final OfferRepository _repository;

  Future<void> _onLoadOffers(
    LoadOffers event,
    Emitter<OfferState> emit,
  ) async {
    emit(const OfferLoading());
    try {
      final offers = await _repository.getActiveOffers();
      final flash = offers.where((o) => o.type == OfferType.flash).toList();
      emit(OfferLoaded(offers: offers, flashOffers: flash));
    } catch (e) {
      emit(OfferError(e.toString()));
    }
  }
}
