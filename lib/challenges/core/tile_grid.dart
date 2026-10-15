import 'dart:math';

import 'package:flutter/widgets.dart';

/// A cols × rows grid of square cells, as large as the space allows (up to
/// [maxCell]) but never under 48 dp, the smallest comfortable tap target.
/// Put it in a Flexible under a header so it takes the room that is left.
class TileGrid extends StatelessWidget {
  const TileGrid({
    super.key,
    required this.cols,
    required this.rows,
    required this.cell,
    this.gap = 6,
    this.maxCell = 96,
  });

  static const minCell = 48.0;

  final int cols;
  final int rows;
  final double gap;
  final double maxCell;

  /// Builds cell [index] (row by row) at [size] × [size].
  final Widget Function(int index, double size) cell;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        double fit(double space, int n) =>
            space.isFinite ? (space - (n - 1) * gap) / n : maxCell;
        final size = max(
          minCell,
          min(maxCell, min(fit(box.maxWidth, cols), fit(box.maxHeight, rows))),
        );
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var r = 0; r < rows; r++)
              Padding(
                padding: EdgeInsets.only(top: r == 0 ? 0 : gap),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var c = 0; c < cols; c++)
                      Padding(
                        padding: EdgeInsets.only(left: c == 0 ? 0 : gap),
                        child: SizedBox.square(
                          dimension: size,
                          child: cell(r * cols + c, size),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}
