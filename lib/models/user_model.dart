class UserModel {
  String uid;
  String email;
  String? name;
  String image;
  List<String> interests;
  bool isAdmin;

  UserModel({
    required this.uid,
    required this.email,
    this.name,
    this.image = '',
    this.interests = const [],
    this.isAdmin = false, // Default value set to false
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      uid: json['uid'],
      email: json['email'],
      name: json['name'],
      image: json.containsKey('image') ? json['image'] : '',
      interests: List<String>.from(json['interests'] ?? []),
      isAdmin: json['isAdmin'] ??
          false, // Default value set to false if not present in JSON
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'email': email,
      'name': name,
      'image': image,
      'interests': interests,
      'isAdmin': isAdmin, // Include isAdmin in JSON representation
    };
  }

  void addInterest(String interest) {
    interest = interest.trim().toLowerCase();

    for (String existingInterest in interests) {
      if (existingInterest == interest ||
          existingInterest.contains(interest) ||
          interest.contains(existingInterest)) {
        return;
      }
    }

    if (interests.length >= 10) {
      interests.removeLast();
    }
    interests.insert(0, interest);
  }
}
