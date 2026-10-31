# EVOKNX V2

Phần mềm thiết kế và điều khiển giao diện nhà thông minh KNX của Evohome.

> Repo **EVOKNX V2** — tách riêng khỏi repo V1, bao gồm đầy đủ Giai đoạn 2 (Thiết kế): canvas điện thoại, kéo thả widget, bảng thuộc tính và gán địa chỉ nhóm. Phiên bản bắt đầu từ 2.0.0.

## Cấu trúc

```
apps/evoknx_editor/   Ứng dụng Editor cho Windows (Flutter)
  - Cấu trúc: quản lý tầng, phòng, trang
  - Thiết kế: canvas điện thoại, thanh thành phần, kéo thả, bảng thuộc tính, gán địa chỉ nhóm
  - Kết nối: kết nối KNX, địa chỉ nhóm, nhập từ ETS
  - Kiểm tra: theo dõi bus KNX thật, đọc/ghi địa chỉ
packages/knx_core/    Thư viện KNX: KNXnet/IP tunneling, cEMI, DPT (Dart thuần, dùng chung với App mobile)
packages/knx_config/  File dự án .evoknx, nâng cấp phiên bản, nhập ETS (.knxproj, CSV, XML)
.github/workflows/    Tự động build bản Windows
```

## Lấy bản cài đặt Windows

1. Mỗi lần đưa code lên nhánh `main`, GitHub tự build (tab **Actions**).
2. Mở lần chạy mới nhất có dấu ✓ xanh, kéo xuống mục **Artifacts**, tải **EVOKNX-Editor-Windows**.
3. Giải nén, chạy `EVOKNX-Editor/evoknx_editor.exe`. Không cần cài đặt thêm.

## Chạy trên máy lập trình

```
cd apps/evoknx_editor
flutter config --enable-windows-desktop
flutter create --platforms=windows --project-name evoknx_editor --org vn.evohome .
flutter run -d windows
```

## Kiểm tra thư viện

```
cd packages/knx_core && dart run tool/selftest.dart
cd packages/knx_config && dart run tool/selftest.dart
```
