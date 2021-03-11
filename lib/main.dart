import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Torus Puzzle',
      theme: ThemeData.dark(),
      home: MyHomePage(title: 'Torus Puzzle'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

extension GlobalKeyExtension on GlobalKey {
  Rect get globalPaintBounds {
    final renderObject = currentContext?.findRenderObject();
    var translation = renderObject?.getTransformTo(null)?.getTranslation();
    if (translation != null && renderObject.paintBounds != null) {
      return renderObject.paintBounds
          .shift(Offset(translation.x, translation.y));
    } else {
      return null;
    }
  }
}

class _MyHomePageState extends State<MyHomePage> {
  static List<int> puzzleDimOptions = [3, 5, 6];
  static int puzzleDim = 5;
  bool solved = true;

  //for logic involving tile shifts
  int prevColumnOffset = 0;
  int prevRowOffset = 0;

  //for rendering
  double tileSize = 0;
  double gridYStart = 0;
  double gridXStart = 0;
  int hoveringOver;

  final containerKey = GlobalKey();

  List<int> tileValues =
      new List<int>.generate(puzzleDim * puzzleDim, (i) => (i + 1));

  void initState(){
    super.initState();
    scramble();
  }

  bool isSolved() {
    for (int k = 0; k < tileValues.length - 1; k++) {
      if (tileValues[k] > tileValues[k + 1]) return false;
    }
    return true;
  }

  void reset() {
    tileValues = new List<int>.generate(puzzleDim * puzzleDim, (i) => (i + 1));
    solved = true;
  }

  void scramble() {
    tileValues = new List<int>.generate(puzzleDim * puzzleDim, (i) => (i + 1));
    var rng = new Random();

    for (var i = 0; i < 10; i++) {
      columnOffset(rng.nextInt(puzzleDim * puzzleDim), rng.nextInt(puzzleDim));
      rowOffset(rng.nextInt(puzzleDim * puzzleDim), rng.nextInt(puzzleDim));
    }
    solved = false;
  }

  void columnOffset(int tileNum, int offset) {
    int column = tileValues.indexOf(tileNum) % puzzleDim;
    if (offset < 0) {
      offset += puzzleDim;
    }
    List<int> oldIndices =
        new List<int>.generate(puzzleDim, (i) => i * puzzleDim + column);
    List<int> rotatedIndices = oldIndices.sublist(offset)
      ..addAll(oldIndices.sublist(0, offset));

    List<int> newTileValues = List.from(tileValues);
    for (int k = 0; k < puzzleDim; k++) {
      newTileValues[rotatedIndices[k]] = tileValues[oldIndices[k]];
    }
    tileValues = newTileValues;
  }

  void rowOffset(int tileNum, int offset) {
    int row = tileValues.indexOf(tileNum) ~/ puzzleDim;
    if (offset < 0) {
      offset += puzzleDim;
    }
    List<int> oldIndices =
        new List<int>.generate(puzzleDim, (i) => i + puzzleDim * row);
    List<int> rotatedIndices = oldIndices.sublist(offset)
      ..addAll(oldIndices.sublist(0, offset));
    List<int> newTileValues = List.from(tileValues);
    for (int k = 0; k < puzzleDim; k++) {
      newTileValues[rotatedIndices[k]] = tileValues[oldIndices[k]];
    }
    tileValues = newTileValues;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Torus Puzzle"),
        actions: <Widget>[
          Tooltip(
            message: "I give up!",
            child: MaterialButton(
              onPressed: () {
                  setState(() {
                    reset();
                  });
                },
              child: Icon(
                  Icons.outlined_flag,
                ),
            ),
          ),
          Tooltip(
            message: "Shuffle",
            child: MaterialButton(
              onPressed: () {
                setState(() {
                  scramble();
                });
              },
              child: Icon(
                Icons.shuffle,
              ),
            ),
          ),
          Tooltip(
            message: "Instructions",
            child: MaterialButton(
              onPressed: () {
                  return showDialog<void>(
                    context: context,
                    barrierDismissible: false, // user must tap button!
                    builder: (BuildContext context) {
                      return AlertDialog(
                        title: Text('Instructions'),
                        content: SingleChildScrollView(
                          child: ListBody(
                            children: <Widget>[
                              Text(
                                  'The grid of numbers lie on a torus. Your goal is to swipe them until they are sorted in ascending order, left to right, top to bottom.'),
                            ],
                          ),
                        ),
                        actions: <Widget>[
                          TextButton(
                            child: Text('Got it!'),
                            onPressed: () {
                              Navigator.of(context).pop();
                            },
                          ),
                        ],
                      );
                    },
                  );
                },
              child: Icon(
                  Icons.info,
                ),
            ),
          ),
          PopupMenuButton<int>(
            onSelected: (value) => {
              setState(() {
                puzzleDim = value;
                scramble();
              })
            },
            itemBuilder: (BuildContext context) {
              return puzzleDimOptions.map((dim) {
                return PopupMenuItem<int>(
                    value: dim,
                    child: Text(dim.toString() + "x" + dim.toString()));
              }).toList();
            },
          ),
        ],
      ),
      body: Center(
        child: Container(
          constraints: BoxConstraints(maxWidth: 500, maxHeight: 500),
          child: GridView.count(
            key: containerKey,
            childAspectRatio: 1,
            shrinkWrap: true,
            primary: true,
            crossAxisCount: puzzleDim,
            children: tileValues.map((e) {
              int intensity = 150 - 100 ~/ (puzzleDim * puzzleDim) * e;
              return MouseRegion(
                cursor: SystemMouseCursors.move,
                onExit: (event) => {
                  setState(() {
                    hoveringOver = -1;
                  })
                },
                onHover: (event) => {
                  setState(() {
                    hoveringOver = e;
                  })
                },
                opaque: false,
                child: GestureDetector(
                  onVerticalDragDown: (details) {
                    gridYStart = containerKey.globalPaintBounds.top;
                    tileSize = (containerKey.globalPaintBounds.right -
                            containerKey.globalPaintBounds.left) /
                        puzzleDim;
                    prevColumnOffset =
                        ((details.globalPosition.dy - gridYStart) ~/ tileSize);
                  },
                  onVerticalDragUpdate: (DragUpdateDetails details) {
                    int newOffset =
                        ((details.globalPosition.dy - gridYStart) ~/ tileSize);
                    if (newOffset != prevColumnOffset) {
                      setState(() {
                        columnOffset(e, newOffset - prevColumnOffset);
                        solved = isSolved();
                      });
                      prevColumnOffset = newOffset;
                    }
                  },
                  onHorizontalDragDown: (details) {
                    gridXStart = containerKey.globalPaintBounds.left;
                    tileSize = (containerKey.globalPaintBounds.right -
                            containerKey.globalPaintBounds.left) /
                        puzzleDim;
                    prevRowOffset =
                        ((details.globalPosition.dx - gridXStart) ~/ tileSize);
                  },
                  onHorizontalDragUpdate: (DragUpdateDetails details) {
                    int newOffset =
                        ((details.globalPosition.dx - gridXStart) ~/ tileSize);
                    if (newOffset != prevRowOffset) {
                      setState(() {
                        rowOffset(e, newOffset - prevRowOffset);
                        solved = isSolved();
                      });
                      prevRowOffset = newOffset;
                    }
                  },
                  child: Container(
                    margin: EdgeInsets.all(4),
                    decoration: BoxDecoration(
                        border: hoveringOver == e
                            ? Border.all(color: Colors.grey, width: 4)
                            : null,
                        color: new Color.fromRGBO(
                            solved ? intensity ~/ 1.5 : intensity,
                            intensity,
                            solved ? intensity ~/ 1.5 : intensity,
                            1),
                        borderRadius: BorderRadius.all(Radius.circular(10))),
                    child: Center(
                        child: FittedBox(
                      child: Text(
                        e.toString(),
                        style: TextStyle(fontSize: 50),
                      ),
                      fit: BoxFit.fitWidth,
                    )),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}
