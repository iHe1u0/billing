import 'package:billing/beans/payment_record.dart';
import 'package:billing/db/payment_database.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AddPaymentPage extends StatefulWidget {
  const AddPaymentPage({super.key});

  @override
  _AddPaymentPageState createState() => _AddPaymentPageState();
}

class _AddPaymentPageState extends State<AddPaymentPage> {
  final _formKey = GlobalKey<FormState>();
  String itemName = '';
  double amount = 0.0;

  void _save(BuildContext buildContext) async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      final time = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
      final record = PaymentRecord(itemName: itemName, amount: amount, time: time);
      await PaymentDatabase.instance.addPayment(record);
      // ignore: use_build_context_synchronously
      Navigator.pop(buildContext);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('添加收费记录')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                decoration: InputDecoration(labelText: '项目名称'),
                onSaved: (v) => itemName = v ?? '',
                
              ),
              TextFormField(
                decoration: InputDecoration(labelText: '金额'),
                keyboardType: TextInputType.number,
                validator: (v) => (v == null || double.tryParse(v) == null) ? '请输入有效金额' : null,
                onSaved: (v) => amount = double.parse(v!),
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  _save(context);
                },
                child: Text('保存'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
