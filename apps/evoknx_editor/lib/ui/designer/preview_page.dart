import 'dart:async';

import 'package:flutter/material.dart';
import 'package:knx_config/knx_config.dart';

import '../../app/theme.dart';
import '../../state/project_controller.dart';
import 'widget_views.dart';

/// "Chạy thử": mô phỏng giao diện app như người dùng cuối sẽ thấy.
/// Bấm được (trạng thái mô phỏng tại chỗ, chưa gửi bus thật) và có
/// thanh chọn tầng ở dưới khung điện thoại.
class PreviewPage extends StatefulWidget {
  const PreviewPage({super.key, required this.project, required this.initialSubId});
  final ProjectController project;
  final String? initialSubId;
  @override
  State<PreviewPage> createState() => _PreviewPageState();
}

class _PreviewPageState extends State<PreviewPage> {
  static const _frameWidths = {'mobile': 380.0, 'tabletP': 520.0, 'tabletL': 680.0};

  String? curSub;
  final Map<String, Object?> _st = {};

  ProjectController get p => widget.project;

  @override
  void initState() {
    super.initState();
    curSub = widget.initialSubId ?? _firstSub(p.doc);
  }

  // ------------------------------------------------------------ lookups

  Json? _sub(Json d) {
    for (final s in allSubpages(d)) {
      if (s['id'] == curSub) return s;
    }
    return null;
  }

  Json? _roomOf(Json d, String subId) {
    for (final r in jsonList(d['pages'])) {
      for (final s in jsonList(r['subpages'])) {
        if (s['id'] == subId) return r;
      }
    }
    return null;
  }

  String? _firstSub(Json d) {
    for (final r in jsonList(d['pages'])) {
      final subs = jsonList(r['subpages']);
      if (subs.isNotEmpty) return subs.first['id'] as String;
    }
    return null;
  }

  List<Json> _subsOfFloor(Json d, String floorId) {
    final out = <Json>[];
    for (final r in jsonList(d['pages'])) {
      if (r['floorId'] == floorId) out.addAll(jsonList(r['subpages']));
    }
    return out;
  }

  double get _frameWidth => _frameWidths[(p.doc['activeDev'] as String?) ?? 'mobile'] ?? 380.0;

  // ------------------------------------------------------------ state helpers

  bool flag(Json w, String key) => _st['${w['id']}:$key'] == true;

  void pulse(Json w) {
    _st['${w['id']}:pulse'] = true;
    setState(() {});
    Future.delayed(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      setState(() => _st['${w['id']}:pulse'] = false);
    });
  }

  // ------------------------------------------------------------ shared chrome

  Widget _head(BuildContext context, Json w, {Color? color}) {
    final c = context.evo;
    final iconSize = (w['iconSize'] as num?)?.toDouble() ?? 17.0;
    final labelSize = (w['labelSize'] as num?)?.toDouble() ?? 13.5;
    return Row(
      children: [
        Icon(evoIcon(w['icon']), size: iconSize, color: color ?? c.muted),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            (w['label'] as String?) ?? '',
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: labelSize, fontWeight: FontWeight.w600, color: c.ink),
          ),
        ),
      ],
    );
  }

  // ------------------------------------------------------------ interactive views

  Widget _view(BuildContext context, Json w) {
    switch (w['type']) {
      case 'switch':
        return _switch(context, w);
      case 'dimmer':
        return _dimmer(context, w);
      case 'shutter':
        return _shutter(context, w);
      case 'button':
        return _button(context, w);
      case 'scene':
        return _scene(context, w);
      case 'ac':
        return _ac(context, w);
      case 'group':
        return _group(context, w);
      default:
        return widgetPreview(context, w);
    }
  }

  Widget _switch(BuildContext context, Json w) {
    final c = context.evo;
    final st = jsonMap(w['style']);
    final on = flag(w, 'on');
    final col = on ? parseHexColor(st['colorOn'] as String?, const Color(0xFFEE9B2A)) : c.muted;
    final textOn = (st['textOn'] as String?) ?? '';
    return _pulseCard(
      context,
      w,
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _head(context, w, color: on ? col : null),
          Expanded(
            child: Center(
              child: Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(shape: BoxShape.circle, color: col.withValues(alpha: on ? 0.14 : 0.06), border: Border.all(color: col, width: 2)),
                child: Icon(Icons.power_settings_new, size: 26, color: col),
              ),
            ),
          ),
          Text(
            on ? (textOn.isEmpty ? 'Đang bật' : textOn) : 'Đang tắt',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: on ? col : c.muted),
          ),
        ],
      ),
      onTap: () => setState(() => _st['${w['id']}:on'] = !on),
    );
  }

  Widget _dimmer(BuildContext context, Json w) {
    final c = context.evo;
    final st = jsonMap(w['style']);
    final f = jsonMap(w['features']);
    final on = flag(w, 'on');
    final level = (_st['${w['id']}:level'] as num?)?.toDouble() ?? 70.0;
    final col = on ? parseHexColor(st['colorOn'] as String?, const Color(0xFFEE9B2A)) : c.muted;
    return _pulseCard(
      context,
      w,
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _head(context, w, color: on ? col : null),
          Expanded(
            child: Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: () => setState(() => _st['${w['id']}:on'] = !on),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: col.withValues(alpha: on ? 0.14 : 0.06), border: Border.all(color: col, width: 2)),
                      child: Icon(Icons.power_settings_new, size: 20, color: col),
                    ),
                  ),
                  if (f['rgb'] == true) ...[
                    const SizedBox(width: 8),
                    Container(width: 26, height: 26, decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF7C4DFF))),
                  ],
                ],
              ),
            ),
          ),
          GestureDetector(
            onHorizontalDragUpdate: (d) {
              final box = context.findRenderObject() as RenderBox?;
              if (box == null) return;
              final t = (d.localPosition.dx / box.size.width).clamp(0.0, 1.0);
              setState(() {
                _st['${w['id']}:level'] = (t * 100).roundToDouble();
                _st['${w['id']}:on'] = true;
              });
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Stack(
                children: [
                  Container(height: 10, color: c.paper),
                  FractionallySizedBox(
                    widthFactor: on ? level / 100 : 0.0,
                    child: Container(height: 10, color: col),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(on ? '${level.round()}%' : 'Tắt', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: on ? col : c.muted)),
              if (f['tw'] == true) Text('3500K', style: TextStyle(fontSize: 10.5, color: c.muted)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _shutter(BuildContext context, Json w) {
    final c = context.evo;
    final ctrl = (w['shCtrl'] ?? 'buttons') as String;
    final curtain = w['shStyle'] == 'curtain';
    final pos = (_st['${w['id']}:pos'] as num?)?.toDouble() ?? 40.0;
    Widget chip(IconData ic, String t, VoidCallback? onTap) => Expanded(
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(7),
            child: Container(
              height: 26,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: c.paper, borderRadius: BorderRadius.circular(7), border: Border.all(color: c.line)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(ic, size: 13, color: c.ink),
                  const SizedBox(width: 3),
                  Text(t, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: c.ink)),
                ],
              ),
            ),
          ),
        );
    void move(double delta) => setState(() {
          _st['${w['id']}:pos'] = (pos + delta).clamp(0.0, 100.0);
        });
    return _pulseCard(
      context,
      w,
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _head(context, w),
          const SizedBox(height: 6),
          Expanded(
            child: Center(
              child: Text(
                '${pos.round()}%',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: c.accentInk),
              ),
            ),
          ),
          GestureDetector(
            onHorizontalDragUpdate: ctrl == 'slider'
                ? (d) {
                    final box = context.findRenderObject() as RenderBox?;
                    if (box == null) return;
                    final t = (d.localPosition.dx / box.size.width).clamp(0.0, 1.0);
                    setState(() => _st['${w['id']}:pos'] = (t * 100).roundToDouble());
                  }
                : null,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Stack(children: [
                Container(height: 8, color: c.paper),
                FractionallySizedBox(widthFactor: pos / 100, child: Container(height: 8, color: c.accent)),
              ]),
            ),
          ),
          const SizedBox(height: 6),
          Row(children: [
            chip(curtain ? Icons.open_in_full : Icons.arrow_upward, curtain ? 'Mở' : 'Lên', ctrl == 'slider' ? null : () => move(10)),
            const SizedBox(width: 5),
            chip(Icons.stop, 'Dừng', ctrl == 'slider' ? null : () {}),
            const SizedBox(width: 5),
            chip(curtain ? Icons.close_fullscreen : Icons.arrow_downward, curtain ? 'Đóng' : 'Xuống', ctrl == 'slider' ? null : () => move(-10)),
          ]),
        ],
      ),
    );
  }

  Widget _button(BuildContext context, Json w) {
    final c = context.evo;
    final active = flag(w, 'pulse');
    return _pulseCard(
      context,
      w,
      Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: active ? c.accent : c.accentSoft,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            (w['label'] as String?) ?? '',
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: (w['labelSize'] as num?)?.toDouble() ?? 13.0,
              fontWeight: FontWeight.w600,
              color: active ? Colors.white : c.accentInk,
            ),
          ),
        ),
      ),
      padding: const EdgeInsets.all(8),
      onTap: () => pulse(w),
    );
  }

  Widget _scene(BuildContext context, Json w) {
    final c = context.evo;
    final active = flag(w, 'pulse');
    return _pulseCard(
      context,
      w,
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _head(context, w),
          Expanded(
            child: Center(
              child: Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(shape: BoxShape.circle, color: active ? c.accent : c.accentSoft, border: Border.all(color: c.accent, width: 2)),
                child: Icon(Icons.star, size: 24, color: active ? Colors.white : c.accent),
              ),
            ),
          ),
          Text('Cảnh ${w['sceneNumber'] ?? 1}', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: c.muted)),
        ],
      ),
      onTap: () => pulse(w),
    );
  }

  Widget _ac(BuildContext context, Json w) {
    final c = context.evo;
    final ac = jsonMap(w['ac']);
    final modes = jsonMap(ac['modes']);
    final names = jsonMap(ac['names']);
    final enabled = [
      for (final m in kAcModes)
        if (modes.containsKey(m.key) ? modes[m.key] == true : m.key != 'heat') m,
    ];
    final cur = (_st['${w['id']}:mode'] as String?) ?? (enabled.isNotEmpty ? enabled.first.key : '');
    final temp = (_st['${w['id']}:temp'] as num?)?.toDouble() ?? 24.5;
    return _pulseCard(
      context,
      w,
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _head(context, w, color: c.accentInk),
          Expanded(
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    onPressed: () => setState(() => _st['${w['id']}:temp'] = (temp - 0.5).clamp(16.0, 30.0)),
                    icon: const Icon(Icons.remove_circle_outline, size: 20),
                  ),
                  Text.rich(
                    TextSpan(children: [
                      TextSpan(text: temp.toStringAsFixed(1), style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700)),
                      TextSpan(text: '°C', style: TextStyle(fontSize: 12, color: c.muted)),
                    ]),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    onPressed: () => setState(() => _st['${w['id']}:temp'] = (temp + 0.5).clamp(16.0, 30.0)),
                    icon: const Icon(Icons.add_circle_outline, size: 20),
                  ),
                ],
              ),
            ),
          ),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              for (final m in enabled.take(4))
                InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => setState(() => _st['${w['id']}:mode'] = m.key),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: m.key == cur ? c.accentSoft : c.paper,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: m.key == cur ? c.accent : c.line),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(evoIcon(m.icon), size: 11, color: m.key == cur ? c.accentInk : c.muted),
                        const SizedBox(width: 3),
                        Text(
                          (names[m.key] as String?)?.isNotEmpty == true ? names[m.key] as String : m.name,
                          style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w600, color: m.key == cur ? c.accentInk : c.muted),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _group(BuildContext context, Json w) {
    final c = context.evo;
    final l = jsonMap(w['layout']);
    final cols = (l['columns'] as num?)?.toInt() ?? 4;
    final rows = (l['rows'] as num?)?.toInt() ?? 4;
    final plain = w['gstyle'] == 'plain';
    final children = jsonList(w['widgets']);
    return Container(
      decoration: BoxDecoration(
        color: plain ? Colors.transparent : c.panel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.line),
      ),
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (w['showTitle'] != false)
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 6),
              child: Text(
                (w['label'] as String?) ?? '',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: (w['labelSize'] as num?)?.toDouble() ?? 12.5, fontWeight: FontWeight.w600, color: c.muted),
              ),
            ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, box) {
                final bw = box.maxWidth, bh = box.maxHeight;
                return Stack(
                  children: [
                    for (final ch in children)
                      Positioned(
                        left: ((jsonMap(ch['pos'])['x'] as num? ?? 0) / cols) * bw,
                        top: ((jsonMap(ch['pos'])['y'] as num? ?? 0) / rows) * bh,
                        width: ((jsonMap(ch['pos'])['w'] as num? ?? 1) / cols) * bw,
                        height: ((jsonMap(ch['pos'])['h'] as num? ?? 1) / rows) * bh,
                        child: Padding(
                          padding: const EdgeInsets.all(2),
                          child: _view(context, ch),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Thẻ có viền sáng búng khi bấm (button/scene) — tách riêng để không đụng
  /// [_pulseCard] của các loại còn lại.
  Widget _pulseCard(BuildContext context, Json w, Widget child, {VoidCallback? onTap, EdgeInsets padding = const EdgeInsets.all(10)}) {
    final c = context.evo;
    final active = flag(w, 'pulse');
    return Container(
      decoration: BoxDecoration(
        color: c.panel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: active ? c.accent : c.line),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }

  // ------------------------------------------------------------ bars

  Widget _pageTabs(BuildContext context, List<Json> subs) {
    final c = context.evo;
    if (subs.length <= 1) return const SizedBox.shrink();
    return Container(
      height: 34,
      decoration: BoxDecoration(border: Border(top: BorderSide(color: c.line))),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        children: [
          for (final s in subs)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: InkWell(
                borderRadius: BorderRadius.circular(7),
                onTap: () => setState(() => curSub = s['id'] as String),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: s['id'] == curSub ? c.accentSoft : Colors.transparent,
                    border: Border.all(color: s['id'] == curSub ? c.accent : c.line),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Text(s['title'] as String? ?? '', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: s['id'] == curSub ? c.accentInk : c.muted)),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _floorBar(BuildContext context, Json d) {
    final c = context.evo;
    final floors = jsonList(d['floors']);
    if (floors.isEmpty) return const SizedBox.shrink();
    final room = curSub == null ? null : _roomOf(d, curSub!);
    final curFloor = room?['floorId'] as String?;
    return Container(
      height: 36,
      decoration: BoxDecoration(border: Border(top: BorderSide(color: c.line))),
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Icon(Icons.stairs_outlined, size: 15, color: c.muted),
          ),
          Expanded(
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              children: [
                for (final f in floors)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(7),
                      onTap: () {
                        final subs = _subsOfFloor(d, f['id'] as String);
                        if (subs.isNotEmpty) setState(() => curSub = subs.first['id'] as String);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: f['id'] == curFloor ? c.accentSoft : Colors.transparent,
                          border: Border.all(color: f['id'] == curFloor ? c.accent : c.line),
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: Text(
                          f['title'] as String? ?? '',
                          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: f['id'] == curFloor ? c.accentInk : c.muted),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------ page

  @override
  Widget build(BuildContext context) {
    final c = context.evo;
    final d = p.doc;
    final sub = _sub(d);
    final room = curSub == null ? null : _roomOf(d, curSub!);
    final subs = room == null ? const <Json>[] : _subsOfFloor(d, room['floorId'] as String? ?? '');
    final cols = (jsonMap(sub?['layout'])['columns'] as num?)?.toInt() ?? 4;
    final rows = (jsonMap(sub?['layout'])['rows'] as num?)?.toInt() ?? 12;
    final widgets = sub == null ? const <Json>[] : jsonList(sub['widgets']);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chạy thử', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: Text('Mô phỏng — chưa gửi bus thật', style: TextStyle(fontSize: 12, color: c.muted)),
          ),
        ],
      ),
      body: Container(
        color: c.paper,
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(18),
            child: Container(
              width: _frameWidth,
              decoration: BoxDecoration(
                color: c.panel,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: c.lineStrong, width: 1.5),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.07), blurRadius: 18, offset: const Offset(0, 6))],
              ),
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    height: 40,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    alignment: Alignment.centerLeft,
                    child: Text(
                      room == null ? 'Chưa chọn trang' : '${room['title']}${sub == null ? '' : '  ·  ${sub['title']}'}',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
                    ),
                  ),
                  if (widgets.isEmpty)
                    Container(
                      height: 220,
                      alignment: Alignment.center,
                      child: Text('Trang chưa có thành phần nào.', style: TextStyle(fontSize: 13, color: c.muted)),
                    )
                  else
                    LayoutBuilder(
                      builder: (context, box) {
                        final cell = box.maxWidth / cols;
                        return SingleChildScrollView(
                          child: SizedBox(
                            height: rows * cell,
                            child: Stack(
                              children: [
                                for (final w in widgets)
                                  Positioned(
                                    left: ((jsonMap(w['pos'])['x'] as num? ?? 0)) * cell,
                                    top: ((jsonMap(w['pos'])['y'] as num? ?? 0)) * cell,
                                    width: ((jsonMap(w['pos'])['w'] as num? ?? 1)) * cell,
                                    height: ((jsonMap(w['pos'])['h'] as num? ?? 1)) * cell,
                                    child: Padding(
                                      padding: const EdgeInsets.all(3),
                                      child: _view(context, w),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  _pageTabs(context, subs),
                  _floorBar(context, d),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
