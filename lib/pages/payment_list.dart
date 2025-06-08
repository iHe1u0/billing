import 'package:billing/beans/payment_record.dart';
import 'package:billing/db/payment_database.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';

class PaymentListPage extends StatefulWidget {
  const PaymentListPage({super.key});

  @override
  State<PaymentListPage> createState() => _PaymentListPageState();
}

class _PaymentListPageState extends State<PaymentListPage> {
  List<PaymentRecord> records = [];
  DateTime? _startDate;
  DateTime? _endDate;
  int _page = 0;
  final int _pageSize = 20;
  bool _hasMore = true;
  bool _loading = false;
  final ScrollController _scrollController = ScrollController();
  final dateFormat = DateFormat('yyyy-MM-dd HH:mm');

  @override
  void initState() {
    super.initState();
    _loadRecords(reset: true);
    _scrollController.addListener(_onScroll);
  }

  Future<void> _loadRecords({bool reset = false}) async {
    if (_loading) return;
    _loading = true;

    if (reset) {
      _page = 0;
      _hasMore = true;
      records.clear();
    }

    final all = await PaymentDatabase.instance.fetchPayments();
    final filtered = all.where((r) {
      if (_startDate != null && r.parsedTime.isBefore(_startDate!)) return false;
      if (_endDate != null && r.parsedTime.isAfter(_endDate!)) return false;
      return true;
    }).toList();

    final paginated = filtered.skip(_page * _pageSize).take(_pageSize).toList();
    if (paginated.length < _pageSize) _hasMore = false;

    setState(() {
      records.addAll(paginated);
      _page++;
    });

    _loading = false;
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 100) {
      if (_hasMore) _loadRecords();
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
      locale: const Locale('zh'),
    );
    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end.add(const Duration(days: 1)).subtract(const Duration(seconds: 1));
      });
      _loadRecords(reset: true);
    }
  }

  void _editRecord(PaymentRecord record) async {
    final controller = TextEditingController(text: record.amount.toStringAsFixed(2));
    final result = await showDialog<double>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('修改金额'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
          decoration: const InputDecoration(labelText: '金额'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          TextButton(
            onPressed: () {
              final newAmount = double.tryParse(controller.text.trim());
              if (newAmount != null) Navigator.pop(context, newAmount);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );

    if (result != null && result != record.amount) {
      await PaymentDatabase.instance.updatePayment(record.copyWith(amount: result));
      _loadRecords(reset: true);
    }
  }

  void _confirmRefund(PaymentRecord record) async {
    if (record.isRefunded || record.isExpense) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('确认退款'),
        content: Text('确定要对「${record.itemName}」退款 ¥${record.amount}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('确认')),
        ],
      ),
    );
    if (confirmed == true) {
      await PaymentDatabase.instance.refundPayment(record.id!);
      _loadRecords(reset: true);
    }
  }

  void _confirmDelete(PaymentRecord record) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除「${record.itemName}」吗？此操作不可恢复。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await PaymentDatabase.instance.deletePayment(record.id!);
      _loadRecords(reset: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('收入/支出记录'),
        actions: [
          IconButton(icon: const Icon(Icons.date_range), tooltip: '按日期区间筛选', onPressed: _pickDateRange),
          IconButton(icon: const Icon(Icons.today), tooltip: '按天/月筛选', onPressed: _pickDayOrMonth),
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: '导出数据',
            onPressed: () async {
              final recordsToExport = await PaymentDatabase.instance.queryRecords(start: _startDate, end: _endDate);
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
          ? const Center(child: Text('暂无记录'))
          : ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(8),
              itemCount: records.length + (_hasMore ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == records.length) {
                  return const Center(
                    child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()),
                  );
                }

                final r = records[index];
                final isExpense = r.isExpense;
                final isRefunded = r.isRefunded;
                final amountColor = isExpense
                    ? Colors.red[700]
                    : isRefunded
                    ? Colors.grey
                    : Colors.green[700];

                return Animate(
                  effects: const [
                    FadeEffect(),
                    SlideEffect(begin: Offset(0, 0.1)),
                  ],
                  child: Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 3,
                    margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                    child: ListTile(
                      onTap: () => _editRecord(r),
                      onLongPress: () => _confirmDelete(r),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      title: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(child: Text(r.itemName, style: TextStyle(fontSize: 16))),
                          Text(
                            '${isExpense ? '-' : ''}¥${r.amount.abs().toStringAsFixed(2)}',
                            style: TextStyle(fontSize: 16, color: amountColor, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      subtitle: Text(dateFormat.format(r.parsedTime)),
                      trailing: _buildTrailing(isRefunded, isExpense, () => _confirmRefund(r)),
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget? _buildTrailing(bool isRefunded, bool isExpense, VoidCallback onRefund) {
    if (isRefunded) {
      return Chip(
        label: const Text('已退款'),
        backgroundColor: Colors.red[100],
        labelStyle: const TextStyle(color: Colors.red),
      );
    } else if (!isExpense) {
      return TextButton(
        onPressed: onRefund,
        child: const Text('退款', style: TextStyle(color: Colors.blue)),
      );
    } else {
      return null;
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _pickDayOrMonth() async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('选择类型'),
        children: [
          SimpleDialogOption(child: const Text('按天筛选'), onPressed: () => Navigator.pop(context, 'day')),
          SimpleDialogOption(child: const Text('按月筛选'), onPressed: () => Navigator.pop(context, 'month')),
        ],
      ),
    );
    if (!mounted) return;
    if (result == 'day') {
      final selected = await showDatePicker(
        context: context,
        initialDate: DateTime.now(),
        firstDate: DateTime(2025),
        lastDate: DateTime(9999),
        locale: const Locale('zh'),
      );
      if (selected != null) {
        setState(() {
          _startDate = DateTime(selected.year, selected.month, selected.day, 0, 0, 0);
          _endDate = DateTime(selected.year, selected.month, selected.day, 23, 59, 59);
        });
        _loadRecords(reset: true);
      }
    } else if (result == 'month') {
      final selected = await showDatePicker(
        context: context,
        initialDate: DateTime.now(),
        firstDate: DateTime(2025),
        lastDate: DateTime(9999),
        helpText: '选择任意一日代表月份',
        locale: const Locale('zh'),
      );
      if (selected != null) {
        setState(() {
          _startDate = DateTime(selected.year, selected.month, 1, 0, 0, 0);
          _endDate = DateTime(selected.year, selected.month + 1, 0, 23, 59, 59); // 月底
        });
        _loadRecords(reset: true);
      }
    }
  }
}
