import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Бир катардагы N карта: туурасы бирдей, бийиктиги = эң узун карта.
/// IntrinsicHeight'тен айырмасы: бийиктикти болжолдобой, ар бир картаны
/// чыныгы өлчөмү менен өлчөйт. Ошондуктан карта астында ашыкча боштук калбайт.
class EqualHeightRow extends MultiChildRenderObjectWidget {
  const EqualHeightRow({super.key, required this.spacing, required super.children});
  final double spacing;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      RenderEqualHeightRow(spacing);

  @override
  void updateRenderObject(BuildContext context, RenderEqualHeightRow renderObject) {
    renderObject.spacing = spacing;
  }
}

class EqualHeightParentData extends ContainerBoxParentData<RenderBox> {}

class RenderEqualHeightRow extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, EqualHeightParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, EqualHeightParentData> {
  RenderEqualHeightRow(this._spacing);

  double _spacing;
  set spacing(double v) {
    if (v == _spacing) return;
    _spacing = v;
    markNeedsLayout();
  }

  double _cell(double maxW) =>
      (maxW - _spacing * (childCount - 1)) / childCount;

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    final w = _cell(constraints.maxWidth);
    var h = 0.0;
    var child = firstChild;
    while (child != null) {
      final s = child.getDryLayout(
          BoxConstraints(minWidth: w, maxWidth: w, maxHeight: double.infinity));
      if (s.height > h) h = s.height;
      child = childAfter(child);
    }
    h += 2.0; // performLayout'тагы запас менен дал келиши үчүн
    return constraints.constrain(Size(constraints.maxWidth, h));
  }

  @override
  void performLayout() {
    final w = _cell(constraints.maxWidth);
    var h = 0.0;
    var child = firstChild;
    // 1) ар бир картанын өз бийиктигин өлчөө
    while (child != null) {
      child.layout(
        BoxConstraints(minWidth: w, maxWidth: w, maxHeight: double.infinity),
        parentUsesSize: true,
      );
      if (child.size.height > h) h = child.size.height;
      child = childAfter(child);
    }
    // ── Коопсуздук запасы: pass 1'де (maxHeight: infinity) өлчөнгөн
    // "табигый" бийиктик менен pass 2'де (tight height) мажбурлап
    // берилген бийиктиктин ортосунда ички пиксел тегеректөөдөн улам
    // 1px'ге чейин айырма чыгышы мүмкүн — ошол "BOTTOM OVERFLOWED BY
    // 1.00 PIXELS" катасынын себеби. Бир нече пиксел запас коюу менен
    // бул эч качан кайталанбайт. ──
    h += 2.0;
    // 2) баарын эң узун бийиктикке келтирүү
    var x = 0.0;
    child = firstChild;
    while (child != null) {
      child.layout(BoxConstraints.tightFor(width: w, height: h),
          parentUsesSize: true);
      (child.parentData! as EqualHeightParentData).offset = Offset(x, 0);
      x += w + _spacing;
      child = childAfter(child);
    }
    size = constraints.constrain(Size(constraints.maxWidth, h));
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! EqualHeightParentData) {
      child.parentData = EqualHeightParentData();
    }
  }

  @override
  void paint(PaintingContext context, Offset offset) =>
      defaultPaint(context, offset);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);
}