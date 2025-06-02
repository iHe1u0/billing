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
    if (record.isRefunded) return;
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
      helpText: '选择收费记录日期范围',
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('收费记录'),
        actions: [IconButton(icon: Icon(Icons.date_range), onPressed: _pickDateRange, tooltip: '选择日期范围')],
      ),
      body: records.isEmpty
          ? Center(child: Text('暂无记录'))
          : ListView.builder(
              padding: EdgeInsets.all(8),
              itemCount: records.length,
              itemBuilder: (context, index) {
                final r = records[index];
                return Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 3,
                  margin: EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                  child: ListTile(
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    title: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(child: Text(r.itemName, style: TextStyle(fontSize: 16))),
                        Text(
                          '¥${r.amount.toStringAsFixed(2)}',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green[700]),
                        ),
                      ],
                    ),
                    subtitle: Text(dateFormat.format(r.parsedTime)),
                    trailing: r.isRefunded
                        ? Chip(
                            label: Text('已退款'),
                            backgroundColor: Colors.red[100],
                            labelStyle: TextStyle(color: Colors.red),
                          )
                        : TextButton(
                            onPressed: () => _refund(r),
                            child: Text('退款', style: TextStyle(color: Colors.blue)),
                          ),
                  ),
                );
              },
            ),
    );
  }
}
