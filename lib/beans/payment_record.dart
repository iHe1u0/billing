class PaymentRecord {
  final int? id;
  final String itemName;
  final double amount;
  final String time;
  final bool isRefunded;

  PaymentRecord({this.id, required this.itemName, required this.amount, required this.time, this.isRefunded = false});

  Map<String, dynamic> toMap() => {
    'id': id,
    'itemName': itemName,
    'amount': amount,
    'time': time,
    'isRefunded': isRefunded ? 1 : 0,
  };

  factory PaymentRecord.fromMap(Map<String, dynamic> map) => PaymentRecord(
    id: map['id'],
    itemName: map['itemName'],
    amount: map['amount'],
    time: map['time'],
    isRefunded: map['isRefunded'] == 1,
  );

  /// ✅ 用于从 SQLite 查询结果恢复成对象
  factory PaymentRecord.fromJson(Map<String, dynamic> json) {
    return PaymentRecord(
      id: json['id'] as int?,
      itemName: json['itemName'] as String,
      amount: json['amount'] is int ? (json['amount'] as int).toDouble() : json['amount'] as double,
      time: json['time'] as String,
      isRefunded: (json['isRefunded'] as int) == 1,
    );
  }

  /// ✅ 用于插入数据库
  Map<String, dynamic> toJson() {
    return {'id': id, 'itemName': itemName, 'amount': amount, 'time': time, 'isRefunded': isRefunded ? 1 : 0};
  }

  /// ✅ 可选：获取时间对象，便于图表处理等逻辑
  DateTime get parsedTime => DateTime.parse(time);
}
