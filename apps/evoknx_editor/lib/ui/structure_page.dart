import 'package:flutter/material.dart';
import 'package:knx_config/knx_config.dart';

import '../app/theme.dart';
import '../state/project_controller.dart';
import 'common.dart';
import 'designer/designer_page.dart';

/// Cấu trúc workspace: tổng quan dự án + quản lý tầng / phòng / trang, và
/// màn hình thiết kế giao diện nằm ngay trong mục này (không tách tab riêng).
class StructurePage extends StatefulWidget {
  const StructurePage({super.key, required this.project});
  final ProjectController project;
  @override
  State<StructurePage> createState() => _StructurePageState();
}

class _StructurePageState extends State<StructurePage> {
  String? selFloor;
  String? selRoom;
  bool designMode = false;
  String? designSub;

  ProjectController get p => widget.project;

  List<Json> _rooms(Json d, String floorId) => jsonList(d['pages']).where((r) => r['floorId'] == floorId).toList();

  void _edit(void Function(Json d) fn, {String? key}) => p.mutate(fn, coalesce: key);

  Json? _find(List<Json> l, String? id) {
    for (final x in l) {
      if (x['id'] == id) return x;
    }
    return null;
  }

  int _widgetCount(Json room) {
    var n = 0;
    for (final s in jsonList(room['subpages'])) {
      n += jsonList(s['widgets']).length;
    }
    return n;
  }

  /// Mở màn hình thiết kế: ưu tiên trang chỉ định, rồi trang đầu của phòng
  /// đang chọn, rồi trang đầu tiên bất kỳ trong dự án.
  void _openDesigner({String? subId}) {
    String? sub = subId;
    if (sub == null) {
      final room = _find(jsonList(p.doc['pages']), selRoom);
      final subs = room == null ? const <Json>[] : jsonList(room['subpages']);
      if (subs.isNotEmpty) sub = subs.first['id'] as String;
    }
    if (sub == null) {
      for (final r in jsonList(p.doc['pages'])) {
        final subs = jsonList(r['subpages']);
        if (subs.isNotEmpty) {
          sub = subs.first['id'] as String;
          break;
        }
      }
    }
    setState(() {
      designSub = sub;
      designMode = true;
    });
  }

  void _addFloor() => _edit((d) {
        final f = makeFloor('Tầng ${jsonList(d['floors']).length + 1}');
        (d['floors'] as List).add(f);
        selFloor = f['id'] as String;
        selRoom = null;
      });

  void _addRoom(Json floor) => _edit((d) {
        final r = makeRoom('Phòng ${jsonList(d['pages']).length + 1}', floorId: floor['id'] as String);
        (d['pages'] as List).add(r);
        selRoom = r['id'] as String;
        selFloor = floor['id'] as String;
      });

  @override
  Widget build(BuildContext context) {
    if (designMode) {
      return DesignerPage(
        project: p,
        initialSubId: designSub,
        onExit: () => setState(() => designMode = false),
      );
    }
    final floors = jsonList(p.doc['floors']);
    final room = _find(jsonList(p.doc['pages']), selRoom);
    final floor = _find(floors, selFloor);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _leftPanel(context, floors),
        Expanded(child: _dashboard(context, floors)),
        _rightPanel(context, room, floor, floors),
      ],
    );
  }

  // ------------------------------------------------------------ left panel

  Widget _leftPanel(BuildContext context, List<Json> floors) {
    final c = context.evo;
    return Container(
      width: 300,
      decoration: BoxDecoration(
        color: c.panel,
        border: Border(right: BorderSide(color: c.line)),
      ),
      child: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          Row(
            children: [
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.center,
                  child: EvoButton(
                    label: 'Tổng quan',
                    icon: Icons.dashboard_outlined,
                    small: true,
                    onPressed: () => setState(() => selRoom = selFloor = null),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.center,
                  child: EvoButton(
                    label: 'Thêm tầng',
                    icon: Icons.add,
                    small: true,
                    onPressed: _addFloor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final f in floors) ...[
            _treeRow(
              context,
              icon: Icons.stairs_outlined,
              text: f['title'] as String? ?? '',
              bold: true,
              selected: f['id'] == selFloor && selRoom == null,
              onTap: () => setState(() {
                selFloor = f['id'] as String;
                selRoom = null;
              }),
              trailing: '${_rooms(p.doc, f['id'] as String).length} phòng',
            ),
            for (final r in _rooms(p.doc, f['id'] as String))
              Padding(
                padding: const EdgeInsets.only(left: 16),
                child: _treeRow(
                  context,
                  icon: Icons.meeting_room_outlined,
                  text: r['title'] as String? ?? '',
                  selected: r['id'] == selRoom,
                  onTap: () => setState(() {
                    selRoom = r['id'] as String;
                    selFloor = f['id'] as String;
                  }),
                  trailing: '${jsonList(r['subpages']).length} trang',
                ),
              ),
            Padding(
              padding: const EdgeInsets.only(left: 16),
              child: _treeRow(
                context,
                icon: Icons.add,
                text: 'Thêm phòng',
                accent: true,
                onTap: () => _addRoom(f),
              ),
            ),
            const SizedBox(height: 6),
          ],
        ],
      ),
    );
  }

  // ------------------------------------------------------------ dashboard (tổng quan)

  Widget _dashboard(BuildContext context, List<Json> floors) {
    final c = context.evo;
    final pages = jsonList(p.doc['pages']);
    final widgets = allWidgets(p.doc).length;
    Widget stat(String n, String t) => Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: c.line),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(n, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
            Text(t, style: TextStyle(fontSize: 12, color: c.muted)),
          ],
        ),
      ),
    );
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Expanded(child: SectionTitle('Tổng quan dự án')),
                  EvoButton(label: 'Thêm tầng', icon: Icons.add, small: true, onPressed: _addFloor),
                  const SizedBox(width: 8),
                  EvoButton(
                    label: 'Thiết kế',
                    icon: Icons.design_services_outlined,
                    small: true,
                    primary: true,
                    onPressed: () => _openDesigner(),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(children: [stat('${floors.length}', 'tầng'), const SizedBox(width: 8), stat('${pages.length}', 'phòng')]),
              const SizedBox(height: 8),
              Row(children: [stat('$widgets', 'thành phần'), const SizedBox(width: 8), stat('${p.groupAddresses.length}', 'địa chỉ nhóm')]),
              const SizedBox(height: 18),
              if (floors.isEmpty)
                _emptyOverview(context)
              else
                for (final f in floors) ...[
                  _floorCard(context, f),
                  const SizedBox(height: 12),
                ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _emptyOverview(BuildContext context) {
    final c = context.evo;
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(color: c.panel, border: Border.all(color: c.line), borderRadius: BorderRadius.circular(14)),
      child: Column(
        children: [
          Icon(Icons.apartment_outlined, size: 38, color: c.accent),
          const SizedBox(height: 12),
          const Text('Chưa có tầng nào', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text(
            'Thêm tầng đầu tiên để bắt đầu sắp xếp các phòng, rồi thiết kế giao diện cho từng trang.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: c.muted, height: 1.45),
          ),
          const SizedBox(height: 14),
          EvoButton(label: 'Thêm tầng đầu tiên', icon: Icons.add, primary: true, onPressed: _addFloor),
        ],
      ),
    );
  }

  Widget _floorCard(BuildContext context, Json f) {
    final c = context.evo;
    final rooms = _rooms(p.doc, f['id'] as String);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: c.panel, border: Border.all(color: c.line), borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.stairs_outlined, size: 18, color: c.accentInk),
              const SizedBox(width: 8),
              Expanded(child: Text(f['title'] as String? ?? '', style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600))),
              Text('${rooms.length} phòng', style: TextStyle(fontSize: 12, color: c.muted)),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final r in rooms) _roomCard(context, r),
              _addRoomCard(context, f),
            ],
          ),
        ],
      ),
    );
  }

  Widget _roomCard(BuildContext context, Json r) {
    final c = context.evo;
    final id = r['id'] as String;
    final subs = jsonList(r['subpages']);
    final selected = id == selRoom;
    return Container(
      width: 236,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: selected ? c.accentSoft : c.paper,
        border: Border.all(color: selected ? c.accent : c.line),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.meeting_room_outlined, size: 17, color: selected ? c.accentInk : c.ink),
              const SizedBox(width: 7),
              Expanded(child: Text(r['title'] as String? ?? '', overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600))),
            ],
          ),
          const SizedBox(height: 4),
          Text('${subs.length} trang · ${_widgetCount(r)} thành phần', style: TextStyle(fontSize: 11.5, color: c.muted)),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              children: [
                EvoButton(
                  label: 'Thiết kế',
                  icon: Icons.design_services_outlined,
                  small: true,
                  primary: true,
                  onPressed: () => _openDesigner(subId: subs.isEmpty ? null : subs.first['id'] as String),
                ),
                const SizedBox(width: 6),
                EvoButton(
                  label: 'Sửa',
                  icon: Icons.tune,
                  small: true,
                  onPressed: () => setState(() {
                    selRoom = id;
                    selFloor = r['floorId'] as String?;
                  }),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _addRoomCard(BuildContext context, Json floor) {
    final c = context.evo;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _addRoom(floor),
      child: Container(
        width: 236,
        height: 96,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: c.paper, border: Border.all(color: c.line), borderRadius: BorderRadius.circular(12)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add, size: 18, color: c.accentInk),
            const SizedBox(width: 6),
            Text('Thêm phòng', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.accentInk)),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------ right panel

  Widget _rightPanel(BuildContext context, Json? room, Json? floor, List<Json> floors) {
    final c = context.evo;
    return Container(
      width: 320,
      decoration: BoxDecoration(
        color: c.panel,
        border: Border(left: BorderSide(color: c.line)),
      ),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (room != null) ..._roomProps(context, room, floors) else if (floor != null) ..._floorProps(context, floor, floors) else ..._projectStats(context),
        ],
      ),
    );
  }

  Widget _treeRow(
    BuildContext context, {
    required IconData icon,
    required String text,
    bool bold = false,
    bool selected = false,
    bool accent = false,
    String? trailing,
    required VoidCallback onTap,
  }) {
    final c = context.evo;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(color: selected ? c.accentSoft : null, borderRadius: BorderRadius.circular(8)),
        child: Row(
          children: [
            Icon(icon, size: 18, color: accent || selected ? c.accentInk : c.ink),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
                  color: accent || selected ? c.accentInk : c.ink,
                  fontSize: accent ? 13.5 : 14,
                ),
              ),
            ),
            if (trailing != null) Text(trailing, style: TextStyle(fontSize: 12, color: c.muted)),
          ],
        ),
      ),
    );
  }

  List<Widget> _projectStats(BuildContext context) {
    final c = context.evo;
    final pages = jsonList(p.doc['pages']);
    final widgets = allWidgets(p.doc).length;
    Widget stat(String n, String t) => Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: c.line),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(n, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
          Text(t, style: TextStyle(fontSize: 12, color: c.muted)),
        ],
      ),
    );
    return [
      const SectionTitle('Tổng quan dự án'),
      const SizedBox(height: 4),
      Row(children: [Expanded(child: stat('${jsonList(p.doc['floors']).length}', 'tầng')), const SizedBox(width: 8), Expanded(child: stat('${pages.length}', 'phòng'))]),
      const SizedBox(height: 8),
      Row(children: [Expanded(child: stat('$widgets', 'thành phần')), const SizedBox(width: 8), Expanded(child: stat('${p.groupAddresses.length}', 'địa chỉ nhóm'))]),
      const SizedBox(height: 14),
      Text('Chọn tầng hoặc phòng ở cây bên trái để xem chi tiết; bấm “Thiết kế” trên thẻ phòng để mở canvas.', style: TextStyle(fontSize: 12.5, color: c.muted, height: 1.5)),
    ];
  }

  List<Widget> _floorProps(BuildContext context, Json f, List<Json> floors) {
    final id = f['id'] as String;
    final nRooms = _rooms(p.doc, id).length;
    return [
      SectionTitle(
        'Tầng',
        trailing: floors.length > 1
            ? EvoButton(
                label: 'Xoá tầng',
                icon: Icons.delete_outline,
                small: true,
                danger: true,
                onPressed: () {
                  if (nRooms > 0) {
                    toast(context, '${f['title']} còn $nRooms phòng. Hãy chuyển hoặc xoá các phòng trước.');
                    return;
                  }
                  _edit((d) => (d['floors'] as List).removeWhere((x) => x is Map && x['id'] == id));
                  setState(() => selFloor = null);
                },
              )
            : null,
      ),
      FieldLabel(
        'Tên tầng',
        SyncedField(
          value: f['title'] as String? ?? '',
          onChanged: (v) => _edit((d) => _find(jsonList(d['floors']), id)?['title'] = v, key: 'fl:$id'),
        ),
      ),
      const SizedBox(height: 12),
      Material(
        type: MaterialType.transparency,
        child: CheckboxListTile(
          value: f['showIcon'] != false,
          contentPadding: EdgeInsets.zero,
          dense: true,
          controlAffinity: ListTileControlAffinity.leading,
          title: const Text('Ẩn/hiện biểu tượng'),
          onChanged: (v) => _edit((d) => _find(jsonList(d['floors']), id)?['showIcon'] = v ?? true),
        ),
      ),
    ];
  }

  List<Widget> _roomProps(BuildContext context, Json r, List<Json> floors) {
    final id = r['id'] as String;
    final subs = jsonList(r['subpages']);
    Json? room(Json d) => _find(jsonList(d['pages']), id);
    return [
      SectionTitle(
        'Phòng',
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            EvoButton(
              label: 'Thiết kế',
              icon: Icons.design_services_outlined,
              small: true,
              primary: true,
              onPressed: () => _openDesigner(),
            ),
            const SizedBox(width: 6),
            EvoButton(
              label: 'Xoá phòng',
              icon: Icons.delete_outline,
              small: true,
              danger: true,
              onPressed: () {
                _edit((d) => (d['pages'] as List).removeWhere((x) => x is Map && x['id'] == id));
                setState(() => selRoom = null);
                toast(context, 'Đã xoá phòng. Có thể hoàn tác (Ctrl+Z).');
              },
            ),
          ],
        ),
      ),
      FieldLabel(
        'Tên phòng',
        SyncedField(
          value: r['title'] as String? ?? '',
          onChanged: (v) => _edit((d) => room(d)?['title'] = v, key: 'rm:$id'),
        ),
      ),
      const SizedBox(height: 12),
      FieldLabel(
        'Thuộc tầng',
        EvoDropdown<String>(
          width: double.infinity,
          value: r['floorId'] as String? ?? '',
          items: [for (final f in floors) (f['id'] as String, f['title'] as String? ?? '')],
          onChanged: (v) => _edit((d) => room(d)?['floorId'] = v),
        ),
      ),
      const SizedBox(height: 18),
      SectionTitle(
        'Trang trong phòng',
        trailing: EvoButton(
          label: 'Thêm trang',
          icon: Icons.add,
          small: true,
          onPressed: () => _edit((d) => (room(d)?['subpages'] as List?)?.add(makeSub('Trang ${subs.length + 1}'))),
        ),
      ),
      for (var i = 0; i < subs.length; i++)
        Padding(
          key: ValueKey(subs[i]['id']),
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              Expanded(
                child: SyncedField(
                  value: subs[i]['title'] as String? ?? '',
                  onChanged: (v) => _edit((d) => _find(jsonList(room(d)?['subpages']), subs[i]['id'] as String)?['title'] = v, key: 'sub:${subs[i]['id']}'),
                ),
              ),
              const SizedBox(width: 6),
              Text('${jsonList(subs[i]['widgets']).length}', style: TextStyle(color: context.evo.muted, fontSize: 12.5)),
              if (subs.length > 1)
                IconButton(
                  tooltip: 'Xoá trang',
                  icon: Icon(Icons.close, size: 17, color: context.evo.muted),
                  onPressed: () => _edit((d) => (room(d)?['subpages'] as List?)?.removeWhere((x) => x is Map && x['id'] == subs[i]['id'])),
                ),
            ],
          ),
        ),
    ];
  }
}
