class PaymentRecord {
  final int? id;
  final String itemName;
  final double amount;
  final String time;
  final bool isRefunded;
  final bool isExpense; // 标记是否为支出记录
  final int userId; // 更改字段类型：用户唯一标识符

  PaymentRecord({
    this.id,
    required this.itemName,
    required this.amount,
    required this.time,
    this.isRefunded = false,
    this.isExpense = false,
    required this.userId,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'itemName': itemName,
    'amount': amount,
    'time': time,
    'isRefunded': isRefunded ? 1 : 0,
    'isExpense': isExpense ? 1 : 0,
    'userId': userId,
  };

  factory PaymentRecord.fromMap(Map<String, dynamic> map) => PaymentRecord(
    id: map['id'],
    itemName: map['itemName'],
    amount: map['amount'] is int ? (map['amount'] as int).toDouble() : map['amount'] as double,
    time: map['time'],
    isRefunded: map['isRefunded'] == 1,
    isExpense: map['isExpense'] == 1,
    userId: map['userId'] as int,
  );

  factory PaymentRecord.fromJson(Map<String, dynamic> json) {
    return PaymentRecord(
      id: json['id'] as int?,
      itemName: json['itemName'] as String,
      amount: json['amount'] is int ? (json['amount'] as int).toDouble() : json['amount'] as double,
      time: json['time'] as String,
      isRefunded: (json['isRefunded'] as int) == 1,
      isExpense: (json['isExpense'] as int) == 1,
      userId: json['userId'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'itemName': itemName,
      'amount': amount,
      'time': time,
      'isRefunded': isRefunded ? 1 : 0,
      'isExpense': isExpense ? 1 : 0,
      'userId': userId,
    };
  }

  DateTime get parsedTime => DateTime.parse(time);

  PaymentRecord copyWith({
    int? id,
    String? itemName,
    double? amount,
    String? time,
    bool? isRefunded,
    bool? isExpense,
    int? userId,
  }) {
    return PaymentRecord(
      id: id ?? this.id,
      itemName: itemName ?? this.itemName,
      amount: amount ?? this.amount,
      time: time ?? this.time,
      isRefunded: isRefunded ?? this.isRefunded,
      isExpense: isExpense ?? this.isExpense,
      userId: userId ?? this.userId,
    );
  }
}
