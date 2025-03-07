import 'package:hive/hive.dart';
import 'package:finazaap/data/model/add_date.dart';

// Definición de la clase AccountItem
class AccountItem extends HiveObject {
  String title;
  double balance;

  AccountItem({required this.title, required this.balance});

  // Métodos para serializar y deserializar la clase
  factory AccountItem.fromJson(Map<String, dynamic> json) {
    return AccountItem(
      title: json['title'],
      balance: json['balance'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'balance': balance,
    };
  }
}

// Adaptador de Hive para AccountItem
class AccountItemAdapter extends TypeAdapter<AccountItem> {
  @override
  final typeId = 2; // Cambiar a 2 para evitar conflicto con AdddataAdapter

  @override
  AccountItem read(BinaryReader reader) {
    return AccountItem(
      title: reader.readString(),
      balance: reader.readDouble(),
    );
  }

  @override
  void write(BinaryWriter writer, AccountItem obj) {
    writer.writeString(obj.title);
    writer.writeDouble(obj.balance);
  }
}

final accountBox = Hive.box<AccountItem>('accounts');

void updateAccountBalance(String accountId, double amount, bool isIncome) {
  var account = accountBox.get(accountId);
  if (account != null) {
    if (isIncome) {
      account.balance += amount;
    } else {
      account.balance -= amount;
    }
    account.save();
  }
}

bool validateExpense(String accountId, double amount) {
  var account = accountBox.get(accountId);
  if (account != null) {
    return account.balance >= amount;
  }
  return false;
}