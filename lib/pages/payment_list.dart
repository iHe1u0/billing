import 'package:billing/beans/payment_record.dart';
import 'package:billing/db/payment_database.dart';
import 'package:flutter/material.dart';
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

  void _refund(PaymentRecord record) async {
    if (record.isRefunded || record.isExpense) return; // 只有正值收入才能退款
    await PaymentDatabase.instance.refundPayment(record.id!);
    _loadRecords();
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
          decoration: InputDecoration(labelText: '金额（正数为收入，负数为支出）', border: OutlineInputBorder()),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('收入/支出记录'),
        actions: [IconButton(icon: Icon(Icons.date_range), onPressed: _pickDateRange, tooltip: '选择日期范围')],
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
                    trailing: _buildTrailing(isRefunded, isExpense, () => _refund(r)),
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
