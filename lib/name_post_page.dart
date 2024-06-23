import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class NamePostPage extends StatefulWidget {
  @override
  _NamePostPageState createState() => _NamePostPageState();
}

class _NamePostPageState extends State<NamePostPage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _detailController = TextEditingController();
  final CollectionReference _namesCollection =
      FirebaseFirestore.instance.collection('names');
  String? _selectedNameId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Name Post App'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Enter your name',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 16.0),
            ElevatedButton(
              onPressed: _postName,
              child: Text('Post Name'),
            ),
            SizedBox(height: 16.0),
            TextField(
              controller: _detailController,
              decoration: InputDecoration(
                labelText: 'Enter detail for selected name',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 16.0),
            ElevatedButton(
              onPressed: _postDetail,
              child: Text('Post Detail'),
            ),
            SizedBox(height: 16.0),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _namesCollection.snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return Center(child: CircularProgressIndicator());
                  }
                  final names = snapshot.data!.docs;
                  return ListView.builder(
                    itemCount: names.length,
                    itemBuilder: (context, index) {
                      return ListTile(
                        title: Text(names[index]['name']),
                        onTap: () => _selectName(names[index].id),
                        subtitle: StreamBuilder<QuerySnapshot>(
                          stream: _namesCollection
                              .doc(names[index].id)
                              .collection('details')
                              .snapshots(),
                          builder: (context, detailsSnapshot) {
                            if (!detailsSnapshot.hasData) {
                              return SizedBox();
                            }
                            final details = detailsSnapshot.data!.docs;
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: details.map((detail) {
                                return Text(' - ${detail['detail']}');
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

  void _postName() {
    if (_nameController.text.isNotEmpty) {
      _namesCollection.add({'name': _nameController.text});
      _nameController.clear();
    }
  }

  void _postDetail() {
    if (_selectedNameId != null && _detailController.text.isNotEmpty) {
      _namesCollection
          .doc(_selectedNameId)
          .collection('details')
          .add({'detail': _detailController.text});
      _detailController.clear();
    }
  }

  void _selectName(String nameId) {
    setState(() {
      _selectedNameId = nameId;
    });
  }
}
