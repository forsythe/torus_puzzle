import 'dart:async';
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

String formatTime(int ms) {
  var msecs = (ms % 1000).toString().padLeft(3, '0');
  var secs = ms ~/ 1000;
  var minutes = ((secs % 3600) ~/ 60).toString().padLeft(2, '0');
  var seconds = (secs % 60).toString().padLeft(2, '0');
  return "$minutes:$seconds:$msecs";
}

int clamp(int val, int minInclusive, int maxExclusive) {
  if (val < minInclusive) return minInclusive;
  if (val >= maxExclusive) return maxExclusive - 1;
  return val;
}

class _MyHomePageState extends State<MyHomePage> {
  static List<int> puzzleDimOptions = [2, 3, 4, 5, 6];
  static int puzzleDim = puzzleDimOptions[2];
  bool solved = true;
  Stopwatch stopwatch;
  Timer timer;

  //for logic involving tile shifts
  int prevRow = 0;
  int prevCol = 0;

  //for rendering
  double tileSize = 0;
  double gridYStart = 0;
  double gridXStart = 0;
  int hoveringOver;
  final containerKey = GlobalKey();

  List<int> tileValues =
      new List<int>.generate(puzzleDim * puzzleDim, (i) => (i + 1));

  void initState() {
    super.initState();

    stopwatch = Stopwatch();
    timer = new Timer.periodic(new Duration(milliseconds: 100), (timer) {
      setState(() {});
    });
    scramble();
  }

  @override
  void dispose() {
    timer.cancel();
    super.dispose();
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
    stopwatch?.stop();
    stopwatch?.reset();
  }

  void scramble() {
    tileValues = new List<int>.generate(puzzleDim * puzzleDim, (i) => (i + 1));
    var rng = new Random();

    for (var i = 0; i < 10; i++) {
      columnOffset(rng.nextInt(puzzleDim), rng.nextInt(puzzleDim));
      rowOffset(rng.nextInt(puzzleDim), rng.nextInt(puzzleDim));
    }
    solved = false;
    stopwatch.stop();
    stopwatch.reset();
  }

  void columnOffset(int column, int offset) {
    offset %= puzzleDim;
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

  void rowOffset(int row, int offset) {
    offset %= puzzleDim;
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
        title: stopwatch.isRunning || stopwatch.elapsedMilliseconds > 0
            ? Text(
                formatTime(stopwatch.elapsedMilliseconds),
              )
            : Text("Torus Puzzle"),
        actions: <Widget>[
          Tooltip(
            message: "I give up!",
            child: MaterialButton(
              onPressed: isSolved()
                  ? null
                  : () {
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
                                'The grid of numbers exists on a torus. Your goal is to swipe them until they are sorted in ascending order, left to right, top to bottom.'),
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
          child: GestureDetector(
            onPanDown: (details) {
              stopwatch.start();

              gridYStart = containerKey.globalPaintBounds.top;
              gridXStart = containerKey.globalPaintBounds.left;
              tileSize = (containerKey.globalPaintBounds.right -
                      containerKey.globalPaintBounds.left) /
                  puzzleDim;

              prevRow = ((details.globalPosition.dy - gridYStart) ~/ tileSize);
              prevCol = ((details.globalPosition.dx - gridXStart) ~/ tileSize);
            },
            onPanUpdate: (details) {
              int newRow =
                  ((details.globalPosition.dy - gridYStart) ~/ tileSize);
              int newCol =
                  ((details.globalPosition.dx - gridXStart) ~/ tileSize);
              newRow = clamp(newRow, 0, puzzleDim);
              newCol = clamp(newCol, 0, puzzleDim);

              if (newRow != prevRow && newCol != prevCol) {
                return; //don't support diagonal drags
              }

              if (newRow != prevRow) {
                setState(() {
                  columnOffset(newCol, newRow - prevRow);
                });
                prevRow = newRow;
              }
              if (newCol != prevCol) {
                setState(() {
                  rowOffset(newRow, newCol - prevCol);
                });
                prevCol = newCol;
              }
              setState(() {
                bool prevSolved = solved;
                solved = isSolved();
                if (!prevSolved && solved) {
                  stopwatch.stop();
                }
              });
            },
            child: GridView.count(
              physics: ClampingScrollPhysics(),
              key: containerKey,
              childAspectRatio: 1,
              shrinkWrap: true,
              primary: true,
              crossAxisCount: puzzleDim,
              children: tileValues.map((e) {
                int intensity = 100 - 90 ~/ (puzzleDim * puzzleDim) * e;
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
                  child: Container(
                    margin: EdgeInsets.all(2),
                    decoration: BoxDecoration(
                        border: Border.all(
                            color: Colors.white70,
                            width: hoveringOver == e ? 4 : 0.5),
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
                        style: TextStyle(fontSize: 35),
                      ),
                      fit: BoxFit.fitWidth,
                    )),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }
}
