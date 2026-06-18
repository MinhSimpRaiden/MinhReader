# MinhReader

## Truyện Tranh Offline

- MinhReader hỗ trợ nền tảng truyện tranh/manga/manhwa offline local qua file `.cbz` hoặc `.zip` hợp pháp trên thiết bị của người dùng.
- Khi nhập truyện tranh, app giải nén ảnh vào thư mục app documents `comics/<storyId>/`, sắp xếp ảnh theo tên file tự nhiên để `1.jpg`, `2.jpg`, `10.jpg` đọc đúng thứ tự.
- Comic Reader hiển thị ảnh theo kiểu lướt dọc từ trên xuống, ảnh fit theo chiều ngang khung đọc và giữ tỉ lệ.
- Truyện chữ cũ vẫn là `contentType: text`; dữ liệu cũ không có `contentType` tự mặc định là text.
- Backup JSON hiện lưu metadata `comicChapters` và `imagePaths`, nhưng chưa đóng gói file ảnh truyện tranh vào backup. Khi restore sang máy khác mà ảnh không đi kèm, app hiển thị placeholder lỗi ảnh và không crash.
- Import folder ảnh trực tiếp chưa bật trong phase này; ưu tiên CBZ/ZIP local ổn định trước.

## Source Plugin Text Và Comic

- Source Plugin hiện hỗ trợ cả truyện chữ và truyện tranh thông qua `SourceStory.contentType` và `SourceChapter.contentKind`.
- `StorySource.getChapterContent` dùng cho truyện chữ; `StorySource.getChapterImages` dùng cho truyện tranh dạng ảnh.
- App có thêm `Truyện tranh demo`, một mock comic source offline/local. Source này chỉ dùng dữ liệu demo trong app, không gọi internet, không scrape website và không tải ảnh từ web.
- Khi thêm truyện từ mock comic source, app tạo ảnh PNG demo đơn giản vào `documents/comics/<storyId>/` để ComicReader đọc bằng file path giống truyện CBZ/ZIP.
- Backup JSON lưu metadata comic source đã thêm vào thư viện, nhưng chưa đóng gói file ảnh PNG demo. Nếu restore sang máy khác mà ảnh không đi kèm, ComicReader sẽ hiển thị placeholder lỗi ảnh thay vì crash.

## Online Plugin Source Architecture

- MinhReader có nền tảng plugin nguồn truyện dạng manifest JSON an toàn. Plugin là dữ liệu cấu hình, không phải code thực thi.
- Hỗ trợ phase đầu cho `static_json` plugin local: import file `.json`, validate, lưu danh sách plugin đã cài và tìm/đọc dữ liệu trong app.
- Manifest hỗ trợ `contentType: text`, `comic`, hoặc `mixed`; source dữ liệu hỗ trợ `static_json` và chuẩn bị schema cho `api_json`.
- Plugin không được khai báo `script`, `javascript`, `eval`, `executable`, `dartCode`, token/cookie/authorization hardcode.
- UI `Nguồn truyện` có section `Plugin nguồn truyện`, nút `Thêm plugin`, `Thêm plugin mẫu`, bật/tắt plugin và xóa plugin.
- Sample plugin nằm trong `assets/sample_plugins/`:
  - `public_domain_text_plugin.json`
  - `public_domain_comic_plugin.json`
- Comic plugin demo không tải ảnh từ web. Khi thêm vào thư viện, app tạo PNG local vào `documents/comics/<storyId>/` để ComicReader đọc.
- Quy tắc an toàn/pháp lý: không source online không rõ giấy phép, không scrape HTML, không bypass paywall/captcha/DRM, không chạy JavaScript plugin.
- Giới hạn hiện tại: chưa gọi remote API JSON thật, chưa marketplace, cache plugin mới ở mức danh sách đã cài/static data, ảnh comic plugin chưa được đóng gói trong backup.
- Roadmap: remote API JSON hợp pháp với timeout/rate limit/cache, marketplace hợp pháp, offline cache nâng cao, sync plugin settings.

## Account & Sync Roadmap

- App hiện vẫn chạy offline/local. Người dùng không cần đăng nhập để đọc truyện, import TXT/EPUB, dùng bookmark, tìm kiếm, backup hoặc restore.
- Phase này chưa thêm Firebase dependency để tránh phụ thuộc `firebase_options.dart` khi project chưa được cấu hình bằng FlutterFire CLI.
- Đăng nhập và đồng bộ hiện là mock/local-only placeholder: `AuthService` có mock/disabled implementation, `SyncService` có local-only implementation.
- Local data là nguồn chính. Đăng xuất không xóa dữ liệu local; dữ liệu local vẫn được giữ trên thiết bị này.
- Trước lần sync thật đầu tiên, app nên tự tạo backup local để tránh mất dữ liệu.
- Chiến lược merge dự kiến cho phase cloud:
  - Reading progress dùng bản có `updatedAt` mới hơn.
  - Bookmarks merge theo `id`.
  - Stories merge theo `id` hoặc `source`.
  - Settings dùng bản có `updatedAt` mới hơn.
  - Cover sẽ xử lý ở phase sau, ưu tiên không làm mất cover local nếu remote chưa có file cover.
- Phase sau có thể thay `LocalMockAuthService`/`DisabledCloudAuthService` bằng `FirebaseAuthService`, và thay `LocalOnlySyncService` bằng `FirebaseSyncService`.
- Khi bật Firebase thật, dùng FlutterFire CLI để tạo cấu hình chính thức, không hardcode API key giả và không commit secret:

```bash
dart pub global activate flutterfire_cli
flutterfire configure
```

MinhReader là ứng dụng đọc truyện offline đa nền tảng viết bằng Flutter. App hỗ trợ nhập file TXT và EPUB hợp pháp của người dùng, quản lý thư viện local, đọc chương và lưu tiến độ đọc trên Android và Windows. Không có backend, không source online, không scrape website.

## Tính Năng

- Thư viện truyện đã nhập, có tìm kiếm theo tên truyện hoặc tác giả.
- Thư viện có card truyện, tiến độ đọc, lọc theo nguồn/trạng thái và sắp xếp theo mới đọc, mới thêm, tên hoặc số chương.
- Nhập truyện offline từ file `.txt` và `.epub`.
- TXT: tách chương theo tiêu đề `Chương`, `CHƯƠNG`, `Chapter`; nếu không có tiêu đề thì chia nội dung theo phần khoảng 4000 từ.
- EPUB: đọc metadata title/author nếu có, đọc chapter từ TOC/spine khi có, làm sạch HTML thành text dễ đọc, fallback chia phần nếu EPUB không có chapter rõ.
- Kiểm tra file rỗng hoặc quá lớn trước khi nhập: TXT dưới 20 MB, EPUB dưới 60 MB.
- Nếu tên truyện bị trùng, app tự thêm hậu tố như `(2)`, `(3)`.
- Trang chi tiết truyện với `Đọc tiếp`, `Đọc từ đầu`, tìm trong truyện, danh sách đánh dấu, danh sách chương và xóa truyện.
- Trang chi tiết truyện có layout responsive cho mobile và màn rộng.
- Reader có chương trước/sau, thanh tiến độ chương, ẩn/hiện thanh điều khiển, lưu chương gần nhất và vị trí cuộn tương đối.
- Bookmark vị trí đang đọc trong chương, kèm ghi chú ngắn tùy chọn.
- Tìm trong chương hiện tại, có số kết quả, điều hướng kết quả trước/sau và highlight đơn giản.
- Cài đặt đọc: theme sáng/tối, cỡ chữ, giãn dòng, font chữ và màu nền đọc.
- Backup và khôi phục dữ liệu offline bằng file JSON local.
- Kiến trúc Source Plugin bước đầu với Local TXT, Local EPUB và Public Domain Demo offline.
- Dữ liệu local lưu trong file JSON `minh_reader_data.json` ở thư mục documents của ứng dụng, ghi qua file tạm để giảm rủi ro mất dữ liệu.

## Cách Import Truyện

1. Mở `Thư viện`.
2. Bấm `Nhập truyện`.
3. Chọn `Nhập TXT` hoặc `Nhập EPUB`.
4. Kiểm tra/sửa tên truyện và tác giả.
5. Bấm `Lưu vào thư viện`.

## Backup Và Khôi Phục

- Vào `Cài đặt` > `Sao lưu dữ liệu`.
- Bấm `Xuất bản sao lưu` để xuất toàn bộ dữ liệu local ra file JSON, gồm truyện, chương, bookmark, ghi chú, tiến độ đọc và cài đặt đọc.
- Bấm `Nhập bản sao lưu` để khôi phục từ file JSON đã xuất trước đó.
- Khi khôi phục, app sẽ tự tạo một bản sao lưu dữ liệu hiện tại trước khi thay thế.
- Dữ liệu vẫn chỉ nằm local/offline. Nên xuất backup trước khi cài lại app, đổi máy hoặc xóa dữ liệu ứng dụng.

## Source Plugin Architecture

MinhReader có lớp trừu tượng `StorySource` để chuẩn bị cho nhiều nguồn truyện hợp pháp trong tương lai. Mỗi source có metadata, tìm kiếm, chi tiết truyện, danh sách chương và nội dung chương.

Hiện app chỉ có các nguồn offline/local:

- `Local TXT`: nhập file TXT hợp pháp từ thiết bị.
- `Local EPUB`: nhập file EPUB hợp pháp từ thiết bị.
- `Public Domain Demo`: dữ liệu mẫu offline tự viết ngắn, dùng để kiểm thử kiến trúc nguồn.

App chưa hỗ trợ nguồn online thật, không scrape website và không tích hợp nguồn vi phạm bản quyền.

## Cách Chạy

```bash
flutter pub get
flutter run -d windows
```

Để chạy Android, hãy bật emulator hoặc kết nối thiết bị rồi chạy:

```bash
flutter pub get
flutter run -d android
```

## Phím Tắt Reader Trên Windows

- Mũi tên trái: chuyển về chương trước.
- Mũi tên phải: chuyển sang chương sau.
- `+`: tăng cỡ chữ.
- `-`: giảm cỡ chữ.
- `Esc`: thoát Reader hoặc đóng hộp cài đặt đang mở.

## Cấu Trúc Thư Mục

```text
lib/
├── main.dart
├── app.dart
├── core/
├── data/
│   ├── local/
│   └── repositories/
└── features/
    ├── import/
    ├── library/
    ├── reader/
    └── settings/
```

## Roadmap

Phase 1:
- Import TXT
- Đọc truyện offline
- Lưu tiến độ
- Cài đặt đọc

Phase 1.5:
- EPUB offline/local
- Bookmark
- Ghi chú
- Tìm kiếm trong chương và trong truyện

Phase 2:
- Tối ưu cover EPUB
- Tìm kiếm nâng cao
- Trải nghiệm Reader nâng cao hơn

Phase 3:
- Đăng nhập
- Đồng bộ PC và điện thoại
- Backup dữ liệu

Phase 4:
- Plugin nguồn truyện hợp pháp
- Thông báo chương mới
- Tải offline nâng cao

## Cover Truyện

- Thư viện và trang chi tiết truyện hiển thị ảnh bìa nếu truyện có `coverPath`.
- Khi nhập EPUB, app cố gắng lấy cover từ EPUB và lưu vào thư mục local `covers/` trong documents của app. Nếu EPUB không có cover hoặc cover lỗi, app dùng placeholder và vẫn nhập truyện bình thường.
- Trong trang chi tiết truyện có thể dùng `Đổi ảnh bìa` để chọn ảnh `.jpg`, `.jpeg`, `.png` hoặc `.webp`, hoặc `Xóa ảnh bìa` để quay về placeholder.
- Backup JSON hiện lưu đường dẫn `coverPath`, nhưng chưa đóng gói file ảnh bìa vào backup. Khi khôi phục trên máy khác hoặc khi file ảnh không còn tồn tại, app sẽ tự hiển thị placeholder và không crash.
