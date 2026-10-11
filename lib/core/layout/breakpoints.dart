import 'package:flutter/widgets.dart';

/// Window size classes theo Material 3.
enum WindowSize {
  compact,
  medium,
  expanded;

  static WindowSize ofWidth(double w) =>
      w < 600 ? compact : (w < 840 ? medium : expanded);

  static WindowSize of(BuildContext context) =>
      ofWidth(MediaQuery.sizeOf(context).width);

  bool get isCompact => this == compact;
}

/// Giới hạn chiều rộng nội dung dạng form/list trên màn rộng.
///
/// [expand] = true khi bọc một widget cuộn làm thân màn hình: giữ nguyên
/// chiều cao được cấp (tránh viewport bị co về 0).
class MaxWidth extends StatelessWidget {
  const MaxWidth({
    super.key,
    this.width = 720,
    this.expand = false,
    required this.child,
  });
  final double width;
  final bool expand;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!expand) {
      return Align(
        alignment: Alignment.topCenter,
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: width),
          child: child,
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, c) => Align(
        alignment: Alignment.topCenter,
        child: SizedBox(
          width: c.maxWidth < width ? c.maxWidth : width,
          height: c.maxHeight,
          child: child,
        ),
      ),
    );
  }
}
