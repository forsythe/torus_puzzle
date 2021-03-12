import 'package:flutter/material.dart';

class Cell extends StatelessWidget {
  const Cell({
    Key key,
    @required this.hoveringOver,
    @required this.solved,
    @required this.colorIntensity,
    @required this.label,
  }) : super(key: key);

  final bool hoveringOver;
  final bool solved;
  final int colorIntensity;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.all(2),
      decoration: BoxDecoration(
          border: Border.all(
              color: Colors.white70, width: hoveringOver ? 4 : 0.5),
          color: new Color.fromRGBO(
              solved ? colorIntensity ~/ 1.5 : colorIntensity,
              colorIntensity,
              solved ? colorIntensity ~/ 1.5 : colorIntensity,
              1),
          borderRadius: BorderRadius.all(Radius.circular(10))),
      child: Center(
          child: FittedBox(
        child: Text(
          label,
          style: TextStyle(fontSize: 35),
        ),
        fit: BoxFit.fitWidth,
      )),
    );
  }
}
