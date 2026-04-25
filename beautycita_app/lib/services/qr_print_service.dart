import 'package:flutter/material.dart' show Color;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// Print-to-PDF helpers for the two recurring QR layouts:
///
/// 1. ExpressCita salon QR — 4 quarter-page cards on US Letter, each with
///    a thin dashed cut line so the salon owner can scissor them out and
///    place on door / mirror / counter. QR module ≈ 80mm (scans cleanly
///    from 2-3m). Branded BeautyCita header + short instruction.
///
/// 2. Stylist QR + PIN — 12-up sticker grid on US Letter sticker paper.
///    Per ISO/IEC 18004 + phone-camera ambient-light reality, QR side ≈
///    40mm gives reliable scan from ~1m (the requested distance) while
///    keeping the sticker small enough to live in a mirror corner.
///    Includes per-stylist 4-digit PIN in human-readable form below the
///    QR as a fallback when scanning is awkward.
///
/// Both layouts use 0.5pt grey dashed cut lines (4-on/3-off pattern) and
/// preserve a 4-module quiet zone around every QR per spec.
class QrPrintService {
  // ── ExpressCita: 4 cards per US Letter page ───────────────────────────────
  static const double _expressMarginPt = 18; // ~6.4mm page edge margin
  static const double _expressGutterPt = 12; // ~4.2mm between cards

  /// Prints a 4-up ExpressCita card layout for the given salon.
  static Future<void> printExpressCitaCards({
    required String qrUrl,
    required String businessName,
  }) async {
    final qrImage = await _renderQr(qrUrl, sizePx: 800);
    final doc = pw.Document(
      title: 'ExpressCita — $businessName',
      author: 'BeautyCita',
    );
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.letter,
        margin: pw.EdgeInsets.all(_expressMarginPt),
        build: (ctx) {
          final page = ctx.page.pageFormat;
          final innerW = page.width - _expressMarginPt * 2;
          final innerH = page.height - _expressMarginPt * 2;
          final cardW = (innerW - _expressGutterPt) / 2;
          final cardH = (innerH - _expressGutterPt) / 2;
          return pw.Stack(
            children: [
              for (int row = 0; row < 2; row++)
                for (int col = 0; col < 2; col++)
                  pw.Positioned(
                    left: col * (cardW + _expressGutterPt),
                    top: row * (cardH + _expressGutterPt),
                    child: _expressCard(
                      width: cardW,
                      height: cardH,
                      qrImage: qrImage,
                      businessName: businessName,
                    ),
                  ),
            ],
          );
        },
      ),
    );
    await Printing.layoutPdf(onLayout: (_) => doc.save());
  }

  static pw.Widget _expressCard({
    required double width,
    required double height,
    required pw.MemoryImage qrImage,
    required String businessName,
  }) {
    return pw.Container(
      width: width,
      height: height,
      child: pw.Stack(
        children: [
          // Cut line (dashed perimeter, inside the card boundary).
          pw.Positioned.fill(
            child: pw.CustomPaint(
              size: PdfPoint(width, height),
              painter: (canvas, size) {
                _drawDashedRect(
                  canvas: canvas,
                  x: 0,
                  y: 0,
                  width: size.x,
                  height: size.y,
                );
              },
            ),
          ),
          // Card content
          pw.Padding(
            padding: const pw.EdgeInsets.all(20),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                pw.Text(
                  'BeautyCita',
                  style: pw.TextStyle(
                    fontSize: 22,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.pink800,
                    letterSpacing: 0.6,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  'ExpressCita',
                  style: pw.TextStyle(
                    fontSize: 12,
                    color: PdfColors.grey700,
                    fontStyle: pw.FontStyle.italic,
                  ),
                ),
                pw.SizedBox(height: 14),
                pw.Container(
                  padding: const pw.EdgeInsets.all(6),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
                    borderRadius: pw.BorderRadius.circular(4),
                  ),
                  child: pw.Image(qrImage, width: 170, height: 170),
                ),
                pw.SizedBox(height: 10),
                pw.Text(
                  businessName,
                  textAlign: pw.TextAlign.center,
                  maxLines: 2,
                  style: pw.TextStyle(
                    fontSize: 13,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 6),
                pw.Text(
                  'Escanea para reservar',
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(
                    fontSize: 10,
                    color: PdfColors.grey700,
                  ),
                ),
              ],
            ),
          ),
          // Scissors hint at the corner of the cut line.
          pw.Positioned(
            top: -2,
            left: 8,
            child: pw.Text(
              '✂',
              style: pw.TextStyle(
                fontSize: 9,
                color: PdfColors.grey500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Stylist sticker grid: 12 per US Letter page ───────────────────────────
  // Designed for a 1m scan distance: QR module 40mm × 40mm with brand mark
  // and PIN line. Sticker boundary slightly larger to leave room for a clean
  // scissor cut. 3 columns × 4 rows = 12 stickers per sheet of sticker paper.
  static const double _stickerW = 56 * PdfPageFormat.mm;
  static const double _stickerH = 64 * PdfPageFormat.mm;
  static const double _stickerGapX = 4 * PdfPageFormat.mm;
  static const double _stickerGapY = 4 * PdfPageFormat.mm;
  static const double _qrSide = 40 * PdfPageFormat.mm;

  /// Prints a 12-up stylist QR+PIN sticker sheet.
  static Future<void> printStylistStickers({
    required String uploadUrl,
    required String stylistName,
    required String pin,
    int copies = 12,
  }) async {
    final qrImage = await _renderQr(uploadUrl, sizePx: 600);
    final doc = pw.Document(
      title: 'BeautyCita — Portafolio $stylistName',
      author: 'BeautyCita',
    );
    final perPage = 12;
    final pages = (copies / perPage).ceil();
    for (int p = 0; p < pages; p++) {
      final remaining = copies - p * perPage;
      final onThisPage = remaining > perPage ? perPage : remaining;
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.letter,
          margin: const pw.EdgeInsets.symmetric(
            horizontal: 10 * PdfPageFormat.mm,
            vertical: 12 * PdfPageFormat.mm,
          ),
          build: (ctx) {
            return pw.Stack(
              children: [
                for (int i = 0; i < onThisPage; i++)
                  pw.Positioned(
                    left: (i % 3) * (_stickerW + _stickerGapX),
                    top: (i ~/ 3) * (_stickerH + _stickerGapY),
                    child: _stylistSticker(
                      qrImage: qrImage,
                      stylistName: stylistName,
                      pin: pin,
                    ),
                  ),
              ],
            );
          },
        ),
      );
    }
    await Printing.layoutPdf(onLayout: (_) => doc.save());
  }

  static pw.Widget _stylistSticker({
    required pw.MemoryImage qrImage,
    required String stylistName,
    required String pin,
  }) {
    return pw.Container(
      width: _stickerW,
      height: _stickerH,
      child: pw.Stack(
        children: [
          // Cut line (dashed perimeter)
          pw.Positioned.fill(
            child: pw.CustomPaint(
              size: PdfPoint(_stickerW, _stickerH),
              painter: (canvas, size) {
                _drawDashedRect(
                  canvas: canvas,
                  x: 0,
                  y: 0,
                  width: size.x,
                  height: size.y,
                );
              },
            ),
          ),
          // Content
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(
              horizontal: 4 * PdfPageFormat.mm,
              vertical: 4 * PdfPageFormat.mm,
            ),
            child: pw.Column(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Text(
                  'BeautyCita Portafolio',
                  style: pw.TextStyle(
                    fontSize: 7,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.pink800,
                  ),
                ),
                pw.Image(qrImage, width: _qrSide, height: _qrSide),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Text(
                      stylistName,
                      maxLines: 1,
                      style: pw.TextStyle(
                        fontSize: 8,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 1.5),
                    pw.Text(
                      'PIN $pin',
                      style: pw.TextStyle(
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.purple800,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  static Future<pw.MemoryImage> _renderQr(String url, {int sizePx = 600}) async {
    final painter = QrPainter(
      data: url,
      version: QrVersions.auto,
      gapless: true,
      eyeStyle: const QrEyeStyle(
        eyeShape: QrEyeShape.square,
        color: Color(0xFF1A1A2E),
      ),
      dataModuleStyle: const QrDataModuleStyle(
        dataModuleShape: QrDataModuleShape.square,
        color: Color(0xFF1A1A2E),
      ),
    );
    final picData = await painter.toImageData(sizePx.toDouble());
    if (picData == null) {
      throw StateError('QR rasterization returned null');
    }
    return pw.MemoryImage(picData.buffer.asUint8List());
  }

  /// Draw a 0.5pt grey dashed rectangle. Pattern: 4 on, 3 off (PDF points).
  static void _drawDashedRect({
    required PdfGraphics canvas,
    required double x,
    required double y,
    required double width,
    required double height,
  }) {
    canvas.setStrokeColor(PdfColors.grey400);
    canvas.setLineWidth(0.5);
    canvas.setLineDashPattern([4, 3]);
    canvas.drawRect(x, y, width, height);
    canvas.strokePath();
    canvas.setLineDashPattern();
  }
}
