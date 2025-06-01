import 'package:billing/beans/payment_record.dart';
import 'package:billing/db/payment_database.dart';
import 'package:billing/pages/add_payment.dart';
import 'package:billing/pages/payment_list.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  double todayIncome = 0.0;
  List<double> paymentAmounts = [];
  List<DateTime> paymentTimes = [];
  Map<String, double> categoryAmountMap = {};

  @override
  void initState() {
    super.initState();
    _loadIncome();
  }

  Future<void> _loadIncome() async {
    final income = await PaymentDatabase.instance.getTodayIncome();
    final payments = await PaymentDatabase.instance.getTodayPayments();

    setState(() {
      todayIncome = income;
      paymentAmounts = payments.map((e) => e.amount).toList();
      paymentTimes = payments.map((e) => e.parsedTime).toList();
      _calculateCategoryAmounts(payments);
    });
  }

  void _calculateCategoryAmounts(List<PaymentRecord> records) {
    categoryAmountMap.clear();
    for (var record in records) {
      if (record.isRefunded) continue;
      categoryAmountMap.update(record.itemName, (value) => value + record.amount, ifAbsent: () => record.amount);
    }
  }

  void _showDetailDialog(String category, double amount, double percentage) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('收入详情'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('项目：$category'),
            Text('金额：¥${amount.toStringAsFixed(2)}'),
            Text('占比：${percentage.toStringAsFixed(1)}%'),
          ],
        ),
        actions: [TextButton(child: Text('关闭'), onPressed: () => Navigator.of(context).pop())],
      ),
    );
  }

  Widget _buildChart() {
    if (categoryAmountMap.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text('暂无数据可展示图表', style: TextStyle(color: Colors.grey)),
      );
    }

    final total = categoryAmountMap.values.fold(0.0, (a, b) => a + b);
    final List<PieChartSectionData> sections = [];
    final colors = [Colors.blue, Colors.green, Colors.orange, Colors.purple, Colors.red, Colors.teal];
    final categories = categoryAmountMap.keys.toList();
    final amounts = categoryAmountMap.values.toList();

    for (int i = 0; i < categories.length; i++) {
      final amount = amounts[i];
      final percentage = total == 0 ? 0 : (amount / total) * 100;

      sections.add(
        PieChartSectionData(
          color: colors[i % colors.length],
          value: amount,
          title: percentage < 5 ? '' : '${categories[i]}\n${percentage.toStringAsFixed(1)}%',
          radius: 60,
          titleStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
        ),
      );
    }

    return Column(
      children: [
        SizedBox(
          height: 250,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: PieChart(
              PieChartData(
                sections: sections,
                sectionsSpace: 2,
                centerSpaceRadius: 40,
                pieTouchData: PieTouchData(
                  touchCallback: (event, response) {
                    // 只处理点击释放事件
                    if (event is FlTapUpEvent && response != null && response.touchedSection != null) {
                      final index = response.touchedSection!.touchedSectionIndex;
                      if (index >= 0 && index < categories.length) {
                        final category = categories[index];
                        final amount = amounts[index];
                        final percentage = total == 0 ? 0 : (amount / total) * 100;
                        _showDetailDialog(category, amount, percentage * 1.0);
                      }
                    }
                  },
                ),
              ),
            ),
          ),
        ),
        _buildLegend(categories, amounts, colors),
      ],
    );
  }

  Widget _buildLegend(List<String> categories, List<double> amounts, List<Color> colors) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Wrap(
        spacing: 12,
        runSpacing: 6,
        children: List.generate(categories.length, (i) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 12, height: 12, color: colors[i % colors.length]),
              SizedBox(width: 4),
              Text('${categories[i]} (¥${amounts[i].toStringAsFixed(2)})'),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildIncomeCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text('今日总收入', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
            SizedBox(height: 8),
            Text(
              '¥${todayIncome.toStringAsFixed(2)}',
              style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.green),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          ElevatedButton.icon(
            icon: Icon(Icons.add),
            label: Text('添加收费'),
            onPressed: () => _navigateAndReload(context, AddPaymentPage()),
          ),
          ElevatedButton.icon(
            icon: Icon(Icons.receipt_long),
            label: Text('流水/退款'),
            onPressed: () => _navigateAndReload(context, PaymentListPage()),
          ),
        ],
      ),
    );
  }

  void _navigateAndReload(BuildContext context, Widget page) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => page));
    _loadIncome();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('游乐场收入统计')),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center, // 垂直方向居中
        crossAxisAlignment: CrossAxisAlignment.center, // 水平方向居中
        children: [_buildIncomeCard(), _buildChart(), _buildActionButtons()],
      ),
    );
  }
}
