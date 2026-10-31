import 'package:flutter/material.dart';
import 'package:knx_config/knx_config.dart';

import '../../app/theme.dart';

// ------------------------------------------------------------- icon helpers

/// Maps EVOKNX icon names (same names as the web editor) to Material icons.
IconData evoIcon(String? name, [IconData fallback = Icons.crop_square_outlined]) {
  return _icons[name] ?? fallback;
}

const Map<String, IconData> _icons = {
  'bulb': Icons.lightbulb_outline,
  'sun': Icons.wb_sunny_outlined,
  'thermo': Icons.thermostat_outlined,
  'button': Icons.touch_app_outlined,
  'blind': Icons.blinds_outlined,
  'star': Icons.star_border,
  'link': Icons.link,
  'globe': Icons.public,
  'snow': Icons.ac_unit,
  'layout': Icons.grid_view_outlined,
  'sofa': Icons.weekend_outlined,
  'stairs': Icons.stairs_outlined,
  'home': Icons.home_outlined,
  'bed': Icons.bed_outlined,
  'bath': Icons.bathtub_outlined,
  'kitchen': Icons.countertops_outlined,
  'door': Icons.door_sliding_outlined,
  'lamp': Icons.light_mode_outlined,
  'tv': Icons.tv_outlined,
  'lock': Icons.lock_outline,
  'cam': Icons.videocam_outlined,
  'speaker': Icons.speaker_outlined,
  'plant': Icons.park_outlined,
  'garage': Icons.garage_outlined,
  'pool': Icons.pool_outlined,
  'acauto': Icons.auto_awesome_outlined,
  'flame': Icons.local_fire_department_outlined,
  'fan': Icons.air,
  'drop': Icons.water_drop_outlined,
};

/// List of icon names offered in the properties panel.
const List<String> kIconNames = [
  'bulb', 'sun', 'thermo', 'button', 'blind', 'star', 'link', 'globe', 'snow',
  'layout', 'sofa', 'stairs', 'home', 'bed', 'bath', 'kitchen', 'door', 'lamp',
  'tv', 'lock', 'cam', 'speaker', 'plant', 'garage', 'pool', 'acauto', 'flame',
  'fan', 'drop',
];

/// Parses '#RRGGBB' (web format) into a [Color].
Color parseHexColor(String? hex, Color fallback) {
  if (hex is! String) return fallback;
  var h = hex.replaceFirst('#', '').trim();
  if (h.length == 6) h = 'FF$h';
  final v = int.tryParse(h, radix: 16);
  return v == null ? fallback : Color(v);
}

// ------------------------------------------------------------- previews

/// Renders a widget exactly like the mobile app would show it, scaled to fit
/// the box the caller gives it. Everything is drawn on a fixed design grid
/// (80 px per cell) and then scaled, so any widget size renders cleanly.
Widget widgetPreview(BuildContext context, Json w, {int depth = 0}) {
  final t = kWidgetTypes[w['type']];
  final dw = ((jsonMap(w['pos'])['w'] as num?)?.toInt() ?? t?.w ?? 2) * 80.0;
  final dh = ((jsonMap(w['pos'])['h'] as num?)?.toInt() ?? t?.h ?? 2) * 80.0;
  return FittedBox(
    fit: BoxFit.contain,
    child: SizedBox(width: dw, height: dh, child: _preview(context, w, depth)),
  );
}

Widget _preview(BuildContext context, Json w, int depth) {
  switch (w['type']) {
    case 'switch':
      return _switchView(context, w);
    case 'dimmer':
      return _dimmerView(context, w);
    case 'value':
      return _valueView(context, w);
    case 'button':
      return _buttonView(context, w);
    case 'shutter':
      return _shutterView(context, w);
    case 'scene':
      return _sceneView(context, w);
    case 'link':
      return _linkView(context, w);
    case 'webview':
      return _webviewView(context, w);
    case 'ac':
      return _acView(context, w);
    case 'group':
      return _groupView(context, w, depth);
    default:
      return _card(
        context,
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(evoIcon(w['icon']), size: 30, color: context.evo.muted),
            const SizedBox(height: 6),
            Text((w['label'] as String?) ?? '', style: const TextStyle(fontSize: 13), textAlign: TextAlign.center),
          ],
        ),
      );
  }
}

Widget _card(BuildContext context, Widget child, {EdgeInsets padding = const EdgeInsets.all(10)}) {
  final c = context.evo;
  return Container(
    decoration: BoxDecoration(
      color: c.panel,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: c.line),
    ),
    padding: padding,
    child: child,
  );
}

Widget _head(BuildContext context, Json w, {Color? color}) {
  final c = context.evo;
  return Row(
    children: [
      Icon(evoIcon(w['icon']), size: 17, color: color ?? c.muted),
      const SizedBox(width: 6),
      Expanded(
        child: Text(
          (w['label'] as String?) ?? '',
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: c.ink),
        ),
      ),
    ],
  );
}

Widget _switchView(BuildContext context, Json w) {
  final st = jsonMap(w['style']);
  final col = parseHexColor(st['colorOn'] as String?, const Color(0xFFEE9B2A));
  final text = (st['textOn'] as String?) ?? '';
  return _card(
    context,
    Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _head(context, w),
        Expanded(
          child: Center(
            child: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(shape: BoxShape.circle, color: col.withValues(alpha: 0.14), border: Border.all(color: col, width: 2)),
              child: Icon(Icons.power_settings_new, size: 26, color: col),
            ),
          ),
        ),
        Text(text, textAlign: TextAlign.center, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: col)),
      ],
    ),
  );
}

Widget _dimmerView(BuildContext context, Json w) {
  final c = context.evo;
  final st = jsonMap(w['style']);
  final f = jsonMap(w['features']);
  final col = parseHexColor(st['colorOn'] as String?, const Color(0xFFEE9B2A));
  return _card(
    context,
    Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _head(context, w, color: col),
        Expanded(
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: col.withValues(alpha: 0.14), border: Border.all(color: col, width: 2)),
                  child: Icon(Icons.power_settings_new, size: 20, color: col),
                ),
                if (f['rgb'] == true) ...[
                  const SizedBox(width: 8),
                  Container(width: 26, height: 26, decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF7C4DFF))),
                ],
              ],
            ),
          ),
        ),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Stack(
            children: [
              Container(height: 8, color: c.paper),
              FractionallySizedBox(widthFactor: 0.7, child: Container(height: 8, color: col)),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('70%', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: col)),
            if (f['tw'] == true) Text('3500K', style: TextStyle(fontSize: 10.5, color: c.muted)),
          ],
        ),
      ],
    ),
  );
}

Widget _valueView(BuildContext context, Json w) {
  final c = context.evo;
  final fmt = jsonMap(w['format']);
  final unit = (fmt['unit'] as String?) ?? '';
  return _card(
    context,
    Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _head(context, w),
        Expanded(
          child: Center(
            child: Text.rich(
              TextSpan(
                children: [
                  const TextSpan(text: '22.5', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w700)),
                  if (unit.isNotEmpty) TextSpan(text: ' $unit', style: TextStyle(fontSize: 13, color: c.muted)),
                ],
              ),
            ),
          ),
        ),
        Text('Cập nhật 12:30', style: TextStyle(fontSize: 10.5, color: c.muted)),
      ],
    ),
  );
}

Widget _buttonView(BuildContext context, Json w) {
  final c = context.evo;
  return _card(
    context,
    Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(color: c.accentSoft, borderRadius: BorderRadius.circular(20)),
        child: Text(
          (w['label'] as String?) ?? '',
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.accentInk),
        ),
      ),
    ),
    padding: const EdgeInsets.all(8),
  );
}

Widget _shutterView(BuildContext context, Json w) {
  final c = context.evo;
  final ctrl = (w['shCtrl'] ?? 'buttons') as String;
  final curtain = w['shStyle'] == 'curtain';
  final openLabel = curtain ? 'Mở' : 'Lên';
  final closeLabel = curtain ? 'Đóng' : 'Xuống';
  Widget chip(IconData ic, String t) => Expanded(
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
      );
  final row = <Widget>[
    chip(curtain ? Icons.open_in_full : Icons.arrow_upward, openLabel),
    const SizedBox(width: 5),
    if (ctrl != 'slider' && w['showStop'] != false) chip(Icons.stop, 'Dừng'),
    if (ctrl == 'slider') chip(Icons.stop, 'Dừng'),
    const SizedBox(width: 5),
    chip(curtain ? Icons.close_fullscreen : Icons.arrow_downward, closeLabel),
  ];
  return _card(
    context,
    Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _head(context, w),
        const SizedBox(height: 6),
        Expanded(
          child: ctrl == 'slider'
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: Stack(children: [
                          Container(height: 8, color: c.paper),
                          FractionallySizedBox(widthFactor: 0.4, child: Container(height: 8, color: c.accent)),
                        ]),
                      ),
                      const SizedBox(height: 4),
                      Text('40%', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: c.accentInk)),
                    ],
                  ),
                )
              : Icon(evoIcon(w['icon']), size: 34, color: c.muted),
        ),
        Row(children: row),
      ],
    ),
  );
}

Widget _sceneView(BuildContext context, Json w) {
  final c = context.evo;
  return _card(
    context,
    Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _head(context, w),
        Expanded(
          child: Center(
            child: Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(shape: BoxShape.circle, color: c.accentSoft, border: Border.all(color: c.accent, width: 2)),
              child: Icon(Icons.star, size: 24, color: c.accent),
            ),
          ),
        ),
        Text('Cảnh ${w['sceneNumber'] ?? 1}', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: c.muted)),
      ],
    ),
  );
}

Widget _linkView(BuildContext context, Json w) {
  final c = context.evo;
  return _card(
    context,
    Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _head(context, w, color: c.accentInk),
        Expanded(
          child: Center(
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(shape: BoxShape.circle, color: c.accentSoft),
              child: Icon(Icons.open_in_new, size: 20, color: c.accentInk),
            ),
          ),
        ),
        Text(
          Uri.tryParse((w['url'] as String?) ?? '')?.host ?? 'example.com',
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 10.5, color: c.muted),
        ),
      ],
    ),
  );
}

Widget _webviewView(BuildContext context, Json w) {
  final c = context.evo;
  final web = jsonMap(w['web']);
  final url = (w['url'] as String?) ?? '';
  return _card(
    context,
    Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (web['showHeader'] != false)
          Container(
            height: 22,
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 6),
            decoration: BoxDecoration(color: c.paper, borderRadius: BorderRadius.circular(6)),
            child: Row(
              children: [
                for (final col in const [Color(0xFFE57373), Color(0xFFFFD54F), Color(0xFF81C784)])
                  Padding(
                    padding: const EdgeInsets.only(right: 3),
                    child: Container(width: 5, height: 5, decoration: BoxDecoration(shape: BoxShape.circle, color: col)),
                  ),
                const SizedBox(width: 4),
                Expanded(
                  child: Container(
                    height: 12,
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    alignment: Alignment.centerLeft,
                    decoration: BoxDecoration(color: c.panel, borderRadius: BorderRadius.circular(6)),
                    child: Text(
                      url.isEmpty ? 'https://…' : url,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 7.5, color: c.muted),
                    ),
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: Container(
            decoration: BoxDecoration(color: c.paper, borderRadius: BorderRadius.circular(8)),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(evoIcon(w['icon']), size: 26, color: c.muted),
                const SizedBox(height: 4),
                Text((w['label'] as String?) ?? '', style: TextStyle(fontSize: 10.5, color: c.muted)),
              ],
            ),
          ),
        ),
      ],
    ),
    padding: const EdgeInsets.all(7),
  );
}

Widget _acView(BuildContext context, Json w) {
  final c = context.evo;
  final ac = jsonMap(w['ac']);
  final modes = jsonMap(ac['modes']);
  final names = jsonMap(ac['names']);
  final enabled = [
    for (final m in kAcModes)
      if (modes.containsKey(m.key) ? modes[m.key] == true : m.key != 'heat') m,
  ];
  return _card(
    context,
    Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _head(context, w, color: c.accentInk),
        Expanded(
          child: Center(
            child: Text.rich(
              TextSpan(children: [
                const TextSpan(text: '24.5', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w700)),
                TextSpan(text: '°C', style: TextStyle(fontSize: 13, color: c.muted)),
              ]),
            ),
          ),
        ),
        Wrap(
          spacing: 4,
          runSpacing: 4,
          children: [
            for (final m in enabled.take(4))
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: m.key == 'cool' ? c.accentSoft : c.paper,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: m.key == 'cool' ? c.accent : c.line),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(evoIcon(m.icon), size: 11, color: m.key == 'cool' ? c.accentInk : c.muted),
                    const SizedBox(width: 3),
                    Text(
                      (names[m.key] as String?)?.isNotEmpty == true ? names[m.key] as String : m.name,
                      style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w600, color: m.key == 'cool' ? c.accentInk : c.muted),
                    ),
                  ],
                ),
              ),
          ],
        ),
        if (ac['showCur'] != false)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text('Phòng 28.0°C', style: TextStyle(fontSize: 10.5, color: c.muted)),
          ),
      ],
    ),
    padding: const EdgeInsets.all(10),
  );
}

Widget _groupView(BuildContext context, Json w, int depth) {
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
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: c.muted),
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
                        child: widgetPreview(context, ch, depth: depth + 1),
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
