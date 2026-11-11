import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/network/api_client.dart';
import '../models/invoice_jatuh_tempo_model.dart';
import '../providers/auth_provider.dart';

final invoiceJatuhTempoRepositoryProvider = Provider<InvoiceJatuhTempoRepository>((ref) {
  final api = ref.watch(apiClientProvider);
  return InvoiceJatuhTempoRepository(api);
});

class InvoiceJatuhTempoRepository {
  final ApiClient _api;

  InvoiceJatuhTempoRepository(this._api);

  Future<InvoiceJatuhTempoResult> getInvoiceJatuhTempo({
    String? sales,
    String? search,
    int page = 1,
    int limit = 5000,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'page': page,
        'limit': limit,
      };
      if (sales != null && sales.isNotEmpty) queryParams['sales'] = sales;
      if (search != null && search.isNotEmpty) queryParams['search'] = search;

      final response = await _api.dio.get(
        '/invoice-jatuh-tempo',
        queryParameters: queryParams,
      );

      final body = response.data;
      if (body != null && body['data'] != null) {
        final data = body['data'] as Map<String, dynamic>;
        final summary = data['summary'] != null
            ? InvoiceJatuhTempoSummary.fromJson(data['summary'] as Map<String, dynamic>)
            : null;
        final rawItems = data['items'] as List? ?? [];
        final items = rawItems
            .map((item) => InvoiceJatuhTempoItem.fromJson(item as Map<String, dynamic>))
            .toList();
        final pagination = InvoiceJatuhTempoPagination.fromJson(
          data['pagination'] as Map<String, dynamic>?,
        );

        return InvoiceJatuhTempoResult(
          summary: summary,
          items: items,
          pagination: pagination,
        );
      }
      return const InvoiceJatuhTempoResult();
    } catch (e, st) {
      debugPrint('[InvoiceJatuhTempoRepository] Error fetching invoices: $e\n$st');
      return const InvoiceJatuhTempoResult();
    }
  }
}
