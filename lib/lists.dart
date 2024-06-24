import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:travelist/list_detail.dart';

class ListsPage extends StatefulWidget {
  @override
  _ListsPageState createState() => _ListsPageState();
}

class _ListsPageState extends State<ListsPage> {
  final CollectionReference _listsCollection =
      FirebaseFirestore.instance.collection('lists');

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
    );
  }
}
