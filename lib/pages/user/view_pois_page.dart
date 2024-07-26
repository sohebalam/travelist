import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ViewPoisPage extends StatelessWidget {
  final String listId;

  ViewPoisPage({required this.listId});

  @override
  Widget build(BuildContext context) {
    final CollectionReference poisCollection = FirebaseFirestore.instance
        .collection('lists')
        .doc(listId)
        .collection('pois');

    return Scaffold(
      appBar: AppBar(
        title: Text('POIs'),
        backgroundColor: Colors.teal,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: poisCollection.snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(child: CircularProgressIndicator());
          }

          var pois = snapshot.data!.docs;

          return ListView.builder(
            itemCount: pois.length,
            itemBuilder: (context, index) {
              var poiData = pois[index].data() as Map<String, dynamic>;
              var poiId = pois[index].id;

              return Card(
                child: ListTile(
                  title: Text(poiData['name'] ?? 'Unnamed POI'),
                  subtitle: Text(poiData['description'] ?? 'No description'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(Icons.edit, color: Colors.blue),
                        onPressed: () {
                          _showEditPoiDialog(context, poiId, poiData);
                        },
                      ),
                      IconButton(
                        icon: Icon(Icons.delete, color: Colors.red),
                        onPressed: () {
                          _showDeletePoiConfirmationDialog(context, poiId);
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showEditPoiDialog(
      BuildContext context, String poiId, Map<String, dynamic> poiData) {
    final _nameController = TextEditingController(text: poiData['name']);
    final _descriptionController =
        TextEditingController(text: poiData['description']);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Edit POI'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _nameController,
                decoration: InputDecoration(labelText: 'Name'),
              ),
              TextField(
                controller: _descriptionController,
                decoration: InputDecoration(labelText: 'Description'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                _editPoi(context, poiId, _nameController.text,
                    _descriptionController.text);
                Navigator.of(context).pop();
              },
              child: Text('Save'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _editPoi(BuildContext context, String poiId, String newName,
      String newDescription) async {
    final poiRef = FirebaseFirestore.instance
        .collection('lists')
        .doc(listId)
        .collection('pois')
        .doc(poiId);

    try {
      await poiRef.update({
        'name': newName,
        'description': newDescription,
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('POI updated')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update POI')),
      );
    }
  }

  Future<void> _showDeletePoiConfirmationDialog(
      BuildContext context, String poiId) async {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Delete POI'),
          content: Text('Are you sure you want to delete this POI?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                _deletePoi(context, poiId);
                Navigator.of(context).pop();
              },
              child: Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deletePoi(BuildContext context, String poiId) async {
    final poiRef = FirebaseFirestore.instance
        .collection('lists')
        .doc(listId)
        .collection('pois')
        .doc(poiId);

    try {
      await poiRef.delete();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('POI deleted')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete POI')),
      );
    }
  }
}
