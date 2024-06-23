import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class listPostPage extends StatefulWidget {
  @override
  _listPostPageState createState() => _listPostPageState();
}

class _listPostPageState extends State<listPostPage> {
  final TextEditingController _listController = TextEditingController();
  final TextEditingController _poiController = TextEditingController();
  final CollectionReference _listsCollection =
      FirebaseFirestore.instance.collection('lists');
  String? _selectedlistId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('list Post App'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _listController,
              decoration: InputDecoration(
                labelText: 'Enter your list',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 16.0),
            ElevatedButton(
              onPressed: _postlist,
              child: Text('Post list'),
            ),
            SizedBox(height: 16.0),
            TextField(
              controller: _poiController,
              decoration: InputDecoration(
                labelText: 'Enter poi for selected list',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 16.0),
            ElevatedButton(
              onPressed: _postpoi,
              child: Text('Post poi'),
            ),
            SizedBox(height: 16.0),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _listsCollection.snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return Center(child: CircularProgressIndicator());
                  }
                  final lists = snapshot.data!.docs;
                  return ListView.builder(
                    itemCount: lists.length,
                    itemBuilder: (context, index) {
                      return ListTile(
                        title: Text(lists[index]['list']),
                        onTap: () => _selectlist(lists[index].id),
                        subtitle: StreamBuilder<QuerySnapshot>(
                          stream: _listsCollection
                              .doc(lists[index].id)
                              .collection('pois')
                              .snapshots(),
                          builder: (context, poisSnapshot) {
                            if (!poisSnapshot.hasData) {
                              return SizedBox();
                            }
                            final pois = poisSnapshot.data!.docs;
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: pois.map((poi) {
                                return Text(' - ${poi['poi']}');
                              }).toList(),
                            );
                          },
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _postlist() {
    if (_listController.text.isNotEmpty) {
      _listsCollection.add({'list': _listController.text});
      _listController.clear();
    }
  }

  void _postpoi() {
    if (_selectedlistId != null && _poiController.text.isNotEmpty) {
      _listsCollection
          .doc(_selectedlistId)
          .collection('pois')
          .add({'poi': _poiController.text});
      _poiController.clear();
    }
  }

  void _selectlist(String listId) {
    setState(() {
      _selectedlistId = listId;
    });
  }
}
