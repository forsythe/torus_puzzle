import 'dart:async';
import 'dart:collection';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'cell.dart';

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
  return "$minutes:$seconds.$msecs";
}

num clamp(num val, num minInclusive, num maxExclusive) {
  if (val < minInclusive) return minInclusive;
  if (val >= maxExclusive) return maxExclusive - 1;
  return val;
}

class _MyHomePageState extends State<MyHomePage> {
  static List<int> puzzleDimOptions = [2, 3, 4, 5, 6];
  static int puzzleDim = puzzleDimOptions[2];
  Map<int, int> rotationBuffer = new HashMap();
  bool solved = true;
  Stopwatch stopwatch;
  Timer timer;

  //for logic involving tile shifts
  double verticalDownYPosition = 0;
  double horizontalDownXPosition = 0;
  int prevRow = 0;
  int newRow = 0;
  int prevCol = 0;
  int newCol = 0;

  //for rendering
  double tileSize = 0;
  double gridYStart = 0;
  double gridXStart = 0;
  int hoveringOver;
  final containerKey = GlobalKey();
  List<Offset> offsets = [];
  int dragState = -1; //-1 undefined, 0 vertical, 1 horizontal

  List<int> tileValues =
      new List<int>.generate(puzzleDim * puzzleDim, (i) => (i + 1));

  void initState() {
    super.initState();
    resetOffsets();
    stopwatch = Stopwatch();
    timer = new Timer.periodic(new Duration(milliseconds: 100), (timer) {
      setState(() {});
    });
  }

  void resetOffsets() {
    offsets = List.filled(puzzleDim * puzzleDim, Offset.zero);
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

    do {
      for (var i = 0; i < 10; i++) {
        columnOffset(rng.nextInt(puzzleDim), rng.nextInt(puzzleDim));
        rowOffset(rng.nextInt(puzzleDim), rng.nextInt(puzzleDim));
      }
    } while (isSolved());

    setState(() {
      solved = false;
    });
    stopwatch.stop();
    stopwatch.reset();
  }

  void doOffset(int rowOrCol, int offset, Function(int) indexGenerator) {
    while (offset < 0) {
      offset += puzzleDim;
    }
    offset %= puzzleDim;
    List<int> oldIndices = new List<int>.generate(puzzleDim, indexGenerator);
    rotationBuffer.clear();
    for (int i in oldIndices) {
      rotationBuffer.putIfAbsent(i, () => tileValues[i]);
    }

    List<int> newTileValues = List.from(tileValues);
    for (int k = 0; k < puzzleDim; k++) {
      newTileValues[oldIndices[(k + offset) % puzzleDim]] =
          rotationBuffer[oldIndices[k]];
    }
    tileValues = newTileValues;
  }

  void columnOffset(int column, int offset) {
    doOffset(column, offset, (i) => i * puzzleDim + column);
  }

  void rowOffset(int row, int offset) {
    doOffset(row, offset, (i) => i + puzzleDim * row);
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
        actions: getAppbarWidgets(context),
      ),
      body: Center(
        child: Container(
          constraints: BoxConstraints(maxWidth: 500, maxHeight: 500),
          child: GestureDetector(
            onHorizontalDragDown: solved
                ? null
                : (DragDownDetails d) {
                    onDragDownCommon(d);
                    verticalDownYPosition = d.globalPosition.dy;

                    newRow = ((d.globalPosition.dy - gridYStart) ~/ tileSize);
                    newRow = clamp(newRow, 0, puzzleDim);
                  },
            onVerticalDragDown: solved
                ? null
                : (DragDownDetails d) {
                    onDragDownCommon(d);
                    horizontalDownXPosition = d.globalPosition.dx;

                    newCol = ((d.globalPosition.dx - gridXStart) ~/ tileSize);
                    newCol = clamp(newCol, 0, puzzleDim);
                  },
            onHorizontalDragEnd: solved
                ? null
                : (DragEndDetails d) {
                    if (prevCol != newCol) {
                      setState(() {
                        rowOffset(newRow, newCol - prevCol);
                      });

                      prevCol = newCol;
                    }
                    onDragEnd();
                  },
            onVerticalDragEnd: solved
                ? null
                : (DragEndDetails d) {
                    if (newRow != prevRow) {
                      setState(() {
                        columnOffset(newCol, newRow - prevRow);
                      });
                      prevRow = newRow;
                    }
                    onDragEnd();
                  },
            onHorizontalDragUpdate: solved
                ? null
                : (DragUpdateDetails d) {
                    var positionRelativeToLeft =
                        d.globalPosition.dx - gridXStart;
                    newCol = positionRelativeToLeft >= 0
                        ? ((positionRelativeToLeft) ~/ tileSize)
                        : ((positionRelativeToLeft -
                                tileSize) ~/ //go DOWN towards nearest tileSize increment
                            tileSize);

                    double totalShifted =
                        d.globalPosition.dx - horizontalDownXPosition;
                    setState(() {
                      for (int i = 0; i < puzzleDim; i++) {
                        offsets[tileValues[i + puzzleDim * newRow] - 1] =
                            Offset(
                                d.globalPosition.dx - horizontalDownXPosition,
                                0);
                      }
                      wrapAroundHorizontal(totalShifted);
                    });
                  },
            onVerticalDragUpdate: solved
                ? null
                : (DragUpdateDetails d) {
                    var positionRelativeToTop =
                        (d.globalPosition.dy - gridYStart);
                    newRow = positionRelativeToTop >= 0
                        ? positionRelativeToTop ~/ tileSize
                        : (positionRelativeToTop - tileSize) ~/ tileSize;
                    double totalShifted =
                        d.globalPosition.dy - verticalDownYPosition;

                    setState(() {
                      for (int i = 0; i < puzzleDim; i++) {
                        offsets[tileValues[i * puzzleDim + newCol] - 1] =
                            Offset(0, totalShifted);
                      }
                      wrapAroundVertical(totalShifted);
                    });
                  },
            child: GridView.count(
              physics: ClampingScrollPhysics(),
              key: containerKey,
              childAspectRatio: 1,
              shrinkWrap: true,
              primary: true,
              crossAxisCount: puzzleDim,
              children: tileValues
                  .map((e) => Transform.translate(
                        offset: offsets[e - 1],
                        child: MouseRegion(
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
                          child: Cell(
                            hoveringOver: hoveringOver == e,
                            solved: solved,
                            colorIntensity:
                                100 - 90 ~/ (puzzleDim * puzzleDim) * e,
                            label: e.toString(),
                          ),
                        ),
                      ))
                  .toList(),
            ),
          ),
        ),
      ),
    );
  }

  void onDragDownCommon(DragDownDetails d) {
    stopwatch.start();
    gridYStart = containerKey.globalPaintBounds.top;
    gridXStart = containerKey.globalPaintBounds.left;
    tileSize = (containerKey.globalPaintBounds.right -
            containerKey.globalPaintBounds.left) /
        puzzleDim;
    prevCol = ((d.globalPosition.dx - gridXStart) ~/ tileSize);
    prevRow = ((d.globalPosition.dy - gridYStart) ~/ tileSize);
  }

  List<Widget> getAppbarWidgets(BuildContext context) {
    return <Widget>[
      if (!solved)
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: MaterialButton(
            color: Colors.red,
            onPressed: () {
              setState(() {
                reset();
              });
            },
            child: Text("I give up!"),
          ),
        ),
      if (solved)
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: MaterialButton(
            color: Colors.green,
            onPressed: () {
              setState(() {
                scramble();
              });
            },
            child: Text("Play"),
          ),
        ),
      Tooltip(
        message: "Instructions",
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: GestureDetector(
            onTap: () {
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
      ),
      PopupMenuButton<int>(
        onSelected: (value) => {
          setState(() {
            puzzleDim = value;
            reset();
            resetOffsets();
          })
        },
        itemBuilder: (BuildContext context) {
          return puzzleDimOptions.map((dim) {
            return PopupMenuItem<int>(
                value: dim, child: Text(dim.toString() + "x" + dim.toString()));
          }).toList();
        },
      ),
    ];
  }

  void onDragEnd() {
    setState(() {
      bool prevSolved = solved;
      solved = isSolved();
      if (!prevSolved && solved) {
        stopwatch.stop();
      }
    });
    resetOffsets();
  }

  void wrapAroundVertical(double totalShifted) {
    if (totalShifted > 0) {
      for (int row = 0; row < puzzleDim; row++) {
        var tileIndex = tileValues[row * puzzleDim + newCol] - 1;
        while (offsets[tileIndex].dy + row * tileSize >
            puzzleDim * tileSize - tileSize / 2) {
          offsets[tileIndex] -= Offset(0, puzzleDim * tileSize);
        }
      }
    } else {
      for (int row = 0; row < puzzleDim; row++) {
        var tileIndex = tileValues[row * puzzleDim + newCol] - 1;
        while (offsets[tileIndex].dy + row * tileSize < -tileSize / 2) {
          offsets[tileIndex] += Offset(0, puzzleDim * tileSize);
        }
      }
    }
  }

  void wrapAroundHorizontal(double totalShifted) {
    if (totalShifted > 0) {
      for (int col = 0; col < puzzleDim; col++) {
        var tileIndex = tileValues[col + puzzleDim * newRow] - 1;
        while (offsets[tileIndex].dx + col * tileSize >
            puzzleDim * tileSize - tileSize / 2) {
          offsets[tileIndex] -= Offset(puzzleDim * tileSize, 0);
        }
      }
    } else {
      for (int col = 0; col < puzzleDim; col++) {
        var tileIndex = tileValues[col + puzzleDim * newRow] - 1;
        while (offsets[tileIndex].dx + col * tileSize < -tileSize / 2) {
          offsets[tileIndex] += Offset(puzzleDim * tileSize, 0);
        }
      }
    }
  }
}
