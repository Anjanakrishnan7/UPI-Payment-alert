import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../providers/payment_provider.dart';

class PdfReportService {
  static Future<void> generateAndShareReport(PaymentProvider provider, String period) async {
    final fontBase = await PdfGoogleFonts.robotoRegular();
    final fontBold = await PdfGoogleFonts.robotoBold();
    
    final pdf = pw.Document(
      title: '$period Payment Report',
      theme: pw.ThemeData.withFont(
        base: fontBase,
        bold: fontBold,
      ),
    );

    final now = DateTime.now();
    final DateFormat formatter = DateFormat('dd/MM/yyyy');
    final DateFormat timeFormatter = DateFormat('hh:mm a');
    final DateFormat dateTimeFormatter = DateFormat('dd/MM/yyyy hh:mm a');
    final String generatedDateStr = formatter.format(now);
    final String generatedTimeStr = timeFormatter.format(now);

    // Filter payments for the period
    final DateTime startDate;
    if (period == 'Daily') {
      startDate = DateTime(now.year, now.month, now.day);
    } else if (period == 'Weekly') {
      startDate = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
    } else {
      // Monthly
      startDate = DateTime(now.year, now.month, 1);
    }

    final periodPayments = provider.paymentHistory.where((p) {
      return p.timestamp.isAfter(startDate) || p.timestamp.isAtSameMomentAs(startDate);
    }).toList();

    double totalReceived = 0;
    double totalSent = 0;
    int receivedCount = 0;
    int sentCount = 0;
    double highestReceived = 0.0;
    double highestSent = 0.0;

    for (final p in periodPayments) {
      if (p.isSent) {
        totalSent += p.amount;
        sentCount++;
        if (p.amount > highestSent) {
          highestSent = p.amount;
        }
      } else {
        totalReceived += p.amount;
        receivedCount++;
        if (p.amount > highestReceived) {
          highestReceived = p.amount;
        }
      }
    }

    final double netChange = totalReceived - totalSent;
    final int totalCount = receivedCount + sentCount;

    // Build daily records for chart (use 7 days chart format for Weekly, 30 days for Monthly)
    final List<Map<String, dynamic>> chartDays = [];
    final int dayCount = period == 'Monthly' ? 30 : (period == 'Weekly' ? 7 : 1);
    for (int i = dayCount - 1; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final label = period == 'Monthly' ? date.day.toString() : DateFormat('E').format(date);
      
      double dayRec = 0;
      double daySent = 0;
      
      for (final p in provider.paymentHistory) {
        if (p.timestamp.year == date.year && p.timestamp.month == date.month && p.timestamp.day == date.day) {
          if (p.isSent) {
            daySent += p.amount;
          } else {
            dayRec += p.amount;
          }
        }
      }
      chartDays.add({
        'label': label,
        'received': dayRec,
        'sent': daySent,
      });
    }

    // Find max for scaling chart
    double maxVal = 100.0;
    for (final d in chartDays) {
      if (d['received'] > maxVal) maxVal = d['received'];
      if (d['sent'] > maxVal) maxVal = d['sent'];
    }

    // Professional theme colors
    final primaryColor = PdfColor.fromHex('#00B894'); // Teal
    final secondaryColor = PdfColor.fromHex('#FF5252'); // Red
    final textColor = PdfColor.fromHex('#2D3436');
    final lightGrey = PdfColor.fromHex('#F5F6FA');
    final darkGrey = PdfColor.fromHex('#7F8C8D');

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (pw.Context context) {
          if (context.pageNumber == 1) {
            return pw.Column(
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          '${period.toUpperCase()} PAYMENT REPORT',
                          style: pw.TextStyle(
                            fontSize: 22,
                            fontWeight: pw.FontWeight.bold,
                            color: primaryColor,
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          'Period: ${formatter.format(startDate)} to $generatedDateStr',
                          style: pw.TextStyle(fontSize: 12, color: darkGrey),
                        ),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                          'UPI Voice Alert',
                          style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: textColor),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          'Generated: $generatedDateStr at $generatedTimeStr',
                          style: pw.TextStyle(fontSize: 10, color: darkGrey),
                        ),
                      ],
                    ),
                  ],
                ),
                pw.SizedBox(height: 12),
                pw.Divider(thickness: 1, color: PdfColors.grey300),
                pw.SizedBox(height: 12),
              ],
            );
          }
          return pw.Container();
        },
        footer: (pw.Context context) {
          return pw.Column(
            children: [
              pw.Divider(thickness: 1, color: PdfColors.grey300),
              pw.SizedBox(height: 10),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Generated by UPI Voice Alert • Page ${context.pageNumber} of ${context.pagesCount}', style: pw.TextStyle(fontSize: 9, color: darkGrey)),
                  pw.Text('Secured Local Report Ledger', style: pw.TextStyle(fontSize: 9, color: darkGrey)),
                ],
              ),
            ],
          );
        },
        build: (pw.Context context) {
          return [
            // Summary Section title
            pw.Text(
              'Financial Performance Summary',
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: textColor),
            ),
            pw.SizedBox(height: 10),

            // Summary Stats Grid
            pw.Row(
              children: [
                _buildStatCard('Total Received', 'INR ${totalReceived.toStringAsFixed(2)}', primaryColor, lightGrey),
                pw.SizedBox(width: 12),
                _buildStatCard('Total Sent', 'INR ${totalSent.toStringAsFixed(2)}', secondaryColor, lightGrey),
                pw.SizedBox(width: 12),
                _buildStatCard(
                  'Net Change',
                  '${netChange >= 0 ? '+' : ''}INR ${netChange.toStringAsFixed(2)}',
                  netChange >= 0 ? primaryColor : secondaryColor,
                  lightGrey,
                ),
                pw.SizedBox(width: 12),
                _buildStatCard('Transactions', '$totalCount Count', textColor, lightGrey),
              ],
            ),
            pw.SizedBox(height: 24),

            // Chart Section
            pw.Text(
              'Performance Trends (Received vs Sent)',
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: textColor),
            ),
            pw.SizedBox(height: 12),

            _buildChartSection(
              period: period,
              chartDays: chartDays,
              maxVal: maxVal,
              primaryColor: primaryColor,
              secondaryColor: secondaryColor,
              lightGrey: lightGrey,
              totalReceived: totalReceived,
              totalSent: totalSent,
            ),
            pw.SizedBox(height: 24),

            // Breakdown Milestone section
            pw.Text(
              'Period Milestones',
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: textColor),
            ),
            pw.SizedBox(height: 10),

            pw.Row(
              children: [
                pw.Expanded(
                  child: pw.Container(
                    padding: const pw.EdgeInsets.all(12),
                    decoration: pw.BoxDecoration(
                      color: lightGrey,
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
                      border: pw.Border.all(color: PdfColors.grey200),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Highest Received Payment', style: pw.TextStyle(fontSize: 10, color: darkGrey)),
                        pw.SizedBox(height: 4),
                        pw.Text('INR ${highestReceived.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: primaryColor)),
                      ],
                    ),
                  ),
                ),
                pw.SizedBox(width: 12),
                pw.Expanded(
                  child: pw.Container(
                    padding: const pw.EdgeInsets.all(12),
                    decoration: pw.BoxDecoration(
                      color: lightGrey,
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
                      border: pw.Border.all(color: PdfColors.grey200),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Highest Outgoing Payment', style: pw.TextStyle(fontSize: 10, color: darkGrey)),
                        pw.SizedBox(height: 4),
                        pw.Text('INR ${highestSent.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: secondaryColor)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 28),

            // Transaction Details section
            pw.Text(
              'Transaction Details',
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: textColor),
            ),
            pw.SizedBox(height: 10),

            if (periodPayments.isEmpty)
              pw.Container(
                padding: const pw.EdgeInsets.all(16),
                alignment: pw.Alignment.center,
                child: pw.Text('No transactions recorded during this period.', style: pw.TextStyle(fontSize: 10, color: darkGrey)),
              )
            else
              pw.Table(
                border: const pw.TableBorder(
                  horizontalInside: pw.BorderSide(width: 0.5, color: PdfColors.grey300),
                  bottom: pw.BorderSide(width: 0.5, color: PdfColors.grey300),
                ),
                columnWidths: const {
                  0: pw.FlexColumnWidth(2.2),
                  1: pw.FlexColumnWidth(2.8),
                  2: pw.FlexColumnWidth(1.5),
                  3: pw.FlexColumnWidth(1.8),
                },
                children: [
                  // Table Header Row
                  pw.TableRow(
                    decoration: pw.BoxDecoration(color: lightGrey),
                    children: [
                      _buildTableHeaderCell('Date & Time'),
                      _buildTableHeaderCell('Sender / Source'),
                      _buildTableHeaderCell('Account'),
                      _buildTableHeaderCell('Amount', alignEnd: true),
                    ],
                  ),
                  // Table Data Rows (Sorted newest first)
                  ...List.generate(periodPayments.length, (index) {
                    final p = periodPayments[index];
                    final rowBg = index % 2 == 0 ? PdfColors.white : lightGrey;
                    final amtColor = p.isSent ? secondaryColor : primaryColor;
                    final amtPrefix = p.isSent ? '-' : '+';
                    
                    return pw.TableRow(
                      decoration: pw.BoxDecoration(color: rowBg),
                      children: [
                        _buildTableCell(dateTimeFormatter.format(p.timestamp)),
                        _buildTableCell(p.sender),
                        _buildTableCell(p.accountNumber != null ? 'A/C ...${p.accountNumber}' : '-'),
                        _buildTableCell(
                          '$amtPrefix INR ${p.amount.toStringAsFixed(2)}',
                          alignEnd: true,
                          color: amtColor,
                          bold: true,
                        ),
                      ],
                    );
                  }),
                ],
              ),
          ];
        },
      ),
    );

    // Save and trigger native save/share sheet
    final Uint8List bytes = await pdf.save();
    await Printing.sharePdf(bytes: bytes, filename: '${period.toLowerCase()}_report.pdf');
  }

  static pw.Widget _buildTableHeaderCell(String text, {bool alignEnd = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: pw.Container(
        alignment: alignEnd ? pw.Alignment.centerRight : pw.Alignment.centerLeft,
        child: pw.Text(
          text,
          style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800),
        ),
      ),
    );
  }

  static pw.Widget _buildTableCell(String text, {bool alignEnd = false, PdfColor? color, bool bold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: pw.Container(
        alignment: alignEnd ? pw.Alignment.centerRight : pw.Alignment.centerLeft,
        child: pw.Text(
          text,
          style: pw.TextStyle(
            fontSize: 8,
            fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
            color: color ?? PdfColors.grey700,
          ),
        ),
      ),
    );
  }

  static pw.Widget _buildStatCard(String label, String value, PdfColor valueColor, PdfColor bgColor) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          color: bgColor,
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
          border: pw.Border.all(color: PdfColors.grey200),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              label,
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              value,
              style: pw.TextStyle(
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
                color: valueColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static pw.Widget _buildLegendItem(PdfColor color, String text) {
    return pw.Row(
      children: [
        pw.Container(
          width: 8,
          height: 8,
          decoration: pw.BoxDecoration(
            color: color,
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(2)),
          ),
        ),
        pw.SizedBox(width: 4),
        pw.Text(text, style: const pw.TextStyle(fontSize: 8)),
      ],
    );
  }

  static pw.Widget _buildChartSection({
    required String period,
    required List<Map<String, dynamic>> chartDays,
    required double maxVal,
    required PdfColor primaryColor,
    required PdfColor secondaryColor,
    required PdfColor lightGrey,
    required double totalReceived,
    required double totalSent,
  }) {
    if (period == 'Daily') {
      final double maxToday = totalReceived > totalSent ? (totalReceived > 0 ? totalReceived : 100) : (totalSent > 0 ? totalSent : 100);
      final double recHeight = (totalReceived / maxToday) * 80;
      final double sentHeight = (totalSent / maxToday) * 80;

      return pw.Container(
        height: 140,
        padding: const pw.EdgeInsets.all(16),
        decoration: pw.BoxDecoration(
          color: lightGrey,
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(12)),
          border: pw.Border.all(color: PdfColors.grey200),
        ),
        child: pw.Column(
          children: [
            pw.Expanded(
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.center,
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Column(
                    mainAxisAlignment: pw.MainAxisAlignment.end,
                    children: [
                      pw.Text(
                        'Received ₹${totalReceived.toStringAsFixed(2)}',
                        style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Container(
                        width: 28,
                        height: recHeight > 2 ? recHeight : 2,
                        decoration: pw.BoxDecoration(
                          color: primaryColor,
                          borderRadius: const pw.BorderRadius.only(
                            topLeft: pw.Radius.circular(4),
                            topRight: pw.Radius.circular(4),
                          ),
                        ),
                      ),
                      pw.SizedBox(height: 6),
                      pw.Text('Total Received', style: const pw.TextStyle(fontSize: 8)),
                    ],
                  ),
                  pw.SizedBox(width: 48),
                  pw.Column(
                    mainAxisAlignment: pw.MainAxisAlignment.end,
                    children: [
                      pw.Text(
                        'Sent ₹${totalSent.toStringAsFixed(2)}',
                        style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Container(
                        width: 28,
                        height: sentHeight > 2 ? sentHeight : 2,
                        decoration: pw.BoxDecoration(
                          color: secondaryColor,
                          borderRadius: const pw.BorderRadius.only(
                            topLeft: pw.Radius.circular(4),
                            topRight: pw.Radius.circular(4),
                          ),
                        ),
                      ),
                      pw.SizedBox(height: 6),
                      pw.Text('Total Sent', style: const pw.TextStyle(fontSize: 8)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    } else if (period == 'Monthly') {
      final List<Map<String, dynamic>> firstHalf = chartDays.sublist(0, 15);
      final List<Map<String, dynamic>> secondHalf = chartDays.sublist(15);

      return pw.Column(
        children: [
          pw.Text('Days 1 - 15', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
          pw.SizedBox(height: 4),
          _buildTimelineChart(firstHalf, maxVal, primaryColor, secondaryColor, lightGrey),
          pw.SizedBox(height: 12),
          pw.Text('Days 16 - 30/31', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
          pw.SizedBox(height: 4),
          _buildTimelineChart(secondHalf, maxVal, primaryColor, secondaryColor, lightGrey),
          pw.SizedBox(height: 8),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: [
              _buildLegendItem(primaryColor, 'Received'),
              pw.SizedBox(width: 16),
              _buildLegendItem(secondaryColor, 'Sent'),
            ],
          ),
        ],
      );
    } else {
      return pw.Container(
        height: 150,
        padding: const pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(
          color: lightGrey,
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(12)),
          border: pw.Border.all(color: PdfColors.grey200),
        ),
        child: pw.Column(
          children: [
            pw.Expanded(
              child: _buildTimelineChartBody(chartDays, maxVal, primaryColor, secondaryColor, barWidth: 8, spacing: 2),
            ),
            pw.SizedBox(height: 6),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                _buildLegendItem(primaryColor, 'Received'),
                pw.SizedBox(width: 16),
                _buildLegendItem(secondaryColor, 'Sent'),
              ],
            ),
          ],
        ),
      );
    }
  }

  static pw.Widget _buildTimelineChart(
    List<Map<String, dynamic>> days,
    double maxVal,
    PdfColor primaryColor,
    PdfColor secondaryColor,
    PdfColor lightGrey,
  ) {
    return pw.Container(
      height: 110,
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: pw.BoxDecoration(
        color: lightGrey,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
        border: pw.Border.all(color: PdfColors.grey200),
      ),
      child: _buildTimelineChartBody(days, maxVal, primaryColor, secondaryColor, barWidth: 5, spacing: 1),
    );
  }

  static pw.Widget _buildTimelineChartBody(
    List<Map<String, dynamic>> days,
    double maxVal,
    PdfColor primaryColor,
    PdfColor secondaryColor, {
    required double barWidth,
    required double spacing,
  }) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.end,
      mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
      children: days.map((d) {
        final double recVal = d['received'];
        final double sentVal = d['sent'];
        final double recHeight = (recVal / maxVal) * 55;
        final double sentHeight = (sentVal / maxVal) * 55;

        return pw.Column(
          mainAxisAlignment: pw.MainAxisAlignment.end,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(
                  '₹${recVal.toStringAsFixed(0)}',
                  style: const pw.TextStyle(fontSize: 5, color: PdfColors.grey800),
                ),
                pw.SizedBox(width: spacing),
                pw.Text(
                  '₹${sentVal.toStringAsFixed(0)}',
                  style: const pw.TextStyle(fontSize: 5, color: PdfColors.grey800),
                ),
              ],
            ),
            pw.SizedBox(height: 2),
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Container(
                  width: barWidth,
                  height: recHeight > 2 ? recHeight : 2,
                  decoration: pw.BoxDecoration(
                    color: primaryColor,
                    borderRadius: const pw.BorderRadius.only(
                      topLeft: pw.Radius.circular(1),
                      topRight: pw.Radius.circular(1),
                    ),
                  ),
                ),
                pw.SizedBox(width: spacing),
                pw.Container(
                  width: barWidth,
                  height: sentHeight > 2 ? sentHeight : 2,
                  decoration: pw.BoxDecoration(
                    color: secondaryColor,
                    borderRadius: const pw.BorderRadius.only(
                      topLeft: pw.Radius.circular(1),
                      topRight: pw.Radius.circular(1),
                    ),
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              d['label'],
              style: const pw.TextStyle(fontSize: 7),
            ),
          ],
        );
      }).toList(),
    );
  }
}
