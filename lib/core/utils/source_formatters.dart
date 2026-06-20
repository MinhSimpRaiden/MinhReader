String formatSourceType(String sourceType) {
  return switch (sourceType) {
    'local_epub' => 'EPUB',
    'local_comic' => 'Truyện tranh',
    'plugin_api_json' => 'Plugin',
    'public_domain_demo' => 'Demo',
    _ => 'TXT',
  };
}
