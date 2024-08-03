import 'package:flutter/material.dart';

class ListDetailsPage extends StatefulWidget {
  final String listId;
  final String listName;

  const ListDetailsPage(
      {super.key, required this.listId, required this.listName});

  @override
  _ListDetailsPageState createState() => _ListDetailsPageState();
}

class _ListDetailsPageState extends State<ListDetailsPage> {
  // List of POI names for demonstration purposes
  List<String> _poiNames = [
    'King\'s Cross',
    'Dishoom Covent Garden',
    'St. Paul\'s Cathedral',
    'Thai Square Trafalgar Square',
  ];

  int _draggingIndex = -1;

  // Method to handle drag and drop
  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      // Adjust newIndex when moving down the list
      if (newIndex > oldIndex) newIndex--;

      // Reorder the list
      final item = _poiNames.removeAt(oldIndex);
      _poiNames.insert(newIndex, item);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.listName),
      ),
      body: ListView.builder(
        itemCount: _poiNames.length,
        itemBuilder: (context, index) {
          return DragTarget<String>(
            builder: (context, candidateData, rejectedData) {
              return Draggable<String>(
                data: _poiNames[index],
                childWhenDragging: Container(
                  padding: const EdgeInsets.all(8.0),
                  color: Colors.grey[200],
                  child: ListTile(
                    title: Text(
                      _poiNames[index],
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                ),
                feedback: Material(
                  child: Container(
                    width: MediaQuery.of(context).size.width - 20,
                    padding: const EdgeInsets.all(8.0),
                    color: Colors.blueAccent,
                    child: ListTile(
                      title: Text(
                        _poiNames[index],
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ),
                child: Container(
                  padding: const EdgeInsets.all(8.0),
                  color: Colors.grey[200],
                  child: ListTile(
                    title: Text(_poiNames[index]),
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
            onWillAcceptWithDetails: (DragTargetDetails<String> details) {
              // Check if the target index is different from the dragging index
              return details.data != _poiNames[index];
            },
            onAcceptWithDetails: (DragTargetDetails<String> details) {
              // Get the old index of the data being dragged
              final oldIndex = _poiNames.indexOf(details.data);
              _onReorder(oldIndex, index);
            },
          );
        },
      ),
    );
  }
}
