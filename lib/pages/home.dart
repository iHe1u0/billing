import 'package:billing/beans/payment_record.dart';
import 'package:billing/db/payment_database.dart';
import 'package:billing/services/auth_service.dart';
import 'package:billing/services/session_service.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  double todayIncome = 0.0;
  double todayExpense = 0.0;

  // 用于存储各类别的金额
  Map<String, double> categoryAmountMap = {};

  // 用于存储支付金额和时间
  List<double> paymentAmounts = [];
  List<DateTime> paymentTimes = [];

  // 用于存储收入和支出记录
  List<PaymentRecord> incomeRecords = [];
  List<PaymentRecord> expenseRecords = [];

  @override
  void initState() {
    super.initState();
    _loadData();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // AppUtils.checkForUpdate(context);
    });
  }

  Future<void> _loadData() async {
    final user = Session.currentUser;
    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('登录失效，请重新登录')));
        AuthService.logout();
        context.goNamed("login");
      }
    }
    final income = await PaymentDatabase.instance.getTodayIncome();
    final expense = await PaymentDatabase.instance.getTodayExpense();
    final allPayments = await PaymentDatabase.instance.getTodayPayments();

    setState(() {
      todayIncome = income;
      todayExpense = expense;
      incomeRecords = allPayments.where((r) => r.isExpense == false).toList();
      expenseRecords = allPayments.where((r) => r.isExpense == true).toList();
    });
  }

  void _showDetailDialog(String type, List<PaymentRecord> records) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$type明细'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: records.length,
            itemBuilder: (context, index) {
              final record = records[index];
              return ListTile(
                title: Text(record.itemName),
                subtitle: Text(record.parsedTime.toString()),
                trailing: Text('¥${record.amount.toStringAsFixed(2)}'),
              );
            },
          ),
        ),
        actions: [TextButton(child: Text('关闭'), onPressed: () => Navigator.of(context).pop())],
      ),
    );
  }

  Widget _buildChart() {
    final dataMap = {'收入': todayIncome, '支出': todayExpense};

    final total = todayIncome + todayExpense;
    if (total == 0) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text('暂无数据可展示图表', style: TextStyle(color: Colors.grey)),
      );
    }

    final colors = [Colors.green, Colors.red];
    final labels = dataMap.keys.toList();
    final values = dataMap.values.toList();

    final sections = List.generate(labels.length, (i) {
      final percent = (values[i] / total) * 100.0;
      return PieChartSectionData(
        color: colors[i],
        value: values[i],
        title: '${labels[i]}\n${percent.toStringAsFixed(1)}%',
        radius: 60,
        titleStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
      );
    });

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
                    if (event is FlTapUpEvent && response?.touchedSection != null) {
                      final index = response!.touchedSection!.touchedSectionIndex;
                      if (index == 0) {
                        _showDetailDialog('收入', incomeRecords);
                      } else if (index == 1) {
                        _showDetailDialog('支出', expenseRecords);
                      }
                    }
                  },
                ),
              ),
            ),
          ),
        ),
        _buildLegend(labels, values, colors),
      ],
    );
  }

  Widget _buildLegend(List<String> labels, List<double> values, List<Color> colors) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Wrap(
        spacing: 12,
        runSpacing: 6,
        children: List.generate(labels.length, (i) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 12, height: 12, color: colors[i]),
              SizedBox(width: 4),
              Text('${labels[i]} (¥${values[i].toStringAsFixed(2)})'),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildIncomeCard() {
    final net = todayIncome - todayExpense;
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text('今日收支概览', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
            SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Text('收入: ¥${todayIncome.toStringAsFixed(2)}', style: TextStyle(color: Colors.green)),
                Text('支出: ¥${todayExpense.toStringAsFixed(2)}', style: TextStyle(color: Colors.red)),
              ],
            ),
            SizedBox(height: 8),
            Text('净收入: ¥${net.toStringAsFixed(2)}', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        alignment: WrapAlignment.center,
        children: [
          ElevatedButton.icon(
            icon: Icon(Icons.add),
            label: Text('添加收费'),
            onPressed: () => _navigateAndReload(context, "add_payment"),
          ),
          ElevatedButton.icon(
            icon: Icon(Icons.receipt_long),
            label: Text('流水/退款'),
            onPressed: () => _navigateAndReload(context, "payment_list"),
          ),
          ElevatedButton.icon(
            icon: Icon(Icons.remove_circle),
            label: Text('添加支出'),
            onPressed: () => _navigateAndReload(context, "add_expense"),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildAppBarActions(BuildContext context) {
    final isAdmin = Session.currentUser?.isAdmin ?? false;

    return [
      if (isAdmin)
        IconButton(
          icon: Icon(Icons.admin_panel_settings),
          tooltip: '用户管理',
          onPressed: () {
            context.goNamed("user_management"); // 确保已在 GoRouter 配置中设置此名称
          },
        ),
      IconButton(
        icon: Icon(Icons.logout),
        tooltip: '退出登录',
        onPressed: () async {
          await AuthService.logout();
          if (context.mounted) {
            context.goNamed("login");
          }
        },
      ),
    ];
  }

  void _navigateAndReload(BuildContext context, String routeName) async {
    await context.pushNamed(routeName); // 跳转到命名路由
    _loadData(); // 返回后刷新
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('游乐场收入统计'), actions: _buildAppBarActions(context)),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [_buildIncomeCard(), _buildChart(), _buildActionButtons()],
      ),
    );
  }
}
