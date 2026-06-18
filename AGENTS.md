# Agent Notes For MinhReader

- Keep the app offline-first. Local data must remain usable without login, cloud, or plugin access.
- Do not break TXT, EPUB, CBZ/ZIP comic import, Reader, ComicReader, Backup/Restore, or existing mock sources.
- Do not add illegal story sources, piracy websites, or hardcoded scraper targets.
- Do not scrape HTML unless a source explicitly permits it and the implementation respects terms.
- Do not bypass paywalls, DRM, login, captcha, or anti-bot systems.
- Do not run JavaScript, Dart, native code, or arbitrary executable code from plugins.
- Prefer small, testable changes that follow the current project structure.
- Run `flutter pub get`, `flutter analyze`, `flutter test`, and `flutter build apk --debug` after changes.
- Do not run Windows build unless the Visual Studio C++ toolchain is available and the user asks for it.
