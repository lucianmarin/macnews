# Macnews

Native macOS client for [Hotnews](https://news.lucianmarin.com) (`news.lucianmarin.com/api`), built with SwiftUI and Swift Package Manager. It brings the clean, distraction-free reading experience of the Hotnews web application to macOS with a unified toolbar featuring **3 segmented tabs** (**Hottest**, **Coldest**, **Newest**), **infinite scroll**, **alternating odd/even row highlighting**, and the signature **red-orange (`#FF4500`)** accent color.

---

## 1. Implementation & Specification Tracker

- [x] **Specification Document (`README.md`)**: Write down complete app and API specifications and track progress.
- [x] **Backend Public API (`../news`)**:
  - [x] `GET /api/hot` — Paginated hottest news feed (`?p=1`, ordered by `-score, pub`, 1 per domain).
  - [x] `GET /api/cold` — Paginated coldest news feed (`?p=1`, ordered by `score, pub`, 1 per domain).
  - [x] `GET /api/new` — Paginated newest news feed (`?p=1`, ordered by `-pub`, 1 per domain).
  - [x] `GET /api/{site}` — Paginated site-specific news feed (`?p=1`, ordered by `-score, pub`).
- [x] **macOS App Scaffolding & Icon**:
  - [x] Swift Package (`Package.swift`) targeting macOS 14+ with `Macnews` executable and `MacnewsTests` test suite.
  - [x] `Makefile` to build and bundle `Hotnews.app` with `AppIcon.icns`.
  - [x] Programmatic `AppIcon` renderer matching `icon.svg`'s 5 warm vertical stripes (`#FBB03B`, `#F7931E`, `#F15A24`, `#ED1C24`, `#C1272D`) inside a macOS squircle.
- [x] **Data Layer (`Models`, `APIClient`, `AppState`)**:
  - [x] `NewsEntry` and `PaginatedNewsResponse` Codable models with relative age (`shortdate`), truncated summary (`480` chars), and degree score (`round(score * 1000)`).
  - [x] Async/await `APIClient` fetching `/api/hot`, `/api/cold`, `/api/new`, and `/api/{site}` from `https://news.lucianmarin.com` (configurable for local development).
  - [x] `AppState` managing selected feed tab, optional site filter, infinite scroll pagination state, visited article tracking, and refresh triggers.
- [x] **Native macOS Interface (`Views` & `Theme`)**:
  - [x] Native macOS unified toolbar (`NSToolbar` with `titleVisibility = .hidden`, `showsBaselineSeparator = false`, `displayMode = .iconOnly`, `sizeMode = .regular`, and `.fullSizeContentView` matching `../multicolor`) featuring **3 segmented tabs** (**Hottest**, **Coldest**, **Newest**).
  - [x] **Odd news rows highlighted** (`#F0F0F0` Light / `#141414` Dark) and **even news rows unhighlighted** (`#FFFFFF` Light / `#000000` Dark), spanning full window width with a centered `520pt` reading column.
  - [x] Entry row matching `news.lucianmarin.com` (`site` + `age ago` + `score°` in `orangered`, bold clickable title with visited state, 480-char `--darkgray` summary).
  - [x] Infinite scroll pagination automatically loading subsequent pages (`?p=2`, `?p=3`, ...) as the user scrolls.
  - [x] Pull-to-refresh and keyboard navigation (`⌘1` Hottest, `⌘2` Coldest, `⌘3` Newest, `⌘R` Refresh).
- [x] **Automated Tests & Build Verification**:
  - [x] Backend unit/integration tests for `/api/hot`, `/api/cold`, `/api/new`, and pagination.
  - [x] Swift unit tests (`swift test`) covering models, formatting filters, odd/even row highlighting logic, infinite scroll pagination, and UI rendering.
  - [x] Release app bundle verification (`make app`).

---

## 2. Design Specifications

1. **Native macOS Unified Toolbar with 3 Segmented Tabs**:
   - Uses a native macOS unified toolbar (`.windowToolbarStyle(.unified(showsTitle: false))` and `NSToolbar` configured like `../multicolor` with `titleVisibility = .hidden`, `showsBaselineSeparator = false`, `fullSizeContentView`, and persisted window frame).
   - Houses a native 3-segment `Picker` (`.pickerStyle(.segmented)`) in `.principal` placement switching between **Hottest** (`/api/hot`), **Coldest** (`/api/cold`), and **Newest** (`/api/new`).
   - Clicking a publication's site name (e.g. `macrumors`, `theverge`, `arstechnica`) filters the feed to that source (`/api/{site}`) and replaces the centered segmented tabs with a centered site filter button in the toolbar.
2. **Odd / Even Row Highlighting**:
   - Unlike the web app's 10-row static page gradient (`.bg-color-9` through `.bg-color-0`), the macOS app uses infinite scrolling with alternating row backgrounds:
     - **Odd rows** (1st, 3rd, 5th, ... i.e. 1-based row index `1, 3, 5` / 0-based `index % 2 == 0`): **Highlighted** with subtle surface fill (`#F0F0F0` in Light mode, `#141414` in Dark mode).
     - **Even rows** (2nd, 4th, 6th, ... i.e. 1-based row index `2, 4, 6` / 0-based `index % 2 == 1`): **Not highlighted** (`#FFFFFF` in Light mode, `#000000` in Dark mode).
   - Row backgrounds span the full width of the window with a `1px` light gray border (`--gainsboro`) between stories, while inner text content is centered with a `520pt` maximum reading width, `20pt` horizontal padding, and `10pt` (`horizontalPadding / 2`) top and bottom padding. The window's maximum width is capped at `560pt` (`520pt` reading width + `2 × 20pt` horizontal padding).
3. **Color Palette & Typography**:
   - **Accent (`orangered`)**: `#FF4500` (`rgb(255, 69, 0)`) used for active segmented tab indicator, degree score (`79°`), brand accents, and interactive highlights.
   - **Background (`--white`)**: `#FFFFFF` (Light) / `#000000` (Dark).
   - **Odd Row Highlight (`--whitesmoke`)**: `#F0F0F0` (Light) / `#141414` (Dark).
   - **Primary Text (`--black`)**: `#000000` (Light) / `#FFFFFF` (Dark).
   - **Summary & Visited Title (`--darkgray`)**: `#404040` (Light) / `#C0C0C0` (Dark).
   - **Secondary Text (`--gray`)**: `#808080` (Light & Dark).
   - **Muted / Divider (`--silver` / `--gainsboro`)**: `#C0C0C0` / `#E0E0E0` (Light), `#404040` / `#242424` (Dark).
   - **Typography**:
     - Metadata row (`.small`): `13pt` regular (`site` in primary color, `35h ago` in gray, `79°` in `orangered`).
     - Headline (`.title`): `14pt` bold, line spacing matching `20px` line height.
     - Summary (`.summary`): `14pt` regular in `--darkgray` (`#404040` Light / `#C0C0C0` Dark), truncated to 480 characters with `...`.

---

## 3. Public API Specification (`../news`)

Base URL: `https://news.lucianmarin.com` (configurable to `http://127.0.0.1:8000` for local development).

### Endpoints

| Endpoint | Query Params | Order | Description |
| :--- | :--- | :--- | :--- |
| `GET /api/hot` | `?p=<page>` (default `1`) | `-score, pub` | Hottest articles (highest similarity score, 1 per domain, 10 per page). |
| `GET /api/cold` | `?p=<page>` (default `1`) | `score, pub` | Coldest articles (lowest similarity score, 1 per domain, 10 per page). |
| `GET /api/new` | `?p=<page>` (default `1`) | `-pub` | Newest articles (most recently published, 1 per domain, 10 per page). |
| `GET /api/{site}` | `?p=<page>` (default `1`) | `-score, pub` | All recent articles from a specific `site` (10 per page). |

### Response Format (`application/json`)

```json
{
  "page": 1,
  "pages": 8,
  "view": "hottest",
  "entries": [
    {
      "id": "d3b07384d113edec49eaa6238ad5ff00",
      "url": "https://www.macrumors.com/2026/10/28/top-stories/",
      "title": "Top Stories: Apple 'Pro and Tell' Debut, iPhone Duo Launch, and More",
      "domain": "macrumors.com",
      "site": "macrumors",
      "pub": 1793200000.0,
      "age": "35h",
      "author": "Juli Clover",
      "description": "Yet another busy week for Apple saw a teaser for even more product announcements...",
      "summary": "Yet another busy week for Apple saw a teaser for even more product announcements...",
      "score": 0.079,
      "degrees": 79
    }
  ]
}
```

---

## 4. Architecture & Project Structure

```text
macnews/
├── Makefile
├── Package.swift
├── README.md
├── Sources/
│   └── Macnews/
│       ├── MacnewsApp.swift           # App entry point, window & command shortcuts
│       ├── AppIcon.swift              # Hotnews 5-stripe macOS squircle icon generator
│       ├── Models/
│       │   └── Models.swift           # FeedTab, NewsEntry, PaginatedNewsResponse
│       ├── Networking/
│       │   └── APIClient.swift        # Async/await URLSession client for /api/hot, /api/cold, /api/new
│       ├── State/
│       │   └── AppState.swift         # Feed selection, infinite scroll state, visited links
│       └── Views/
│           ├── Theme.swift            # Adaptive color palette (#FF4500 accent, odd/even rows) & window configurator
│           ├── MainNewsView.swift     # Toolbar area with 3 segmented tabs + infinite-scroll feed
│           └── NewsRowView.swift      # Article row with odd/even highlight, metadata, title, summary
└── Tests/
    └── MacnewsTests/
        └── MacnewsTests.swift         # Unit tests for API decoding, formatting, odd/even rows, and pagination
```

---

## 5. Building & Running

Build and bundle `Hotnews.app`:

```bash
make app
open Hotnews.app
```

Or run directly with Swift Package Manager:

```bash
# Build the app
swift build

# Run unit tests
swift test

# Run the macOS app from terminal
swift run Macnews
```

