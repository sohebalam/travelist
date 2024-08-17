// reorder_dialog.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ReorderDialog extends StatefulWidget {
  final List<Map<String, dynamic>> poiData;
  final String listId;
  final Function(List<Map<String, dynamic>>) onSave;

  ReorderDialog({
    required this.poiData,
    required this.listId,
    required this.onSave,
  });

  @override
  _ReorderDialogState createState() => _ReorderDialogState();
}

class _ReorderDialogState extends State<ReorderDialog> {
  late List<Map<String, dynamic>> reorderedPOIData;

  @override
  void initState() {
    super.initState();
    reorderedPOIData = List.from(widget.poiData);
  }

  @override
  Widget build(BuildContext context) {
    int _draggingIndex = -1;

    return AlertDialog(
      title: Text(
        "Reorder Points of Interest",
        style: TextStyle(
          fontSize: MediaQuery.maybeTextScalerOf(context)?.scale(18.0) ?? 18.0,
        ),
      ),
      content: Container(
        width: double.maxFinite,
        height: MediaQuery.of(context).size.height * 0.6,
        child: ListView.builder(
          padding: EdgeInsets.zero,
          itemCount: reorderedPOIData.length,
          itemBuilder: (context, index) {
            double textSize = reorderedPOIData.length > 5
                ? MediaQuery.maybeTextScalerOf(context)?.scale(14.0) ?? 14.0
                : MediaQuery.maybeTextScalerOf(context)?.scale(16.0) ?? 16.0;

            return DragTarget<Map<String, dynamic>>(
              builder: (context, candidateData, rejectedData) {
                return Draggable<Map<String, dynamic>>(
                  data: reorderedPOIData[index],
                  childWhenDragging: Container(
                    padding: const EdgeInsets.symmetric(vertical: 2.0),
                    child: ListTile(
                      contentPadding:
                          EdgeInsets.symmetric(vertical: 0.0, horizontal: 1.0),
                      dense: true,
                      minVerticalPadding: 0,
                      leading: Text(
                        '${index + 1}.',
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: textSize,
                        ),
                      ),
                      title: Text(
                        reorderedPOIData[index]['name'],
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: textSize,
                        ),
                      ),
                    ),
                  ),
                  feedback: Material(
                    child: Container(
                      width: MediaQuery.of(context).size.width - 20,
                      padding: const EdgeInsets.all(1.0),
                      color: Colors.blueAccent,
                      child: ListTile(
                        dense: true,
                        leading: Text(
                          '${index + 1}.',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: textSize,
                          ),
                        ),
                        title: Text(
                          reorderedPOIData[index]['name'],
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: textSize,
                          ),
                        ),
                      ),
                    ),
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 2.0),
                    child: ListTile(
                      dense: true,
                      minVerticalPadding: 0,
                      leading: Text(
                        '${index + 1}.',
                        style: TextStyle(
                          fontSize: textSize,
                        ),
                      ),
                      title: Text(
                        reorderedPOIData[index]['name'],
                        style: TextStyle(
                          fontSize: textSize,
                        ),
                      ),
                      trailing: const Icon(Icons.drag_handle),
                    ),
                  ),
                  onDragStarted: () {
                    setState(() {
                      _draggingIndex = index;
                    });
                  },
                  onDragEnd: (details) {
                    setState(() {
                      _draggingIndex = -1;
                    });
                  },
                );
              },
              onWillAcceptWithDetails:
                  (DragTargetDetails<Map<String, dynamic>> details) {
                return details.data != reorderedPOIData[index];
              },
              onAcceptWithDetails:
                  (DragTargetDetails<Map<String, dynamic>> details) {
                final oldIndex = reorderedPOIData.indexOf(details.data);
                setState(() {
                  if (oldIndex != index) {
                    var movedItem = reorderedPOIData.removeAt(oldIndex);
                    reorderedPOIData.insert(index, movedItem);
                  }
                });
              },
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: Text(
            "Cancel",
            style: TextStyle(
              fontSize:
                  MediaQuery.maybeTextScalerOf(context)?.scale(16.0) ?? 16.0,
            ),
          ),
        ),
        TextButton(
          onPressed: () async {
            await _updatePOIOrderInFirestore();
            widget.onSave(reorderedPOIData);
            Navigator.of(context).pop();
          },
          child: Text(
            "Save",
            style: TextStyle(
              fontSize:
                  MediaQuery.maybeTextScalerOf(context)?.scale(16.0) ?? 16.0,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _updatePOIOrderInFirestore() async {
    final batch = FirebaseFirestore.instance.batch();
    for (int i = 0; i < reorderedPOIData.length; i++) {
      final poi = reorderedPOIData[i];
      final docRef = FirebaseFirestore.instance
          .collection('lists')
          .doc(widget.listId)
          .collection('pois')
          .doc(poi['id']);
      batch.update(docRef, {'order': i});
    }
    await batch.commit();
  }
}
