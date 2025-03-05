class Account {
  String id;
  String name;
  double balance;

  Account({required this.id, required this.name, required this.balance});

  factory Account.fromMap(Map<String, dynamic> json) {
    return Account(
      id: json['id'],
      name: json['name'],
      balance: json['balance'].toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'balance': balance,
    };
  }

  void updateBalance(double amount) {
    balance += amount;
  }
}
