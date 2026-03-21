class MemberModel {
  final String id;
  final String name;
  final int age;
  final String relation;
  final bool isSelf;

  const MemberModel({
    required this.id,
    required this.name,
    required this.age,
    required this.relation,
    required this.isSelf,
  });

  factory MemberModel.fromMap(String id, Map<String, dynamic> map) {
    return MemberModel(
      id: id,
      name: map['name'] as String? ?? '',
      age: (map['age'] as num?)?.toInt() ?? 0,
      relation: map['relation'] as String? ?? '',
      isSelf: map['isSelf'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'age': age,
      'relation': relation,
      'isSelf': isSelf,
    };
  }

  MemberModel copyWith({
    String? id,
    String? name,
    int? age,
    String? relation,
    bool? isSelf,
  }) {
    return MemberModel(
      id: id ?? this.id,
      name: name ?? this.name,
      age: age ?? this.age,
      relation: relation ?? this.relation,
      isSelf: isSelf ?? this.isSelf,
    );
  }

  @override
  String toString() => 'MemberModel(id: $id, name: $name, relation: $relation)';
}

