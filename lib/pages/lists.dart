import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:travelist/pages/list_detail.dart';
import 'package:travelist/services/bottom_navbar.dart'; // Ensure this is the correct path to your BottomNavBar component

class ListsPage extends StatefulWidget {
  @override
  _ListsPageState createState() => _ListsPageState();
}

class _ListsPageState extends State<ListsPage> {
  final CollectionReference _listsCollection =
      FirebaseFirestore.instance.collection('lists');

  int _selectedIndex = 1; // Set the default selected index to 1 (Lists Page)

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    if (index == 0) {
      Navigator.pushNamed(context, '/'); // Navigate to HomePage
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Lists'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _listsCollection.snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(child: CircularProgressIndicator());
          }

          var lists = snapshot.data!.docs;

          return ListView.builder(
            itemCount: lists.length,
            itemBuilder: (context, index) {
              var listData = lists[index].data() as Map<String, dynamic>;
              return FutureBuilder<QuerySnapshot>(
                future: _listsCollection
                    .doc(lists[index].id)
                    .collection('pois')
                    .get(),
                builder: (context, poiSnapshot) {
                  if (!poiSnapshot.hasData) {
                    return ListTile(
                      title: Text(listData.containsKey('list')
                          ? listData['list']
                          : 'Unnamed List'),
                      subtitle: Text('Loading...'),
                    );
                  }

                  var pois = poiSnapshot.data!.docs;

                  return ListTile(
                    title: Text(listData.containsKey('list')
                        ? listData['list']
                        : 'Unnamed List'),
                    subtitle: Text('${pois.length} places'),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ListDetailsPage(
                            listId: lists[index].id,
                            listName: listData['list'],
                          ),
                        ),
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddListDialog(context),
        child: Icon(Icons.add),
        tooltip: 'Add New List',
      ),
      // bottomNavigationBar: BottomNavBar(
      //   selectedIndex: _selectedIndex,
      //   onItemTapped: _onItemTapped,
      //   onLogoutTapped: () {
      //     print('logout');
      //   },
      // ),
    );
  }

  void _showAddListDialog(BuildContext context) {
    final _formKey = GlobalKey<FormState>();
    final _listNameController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Add New List'),
          content: Form(
            key: _formKey,
            child: TextFormField(
              controller: _listNameController,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a list name';
                }
                return null;
              },
              decoration: InputDecoration(hintText: 'List Name'),
            ),
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
                if (_formKey.currentState!.validate()) {
                  _listsCollection.add({
                    'list': _listNameController.text,
                  });
                  Navigator.of(context).pop();
                }
              },
              child: Text('Add'),
            ),
          ],
        );
      },
    );
  }
}
