import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:knx_config/knx_config.dart';

import 'package:evoknx_editor/state/project_controller.dart';
import 'package:evoknx_editor/ui/designer/designer_page.dart';
import 'package:evoknx_editor/ui/designer/preview_page.dart';
import 'package:evoknx_editor/ui/structure_page.dart';

/// Builds a controller with a starter document directly (skips [ProjectController.init],
/// which waits on path_provider platform channels unavailable in widget tests).
ProjectController makeProject() {
  final project = ProjectController();
  final d = newProject('Test');
  (d['pages'] as List).add(makeRoom('Phòng khách', floorId: (jsonList(d['floors']).first)['id'] as String));
  project.doc = d;
  return project;
}

void setUpDesktop(WidgetTester tester) {
  tester.view.physicalSize = const Size(1600, 960);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

/// Drags in several small steps so the pan recognizer can win the arena and
/// receive updates (a single big move would only resolve at pointer-up).
Future<void> canvasDrag(WidgetTester tester, Finder finder, Offset offset) async {
  final gesture = await tester.startGesture(tester.getCenter(finder));
  await tester.pump();
  final steps = (offset.distance / 40).ceil();
  final unit = offset / steps.toDouble();
  for (var i = 0; i < steps; i++) {
    await gesture.moveBy(unit);
    await tester.pump();
  }
  await gesture.up();
  await tester.pump();
}

void main() {
  test('new project is valid', () {
    expect(isProject(newProject('Test')), isTrue);
  });

  testWidgets('designer: chọn trang và thêm widget từ palette', (tester) async {
    setUpDesktop(tester);
    final project = makeProject();
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: DesignerPage(project: project))));
    await tester.pump();

    // Mở trang đầu tiên trong cây bên trái.
    await tester.tap(find.text('Trang 1').first);
    await tester.pump();

    // Bấm tile "Công tắc" trên palette -> widget xuất hiện trong tài liệu.
    await tester.tap(find.text('Công tắc').first);
    await tester.pump(const Duration(seconds: 2));

    final sub = allSubpages(project.doc).first;
    final widgets = jsonList(sub['widgets']);
    expect(widgets, hasLength(1));
    expect(widgets.first['type'], 'switch');
    expect(widgets.first['label'], 'Công tắc');
  });

  testWidgets('designer: kéo widget trên canvas sang phải', (tester) async {
    setUpDesktop(tester);
    final project = makeProject();
    final sub = allSubpages(project.doc).first;
    (sub['widgets'] as List).add(makeWidget('switch', 0, 0));

    await tester.pumpWidget(MaterialApp(home: Scaffold(body: DesignerPage(project: project))));
    await tester.pump();
    await tester.tap(find.text('Trang 1').first);
    await tester.pump();

    // Kéo nhãn widget trên canvas (bản render cuối trong cây widget).
    final target = find.text('Công tắc').last;
    await canvasDrag(tester, target, const Offset(200, 0));
    await tester.pump(const Duration(seconds: 2));

    final w = jsonList(allSubpages(project.doc).first['widgets']).first;
    final pos = jsonMap(w['pos']);
    // Canvas 4 cột: cell ~ (380-24)/4 ≈ 89px -> 200px ≈ 2 ô.
    expect((pos['x'] as num).toInt(), greaterThan(0));
    expect((pos['y'] as num).toInt(), 0);
  });

  testWidgets('designer: chọn widget, gán địa chỉ nhóm qua bảng thuộc tính', (tester) async {
    setUpDesktop(tester);
    final project = makeProject();
    (project.doc['groupAddresses'] as List).add({
      'id': 'ga_1_1_1',
      'address': '1/1/1',
      'name': 'Đèn trần',
      'dpt': '1.001',
    });
    final sub = allSubpages(project.doc).first;
    (sub['widgets'] as List).add(makeWidget('switch', 0, 0));

    await tester.pumpWidget(MaterialApp(home: Scaffold(body: DesignerPage(project: project))));
    await tester.pump();
    await tester.tap(find.text('Trang 1').first);
    await tester.pump();

    // Chọn widget trên canvas (bản render cuối trong cây).
    await tester.tap(find.text('Công tắc').last);
    await tester.pump();

    // Bảng thuộc tính hiện mục Liên kết với slot "Địa chỉ ghi *".
    expect(find.text('Địa chỉ ghi *'), findsOneWidget);

    // Dropdown thứ tự trong panel: [0] Biểu tượng, [1] slot "write", [2] slot "status".
    await tester.tap(find.byType(DropdownButton<String>).at(1));
    await tester.pumpAndSettle();
    await tester.tap(find.text('1/1/1  ·  Đèn trần').last);
    await tester.pump(const Duration(seconds: 2));

    final w = jsonList(allSubpages(project.doc).first['widgets']).first;
    expect(jsonMap(w['bind'])['write'], 'ga_1_1_1');
  });

  testWidgets('designer: chuyển sang tablet dọc', (tester) async {
    setUpDesktop(tester);
    final project = makeProject();
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: DesignerPage(project: project))));
    await tester.pump();
    await tester.tap(find.text('Trang 1').first);
    await tester.pump();

    // Chip bố cục luôn hiển thị; bấm là bật và chuyển ngay.
    await tester.tap(find.text('Tablet dọc'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));

    expect(project.doc['activeDev'], 'tabletP');
    expect(jsonMap(project.doc['devices'])['tabletP'], true);
  });

  testWidgets('structure: tổng quan, thêm tầng và mở thiết kế trong cấu trúc', (tester) async {
    setUpDesktop(tester);
    final project = makeProject();
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: StructurePage(project: project))));
    await tester.pump();

    // Dashboard tổng quan hiện thống kê và sơ đồ tầng.
    expect(find.text('Tổng quan dự án'), findsWidgets);
    expect(find.text('Phòng khách'), findsWidgets);

    // Thêm tầng từ dashboard -> tài liệu có 2 tầng.
    await tester.tap(find.text('Thêm tầng').first);
    await tester.pump();
    expect(jsonList(project.doc['floors']), hasLength(2));

    // Bấm "Thiết kế" trên thẻ phòng -> canvas nằm ngay trong mục Cấu trúc.
    await tester.tap(find.text('Thiết kế').last);
    await tester.pump();
    expect(find.text('THÀNH PHẦN — kéo vào trang hoặc bấm để thêm'), findsOneWidget);

    // Quay lại tổng quan bằng nút mũi tên.
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Tổng quan dự án'), findsWidgets);
  });

  testWidgets('preview: chạy thử có thanh tầng và mô phỏng công tắc', (tester) async {
    setUpDesktop(tester);
    final project = makeProject();
    final sub = allSubpages(project.doc).first;
    (sub['widgets'] as List).add(makeWidget('switch', 0, 0));

    await tester.pumpWidget(MaterialApp(home: PreviewPage(project: project, initialSubId: sub['id'] as String)));
    await tester.pump();

    // Thanh chọn tầng ở dưới khung.
    expect(find.text('Tầng 1'), findsWidgets);
    expect(find.text('Mô phỏng — chưa gửi bus thật'), findsOneWidget);

    // Bấm công tắc -> chuyển sang trạng thái bật.
    await tester.tap(find.text('Công tắc').last);
    await tester.pump();
    expect(find.text('Đang bật'), findsOneWidget);
  });

  testWidgets('designer: khung canvas có thanh chọn tầng ở dưới', (tester) async {
    setUpDesktop(tester);
    final project = makeProject();
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: DesignerPage(project: project))));
    await tester.pump();
    await tester.tap(find.text('Trang 1').first);
    await tester.pump();

    expect(find.text('Tầng 1'), findsWidgets);
  });

  testWidgets('designer: đổi cỡ chữ tiêu đề và cỡ biểu tượng từ bảng thuộc tính', (tester) async {
    setUpDesktop(tester);
    final project = makeProject();
    final sub = allSubpages(project.doc).first;
    (sub['widgets'] as List).add(makeWidget('switch', 0, 0));

    await tester.pumpWidget(MaterialApp(home: Scaffold(body: DesignerPage(project: project))));
    await tester.pump();
    await tester.tap(find.text('Trang 1').first);
    await tester.pump();
    await tester.tap(find.text('Công tắc').last);
    await tester.pump();

    // Dropdown double thứ nhất: cỡ chữ tiêu đề -> chọn Lớn (15).
    await tester.tap(find.byType(DropdownButton<double>).at(0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lớn (15)').last);
    await tester.pump(const Duration(seconds: 2));

    // Dropdown double thứ hai: cỡ biểu tượng -> chọn To (24).
    await tester.tap(find.byType(DropdownButton<double>).at(1));
    await tester.pumpAndSettle();
    await tester.tap(find.text('To (24)').last);
    await tester.pump(const Duration(seconds: 2));

    final w = jsonList(allSubpages(project.doc).first['widgets']).first;
    expect((w['labelSize'] as num).toDouble(), 15.0);
    expect((w['iconSize'] as num).toDouble(), 24.0);
  });
}
