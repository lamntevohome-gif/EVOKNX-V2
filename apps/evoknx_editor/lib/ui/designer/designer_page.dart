import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:knx_config/knx_config.dart';

import '../../app/theme.dart';
import '../../state/project_controller.dart';
import '../common.dart';
import 'properties_panel.dart';
import 'widget_views.dart';

/// Giai đoạn 2: visual designer. Left: room tree + component palette.
/// Center: phone canvas with drag & drop, resize and grid snapping.
/// Right: properties panel with group address bindings.
class DesignerPage extends StatefulWidget {
  const DesignerPage({super.key, required this.project});
  final ProjectController project;
  @override
  State<DesignerPage> createState() => _DesignerPageState();
}

class _DesignerPageState extends State<DesignerPage> {
  String? selSub;
  String? selWidget;
  String? selChild;
  double zoom = 1.0;

  // Live drag state (visual only — committed to the document once, on end).
  String? _moveId;
  int _moveX = 0, _moveY = 0, _moveOX = 0, _moveOY = 0;
  double _accumDx = 0, _accumDy = 0;
  bool _moveValid = true;

  String? _resizeId;
  int _resW = 0, _resH = 0, _resOW = 0, _resOH = 0;
  double _accumW = 0, _accumH = 0;
  bool _resValid = true;

  // Palette drop preview.
  int? _hoverX, _hoverY;
  bool _hoverOk = false;
  String? _hoverType;

  static const _frameWidths = {'mobile': 380.0, 'tabletP': 520.0, 'tabletL': 680.0};
  static const _pad = 12.0;

  final _gridKey = GlobalKey();

  ProjectController get p => widget.project;

  // ------------------------------------------------------------ lookups

  Json? _findSub(Json d) {
    for (final s in allSubpages(d)) {
      if (s['id'] == selSub) return s;
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

  Json? _findWidget(Json? sub, String? id) {
    if (sub == null || id == null) return null;
    for (final w in jsonList(sub['widgets'])) {
      if (w['id'] == id) return w;
    }
    return null;
  }

  String get _activeDev => (p.doc['activeDev'] as String?) ?? 'mobile';

  // Keep the selection valid after undo/redo or structure edits.
  void _sanitize(Json d) {
    final sub = _findSub(d);
    if (selSub != null && sub == null) selSub = null;
    if (_findWidget(sub, selWidget) == null) {
      selWidget = null;
      selChild = null;
    }
  }

  // ------------------------------------------------------------ editing

  void _select({String? sub, String? widget, String? child}) {
    setState(() {
      if (sub != null) selSub = sub;
      selWidget = widget;
      selChild = child;
    });
  }

  void _addWidget(String type, {int? atX, int? atY}) {
    final sub = _findSub(p.doc);
    if (sub == null) {
      toast(context, 'Hãy mở một trang ở danh sách bên trái trước khi thêm thành phần.');
      return;
    }
    final def = kWidgetTypes[type]!;
    final f = atX != null && atY != null && isFree(sub, atX, atY, def.w, def.h) ? (x: atX, y: atY) : findFree(sub, def.w, def.h);
    String? newId;
    p.mutate((d) {
      final s = _findSub(d);
      if (s == null) return;
      final w = makeWidget(type, f.x, f.y);
      newId = w['id'] as String;
      (s['widgets'] as List).add(w);
    });
    if (newId != null) _select(widget: newId);
  }

  void _deleteSelected() {
    final sub = _findSub(p.doc);
    final w = _findWidget(sub, selWidget);
    if (w == null) return;
    if (selChild != null) {
      final childId = selChild;
      p.mutate((d) {
        final s = _findSub(d);
        final g = _findWidget(s, selWidget);
        (g?['widgets'] as List?)?.removeWhere((x) => x is Map && x['id'] == childId);
      });
      _select(child: null);
    } else {
      p.mutate((d) {
        final s = _findSub(d);
        (s?['widgets'] as List?)?.removeWhere((x) => x is Map && x['id'] == w['id']);
      });
      _select(widget: null);
    }
    toast(context, 'Đã xoá thành phần. Có thể hoàn tác (Ctrl+Z).');
  }

  void _duplicateSelected() {
    final sub = _findSub(p.doc);
    if (sub == null) return;
    final w = _findWidget(sub, selWidget);
    if (w == null || selChild != null) return;
    final copy = Json.from(_deepCopy(w) as Map);
    copy['id'] = uid('w_');
    final pw = jsonMap(w['pos']);
    final spot = findFree(sub, (pw['w'] as num?)?.toInt() ?? 2, (pw['h'] as num?)?.toInt() ?? 2);
    final pos = jsonMap(copy['pos']);
    pos['x'] = spot.x;
    pos['y'] = spot.y;
    String? newId;
    p.mutate((d) {
      final s = _findSub(d);
      (s?['widgets'] as List?)?.add(copy);
      newId = copy['id'] as String;
    });
    if (newId != null) _select(widget: newId);
  }

  void _nudge(int dx, int dy) {
    final sub = _findSub(p.doc);
    final w = _findWidget(sub, selWidget);
    if (w == null || selChild != null) return;
    final pos = jsonMap(w['pos']);
    final cols = (jsonMap(sub?['layout'])['columns'] as num?)?.toInt() ?? 4;
    final x = (pos['x'] as num?)?.toInt() ?? 0;
    final y = (pos['y'] as num?)?.toInt() ?? 0;
    final ww = (pos['w'] as num?)?.toInt() ?? 1;
    final hh = (pos['h'] as num?)?.toInt() ?? 1;
    final nx = x + dx, ny = y + dy;
    if (nx < 0 || ny < 0 || nx + ww > cols || !isFree(sub!, nx, ny, ww, hh, w['id'] as String)) return;
    p.mutate((d) {
      final pp = jsonMap(_findWidget(_findSub(d), selWidget)?['pos']);
      pp['x'] = nx;
      pp['y'] = ny;
    });
  }

  static Object? _deepCopy(Object? v) {
    if (v is Map) return v.map((k, e) => MapEntry(k.toString(), _deepCopy(e)));
    if (v is List) return v.map(_deepCopy).toList();
    return v;
  }

  // ------------------------------------------------------------ canvas helpers

  (int, int)? _cellFromGlobal(Offset global, int cols) {
    final box = _gridKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return null;
    final local = box.globalToLocal(global);
    final x = (local.dx / _cell).floor().clamp(0, cols - 1);
    final y = (local.dy / _cell).floor();
    return (x, y < 0 ? 0 : y);
  }

  double get _cell => (_frameWidths[_activeDev] ?? 380.0) * zoom / (((_findSub(p.doc)?['layout'] as Map?)?['columns'] as num?)?.toInt() ?? 4);

  void _onPaletteMove(DragTargetDetails<String> d, Json sub) {
    final cols = (jsonMap(sub['layout'])['columns'] as num?)?.toInt() ?? 4;
    final cell = _cell;
    final box = _gridKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final local = box.globalToLocal(d.offset);
    final x = (local.dx / cell).floor().clamp(0, cols - 1);
    final y = (local.dy / cell).floor();
    final def = kWidgetTypes[d.data]!;
    final ok = y >= 0 && isFree(sub, x, y, def.w, def.h);
    if (_hoverX != x || _hoverY != y || _hoverOk != ok || _hoverType != d.data) {
      setState(() {
        _hoverX = x;
        _hoverY = y;
        _hoverOk = ok;
        _hoverType = d.data;
      });
    }
  }

  void _onPaletteAccept(DragTargetDetails<String> d, Json sub) {
    final cols = (jsonMap(sub['layout'])['columns'] as num?)?.toInt() ?? 4;
    final c = _cellFromGlobal(d.offset, cols);
    final def = kWidgetTypes[d.data]!;
    final ok = c != null && isFree(sub, c.$1, c.$2, def.w, def.h);
    setState(() => _hoverX = _hoverY = _hoverType = null);
    _addWidget(d.data, atX: ok ? c.$1 : null, atY: ok ? c.$2 : null);
  }

  // ------------------------------------------------------------ build

  @override
  Widget build(BuildContext context) {
    final c = context.evo;
    final d = p.doc;
    _sanitize(d);
    final sub = _findSub(d);
    final room = selSub == null ? null : _roomOf(d, selSub!);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _leftSidebar(context),
        Expanded(
          child: Column(
            children: [
              _canvasHeader(context, room),
              Expanded(
                child: sub == null ? _emptyCanvas(context) : _canvas(context, sub),
              ),
            ],
          ),
        ),
        Container(
          width: 360,
          decoration: BoxDecoration(color: c.panel, border: Border(left: BorderSide(color: c.line))),
          child: PropertiesPanel(
            project: p,
            subId: selSub,
            widgetId: selWidget,
            childId: selChild,
            onSelect: (wId, cId) => _select(widget: wId, child: cId),
          ),
        ),
      ],
    );
  }

  // ------------------------------------------------------------ left sidebar

  Widget _leftSidebar(BuildContext context) {
    final c = context.evo;
    return Container(
      width: 280,
      decoration: BoxDecoration(color: c.panel, border: Border(right: BorderSide(color: c.line))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: _tree(context)),
          Container(height: 1, color: c.line),
          SizedBox(
            height: 262,
            child: _palette(context),
          ),
        ],
      ),
    );
  }

  Widget _tree(BuildContext context) {
    final c = context.evo;
    final d = p.doc;
    final rooms = jsonList(d['pages']);
    final floors = jsonList(d['floors']);
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        const SectionTitle('Phòng & trang'),
        if (rooms.isEmpty)
          Text('Chưa có phòng nào. Hãy thêm phòng ở màn hình Cấu trúc.', style: TextStyle(fontSize: 12.5, color: c.muted)),
        for (final f in floors) ...[
          Padding(
            padding: const EdgeInsets.only(top: 6, bottom: 2),
            child: Row(
              children: [
                Icon(Icons.stairs_outlined, size: 15, color: c.muted),
                const SizedBox(width: 6),
                Expanded(child: Text(f['title'] as String? ?? '', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c.muted))),
              ],
            ),
          ),
          for (final r in rooms.where((r) => r['floorId'] == f['id'])) ...[
            _treeRow(
              Icons.meeting_room_outlined,
              r['title'] as String? ?? '',
              selected: false,
              trailing: '${jsonList(r['subpages']).length}',
              onTap: () {
                final subs = jsonList(r['subpages']);
                _select(sub: subs.isEmpty ? null : subs.first['id'] as String, widget: null);
              },
            ),
            for (final s in jsonList(r['subpages']))
              Padding(
                padding: const EdgeInsets.only(left: 16),
                child: _treeRow(
                  Icons.layers_outlined,
                  s['title'] as String? ?? '',
                  selected: s['id'] == selSub,
                  onTap: () => _select(sub: s['id'] as String, widget: null),
                ),
              ),
          ],
        ],
      ],
    );
  }

  Widget _treeRow(IconData icon, String text, {required bool selected, String? trailing, required VoidCallback onTap}) {
    final c = context.evo;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(color: selected ? c.accentSoft : null, borderRadius: BorderRadius.circular(8)),
        child: Row(
          children: [
            Icon(icon, size: 16, color: selected ? c.accentInk : c.ink),
            const SizedBox(width: 8),
            Expanded(child: Text(text, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, color: selected ? c.accentInk : c.ink, fontWeight: selected ? FontWeight.w600 : FontWeight.w400))),
            if (trailing != null) Text(trailing, style: TextStyle(fontSize: 11.5, color: c.muted)),
          ],
        ),
      ),
    );
  }

  Widget _palette(BuildContext context) {
    final c = context.evo;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
          child: Text('THÀNH PHẦN — kéo vào trang hoặc bấm để thêm', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: c.muted, letterSpacing: 0.3)),
        ),
        Expanded(
          child: GridView(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 8, crossAxisSpacing: 8, childAspectRatio: 1.24),
            children: [
              for (final t in kWidgetTypes.values)
                _paletteTile(context, t),
            ],
          ),
        ),
      ],
    );
  }

  Widget _paletteTile(BuildContext context, WidgetTypeDef t) {
    final c = context.evo;
    final tile = Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: c.paper, border: Border.all(color: c.line), borderRadius: BorderRadius.circular(10)),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(evoIcon(t.icon), size: 22, color: c.ink),
          const SizedBox(height: 4),
          Text(t.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          Text('${t.w} × ${t.h}', style: TextStyle(fontSize: 10.5, color: c.muted)),
        ],
      ),
    );
    return GestureDetector(
      onTap: () => _addWidget(t.type),
      child: Draggable<String>(
        data: t.type,
        feedback: Material(
          elevation: 6,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            width: 108,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: c.panel, border: Border.all(color: c.accent), borderRadius: BorderRadius.circular(10)),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(evoIcon(t.icon), size: 22, color: c.accentInk),
                const SizedBox(height: 4),
                Text(t.name, maxLines: 1, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
        childWhenDragging: Opacity(opacity: 0.35, child: tile),
        onDragStarted: () => _select(widget: null),
        child: tile,
      ),
    );
  }

  // ------------------------------------------------------------ canvas chrome

  Widget _canvasHeader(BuildContext context, Json? room) {
    final c = context.evo;
    final d = p.doc;
    final devs = jsonMap(d['devices']);
    final active = _activeDev;
    final subs = room == null ? <Json>[] : jsonList(room['subpages']);
    Widget devChip(String dev, String label) {
      final on = dev == active;
      return InkWell(
        borderRadius: BorderRadius.circular(7),
        onTap: on
            ? null
            : () {
                p.mutate((doc) => switchDevice(doc, dev));
                setState(() => selWidget = selChild = null);
              },
        child: Container(
          height: 28,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: on ? c.accentSoft : Colors.transparent,
            border: Border.all(color: on ? c.accent : c.line),
            borderRadius: BorderRadius.circular(7),
          ),
          child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: on ? c.accentInk : c.muted)),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(color: c.panel, border: Border(bottom: BorderSide(color: c.line))),
      child: Row(
        children: [
          Icon(Icons.smartphone, size: 17, color: c.muted),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              room == null ? 'Chưa chọn trang' : '${room['title']}${subs.isEmpty ? '' : '  ·  ${subs.where((s) => s['id'] == selSub).map((s) => s['title']).join('')}'}',
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              reverse: true,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final s in subs)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(7),
                        onTap: () => _select(sub: s['id'] as String, widget: null),
                        child: Container(
                          height: 28,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: s['id'] == selSub ? c.accentSoft : Colors.transparent,
                            border: Border.all(color: s['id'] == selSub ? c.accent : c.line),
                            borderRadius: BorderRadius.circular(7),
                          ),
                          child: Text(s['title'] as String? ?? '', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: s['id'] == selSub ? c.accentInk : c.muted)),
                        ),
                      ),
                    ),
                  devChip('mobile', 'Điện thoại'),
                  if (devs['tabletP'] == true) ...[const SizedBox(width: 5), devChip('tabletP', 'Tablet dọc')],
                  if (devs['tabletL'] == true) ...[const SizedBox(width: 5), devChip('tabletL', 'Tablet ngang')],
                  _devMenu(context, devs),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Thu nhỏ',
                    onPressed: zoom <= 0.6 ? null : () => setState(() => zoom -= 0.2),
                    icon: const Icon(Icons.zoom_out, size: 19),
                  ),
                  Text('${(zoom * 100).round()}%', style: TextStyle(fontSize: 12, color: c.muted)),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Phóng to',
                    onPressed: zoom >= 1.6 ? null : () => setState(() => zoom += 0.2),
                    icon: const Icon(Icons.zoom_in, size: 19),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _devMenu(BuildContext context, Json devs) {
    final c = context.evo;
    return PopupMenuButton<String>(
      tooltip: 'Thiết bị bố cục',
      position: PopupMenuPosition.under,
      onSelected: (v) => p.mutate((d) {
        final dd = jsonMap(d['devices']);
        dd[v] = !(dd[v] == true);
        d['devices'] = dd;
      }),
      itemBuilder: (_) => [
        PopupMenuItem(value: 'tabletP', enabled: false, child: Row(children: [
          Icon(devs['tabletP'] == true ? Icons.check_box_outlined : Icons.check_box_outline_blank, size: 18, color: devs['tabletP'] == true ? c.accent : c.muted),
          const SizedBox(width: 8),
          const Text('Bố cục tablet dọc (6 cột)', style: TextStyle(fontSize: 13)),
        ])),
        PopupMenuItem(value: 'tabletL', enabled: false, child: Row(children: [
          Icon(devs['tabletL'] == true ? Icons.check_box_outlined : Icons.check_box_outline_blank, size: 18, color: devs['tabletL'] == true ? c.accent : c.muted),
          const SizedBox(width: 8),
          const Text('Bố cục tablet ngang (8 cột)', style: TextStyle(fontSize: 13)),
        ])),
      ],
      child: const Padding(
        padding: EdgeInsets.all(6),
        child: Icon(Icons.devices_other, size: 19),
      ),
    );
  }

  Widget _emptyCanvas(BuildContext context) {
    final c = context.evo;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 460),
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(color: c.panel, border: Border.all(color: c.line), borderRadius: BorderRadius.circular(14)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.design_services, size: 38, color: c.accent),
              const SizedBox(height: 12),
              const Text('Chọn một trang để thiết kế', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Text(
                'Chọn phòng và trang ở danh sách bên trái, rồi kéo thành phần từ thanh “Thành phần” vào canvas. '
                'Thiết kế ở đây chính là giao diện app điện thoại sẽ hiển thị.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: c.muted, height: 1.45),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------ canvas

  Widget _canvas(BuildContext context, Json sub) {
    final c = context.evo;
    final cols = (jsonMap(sub['layout'])['columns'] as num?)?.toInt() ?? 4;
    final rows = (jsonMap(sub['layout'])['rows'] as num?)?.toInt() ?? 12;
    final cell = (_frameWidths[_activeDev] ?? 380.0) * zoom;
    final inner = cell - 2 * _pad;
    final unit = inner / cols;
    final widgets = jsonList(sub['widgets']);

    final moving = _findWidget(sub, _moveId);

    Widget canvasStack() => Stack(
          key: _gridKey,
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _GridPainter(
                  cols: cols,
                  rows: rows,
                  unit: unit,
                  line: c.line,
                  hoverRect: _hoverType != null && _hoverX != null ? (_hoverX!, _hoverY!, kWidgetTypes[_hoverType]?.w ?? 2, kWidgetTypes[_hoverType]?.h ?? 2) : null,
                  hoverOk: _hoverOk,
                  hoverColor: c.accent.withValues(alpha: 0.25),
                  hoverBadColor: c.danger.withValues(alpha: 0.2),
                ),
              ),
            ),
            for (final w in widgets) _canvasWidget(context, sub, w, unit),
            if (moving != null && !_moveValid) _ghostRect(moving, unit, c.danger.withValues(alpha: 0.18)),
          ],
        );

    final frame = Container(
      width: cell,
      margin: const EdgeInsets.symmetric(vertical: 18),
      padding: EdgeInsets.all(_pad),
      decoration: BoxDecoration(
        color: c.paper,
        borderRadius: BorderRadius.circular(22 * zoom),
        border: Border.all(color: c.lineStrong, width: 1.5),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.07), blurRadius: 18, offset: const Offset(0, 6))],
      ),
      child: SizedBox(height: rows * unit, child: canvasStack()),
    );

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.delete): _deleteSelected,
        const SingleActivator(LogicalKeyboardKey.backspace): _deleteSelected,
        const SingleActivator(LogicalKeyboardKey.keyD, control: true): _duplicateSelected,
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () => _nudge(-1, 0),
        const SingleActivator(LogicalKeyboardKey.arrowRight): () => _nudge(1, 0),
        const SingleActivator(LogicalKeyboardKey.arrowUp): () => _nudge(0, -1),
        const SingleActivator(LogicalKeyboardKey.arrowDown): () => _nudge(0, 1),
      },
      child: Focus(
        autofocus: true,
        child: GestureDetector(
          onTap: () => _select(widget: null, child: null),
          child: SingleChildScrollView(
            child: DragTarget<String>(
              onMove: (d) => _onPaletteMove(d, sub),
              onLeave: (_) {
                if (_hoverType != null) setState(() => _hoverX = _hoverY = _hoverType = null);
              },
              onAcceptWithDetails: (d) => _onPaletteAccept(d, sub),
              builder: (context, _, __) => Align(alignment: Alignment.topCenter, child: frame),
            ),
          ),
        ),
      ),
    );
  }

  Widget _ghostRect(Json w, double unit, Color color) {
    final pos = jsonMap(w['pos']);
    return Positioned(
      left: (pos['x'] as num? ?? 0) * unit,
      top: (pos['y'] as num? ?? 0) * unit,
      width: (pos['w'] as num? ?? 1) * unit,
      height: (pos['h'] as num? ?? 1) * unit,
      child: Container(
        margin: const EdgeInsets.all(4),
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Widget _canvasWidget(BuildContext context, Json sub, Json w, double unit) {
    final c = context.evo;
    final pos = jsonMap(w['pos']);
    final isMoving = _moveId == w['id'];
    final isResizing = _resizeId == w['id'];
    final selected = selWidget == w['id'];
    final x = isMoving ? _moveX : (pos['x'] as num?)?.toInt() ?? 0;
    final y = isMoving ? _moveY : (pos['y'] as num?)?.toInt() ?? 0;
    final ww = isResizing ? _resW : (pos['w'] as num?)?.toInt() ?? 1;
    final hh = isResizing ? _resH : (pos['h'] as num?)?.toInt() ?? 1;
    final invalid = (isMoving && !_moveValid) || (isResizing && !_resValid);
    final child = selChild == w['id'];

    final inner = Padding(
      padding: const EdgeInsets.all(4),
      child: widgetPreview(context, w),
    );

    return Positioned(
      left: x * unit,
      top: y * unit,
      width: ww * unit,
      height: hh * unit,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _select(widget: w['id'] as String, child: null),
        onPanStart: (DragStartDetails d) {
          if (selChild != null && selected) return;
          _accumDx = _accumDy = 0;
          _moveOX = x;
          _moveOY = y;
          setState(() {
            _moveId = w['id'] as String;
            _moveX = x;
            _moveY = y;
            _moveValid = true;
          });
        },
        onPanUpdate: (DragUpdateDetails d) {
          if (_moveId != w['id']) return;
          _accumDx += d.delta.dx;
          _accumDy += d.delta.dy;
          final cols = (jsonMap(sub['layout'])['columns'] as num?)?.toInt() ?? 4;
          final tx = (_moveOX + (_accumDx / unit).round()).clamp(0, cols - ww);
          final ty = (_moveOY + (_accumDy / unit).round());
          final valid = ty >= 0 && isFree(sub, tx, ty, ww, hh, w['id'] as String);
          setState(() {
            _moveX = tx;
            _moveY = ty < 0 ? _moveY : ty;
            _moveValid = valid;
          });
        },
        onPanEnd: (DragEndDetails d) {
          if (_moveId != w['id']) return;
          final changed = _moveX != _moveOX || _moveY != _moveOY;
          final tx = _moveX, ty = _moveY, ok = _moveValid;
          setState(() => _moveId = null);
          if (!ok || !changed) return;
          p.mutate((doc) {
            final pp = jsonMap(_findWidget(_findSub(doc), w['id'] as String)?['pos']);
            pp['x'] = tx;
            pp['y'] = ty;
          });
        },
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: invalid ? c.danger : (selected || child ? c.accent : Colors.transparent),
                  width: 1.6,
                ),
              ),
              child: child ? inner : IgnorePointer(child: inner),
            ),
            if (selected || child)
              Positioned(
                top: 2,
                right: 2,
                child: BindDot(
                  bind: jsonMap(w['bind']),
                  w: w,
                  size: 8,
                ),
              ),
            if (selected && selChild == null)
              Positioned(
                right: 0,
                bottom: 0,
                width: 18,
                height: 18,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onPanStart: (DragStartDetails d) {
                    _accumW = _accumH = 0;
                    setState(() {
                      _resizeId = w['id'] as String;
                      _resW = ww;
                      _resH = hh;
                      _resOW = ww;
                      _resOH = hh;
                      _resValid = true;
                    });
                  },
                  onPanUpdate: (DragUpdateDetails d) {
                    if (_resizeId != w['id']) return;
                    _accumW += d.delta.dx;
                    _accumH += d.delta.dy;
                    final cols = (jsonMap(sub['layout'])['columns'] as num?)?.toInt() ?? 4;
                    final nw = (_resOW + (_accumW / unit).round()).clamp(1, cols - x);
                    final nh = (_resOH + (_accumH / unit).round()).clamp(1, 40);
                    final valid = isFree(sub, x, y, nw, nh, w['id'] as String);
                    setState(() {
                      _resW = nw;
                      _resH = nh;
                      _resValid = valid;
                    });
                  },
                  onPanEnd: (DragEndDetails d) {
                    if (_resizeId != w['id']) return;
                    final nw = _resW, nh = _resH, ok = _resValid;
                    final changed = nw != _resOW || nh != _resOH;
                    setState(() => _resizeId = null);
                    if (!ok || !changed) return;
                    p.mutate((doc) {
                      final pp = jsonMap(_findWidget(_findSub(doc), w['id'] as String)?['pos']);
                      pp['w'] = nw;
                      pp['h'] = nh;
                    });
                  },
                  child: MouseRegion(
                    cursor: SystemMouseCursors.resizeDownRight,
                    child: Container(
                      decoration: BoxDecoration(
                        color: c.accent,
                        borderRadius: const BorderRadius.only(bottomRight: Radius.circular(8), topLeft: Radius.circular(8)),
                      ),
                      child: const Icon(Icons.drag_indicator, size: 12, color: Colors.white),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Draws the layout grid lines and the palette drop preview.
class _GridPainter extends CustomPainter {
  _GridPainter({
    required this.cols,
    required this.rows,
    required this.unit,
    required this.line,
    required this.hoverRect,
    required this.hoverOk,
    required this.hoverColor,
    required this.hoverBadColor,
  });

  final int cols, rows;
  final double unit;
  final Color line;
  final (int, int, int, int)? hoverRect;
  final bool hoverOk;
  final Color hoverColor, hoverBadColor;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = line.withValues(alpha: 0.55);
    for (var i = 0; i <= cols; i++) {
      canvas.drawLine(Offset(i * unit, 0), Offset(i * unit, rows * unit), p);
    }
    for (var j = 0; j <= rows; j++) {
      canvas.drawLine(Offset(0, j * unit), Offset(cols * unit, j * unit), p);
    }
    final hr = hoverRect;
    if (hr != null) {
      final r = Rect.fromLTWH(hr.$1 * unit, hr.$2 * unit, hr.$3 * unit, hr.$4 * unit).deflate(3);
      canvas.drawRRect(
        RRect.fromRectAndRadius(r, const Radius.circular(10)),
        Paint()..color = hoverOk ? hoverColor : hoverBadColor,
      );
    }
  }

  @override
  bool shouldRepaint(_GridPainter old) =>
      old.cols != cols || old.rows != rows || old.unit != unit || old.hoverRect != hoverRect || old.hoverOk != hoverOk || old.line != line;
}
