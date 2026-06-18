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
- Missing license.
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
