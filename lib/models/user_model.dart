class UserModel {
  String uid;
  String email;
  String? name;
  String image;
  List<String>? interests;

  UserModel({
    required this.uid,
    required this.email,
    this.name,
    this.image = '',
    this.interests,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      uid: json['uid'],
      email: json['email'],
      name: json['name'],
      image: json.containsKey('image') ? json['image'] : '',
      interests: json.containsKey('interests')
          ? List<String>.from(json['interests'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    final data = {
      'uid': uid,
      'email': email,
      'name': name,
      'image': image,
    };

    if (interests != null) {
      data['interests'] = interests as String?;
    }

    return data;
  }

  void addInterest(String interest) {
    if (interests == null) {
      interests = [interest];
    } else {
      interests!.insert(0, interest);
    }
  }
}
