class UserModel {
  String uid;
  String email;
  String? name;
  String image;

  UserModel(
      {required this.uid, required this.email, this.name, this.image = ''});

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      uid: json['uid'],
      email: json['email'],
      name: json['name'],
      image: json.containsKey('image') ? json['image'] : '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'email': email,
      'name': name,
      'image': image,
    };
  }
}
