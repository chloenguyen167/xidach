# Tính điểm xì dách

App Flutter ghi điểm/tiền xì dách theo từng ván. Chạy hoàn toàn offline, không đăng nhập, không có server.

## Chạy & kiểm thử

```sh
flutter pub get
flutter run                      # máy thật / emulator
flutter analyze
flutter test                     # unit + widget (DB thật qua sqflite_common_ffi)

# Chụp màn hình các màn chính (font thật) vào build/screenshots/ — dùng soát UI / làm ảnh store
flutter test test/screenshots --update-goldens --dart-define=SCREENSHOTS=true
```

## Bản web (GitHub Pages)

Cùng một codebase, build ra web: https://chloenguyen167.github.io/xidach/

- Không có backend. Dữ liệu vẫn là SQLite (chạy bằng wasm qua `sqflite_common_ffi_web`), file DB lưu trong IndexedDB của trình duyệt.
  "Xóa dữ liệu chơi / cài đặt" trong Cài đặt hoạt động như bản app. Xóa dữ liệu trang web của trình duyệt cũng sẽ xóa hết.
- Trên web ẩn mục Ủng hộ (Google Play Billing) và Xoay màn hình (trình duyệt không cho khóa xoay).
- `web/sqlite3.wasm` và `web/sqflite_sw.js` được commit sẵn. Khi nâng version `sqflite_common_ffi_web` thì chạy lại
  `dart run sqflite_common_ffi_web:setup --force` để cập nhật 2 file này.
- Deploy: tự chạy qua `.github/workflows/deploy-web.yml` mỗi khi push lên `main` (analyze + test → build → Pages).
  Lần đầu cần vào *Settings › Pages › Source* chọn **GitHub Actions**.
- Chạy thử trên máy: `flutter run -d chrome`. Build giống CI:
  ```sh
  flutter build web --release --base-href /xidach/ --no-tree-shake-icons
  ```
  Cần `--no-tree-shake-icons` vì nếu tree-shake thì một số icon Font Awesome trên web bị mất (hiện ô vuông).

## Cấu trúc

```
lib/
  core/        theme (seed #33A13F, màu người chơi, màu nhà cái), format tiền, breakpoint, DB, widget dùng chung
  domain/      model + scoring_engine (hàm thuần: delta, nút nhanh nhà cái, gợi ý nhà cái) + settlement
  data/        SessionRepository (lần chơi/ván, tính lại tổng trong transaction), SettingsRepository (nhóm, bộ luật, prefs)
  state/       providers Riverpod 3
  features/    home, new_session, session (bảng điểm, nhập ván, tổng kết, người chơi), settings, donate, rules_reference
tool/icon/     icon gốc (SVG sinh bằng make_icon.py) + render.sh
```

Nguyên tắc quan trọng:
- Mỗi ván lưu `outcome × hệ số × cược` của từng con. Nhà cái = −tổng, nên mọi ván luôn có tổng bằng 0.
- `sessions.totals_json` chỉ là cache. Mỗi lần thêm/sửa/xóa ván đều tính lại toàn bộ từ bảng `rounds` trong cùng transaction.
- Lần chơi lưu **bản sao** bộ luật, nên sửa preset sau này không làm đổi kết quả của lần chơi cũ.
- Tối đa 10 người kể cả nhà cái (52 lá / tối đa 5 lá mỗi người).

## Icon app

Sửa `tool/icon/make_icon.py`, sau đó chạy:

```sh
sh tool/icon/render.sh            # cần Google Chrome (headless) + ImageMagick
dart run flutter_launcher_icons
```

## Phát hành lên CH Play

1. **Keystore** (chỉ làm 1 lần, giữ file `.jks` và mật khẩu thật cẩn thận):
   ```sh
   keytool -genkey -v -keystore ~/upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
   cp android/key.properties.example android/key.properties   # rồi điền mật khẩu + đường dẫn
   ```
2. **Tăng version** trong `pubspec.yaml` (`1.0.0+1` → `1.0.1+2`…) và `appVersion` trong `lib/app.dart`.
3. **Build**:
   ```sh
   flutter build appbundle --release --obfuscate --split-debug-info=build/symbols
   ```
   Upload `build/app/outputs/bundle/release/app-release.aab`. Giữ lại thư mục `build/symbols` của từng bản để đọc crash log.
   Dung lượng tải về ước tính khoảng 8 MB (APK arm64 nén lại).
4. **Play Console**
   - Tạo app với tên "Tính điểm xì dách", ngôn ngữ mặc định tiếng Việt. Nội dung mô tả có sẵn ở `docs/store-listing.md`.
   - **Chính sách quyền riêng tư**: host file `docs/privacy-policy.html` (ví dụ GitHub Pages), sau đó dán URL vào Play Console.
   - **An toàn dữ liệu (Data safety)**: app không thu thập và không chia sẻ dữ liệu. Thanh toán ủng hộ do Google Play xử lý.
   - **Phân loại nội dung**: khai trung thực. App chỉ ghi chép điểm, không cho cá cược hay chơi bằng tiền thật, không có cơ chế thắng thưởng.
   - **Ủng hộ (in-app products)**: cần tạo payments profile, rồi vào *Monetize › Products › In-app products* tạo 3 sản phẩm **consumable**:
     `donate_coffee` (~20.000đ), `donate_meal` (~50.000đ), `donate_big` (~100.000đ). Lưu ý: chỉ tạo được sản phẩm sau khi đã upload ít nhất 1 bản AAB có quyền BILLING (ví dụ lên track Internal testing).
     Thêm tài khoản vào *License testing* để thử mua không mất tiền.
   - **Tài khoản cá nhân mới** phải chạy **Closed testing với ít nhất 12 tester liên tục 14 ngày** thì mới được xin lên Production.
   - Ảnh chụp: dùng `build/screenshots/` (dọc, ngang, tablet). Ảnh feature graphic 1024×500 có thể dựng từ `tool/icon/icon_full.png`.

## Kiểm thử thủ công trước khi phát hành

- [ ] Tạo lần chơi ở cả 3 chế độ (Điểm / Tiền cố định / Tiền theo ván), nhập 5–10 ván.
- [ ] Sửa ván cũ, xóa ván (vuốt), Hoàn tác: tổng phải khớp với bảng.
- [ ] Đổi nhà cái giữa chừng; cho 1 người nghỉ; thêm người mới.
- [ ] Xoay ngang giữa lúc đang nhập ván (dữ liệu đang nhập phải giữ nguyên); thử trên tablet (2 pane).
- [ ] Dark mode, cỡ chữ hệ thống lớn nhất, TalkBack đọc được tên + điểm.
- [ ] Tắt app hẳn rồi mở lại, bấm "Tiếp tục lần gần nhất".
- [ ] Cài đặt › Xóa dữ liệu chơi / Xóa dữ liệu cài đặt (phải độc lập với nhau).
- [ ] Ủng hộ: mua thử bằng license tester; khi mất mạng phải hiện thông báo, không crash.
