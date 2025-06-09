import 'dart:io';
import 'package:billing/beans/payment_record.dart';
import 'package:billing/db/user_database.dart';
import 'package:billing/utils/file_utils.dart';
import 'package:excel/excel.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_file/open_file.dart';
import 'package:permission_handler/permission_handler.dart';

class ExportPaymentPage extends StatefulWidget {
  final List<PaymentRecord>? records;
  final DateTime? startDate;
  final DateTime? endDate;

  const ExportPaymentPage({super.key, this.records, this.startDate, this.endDate});

  @override
  State<ExportPaymentPage> createState() => _ExportPaymentPageState();
}

class _ExportPaymentPageState extends State<ExportPaymentPage> {
  bool _exporting = false;
  String? _exportResult;
  String? _exportedFilePath;

  Future<void> _exportToExcel() async {
    if (widget.records == null || widget.records!.isEmpty) {
      setState(() => _exportResult = '没有可导出的记录');
      return;
    }

    setState(() {
      _exporting = true;
      _exportResult = null;
    });

    if (Platform.isAndroid || Platform.isIOS) {
      final status = await Permission.storage.request();
      if (!status.isGranted) {
        setState(() {
          _exportResult = '未获得存储权限';
          _exporting = false;
        });
        return;
      }
    }

    final users = await UserDatabase.instance.getUserIdUsernameMap();

    final excel = Excel.createExcel();
    excel.rename('Sheet1', '收支记录');
    final sheet = excel['收支记录'];

    _writeHeaderRow(sheet);

    List<PaymentRecord> sortRecords = widget.records!;
    sortRecords.sort((a, b) => a.id!.compareTo(b.id!));

    for (int i = 0; i < widget.records!.length; i++) {
      _writeRecordRow(sheet, i + 1, widget.records![i], users);
    }

    final dir = await FileUtils.getSaveDirectory();
    if (dir == null) {
      setState(() {
        _exportResult = '未选择保存目录';
        _exporting = false;
      });
      return;
    }

    final fileName = _generateFileName();
    _exportedFilePath = '${dir.path}/$fileName';
    final file = File(_exportedFilePath!);
    try {
      await file.writeAsBytes(excel.encode()!);
    } catch (e) {
      setState(() {
        _exportResult = '导出失败，请检查文件是否已经打开或磁盘空间是否充足: $e';
        _exporting = false;
      });
      return;
    }

    setState(() {
      _exportResult = '导出成功：$_exportedFilePath';
      _exporting = false;
    });
  }

  void _writeHeaderRow(Sheet sheet) {
    CellStyle cellStyle = CellStyle(
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center, // 可选：垂直居中
      bold: true, // 可选：加粗
    );

    const headers = ['记录ID', '时间', '项目名称', '金额', '类型', '备注', '操作人'];
    for (int col = 0; col < headers.length; col++) {
      var cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 0));
      cell.value = TextCellValue(headers[col]);
      cell.cellStyle = cellStyle; // 设置居中样式
      sheet.setColumnWidth(col, 20.0); // 设置列宽
    }
  }

  void _writeRecordRow(Sheet sheet, int row, PaymentRecord record, Map<int, String> users) {
    CellStyle cellStyle = CellStyle(
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
      bold: false,
    );

    // 写入每一列并应用样式
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
      ..value = TextCellValue(record.id.toString())
      ..cellStyle = cellStyle;

    final formattedTime =
        '${record.parsedTime.year.toString().padLeft(4, '0')}-'
        '${record.parsedTime.month.toString().padLeft(2, '0')}-'
        '${record.parsedTime.day.toString().padLeft(2, '0')} '
        '${record.parsedTime.hour.toString().padLeft(2, '0')}:'
        '${record.parsedTime.minute.toString().padLeft(2, '0')}:'
        '${record.parsedTime.second.toString().padLeft(2, '0')}';

    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row))
      ..value = TextCellValue(formattedTime)
      ..cellStyle = cellStyle;

    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row))
      ..value = TextCellValue(record.itemName)
      ..cellStyle = cellStyle;

    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row))
      ..value = DoubleCellValue(record.amount)
      ..cellStyle = cellStyle;

    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: row))
      ..value = TextCellValue(record.isExpense ? '支出' : '收入')
      ..cellStyle = cellStyle;

    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: row))
      ..value = TextCellValue(record.isRefunded ? '已退款' : '')
      ..cellStyle = cellStyle;

    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: row))
      ..value = TextCellValue(users[record.userId] ?? '未知用户')
      ..cellStyle = cellStyle;
  }

  String _generateFileName() {
    final startStr = widget.startDate != null ? DateFormat('yyyyMMdd').format(widget.startDate!) : '开始';
    final endStr = widget.endDate != null ? DateFormat('yyyyMMdd').format(widget.endDate!) : '结束';
    return '收支导出_$startStr-$endStr.xlsx';
  }

  Future<void> _openFile() async {
    if (_exportedFilePath == null || !File(_exportedFilePath!).existsSync()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("未找到导出的文件")));
      }
      return;
    }

    try {
      OpenFile.open(_exportedFilePath!).then((result) {
        if (result.type != ResultType.done) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("打开文件失败: ${result.message}")));
          }
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("打开文件失败: $e")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasResult = _exportResult != null;
    return Scaffold(
      appBar: AppBar(title: const Text('导出记录')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('记录总数：${widget.records?.length ?? 0}', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _exporting ? null : _exportToExcel,
              icon: _exporting
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.save_alt),
              label: const Text('导出为 Excel'),
              style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
            ),
            const SizedBox(height: 20),
            if (hasResult)
              Column(
                children: [
                  Text(
                    _exportResult!,
                    style: TextStyle(
                      color: _exportResult!.contains('成功') ? Colors.green : Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _openFile,
                    icon: const Icon(Icons.folder_open),
                    label: const Text("打开文件"),
                    style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
