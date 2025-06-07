import 'package:billing/beans/payment_record.dart';
import 'package:billing/db/payment_database.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class PaymentListPage extends StatefulWidget {
  const PaymentListPage({super.key});

  @override
  _PaymentListPageState createState() => _PaymentListPageState();
}

class _PaymentListPageState extends State<PaymentListPage> {
  List<PaymentRecord> records = [];
  DateTime? _startDate;
  DateTime? _endDate;

  final dateFormat = DateFormat('yyyy-MM-dd HH:mm');

  @override
  void initState() {
    super.initState();
    _loadRecords();
  }

  Future<void> _loadRecords() async {
    final all = await PaymentDatabase.instance.fetchPayments();

    final filtered = all.where((r) {
      if (_startDate != null && r.parsedTime.isBefore(_startDate!)) return false;
      if (_endDate != null && r.parsedTime.isAfter(_endDate!)) return false;
      return true;
    }).toList();

    setState(() => records = filtered);
  }

  void _confirmRefund(PaymentRecord record) async {
    if (record.isRefunded || record.isExpense) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('确认退款'),
        content: Text('确定要对「${record.itemName}」退款 ¥${record.amount}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('取消')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text('确认')),
        ],
      ),
    );

    if (confirmed == true) {
      await PaymentDatabase.instance.refundPayment(record.id!);
      _loadRecords();
    }
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 1),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
      helpText: '选择记录日期范围',
      confirmText: '确定',
      cancelText: '取消',
      locale: Locale('zh'),
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end.add(Duration(days: 1)).subtract(Duration(seconds: 1));
      });
      _loadRecords();
    }
  }

  void _editRecord(PaymentRecord record) async {
    final controller = TextEditingController(text: record.amount.toStringAsFixed(2));

    final result = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('修改金额'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.numberWithOptions(decimal: true, signed: true),
          decoration: InputDecoration(labelText: '金额', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('取消')),
          TextButton(
            onPressed: () {
              final newAmount = double.tryParse(controller.text.trim());
              if (newAmount != null) {
                Navigator.pop(context, newAmount);
              }
            },
            child: Text('保存'),
          ),
        ],
      ),
    );

    if (result != null && result != record.amount) {
      final updated = record.copyWith(amount: result);
      await PaymentDatabase.instance.updatePayment(updated);
      _loadRecords();
    }
  }

  void _confirmDelete(PaymentRecord record) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('确认删除'),
        content: Text('确定要删除记录「${record.itemName}」吗？该操作不可恢复。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('取消')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await PaymentDatabase.instance.deletePayment(record.id!);
      _loadRecords();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('收入/支出记录'),
        actions: [
          IconButton(icon: Icon(Icons.date_range), onPressed: _pickDateRange, tooltip: '选择日期范围'),
          IconButton(
            icon: Icon(Icons.download),
            tooltip: '导出数据',
            onPressed: () async {
              List<PaymentRecord> recordsToExport = await PaymentDatabase.instance.queryRecords(
                start: _startDate,
                end: _endDate,
              );
              if (context.mounted) {
                context.pushNamed(
                  'export_payment',
                  extra: {'records': recordsToExport, 'startDate': _startDate, 'endDate': _endDate},
                );
              }
            },
          ),
        ],
      ),
      body: records.isEmpty
          ? Center(child: Text('暂无记录'))
          : ListView.builder(
              padding: EdgeInsets.all(8),
              itemCount: records.length,
              itemBuilder: (context, index) {
                final r = records[index];
                final isExpense = r.isExpense;
                final isRefunded = r.isRefunded;
                final amountColor = isExpense ? Colors.red[700] : (isRefunded ? Colors.grey : Colors.green[700]);

                return Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 3,
                  margin: EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                  child: ListTile(
                    onTap: () => _editRecord(r),
                    onLongPress: () => _confirmDelete(r), // 长按删除
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    title: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(child: Text(r.itemName, style: TextStyle(fontSize: 16))),
                        Text(
                          '${isExpense ? '-' : ''}¥${r.amount.abs().toStringAsFixed(2)}',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: amountColor),
                        ),
                      ],
                    ),
                    subtitle: Text(dateFormat.format(r.parsedTime)),
                    trailing: _buildTrailing(isRefunded, isExpense, () => _confirmRefund(r)),
                  ),
                );
              },
            ),
    );
  }

  Widget? _buildTrailing(bool isRefunded, bool isExpense, VoidCallback onRefund) {
    if (isRefunded) {
      return Chip(
        label: Text('已退款'),
        backgroundColor: Colors.red[100],
        labelStyle: TextStyle(color: Colors.red),
      );
    } else if (!isExpense) {
      return TextButton(
        onPressed: onRefund,
        child: Text('退款', style: TextStyle(color: Colors.blue)),
      );
    } else {
      return null;
    }
  }
}
