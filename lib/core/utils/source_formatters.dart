String formatSourceType(String sourceType) {
  return switch (sourceType) {
    'local_epub' => 'EPUB',
    'local_comic' => 'Truyện tranh',
    'public_domain_demo' => 'Demo',
    _ => 'TXT',
  };
}
