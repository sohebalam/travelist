import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:travelist/pages/list_detail.dart';
import 'package:travelist/services/shared_functions.dart';
import 'package:travelist/services/styles.dart';

class ListsPage extends StatefulWidget {
  const ListsPage({super.key});

  @override
  _ListsPageState createState() => _ListsPageState();
}

class _ListsPageState extends State<ListsPage> {
  final CollectionReference _listsCollection =
      FirebaseFirestore.instance.collection('lists');

  int _selectedIndex = 1;
  User? _currentUser;

  @override
  void initState() {
    super.initState();
    _currentUser = FirebaseAuth.instance.currentUser;
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    if (index == 0) {
      Navigator.pushNamed(context, '/');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Lists',
          style: TextStyle(
            color: Colors.white,
            fontSize:
                MediaQuery.maybeTextScalerOf(context)?.scale(18.0) ?? 18.0,
          ),
        ),
        backgroundColor: AppColors.primaryColor,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _listsCollection
            .where('userId', isEqualTo: _currentUser?.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(),
            );
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
                    return Semantics(
                      label:
                          'List: ${listData.containsKey('list') ? listData['list'] : 'Unnamed List'}, loading places',
                      child: ListTile(
                        title: Text(
                          listData.containsKey('list')
                              ? listData['list']
                              : 'Unnamed List',
                          style: TextStyle(
                            fontSize: MediaQuery.maybeTextScalerOf(context)
                                    ?.scale(16.0) ??
                                16.0,
                          ),
                        ),
                        subtitle: Text(
                          'Loading...',
                          style: TextStyle(
                            fontSize: MediaQuery.maybeTextScalerOf(context)
                                    ?.scale(14.0) ??
                                14.0,
                          ),
                        ),
                      ),
                    );
                  }

                  var pois = poiSnapshot.data!.docs;

                  return Semantics(
                    label:
                        'List: ${listData.containsKey('list') ? listData['list'] : 'Unnamed List'}, ${pois.length} places',
                    child: ListTile(
                      title: Text(
                        listData.containsKey('list')
                            ? listData['list']
                            : 'Unnamed List',
                        style: TextStyle(
                          fontSize: MediaQuery.maybeTextScalerOf(context)
                                  ?.scale(16.0) ??
                              16.0,
                        ),
                      ),
                      subtitle: Text(
                        '${pois.length} places',
                        style: TextStyle(
                          fontSize: MediaQuery.maybeTextScalerOf(context)
                                  ?.scale(14.0) ??
                              14.0,
                        ),
                      ),
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
                    ),
                  );
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddListDialog(context),
        tooltip: 'Add New List',
        backgroundColor: AppColors.primaryColor,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8.0),
        ),
      ),
    );
  }

  void _showAddListDialog(BuildContext context) {
    final formKey = GlobalKey<FormState>();
    final listNameController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            'Add New List',
            style: TextStyle(
              fontSize:
                  MediaQuery.maybeTextScalerOf(context)?.scale(18.0) ?? 18.0,
            ),
          ),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: listNameController,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a list name';
                }
                return null;
              },
              decoration: InputDecoration(
                hintText: 'List Name',
                hintStyle: TextStyle(
                  fontSize:
                      MediaQuery.maybeTextScalerOf(context)?.scale(16.0) ??
                          16.0,
                ),
              ),
              style: TextStyle(
                fontSize:
                    MediaQuery.maybeTextScalerOf(context)?.scale(16.0) ?? 16.0,
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text(
                'Cancel',
                style: TextStyle(
                  fontSize:
                      MediaQuery.maybeTextScalerOf(context)?.scale(16.0) ??
                          16.0,
                ),
              ),
            ),
            TextButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  await createList(listNameController.text, _listsCollection);
                  Navigator.of(context).pop();
                }
              },
              child: Text(
                'Add',
                style: TextStyle(
                  fontSize:
                      MediaQuery.maybeTextScalerOf(context)?.scale(16.0) ??
                          16.0,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
