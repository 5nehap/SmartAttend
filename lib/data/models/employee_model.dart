import 'package:equatable/equatable.dart';

class EmployeeModel extends Equatable {
  final String id;
  final String name;
  final String email;
  final String password;
  final String role;

  const EmployeeModel({
    required this.id,
    required this.name,
    required this.email,
    required this.password,
    required this.role,
  });

  factory EmployeeModel.fromMap(Map<String, dynamic> map) {
    return EmployeeModel(
      id: map['id'] as String,
      name: map['name'] as String,
      email: map['email'] as String,
      password: map['password'] as String,
      role: map['role'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'password': password,
      'role': role,
    };
  }

  EmployeeModel copyWith({
    String? id,
    String? name,
    String? email,
    String? password,
    String? role,
  }) {
    return EmployeeModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      password: password ?? this.password,
      role: role ?? this.role,
    );
  }

  @override
  List<Object?> get props => [id, name, email, password, role];
}
