import 'package:billing/beans/payment_record.dart';
import 'package:billing/db/payment_database.dart';
import 'package:flutter/material.dart';

class PaymentListPage extends StatefulWidget {
  const PaymentListPage({super.key});

  @override
  _PaymentListPageState createState() => _PaymentListPageState();
}

class _PaymentListPageState extends State<PaymentListPage> {
  List<PaymentRecord> records = [];

  @override
  void initState() {
    super.initState();
    _loadRecords();
  }

  Future<void> _loadRecords() async {
    final data = await PaymentDatabase.instance.fetchPayments();
    setState(() => records = data);
  }

  void _refund(PaymentRecord record) async {
    if (record.isRefunded) return;
    await PaymentDatabase.instance.refundPayment(record.id!);
    _loadRecords();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('收费记录')),
      body: ListView.builder(
        itemCount: records.length,
        itemBuilder: (context, index) {
          final r = records[index];
          return ListTile(
            title: Text('${r.itemName} - ¥${r.amount.toStringAsFixed(2)}'),
            subtitle: Text(r.time),
            trailing: r.isRefunded
                ? Text('已退款', style: TextStyle(color: Colors.red))
                : TextButton(onPressed: () => _refund(r), child: Text('退款')),
          );
        },
      ),
    );
  }
}
