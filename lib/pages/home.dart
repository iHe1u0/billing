import 'dart:convert';

import 'package:billing/beans/payment_record.dart';
import 'package:billing/db/payment_database.dart';
import 'package:billing/pages/add_payment.dart';
import 'package:billing/pages/payment_list.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      checkForUpdate(context);
    });
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

  Future<void> checkForUpdate(BuildContext context) async {
    const updateJsonUrl = 'http://192.168.0.109:10924/#s/_n76K9Ww'; // 替换为你的链接

    try {
      final response = await http.get(Uri.parse(updateJsonUrl));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final latestVersion = data['version'];
        final downloadUrl = data['url'];
        final description = data['desc'];

        final packageInfo = await PackageInfo.fromPlatform();
        final currentVersion = packageInfo.version;

        if (_isNewerVersion(latestVersion, currentVersion) && (context.mounted)) {
          _showUpdateDialog(context, latestVersion, description, downloadUrl);
        }
      } else {
        debugPrint("服务器响应错误: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("检查更新失败: $e");
    }
  }

  bool _isNewerVersion(String latest, String current) {
    List<int> latestParts = latest.split('.').map(int.parse).toList();
    List<int> currentParts = current.split('.').map(int.parse).toList();
    debugPrint("最新版本: $latest, 当前版本: $current");
    for (int i = 0; i < latestParts.length; i++) {
      if (i >= currentParts.length || latestParts[i] > currentParts[i]) {
        return true;
      } else if (latestParts[i] < currentParts[i]) {
        return false;
      }
    }
    return false;
  }

  void _showUpdateDialog(BuildContext context, String version, String desc, String url) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("发现新版本 v$version"),
          content: Text(desc),
          actions: [
            TextButton(child: Text("稍后"), onPressed: () => Navigator.of(context).pop()),
            TextButton(
              child: Text("立即更新"),
              onPressed: () async {
                Navigator.of(context).pop();
                if (await canLaunchUrl(Uri.parse(url))) {
                  await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                } else {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("无法打开下载链接，请稍后再试。")));
                  }
                }
              },
            ),
          ],
        );
      },
    );
  }
}
