import 'package:flutter/material.dart';
import 'package:knx_config/knx_config.dart';

import '../../app/theme.dart';
import '../../state/project_controller.dart';
import '../common.dart';
import 'widget_views.dart';

/// Right-hand panel of the designer: widget properties, group address
/// bindings, per-type options, or subpage settings when nothing is selected.
class PropertiesPanel extends StatelessWidget {
  const PropertiesPanel({
    super.key,
    required this.project,
    required this.subId,
    required this.widgetId,
    required this.childId,
    required this.onSelect,
  });

  final ProjectController project;
  final String? subId;
  final String? widgetId;
  final String? childId;
  final void Function(String? widgetId, String? childId) onSelect;

  ProjectController get p => project;

  Json? _findSub(Json d) {
    for (final s in allSubpages(d)) {
      if (s['id'] == subId) return s;
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

  Json? _findChild(Json? w, String? id) {
    if (w == null || id == null || w['type'] != 'group') return null;
    for (final c in jsonList(w['widgets'])) {
      if (c['id'] == id) return c;
    }
    return null;
  }

  void _edit(void Function(Json sub, Json w) fn, {String? coalesce}) {
    p.mutate((d) {
      final sub = _findSub(d);
      final w = _findWidget(sub, widgetId);
      if (sub != null && w != null) fn(sub, w);
    }, coalesce: coalesce);
  }

  void _editChild(void Function(Json w, Json child) fn, {String? coalesce}) {
    p.mutate((d) {
      final sub = _findSub(d);
      final w = _findWidget(sub, widgetId);
      final ch = _findChild(w, childId);
      if (w != null && ch != null) fn(w, ch);
    }, coalesce: coalesce);
  }

  @override
  Widget build(BuildContext context) {
    final sub = _findSub(p.doc);
    if (sub == null) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          SectionTitle('Thuộc tính'),
          Text('Chọn một phòng và trang ở danh sách bên trái để bắt đầu thiết kế.', style: TextStyle(fontSize: 13.5)),
        ],
      );
    }
    final w = _findWidget(sub, widgetId);
    if (w == null) return _subSettings(context, sub);
    final child = _findChild(w, childId);
    if (child != null) return _childProps(context, sub, w, child);
    return _widgetProps(context, sub, w);
  }

  // ------------------------------------------------------------ subpage

  List<Widget> _subSettingsBody(BuildContext context, Json sub) {
    final c = context.evo;
    final l = jsonMap(sub['layout']);
    final cols = (l['columns'] as num?)?.toInt() ?? 4;
    final rows = (l['rows'] as num?)?.toInt() ?? 12;
    Widget stepper(String label, int value, int min, int max, void Function(int) set) => Row(
          children: [
            Expanded(child: Text(label, style: TextStyle(fontSize: 13.5, color: c.ink))),
            IconButton(
              visualDensity: VisualDensity.compact,
              onPressed: value <= min ? null : () => set(value - 1),
              icon: const Icon(Icons.remove_circle_outline, size: 19),
            ),
            Text('$value', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, fontFeatures: [])),
            IconButton(
              visualDensity: VisualDensity.compact,
              onPressed: value >= max ? null : () => set(value + 1),
              icon: const Icon(Icons.add_circle_outline, size: 19),
            ),
          ],
        );
    return [
      SectionTitle('Trang'),
      FieldLabel(
        'Tên trang',
        SyncedField(
          value: (sub['title'] as String?) ?? '',
          onChanged: (v) => p.mutate((d) {
            _findSub(d)?['title'] = v;
          }, coalesce: 'sub:${sub['id']}'),
        ),
      ),
      const SizedBox(height: 12),
      Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(border: Border.all(color: c.line), borderRadius: BorderRadius.circular(10)),
        child: Column(
          children: [
            stepper('Số cột lưới', cols, 2, 8, (v) => p.mutate((d) => _findSub(d)?['layout']['columns'] = v)),
            const SizedBox(height: 4),
            stepper('Số hàng lưới', rows, 4, 40, (v) => p.mutate((d) => _findSub(d)?['layout']['rows'] = v)),
          ],
        ),
      ),
      const SizedBox(height: 16),
      SectionTitle('Mẹo'),
      _tip(context, Icons.add_box_outlined, 'Bấm vào một thành phần trong thanh trái để thêm vào trang, hoặc kéo thả vào vị trí tuỳ ý.'),
      _tip(context, Icons.open_with, 'Kéo để di chuyển, kéo ô góc dưới phải để đổi kích thước. Phím mũi tên dịch từng ô.'),
      _tip(context, Icons.delete_outline, 'Chọn thành phần rồi bấm Delete để xoá, Ctrl+D để nhân bản.'),
      _tip(context, Icons.link, 'Gán địa chỉ nhóm cho từng chức năng ở phần “Liên kết” khi chọn một thành phần.'),
    ];
  }

  Widget _subSettings(BuildContext context, Json sub) {
    return ListView(padding: const EdgeInsets.all(16), children: _subSettingsBody(context, sub));
  }

  Widget _tip(BuildContext context, IconData icon, String text) {
    final c = context.evo;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: c.accent),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: TextStyle(fontSize: 12.5, color: c.muted, height: 1.4))),
        ],
      ),
    );
  }

  // ------------------------------------------------------------ widget props

  Widget _widgetProps(BuildContext context, Json sub, Json w) {
    final c = context.evo;
    final type = kWidgetTypes[w['type']];
    final missing = missingSlots(w);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(color: c.accentSoft, borderRadius: BorderRadius.circular(9)),
              child: Icon(evoIcon(type?.icon), size: 19, color: c.accentInk),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                type?.name ?? (w['type'] as String? ?? 'Thành phần'),
                style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600),
              ),
            ),
            IconButton(
              tooltip: 'Nhân bản (Ctrl+D)',
              onPressed: () => _duplicate(context, sub, w),
              icon: const Icon(Icons.copy_outlined, size: 19),
            ),
            IconButton(
              tooltip: 'Xoá thành phần',
              onPressed: () => _deleteWidget(context, sub, w),
              icon: Icon(Icons.delete_outline, size: 19, color: c.danger),
            ),
          ],
        ),
        const SizedBox(height: 14),
        SectionTitle('Chung'),
        FieldLabel(
          'Tên hiển thị',
          SyncedField(
            value: (w['label'] as String?) ?? '',
            onChanged: (v) => _edit((_, x) => x['label'] = v, coalesce: 'lbl:${w['id']}'),
          ),
        ),
        const SizedBox(height: 10),
        FieldLabel(
          'Biểu tượng',
          EvoDropdown<String>(
            width: double.infinity,
            value: (w['icon'] as String?) ?? '',
            items: [
              if (!kIconNames.contains(w['icon'])) ((w['icon'] as String?) ?? '', 'Hiện tại'),
              for (final name in kIconNames) (name, name),
            ],
            onChanged: (v) => _edit((_, x) => x['icon'] = v),
          ),
        ),
        const SizedBox(height: 10),
        FieldLabel(
          'Cỡ chữ tiêu đề',
          EvoDropdown<double>(
            width: double.infinity,
            value: (w['labelSize'] as num?)?.toDouble() ?? 13.5,
            items: const [
              (12.0, 'Nhỏ (12)'),
              (13.5, 'Vừa (13.5) — mặc định'),
              (15.0, 'Lớn (15)'),
              (17.0, 'To (17)'),
              (20.0, 'Rất to (20)'),
            ],
            onChanged: (v) => _edit((_, x) => x['labelSize'] = v),
          ),
        ),
        const SizedBox(height: 10),
        FieldLabel(
          'Cỡ biểu tượng',
          EvoDropdown<double>(
            width: double.infinity,
            value: (w['iconSize'] as num?)?.toDouble() ?? 17.0,
            items: const [
              (14.0, 'Nhỏ (14)'),
              (17.0, 'Vừa (17) — mặc định'),
              (20.0, 'Lớn (20)'),
              (24.0, 'To (24)'),
              (28.0, 'Rất to (28)'),
            ],
            onChanged: (v) => _edit((_, x) => x['iconSize'] = v),
          ),
        ),
        const SizedBox(height: 10),
        _sizeRow(context, sub, w),
        if (missing.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: c.dangerSoft, borderRadius: BorderRadius.circular(10)),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.warning_amber_outlined, size: 17, color: c.danger),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Thiếu địa chỉ nhóm bắt buộc: ${missing.map((s) => s.label).join(', ')}',
                    style: TextStyle(fontSize: 12.5, color: c.danger, height: 1.35),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 16),
        SectionTitle('Liên kết địa chỉ nhóm'),
        if (slotsFor(w).isEmpty)
          Text('Thành phần này không cần địa chỉ nhóm.', style: TextStyle(fontSize: 13, color: c.muted))
        else
          for (final slot in slotsFor(w)) _slotRow(context, w, slot),
        ..._typeOptions(context, sub, w),
      ],
    );
  }

  Widget _sizeRow(BuildContext context, Json sub, Json w) {
    final c = context.evo;
    final pos = jsonMap(w['pos']);
    final cols = (jsonMap(sub['layout'])['columns'] as num?)?.toInt() ?? 4;
    final kx = (pos['x'] as num?)?.toInt() ?? 0;
    final ky = (pos['y'] as num?)?.toInt() ?? 0;
    final kw = (pos['w'] as num?)?.toInt() ?? 1;
    final kh = (pos['h'] as num?)?.toInt() ?? 1;
    void setPos({int? x, int? y, int? ww, int? hh}) {
      final nx = x ?? kx, ny = y ?? ky, nw = ww ?? kw, nh = hh ?? kh;
      final okCols = nx >= 0 && ny >= 0 && nx + nw <= cols;
      if (!okCols || !isFree(sub, nx, ny, nw, nh, w['id'] as String)) return;
      _edit((_, t) {
        final pp = jsonMap(t['pos']);
        pp['x'] = nx;
        pp['y'] = ny;
        pp['w'] = nw;
        pp['h'] = nh;
      });
    }

    Widget cell(String label, String value, VoidCallback? minus, VoidCallback? plus) => Column(
          children: [
            Text(label, style: TextStyle(fontSize: 11.5, color: c.muted)),
            const SizedBox(height: 3),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _miniIconBtn(minus, Icons.remove, 'Giảm $label'),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    child: Text(value, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                  ),
                  _miniIconBtn(plus, Icons.add, 'Tăng $label'),
                ],
              ),
            ),
          ],
        );
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(border: Border.all(color: c.line), borderRadius: BorderRadius.circular(10)),
      child: Row(
        children: [
          Expanded(child: cell('X', '$kx', () => setPos(x: kx - 1), () => setPos(x: kx + 1))),
          Expanded(child: cell('Y', '$ky', () => setPos(y: ky - 1), () => setPos(y: ky + 1))),
          Expanded(child: cell('Rộng', '$kw', () => setPos(ww: kw - 1), () => setPos(ww: kw + 1))),
          Expanded(child: cell('Cao', '$kh', () => setPos(hh: kh - 1), () => setPos(hh: kh + 1))),
        ],
      ),
    );
  }

  Widget _miniIconBtn(VoidCallback? onPressed, IconData icon, String tooltip) => IconButton(
        visualDensity: VisualDensity.compact,
        onPressed: onPressed,
        icon: Icon(icon, size: 15),
        tooltip: tooltip,
        constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
        padding: EdgeInsets.zero,
      );

  Widget _slotRow(BuildContext context, Json w, SlotDef slot) {
    final c = context.evo;
    final bind = jsonMap(w['bind']);
    final boundId = bind[slot.key] as String?;
    final ga = p.gaById(boundId);
    final sorted = [...p.groupAddresses]..sort((a, b) => gaSortKey(a['address'] as String).compareTo(gaSortKey(b['address'] as String)));
    final candidates = sorted.where((g) => g['id'] == boundId || slotAccepts(slot, g)).toList();
    final has = candidates.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: FieldLabel(
              '${slot.label}${slot.required ? ' *' : (slot.recommended ? ' (nên gán)' : '')}',
              EvoDropdown<String>(
                width: double.infinity,
                warn: boundId == null && slot.required,
                value: boundId ?? '',
                items: [
                  ('', boundId == null ? (slot.required ? 'Chưa gán địa chỉ' : 'Không gán') : '— gỡ liên kết —'),
                  if (boundId != null && ga == null) (boundId, 'Đã xoá khỏi dự án'),
                  for (final g in candidates) (g['id'] as String, _gaLabel(g)),
                ],
                onChanged: has || boundId != null
                    ? (v) => _edit((_, x) {
                          final b = jsonMap(x['bind']);
                          if (v.isEmpty) {
                            b.remove(slot.key);
                          } else {
                            b[slot.key] = v;
                          }
                          x['bind'] = b;
                        })
                    : null,
              ),
            ),
          ),
          if (ga != null) ...[
            const SizedBox(width: 6),
            Padding(
              padding: const EdgeInsets.only(top: 18),
              child: Text((ga['dpt'] as String?) == '' ? 'Không DPT' : 'DPT ${ga['dpt']}', style: TextStyle(fontSize: 11, color: c.muted)),
            ),
          ],
        ],
      ),
    );
  }

  // ------------------------------------------------------------ child props

  Widget _childProps(BuildContext context, Json sub, Json group, Json child) {
    final c = context.evo;
    final type = kWidgetTypes[child['type']];
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            IconButton(
              tooltip: 'Về khung cha',
              onPressed: () => onSelect(widgetId, null),
              icon: const Icon(Icons.arrow_back, size: 19),
            ),
            const SizedBox(width: 4),
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(color: c.accentSoft, borderRadius: BorderRadius.circular(9)),
              child: Icon(evoIcon(type?.icon), size: 19, color: c.accentInk),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(type?.name ?? '', style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600))),
            IconButton(
              tooltip: 'Xoá thành phần con',
              onPressed: () {
                p.mutate((d) {
                  final sub2 = _findSub(d);
                  final g = _findWidget(sub2, widgetId);
                  (g?['widgets'] as List?)?.removeWhere((x) => x is Map && x['id'] == child['id']);
                });
                onSelect(widgetId, null);
              },
              icon: Icon(Icons.delete_outline, size: 19, color: c.danger),
            ),
          ],
        ),
        const SizedBox(height: 14),
        SectionTitle('Chung'),
        FieldLabel(
          'Tên hiển thị',
          SyncedField(
            value: (child['label'] as String?) ?? '',
            onChanged: (v) => _editChild((_, ch) => ch['label'] = v, coalesce: 'clbl:${child['id']}'),
          ),
        ),
        const SizedBox(height: 10),
        FieldLabel(
          'Biểu tượng',
          EvoDropdown<String>(
            width: double.infinity,
            value: (child['icon'] as String?) ?? '',
            items: [
              if (!kIconNames.contains(child['icon'])) ((child['icon'] as String?) ?? '', 'Hiện tại'),
              for (final name in kIconNames) (name, name),
            ],
            onChanged: (v) => _editChild((_, ch) => ch['icon'] = v),
          ),
        ),
        const SizedBox(height: 10),
        FieldLabel(
          'Cỡ chữ tiêu đề',
          EvoDropdown<double>(
            width: double.infinity,
            value: (child['labelSize'] as num?)?.toDouble() ?? 13.5,
            items: const [
              (12.0, 'Nhỏ (12)'),
              (13.5, 'Vừa (13.5) — mặc định'),
              (15.0, 'Lớn (15)'),
              (17.0, 'To (17)'),
              (20.0, 'Rất to (20)'),
            ],
            onChanged: (v) => _editChild((_, ch) => ch['labelSize'] = v),
          ),
        ),
        const SizedBox(height: 10),
        FieldLabel(
          'Cỡ biểu tượng',
          EvoDropdown<double>(
            width: double.infinity,
            value: (child['iconSize'] as num?)?.toDouble() ?? 17.0,
            items: const [
              (14.0, 'Nhỏ (14)'),
              (17.0, 'Vừa (17) — mặc định'),
              (20.0, 'Lớn (20)'),
              (24.0, 'To (24)'),
              (28.0, 'Rất to (28)'),
            ],
            onChanged: (v) => _editChild((_, ch) => ch['iconSize'] = v),
          ),
        ),
        const SizedBox(height: 16),
        SectionTitle('Liên kết địa chỉ nhóm'),
        if (slotsFor(child).isEmpty)
          Text('Thành phần này không cần địa chỉ nhóm.', style: TextStyle(fontSize: 13, color: c.muted))
        else
          for (final slot in slotsFor(child)) _childSlotRow(context, group, child, slot),
        if (child['type'] == 'switch' || child['type'] == 'dimmer') ..._childStyleOptions(child),
        if (child['type'] == 'button')
          FieldLabel(
            'Giá trị gửi khi bấm',
            SyncedField(
              value: '${child['sendValue'] ?? '1'}',
              onChanged: (v) => _editChild((_, ch) => ch['sendValue'] = v),
            ),
          ),
        if (child['type'] == 'scene')
          FieldLabel(
            'Số cảnh',
            SyncedField(
              value: '${child['sceneNumber'] ?? 1}',
              number: true,
              onChanged: (v) => _editChild((_, ch) => ch['sceneNumber'] = int.tryParse(v) ?? 1),
            ),
          ),
        if (child['type'] == 'value') ..._childValueFormat(child),
      ],
    );
  }

  List<Widget> _childStyleOptions(Json child) {
    final st = jsonMap(child['style']);
    Widget colorField(String key, String label) => FieldLabel(
          label,
          _colorPicker(
            (st[key] as String?) ?? '',
            (hex) => _editChild((_, ch) {
              final s = jsonMap(ch['style']);
              s[key] = hex;
              ch['style'] = s;
            }, coalesce: 'ccol:${child['id']}:$key'),
          ),
        );
    return [
      const SizedBox(height: 16),
      SectionTitle('Kiểu hiển thị'),
      colorField('colorOn', 'Màu khi bật'),
      const SizedBox(height: 10),
      colorField('colorOff', 'Màu khi tắt'),
    ];
  }

  List<Widget> _childValueFormat(Json child) {
    final fmt = jsonMap(child['format']);
    void setFmt(String key, dynamic v) => _editChild((_, ch) {
          final f = jsonMap(ch['format']);
          f[key] = v;
          ch['format'] = f;
        }, coalesce: 'cfmt:${child['id']}:$key');
    return [
      const SizedBox(height: 16),
      SectionTitle('Định dạng giá trị'),
      Row(
        children: [
          Expanded(
            child: FieldLabel(
              'Đơn vị',
              SyncedField(value: (fmt['unit'] as String?) ?? '', onChanged: (v) => setFmt('unit', v)),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: FieldLabel(
              'Số thập phân',
              SyncedField(
                value: '${fmt['decimals'] ?? 1}',
                number: true,
                onChanged: (v) => setFmt('decimals', int.tryParse(v) ?? 1),
              ),
            ),
          ),
        ],
      ),
    ];
  }

  Widget _childSlotRow(BuildContext context, Json group, Json child, SlotDef slot) {
    final bind = jsonMap(child['bind']);
    final boundId = bind[slot.key] as String?;
    final ga = p.gaById(boundId);
    final sorted = [...p.groupAddresses]..sort((a, b) => gaSortKey(a['address'] as String).compareTo(gaSortKey(b['address'] as String)));
    final candidates = sorted.where((g) => g['id'] == boundId || slotAccepts(slot, g)).toList();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: FieldLabel(
        '${slot.label}${slot.required ? ' *' : ''}',
        EvoDropdown<String>(
          width: double.infinity,
          warn: boundId == null && slot.required,
          value: boundId ?? '',
          items: [
            ('', boundId == null ? (slot.required ? 'Chưa gán địa chỉ' : 'Không gán') : '— gỡ liên kết —'),
            if (boundId != null && ga == null) (boundId, 'Đã xoá khỏi dự án'),
            for (final g in candidates) (g['id'] as String, _gaLabel(g)),
          ],
          onChanged: (v) => _editChild((_, ch) {
            final b = jsonMap(ch['bind']);
            if (v.isEmpty) {
              b.remove(slot.key);
            } else {
              b[slot.key] = v;
            }
            ch['bind'] = b;
          }),
        ),
      ),
    );
  }

  // ------------------------------------------------------------ per-type options

  List<Widget> _typeOptions(BuildContext context, Json sub, Json w) {
    switch (w['type']) {
      case 'switch':
      case 'dimmer':
        return [..._styleOptions(w), if (w['type'] == 'dimmer') ..._dimmerOptions(w)];
      case 'value':
        return [..._valueFormat(w)];
      case 'button':
        return _buttonOptions(w);
      case 'scene':
        return _sceneOptions(w);
      case 'link':
        return _linkOptions(w);
      case 'webview':
        return _webviewOptions(w);
      case 'shutter':
        return _shutterOptions(w);
      case 'ac':
        return _acOptions(context, w);
      case 'group':
        return _groupOptions(context, sub, w);
      default:
        return [];
    }
  }

  List<Widget> _styleOptions(Json w) {
    final st = jsonMap(w['style']);
    Widget colorField(String key, String label) => FieldLabel(
          label,
          _colorPicker(
            (st[key] as String?) ?? '',
            (hex) => _edit((_, x) {
              final s = jsonMap(x['style']);
              s[key] = hex;
              x['style'] = s;
            }, coalesce: 'col:${w['id']}:$key'),
          ),
        );
    return [
      const SizedBox(height: 16),
      SectionTitle('Kiểu hiển thị'),
      colorField('colorOn', 'Màu khi bật'),
      const SizedBox(height: 10),
      colorField('colorOff', 'Màu khi tắt'),
      const SizedBox(height: 10),
      Row(
        children: [
          Expanded(
            child: FieldLabel(
              'Chữ khi bật',
              SyncedField(
                value: (st['textOn'] as String?) ?? '',
                onChanged: (v) => _edit((_, x) {
                  final s = jsonMap(x['style']);
                  s['textOn'] = v;
                  x['style'] = s;
                }, coalesce: 'ton:${w['id']}'),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: FieldLabel(
              'Chữ khi tắt',
              SyncedField(
                value: (st['textOff'] as String?) ?? '',
                onChanged: (v) => _edit((_, x) {
                  final s = jsonMap(x['style']);
                  s['textOff'] = v;
                  x['style'] = s;
                }, coalesce: 'toff:${w['id']}'),
              ),
            ),
          ),
        ],
      ),
    ];
  }

  List<Widget> _dimmerOptions(Json w) {
    final f = jsonMap(w['features']);
    final tw = jsonMap(w['tw']);
    void setFeature(String key, bool v) => _edit((_, x) {
          final ff = jsonMap(x['features']);
          ff[key] = v;
          x['features'] = ff;
        });
    return [
      const SizedBox(height: 16),
      SectionTitle('Tuỳ chọn đèn dim'),
      CheckboxListTile(
        value: f['tw'] == true,
        contentPadding: EdgeInsets.zero,
        dense: true,
        controlAffinity: ListTileControlAffinity.leading,
        title: const Text('Có nhiệt độ màu (2700–6500K)'),
        onChanged: (v) => setFeature('tw', v ?? false),
      ),
      if (f['tw'] == true)
        Row(
          children: [
            Expanded(
              child: FieldLabel(
                'K thấp nhất',
                SyncedField(
                  value: '${tw['min'] ?? 2700}',
                  number: true,
                  onChanged: (v) => _edit((_, x) {
                    final t = jsonMap(x['tw']);
                    t['min'] = int.tryParse(v) ?? 2700;
                    x['tw'] = t;
                  }, coalesce: 'twmin:${w['id']}'),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FieldLabel(
                'K cao nhất',
                SyncedField(
                  value: '${tw['max'] ?? 6500}',
                  number: true,
                  onChanged: (v) => _edit((_, x) {
                    final t = jsonMap(x['tw']);
                    t['max'] = int.tryParse(v) ?? 6500;
                    x['tw'] = t;
                  }, coalesce: 'twmax:${w['id']}'),
                ),
              ),
            ),
          ],
        ),
      CheckboxListTile(
        value: f['rgb'] == true,
        contentPadding: EdgeInsets.zero,
        dense: true,
        controlAffinity: ListTileControlAffinity.leading,
        title: const Text('Có màu RGB (DPT 232/251)'),
        onChanged: (v) => setFeature('rgb', v ?? false),
      ),
    ];
  }

  List<Widget> _valueFormat(Json w) {
    final fmt = jsonMap(w['format']);
    void setFmt(String key, dynamic v) => _edit((_, x) {
          final f = jsonMap(x['format']);
          f[key] = v;
          x['format'] = f;
        }, coalesce: 'fmt:${w['id']}:$key');
    return [
      const SizedBox(height: 16),
      SectionTitle('Định dạng giá trị'),
      Row(
        children: [
          Expanded(
            child: FieldLabel(
              'Đơn vị',
              SyncedField(value: (fmt['unit'] as String?) ?? '', onChanged: (v) => setFmt('unit', v)),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: FieldLabel(
              'Số thập phân',
              SyncedField(
                value: '${fmt['decimals'] ?? 1}',
                number: true,
                onChanged: (v) => setFmt('decimals', int.tryParse(v) ?? 1),
              ),
            ),
          ),
        ],
      ),
    ];
  }

  List<Widget> _buttonOptions(Json w) {
    return [
      const SizedBox(height: 16),
      SectionTitle('Tuỳ chọn nút nhấn'),
      FieldLabel(
        'Giá trị gửi khi bấm (theo DPT)',
        SyncedField(
          value: '${w['sendValue'] ?? '1'}',
          onChanged: (v) => _edit((_, x) => x['sendValue'] = v, coalesce: 'send:${w['id']}'),
        ),
      ),
    ];
  }

  List<Widget> _sceneOptions(Json w) {
    return [
      const SizedBox(height: 16),
      SectionTitle('Tuỳ chọn cảnh'),
      FieldLabel(
        'Số cảnh (scene number)',
        SyncedField(
          value: '${w['sceneNumber'] ?? 1}',
          number: true,
          onChanged: (v) => _edit((_, x) => x['sceneNumber'] = int.tryParse(v) ?? 1, coalesce: 'scn:${w['id']}'),
        ),
      ),
    ];
  }

  List<Widget> _linkOptions(Json w) {
    return [
      const SizedBox(height: 16),
      SectionTitle('Tuỳ chọn liên kết'),
      FieldLabel(
        'Địa chỉ URL',
        SyncedField(
          value: (w['url'] as String?) ?? '',
          hint: 'https://evohome.vn',
          onChanged: (v) => _edit((_, x) => x['url'] = v, coalesce: 'url:${w['id']}'),
        ),
      ),
      const SizedBox(height: 10),
      FieldLabel(
        'Mở bằng',
        EvoDropdown<String>(
          width: double.infinity,
          value: (w['openIn'] as String?) ?? 'inApp',
          items: const [('inApp', 'Trong app'), ('external', 'Trình duyệt ngoài')],
          onChanged: (v) => _edit((_, x) => x['openIn'] = v),
        ),
      ),
    ];
  }

  List<Widget> _webviewOptions(Json w) {
    final web = jsonMap(w['web']);
    void setWeb(String key, dynamic v) => _edit((_, x) {
          final ww = jsonMap(x['web']);
          ww[key] = v;
          x['web'] = ww;
        }, coalesce: 'web:${w['id']}:$key');
    return [
      const SizedBox(height: 16),
      SectionTitle('Tuỳ chọn trang web'),
      FieldLabel(
        'Địa chỉ URL',
        SyncedField(
          value: (w['url'] as String?) ?? '',
          hint: 'https://camera.local',
          onChanged: (v) => _edit((_, x) => x['url'] = v, coalesce: 'wurl:${w['id']}'),
        ),
      ),
      CheckboxListTile(
        value: web['showHeader'] != false,
        contentPadding: EdgeInsets.zero,
        dense: true,
        controlAffinity: ListTileControlAffinity.leading,
        title: const Text('Hiện thanh địa chỉ'),
        onChanged: (v) => setWeb('showHeader', v ?? true),
      ),
      CheckboxListTile(
        value: web['interactive'] == true,
        contentPadding: EdgeInsets.zero,
        dense: true,
        controlAffinity: ListTileControlAffinity.leading,
        title: const Text('Cho phép tương tác'),
        onChanged: (v) => setWeb('interactive', v ?? false),
      ),
      CheckboxListTile(
        value: web['fullscreen'] != false,
        contentPadding: EdgeInsets.zero,
        dense: true,
        controlAffinity: ListTileControlAffinity.leading,
        title: const Text('Cho phép toàn màn hình'),
        onChanged: (v) => setWeb('fullscreen', v ?? true),
      ),
    ];
  }

  List<Widget> _shutterOptions(Json w) {
    return [
      const SizedBox(height: 16),
      SectionTitle('Tuỳ chọn rèm'),
      FieldLabel(
        'Kiểu điều khiển',
        EvoDropdown<String>(
          width: double.infinity,
          value: (w['shCtrl'] ?? 'buttons') as String,
          items: const [('buttons', 'Nút lên / dừng / xuống'), ('slider', 'Thanh trượt vị trí')],
          onChanged: (v) => _edit((_, x) => x['shCtrl'] = v),
        ),
      ),
      const SizedBox(height: 10),
      FieldLabel(
        'Kiểu thiết bị',
        EvoDropdown<String>(
          width: double.infinity,
          value: (w['shStyle'] ?? 'shutter') as String,
          items: const [('shutter', 'Rèm cửa'), ('curtain', 'Bình phong / màn curtain')],
          onChanged: (v) => _edit((_, x) => x['shStyle'] = v),
        ),
      ),
      CheckboxListTile(
        value: w['showStop'] != false,
        contentPadding: EdgeInsets.zero,
        dense: true,
        controlAffinity: ListTileControlAffinity.leading,
        title: const Text('Hiện nút dừng'),
        onChanged: (v) => _edit((_, x) => x['showStop'] = v ?? true),
      ),
    ];
  }

  List<Widget> _acOptions(BuildContext context, Json w) {
    final ac = jsonMap(w['ac']);
    final modes = jsonMap(ac['modes']);
    final names = jsonMap(ac['names']);
    final values = jsonMap(ac['values']);
    void setAc(String key, dynamic v) => _edit((_, x) {
          final a = jsonMap(x['ac']);
          a[key] = v;
          x['ac'] = a;
        }, coalesce: 'ac:${w['id']}:$key');
    void setMode(String key, {bool? on, int? value}) => _edit((_, x) {
          final a = jsonMap(x['ac']);
          final m = jsonMap(a['modes']);
          final vals = jsonMap(a['values']);
          if (on != null) m[key] = on;
          if (value != null) vals[key] = value;
          a['modes'] = m;
          a['values'] = vals;
          x['ac'] = a;
        }, coalesce: 'acm:${w['id']}:$key');
    return [
      const SizedBox(height: 16),
      SectionTitle('Tuỳ chọn máy lạnh'),
      Row(
        children: [
          Expanded(
            child: FieldLabel(
              'Nhiệt độ thấp nhất',
              SyncedField(
                value: '${ac['min'] ?? 16}',
                number: true,
                onChanged: (v) => setAc('min', num.tryParse(v) ?? 16),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: FieldLabel(
              'Cao nhất',
              SyncedField(
                value: '${ac['max'] ?? 30}',
                number: true,
                onChanged: (v) => setAc('max', num.tryParse(v) ?? 30),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: FieldLabel(
              'Bước nhảy',
              SyncedField(
                value: '${ac['step'] ?? 0.5}',
                number: true,
                onChanged: (v) => setAc('step', num.tryParse(v.replaceAll(',', '.')) ?? 0.5),
              ),
            ),
          ),
        ],
      ),
      CheckboxListTile(
        value: ac['showCur'] != false,
        contentPadding: EdgeInsets.zero,
        dense: true,
        controlAffinity: ListTileControlAffinity.leading,
        title: const Text('Hiện nhiệt độ phòng'),
        onChanged: (v) => setAc('showCur', v ?? true),
      ),
      FieldLabel(
        'Địa chỉ chế độ',
        EvoDropdown<String>(
          width: double.infinity,
          value: (ac['modeAddr'] ?? 'single') as String,
          items: const [('single', 'Một địa chỉ chung (DPT 20.102)'), ('separate', 'Địa chỉ riêng cho từng chế độ')],
          onChanged: (v) => setAc('modeAddr', v),
        ),
      ),
      const SizedBox(height: 8),
      Text('Chế độ cho phép', style: TextStyle(fontSize: 12.5, color: context.evo.muted)),
      for (final m in kAcModes)
        Row(
          children: [
            Expanded(
              child: CheckboxListTile(
                value: modes.containsKey(m.key) ? modes[m.key] == true : m.key != 'heat',
                dense: true,
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
                title: Text(m.name, style: const TextStyle(fontSize: 13.5)),
                onChanged: (v) => setMode(m.key, on: v ?? false),
              ),
            ),
            SizedBox(
              width: 64,
              child: SyncedField(
                value: '${values[m.key] ?? m.value}',
                number: true,
                onChanged: (v) => setMode(m.key, value: int.tryParse(v) ?? m.value),
              ),
            ),
          ],
        ),
      const SizedBox(height: 8),
      FieldLabel(
        'Tên chế độ hiển thị (tuỳ chọn)',
        SyncedField(
          value: (names['cool'] as String?) ?? '',
          hint: 'Ví dụ: Làm lạnh',
          onChanged: (v) => _edit((_, x) {
            final a = jsonMap(x['ac']);
            final n = jsonMap(a['names']);
            n['cool'] = v;
            a['names'] = n;
            x['ac'] = a;
          }, coalesce: 'acn:${w['id']}'),
        ),
      ),
    ];
  }

  List<Widget> _groupOptions(BuildContext context, Json sub, Json w) {
    final l = jsonMap(w['layout']);
    final children = jsonList(w['widgets']);
    final cols = (l['columns'] as num?)?.toInt() ?? 4;
    void setL(String key, int v) => _edit((_, x) {
          final ll = jsonMap(x['layout']);
          ll[key] = v;
          x['layout'] = ll;
        }, coalesce: 'gl:${w['id']}:$key');
    return [
      const SizedBox(height: 16),
      SectionTitle('Khung lưới'),
      CheckboxListTile(
        value: w['showTitle'] != false,
        contentPadding: EdgeInsets.zero,
        dense: true,
        controlAffinity: ListTileControlAffinity.leading,
        title: const Text('Hiện tiêu đề khung'),
        onChanged: (v) => _edit((_, x) => x['showTitle'] = v ?? true),
      ),
      Row(
        children: [
          Expanded(
            child: FieldLabel(
              'Kiểu nền',
              EvoDropdown<String>(
                width: double.infinity,
                value: (w['gstyle'] ?? 'card') as String,
                items: const [('card', 'Thẻ có viền'), ('plain', 'Không nền')],
                onChanged: (v) => _edit((_, x) => x['gstyle'] = v),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: FieldLabel(
              'Cột con',
              SyncedField(
                value: '$cols',
                number: true,
                onChanged: (v) => setL('columns', v.isEmpty ? 4 : int.parse(v).clamp(1, 8)),
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 14),
      _AddChildRow(
        count: children.length,
        onAdd: (addType) {
          final box = <String, dynamic>{'layout': w['layout'], 'widgets': w['widgets']};
          final spot = findFree(box, kWidgetTypes[addType]!.w, kWidgetTypes[addType]!.h);
          String? newId;
          p.mutate((d) {
            final sub2 = _findSub(d);
            final g = _findWidget(sub2, widgetId);
            if (g == null) return;
            final ch = makeWidget(addType, spot.x, spot.y);
            newId = ch['id'] as String;
            (g['widgets'] as List).add(ch);
          });
          if (newId != null) onSelect(widgetId, newId);
        },
      ),
      const SizedBox(height: 8),
      for (final ch in children)
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => onSelect(widgetId, ch['id'] as String),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(border: Border.all(color: context.evo.line), borderRadius: BorderRadius.circular(8)),
              child: Row(
                children: [
                  Icon(evoIcon(ch['icon']), size: 16, color: context.evo.muted),
                  const SizedBox(width: 8),
                  Expanded(child: Text((ch['label'] as String?) ?? '', overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13))),
                  Text('${kWidgetTypes[ch['type']]?.name ?? ch['type']}', style: TextStyle(fontSize: 11.5, color: context.evo.muted)),
                  const SizedBox(width: 6),
                  BindDot(bind: jsonMap(ch['bind']), w: ch, size: 8),
                ],
              ),
            ),
          ),
        ),
    ];
  }

  // ------------------------------------------------------------ actions

  void _deleteWidget(BuildContext context, Json sub, Json w) {
    p.mutate((d) {
      final sub2 = _findSub(d);
      (sub2?['widgets'] as List?)?.removeWhere((x) => x is Map && x['id'] == w['id']);
    });
    onSelect(null, null);
    toast(context, 'Đã xoá thành phần. Có thể hoàn tác (Ctrl+Z).');
  }

  void _duplicate(BuildContext context, Json sub, Json w) {
    final copy = Json.from(_deepCopyWidget(w) as Map);
    copy['id'] = uid('w_');
    final spot = findFree(sub, (jsonMap(w['pos'])['w'] as num?)?.toInt() ?? 2, (jsonMap(w['pos'])['h'] as num?)?.toInt() ?? 2);
    final pos = jsonMap(copy['pos']);
    pos['x'] = spot.x;
    pos['y'] = spot.y;
    String? newId;
    p.mutate((d) {
      final sub2 = _findSub(d);
      (sub2?['widgets'] as List?)?.add(copy);
      newId = copy['id'] as String;
    });
    if (newId != null) onSelect(newId, null);
  }
}

/// '1/1/1  · Tên  · DPT 1.001' label for a group address.
String _gaLabel(Json g) {
  final name = (g['name'] as String?) ?? '';
  final dpt = (g['dpt'] as String?) ?? '';
  final extra = name.isNotEmpty ? name : (dpt.isNotEmpty ? dpt : '');
  return extra.isEmpty ? '${g['address']}' : '${g['address']}  ·  $extra';
}

/// Type picker + add button for group children (owns its own state).
class _AddChildRow extends StatefulWidget {
  const _AddChildRow({required this.count, required this.onAdd});
  final int count;
  final ValueChanged<String> onAdd;
  @override
  State<_AddChildRow> createState() => _AddChildRowState();
}

class _AddChildRowState extends State<_AddChildRow> {
  String type = 'switch';
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: SectionTitle(
            'Thành phần con (${widget.count})',
            trailing: EvoDropdown<String>(
              width: 150,
              value: type,
              items: [
                for (final t in kWidgetTypes.values)
                  if (t.type != 'group' && t.type != 'webview') (t.type, t.name),
              ],
              onChanged: (v) => setState(() => type = v),
            ),
          ),
        ),
        const SizedBox(width: 8),
        EvoButton(
          label: 'Thêm',
          icon: Icons.add,
          small: true,
          onPressed: () => widget.onAdd(type),
        ),
      ],
    );
  }
}

/// Deep-copies widget JSON for duplication (kept local to avoid exporting
/// the private helper in knx_config).
Object? _deepCopyWidget(Object? v) {
  if (v is Map) return v.map((k, e) => MapEntry(k.toString(), _deepCopyWidget(e)));
  if (v is List) return v.map(_deepCopyWidget).toList();
  return v;
}

// ------------------------------------------------------------- shared bits

/// Green/red status dot showing whether all required slots are bound.
class BindDot extends StatelessWidget {
  const BindDot({super.key, required this.bind, required this.w, this.size = 9});
  final Json bind;
  final Json w;
  final double size;

  @override
  Widget build(BuildContext context) {
    final required = slotsFor(w).where((s) => s.required).toList();
    if (required.isEmpty) return const SizedBox.shrink();
    final ok = required.every((s) => (bind[s.key] as String?)?.isNotEmpty == true);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: ok ? const Color(0xFF2FA36B) : const Color(0xFFD9463B),
      ),
    );
  }
}

List<SlotDef> missingSlots(Json w) {
  final bind = jsonMap(w['bind']);
  return slotsFor(w).where((s) => s.required && (bind[s.key] as String?)?.isNotEmpty != true).toList();
}

/// Colour swatch row + custom hex entry.
class _colorPicker extends StatelessWidget {
  const _colorPicker(this.value, this.onChanged);
  final String value;
  final ValueChanged<String> onChanged;

  static const List<String> _presets = [
    '#EE9B2A', '#1E7F57', '#2E62B0', '#7C4DFF', '#D9463B', '#0F8A8A',
    '#C2410C', '#8A938F', '#1B2320',
  ];

  @override
  Widget build(BuildContext context) {
    final c = context.evo;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(color: c.panel, border: Border.all(color: c.line), borderRadius: BorderRadius.circular(8)),
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: parseHexColor(value, const Color(0xFFEE9B2A)),
              shape: BoxShape.circle,
              border: Border.all(color: c.lineStrong),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Wrap(
              spacing: 5,
              runSpacing: 5,
              children: [
                for (final hex in _presets)
                  InkWell(
                    onTap: () => onChanged(hex),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: parseHexColor(hex, c.panel),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: value.toLowerCase() == hex.toLowerCase() ? c.ink : c.lineStrong,
                          width: value.toLowerCase() == hex.toLowerCase() ? 2 : 1,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(
            width: 86,
            child: SyncedField(
              value: value,
              hint: '#RRGGBB',
              onChanged: (v) {
                final h = v.trim();
                if (RegExp(r'^#?[0-9a-fA-F]{6}$').hasMatch(h)) {
                  onChanged(h.startsWith('#') ? h : '#$h');
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}
