# MinhReader Plugin Spec

MinhReader plugin source is a safe manifest/schema format for legal story sources. A plugin is data, not executable code. The app must not run JavaScript, Dart, dynamic eval, native binaries, or arbitrary code from a plugin.

## Goals

- Support legal text and comic sources.
- Support offline/static JSON first.
- Prepare for public API JSON sources later.
- Keep MinhReader offline-first and local-data-first.

## Plugin Types

- `text`: text stories and text chapters.
- `comic`: comic stories and image/page chapters.
- `mixed`: a plugin may contain both text and comic stories.
- `static_json`: all source data is declared in the manifest JSON.
- `api_json`: future public API JSON runtime with timeout, validation, rate limit, and cache.

## Manifest Format

Required fields:

```json
{
  "id": "sample_public_domain_text",
  "name": "Sample Public Domain Text",
  "version": "1.0.0",
  "author": "MinhReader Demo",
  "description": "Legal offline demo source",
  "contentType": "text",
  "sourceType": "static_json",
  "license": "CC0-1.0",
  "language": "vi",
  "stories": []
}
```

Optional fields:

- `baseUrl`
- `homepage`
- `isAdultContent`, default `false`
- `endpoints.search`
- `endpoints.detail`
- `endpoints.chapters`
- `endpoints.chapterContent`
- `endpoints.chapterImages`
- `headers`
- `rateLimit`
- `attribution`

## API JSON Catalog Manifest

`api_json` plugins must describe every endpoint explicitly. MinhReader only calls declared JSON endpoints and never scrapes HTML or executes plugin code.

```json
{
  "schemaVersion": 1,
  "id": "demo_catalog_source",
  "name": "Demo Catalog Source",
  "version": "1.0.0",
  "author": "MinhReader",
  "description": "Authorized API JSON source",
  "contentType": "mixed",
  "sourceType": "api_json",
  "language": "vi",
  "license": "Demo / Authorized API",
  "homepage": "https://example.com",
  "baseUrl": "https://example.com/api",
  "features": {
    "catalog": true,
    "search": true,
    "latest": true,
    "detail": true,
    "chapters": true,
    "readText": true,
    "readComic": true
  },
  "endpoints": {
    "catalog": "/stories?page={page}&limit={limit}",
    "latest": "/stories/latest?page={page}&limit={limit}",
    "search": "/stories/search?q={query}&page={page}&limit={limit}",
    "detail": "/stories/{storyId}",
    "chapters": "/stories/{storyId}/chapters",
    "chapterContent": "/chapters/{chapterId}",
    "chapterImages": "/comic-chapters/{chapterId}/images"
  },
  "pagination": {
    "type": "page",
    "startPage": 1,
    "defaultLimit": 20,
    "maxPagesPerSync": 5
  },
  "rateLimit": {
    "requestsPerMinute": 30
  }
}
```

Validation rules:

- `baseUrl` is required for `api_json` and must be `http` or `https`.
- `features.catalog` requires `endpoints.catalog`.
- `features.detail` requires `endpoints.detail`.
- `features.chapters` requires `endpoints.chapters`.
- `features.readText` requires `endpoints.chapterContent`.
- `features.readComic` requires `endpoints.chapterImages`.
- Dangerous fields such as `script`, `javascript`, `eval`, `code`, `executable`, cookie, authorization, token, or authToken are rejected.
- Missing `license` is allowed for compatibility, but UI must warn the user.

## Catalog Runtime

Catalog response:

```json
{
  "page": 1,
  "limit": 20,
  "hasNextPage": true,
  "stories": [
    {
      "id": "story_001",
      "title": "Story title",
      "author": "Author",
      "description": "Description",
      "coverUrl": "https://example.com/cover.jpg",
      "contentType": "text",
      "status": "ongoing",
      "genres": ["fantasy"],
      "updatedAt": "2026-06-18T10:00:00Z"
    }
  ]
}
```

Catalog sync stores metadata only in `plugin_catalog_cache.json`: pluginId, stories, lastSyncAt, pageSynced, and hasNextPage. It must not download chapter text or comic images.

Detail response:

```json
{
  "id": "story_001",
  "title": "Story title",
  "author": "Author",
  "description": "Full description",
  "coverUrl": "https://example.com/cover.jpg",
  "contentType": "text",
  "status": "ongoing",
  "genres": ["fantasy"]
}
```

Chapter list response:

```json
{
  "storyId": "story_001",
  "chapters": [
    {
      "id": "chapter_001",
      "title": "Chapter 1",
      "index": 0,
      "updatedAt": "2026-06-18T10:00:00Z"
    }
  ]
}
```

Text chapter response:

```json
{
  "id": "chapter_001",
  "title": "Chapter 1",
  "index": 0,
  "contentType": "text",
  "content": "Chapter content..."
}
```

Comic images response:

```json
{
  "id": "comic_chapter_001",
  "title": "Chapter 1",
  "index": 0,
  "contentType": "comic",
  "images": ["https://example.com/001.jpg"]
}
```

Rules for `chapterImages`:

- `images` must be an array of absolute image URLs.
- Each image URL must use `http` or `https`.
- MinhReader displays images directly from the returned list and does not scrape HTML to discover more pages.
- MinhReader does not send cookies, bearer tokens, hardcoded auth headers, or plugin-provided credentials when loading comic page images.
- Invalid or unsupported image URLs should be ignored by the source, and the app will show an error placeholder instead of crashing if one is returned.

## Static Stories

Text story:

```json
{
  "id": "story-id",
  "title": "Story title",
  "author": "Author",
  "description": "Description",
  "contentType": "text",
  "chapters": [
    {
      "id": "c1",
      "title": "Chapter 1",
      "index": 0,
      "contentKind": "text",
      "content": "Chapter text"
    }
  ]
}
```

Comic story:

```json
{
  "id": "comic-id",
  "title": "Comic title",
  "author": "Author",
  "description": "Description",
  "contentType": "comic",
  "chapters": [
    {
      "id": "c1",
      "title": "Chapter 1",
      "index": 0,
      "contentKind": "images",
      "imagePaths": ["page-1", "page-2"]
    }
  ]
}
```

For static demo comic plugins, `imagePaths` may be page identifiers. MinhReader can generate local PNG demo pages when adding the story to the library.

## Runtime Methods

- Search story: match `title`, `author`, or `description`.
- Detail: return story metadata by id.
- Chapter list: return `SourceChapter` entries.
- Text content: use `StorySource.getChapterContent`.
- Comic images/pages: use `StorySource.getChapterImages`.

## Validation

The validator must reject:

- Missing `id`, `name`, or `version`.
- Unsupported `contentType` or `sourceType`.
- `script`, `javascript`, `eval`, `executable`, `dartCode`, or similar keys.
- Hardcoded `authorization`, `cookie`, or `token` headers.
- Static JSON plugins without stories.

## Legal And Safety Rules

- Do not clone Vbook names, logos, code, or plugin packages.
- Do not use plugins with unclear licenses.
- Do not scrape websites when terms do not allow it.
- Do not bypass paywalls, DRM, login, captcha, or anti-bot systems.
- Do not download infringing content.
- Only support legal sources: public domain, explicit open APIs, user-owned sources, or sources with clear permission.
- Do not run code from plugins.

## Roadmap

- Phase A: local static JSON import.
- Phase B: remote public API JSON with timeout, error handling, rate limit, and cache.
- Phase C: legal plugin marketplace and signed manifests.
- Phase D: advanced offline cache and plugin settings sync.
