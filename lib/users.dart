class User {
  final String name;
  final String location;
  final List<String> interests;

  User({
    required this.name,
    required this.location,
    required this.interests,
  });
}

final List<User> users = [
  User(
    name: 'John Doe',
    location: 'New York',
    interests: ['nightclub', 'museum', 'restaurant'],
  ),
  User(
    name: 'Jane Smith',
    location: 'London',
    interests: ['historic site', 'park', 'theater'],
  ),
  User(
    name: 'Alice Johnson',
    location: 'Paris',
    interests: ['cafe', 'art gallery', 'shopping'],
  ),
];
