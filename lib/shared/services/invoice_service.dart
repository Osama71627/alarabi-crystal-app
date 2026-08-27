import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../core/widgets/order_status_x.dart';
import '../../l10n/app_strings.dart';
import '../models/order.dart';
import 'currency_formatter.dart';

/// توليد فاتورة الطلب كملف PDF وفتح نافذة الطباعة/المشاركة الأصلية
/// للنظام (تسمح بالطباعة أو الحفظ كـ PDF أو الإرسال لأي تطبيق).
///
/// يُستخدم خط Cairo المرفق بالتطبيق لأن خطوط PDF الافتراضية لا تدعم
/// الحروف العربية إطلاقاً (تظهر مربعات فارغة بدونه).
class InvoiceService {
  InvoiceService._internal();
  static final InvoiceService instance = InvoiceService._internal();

  pw.Font? _regular;
  pw.Font? _bold;

  Future<void> _loadFonts() async {
    if (_regular != null && _bold != null) return;
    _regular = pw.Font.ttf(
      await rootBundle.load('assets/fonts/Cairo-Regular.ttf'),
    );
    _bold = pw.Font.ttf(
      await rootBundle.load('assets/fonts/Cairo-Bold.ttf'),
    );
  }

  /// بناء مستند الفاتورة
  Future<pw.Document> buildInvoice(Order order) async {
    await _loadFonts();
    final theme = pw.ThemeData.withFont(base: _regular!, bold: _bold!);
    final doc = pw.Document(theme: theme);
    final created = order.createdAt;
    final dateText = created == null
        ? ''
        : '${created.day}/${created.month}/${created.year}';

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        textDirection: pw.TextDirection.rtl,
        build: (context) => pw.Directionality(
          textDirection: pw.TextDirection.rtl,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                AppStrings.appName,
                style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 2),
              pw.Text(AppStrings.appTagline,
                  style: const pw.TextStyle(fontSize: 11)),
              pw.Divider(height: 24),
              _kv('${AppStrings.invoice}:', '#${order.id}'),
              if (dateText.isNotEmpty) _kv('${AppStrings.date}:', dateText),
              _kv('${AppStrings.paymentMethod}:', order.paymentMethod.label),
              if (order.shippingAddress != null &&
                  order.shippingAddress!.isNotEmpty)
                _kv('${AppStrings.shippingAddress}:', order.shippingAddress!),
              if (order.couponCode != null && order.couponCode!.isNotEmpty)
                _kv('${AppStrings.coupon}:', order.couponCode!),
              pw.SizedBox(height: 16),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
                columnWidths: {
                  0: const pw.FlexColumnWidth(4),
                  1: const pw.FlexColumnWidth(1),
                  2: const pw.FlexColumnWidth(2),
                },
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                    children: [
                      _cell(AppStrings.productName, bold: true),
                      _cell(AppStrings.quantity, bold: true),
                      _cell(AppStrings.price, bold: true),
                    ],
                  ),
                  for (final item in order.items)
                    pw.TableRow(
                      children: [
                        _cell(item.name),
                        _cell('${item.quantity}'),
                        _cell(CurrencyFormatter.formatClean(item.totalPrice)),
                      ],
                    ),
                ],
              ),
              pw.SizedBox(height: 16),
              _total(AppStrings.subtotal,
                  CurrencyFormatter.formatClean(order.subtotal)),
              _total(AppStrings.shippingFee,
                  CurrencyFormatter.formatClean(order.shippingFee)),
              if (order.discountAmount > 0)
                _total(AppStrings.discount,
                    '-${CurrencyFormatter.formatClean(order.discountAmount)}'),
              pw.Divider(height: 12),
              _total(
                AppStrings.total,
                CurrencyFormatter.formatClean(order.total),
                bold: true,
              ),
            ],
          ),
        ),
      ),
    );
    return doc;
  }

  /// فتح نافذة الطباعة/الحفظ الأصلية للنظام
  Future<void> printInvoice(Order order) async {
    final doc = await buildInvoice(order);
    await Printing.layoutPdf(
      onLayout: (format) async => doc.save(),
      name: 'invoice-${order.id}',
    );
  }

  pw.Widget _kv(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 10)),
          pw.SizedBox(width: 6),
          pw.Expanded(
            child: pw.Text(value, style: const pw.TextStyle(fontSize: 10)),
          ),
        ],
      ),
    );
  }

  pw.Widget _cell(String text, {bool bold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 10,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }

  pw.Widget _total(String label, String value, {bool bold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: bold ? 13 : 11,
              fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: bold ? 13 : 11,
              fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
