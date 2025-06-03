class PaymentRecord {
  final int? id;
  final String itemName;
  final double amount;
  final String time;
  final bool isRefunded;
  final bool isExpense; // 标记是否为支出记录

  PaymentRecord({
    this.id,
    required this.itemName,
    required this.amount,
    required this.time,
    this.isRefunded = false,
    this.isExpense = false,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'itemName': itemName,
    'amount': amount,
    'time': time,
    'isRefunded': isRefunded ? 1 : 0,
    'isExpense': isExpense ? 1 : 0,
  };

  factory PaymentRecord.fromMap(Map<String, dynamic> map) => PaymentRecord(
    id: map['id'],
    itemName: map['itemName'],
    amount: map['amount'],
    time: map['time'],
    isRefunded: map['isRefunded'] == 1,
    isExpense: map['isExpense'] == 1,
  );

  /// 用于从 SQLite 查询结果恢复成对象
  factory PaymentRecord.fromJson(Map<String, dynamic> json) {
    return PaymentRecord(
      id: json['id'] as int?,
      itemName: json['itemName'] as String,
      amount: json['amount'] is int ? (json['amount'] as int).toDouble() : json['amount'] as double,
      time: json['time'] as String,
      isRefunded: (json['isRefunded'] as int) == 1,
      isExpense: (json['isExpense'] as int) == 1,
    );
  }

  /// 用于插入数据库
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'itemName': itemName,
      'amount': amount,
      'time': time,
      'isRefunded': isRefunded ? 1 : 0,
      'isExpense': isExpense ? 1 : 0,
    };
  }

  /// 取时间对象，便于图表处理等逻辑
  DateTime get parsedTime => DateTime.parse(time);

  /// 复制当前对象，允许修改部分字段
  PaymentRecord copyWith({int? id, String? itemName, double? amount, String? time, bool? isRefunded, bool? isExpense}) {
    return PaymentRecord(
      id: id ?? this.id,
      itemName: itemName ?? this.itemName,
      amount: amount ?? this.amount,
      time: time ?? this.time,
      isRefunded: isRefunded ?? this.isRefunded,
      isExpense: isExpense ?? this.isExpense,
    );
  }
}
