<div align="center">

# JassyNote

Compact lecture slides into clean, printable paper notes.

[![Platform](https://img.shields.io/badge/platform-iPhone%20%7C%20iPad-111111?style=for-the-badge&logo=apple)](./JassyNote.xcodeproj)
[![SwiftUI](https://img.shields.io/badge/SwiftUI-native-0A84FF?style=for-the-badge&logo=swift)](./JassyNote)
[![PDF Workflow](https://img.shields.io/badge/PDF-import%20%E2%86%92%20layout%20%E2%86%92%20export-2E7D32?style=for-the-badge)](./JassyNote)

</div>

## Overview

JassyNote is a native SwiftUI app that turns lecture slide decks into dense, review-friendly handouts.

Instead of printing one oversized slide per sheet, it imports a deck, arranges slides into compact paper columns, and exports a brand-new PDF that is easier to annotate, print, and study from.

This repository already includes a working end-to-end PDF workflow:

- import a slide deck as `PDF`
- render each slide safely as an image
- place slides into compact paper pages
- preview the generated handout
- share or export the final PDF

## Why It’s Useful

Lecture slides are usually built for screens, not for paper.

JassyNote makes them feel like actual notes:

- more slides per sheet
- cleaner paper proportions
- adjustable spacing and margins
- printer-friendly output
- fast PDF preview and export on-device

## Quick Start

### Run In Xcode

1. Open `JassyNote.xcodeproj`
2. Select an iPhone, iPad, or simulator
3. Set your signing team in `Signing & Capabilities`
4. Build and run

### Use The App

1. Tap `Import PDF or PowerPoint`
2. Select a deck from Files
3. Adjust the layout settings
4. Tap `Regenerate PDF` if needed
5. Preview the result
6. Share, print, or save the generated PDF

## Feature Highlights

### Input

| Format | Status | Notes |
| --- | --- | --- |
| `PDF` | Supported | Fully working import, rendering, layout, preview, and export |
| `PPT` / `PPTX` | Accepted gracefully | User is told to export as PDF first in this version |

### Layout Controls

| Setting | Notes |
| --- | --- |
| Paper size | `A4`, `Letter` |
| Orientation | `Portrait`, `Landscape` |
| Columns | Configurable, default `2` |
| Margins | Supports `0` |
| Column gutter | Supports `0` |
| Vertical spacing | Adjustable |
| Minimum readable slide height | Adjustable |
| Slide border | Optional |
| Paper background | `Off`, `Grid`, `Ruled` |
| Paper color | `White`, `Match Deck`, `Pick from Slide` |

### Output

- Generates a real PDF using `UIGraphicsPDFRenderer`
- Saves to a local temporary file
- Opens in an in-app `PDFKit` preview
- Shares through the standard iOS share sheet

## Paper Color Modes

JassyNote supports three different paper color styles:

- `White`
  Clean, neutral paper background
- `Match Deck`
  Estimates a dominant non-white tone from the imported slides
- `Pick from Slide`
  Lets the user tap directly on a rendered slide and sample a paper color manually

This makes it easy to create handouts that visually match the original deck without hardcoding a theme.

## How The Layout Engine Works

For each output page, JassyNote:

1. Calculates the usable paper area from the selected size, margins, and orientation
2. Divides the usable area into columns using the selected gutter
3. Scales each slide to fit the current column width while preserving aspect ratio
4. Stacks slides from top to bottom
5. Moves to the next column when the next slide no longer fits
6. Creates a new page when all columns are full

The renderer is designed to avoid:

- cropping
- overlap
- distortion
- cut-off slides

## Project Structure

```text
JassyNote/
├── JassyNoteApp.swift
├── ContentView.swift
├── HandoutViewModel.swift
├── SlideSourceImporter.swift
├── PDFSlideImporter.swift
├── PowerPointSlideImporter.swift
├── SlideImage.swift
├── LayoutSettings.swift
├── DeckColorAnalyzer.swift
├── SlideColorPickerView.swift
├── GeneratedPageLayout.swift
├── TwoColumnLayoutEngine.swift
├── PDFHandoutRenderer.swift
├── PDFPreviewView.swift
└── Info.plist
```

## Architecture

### UI Layer

- `ContentView.swift`
  Main import, settings, preview, and export flow
- `PDFPreviewView.swift`
  SwiftUI bridge for `PDFKit`
- `SlideColorPickerView.swift`
  Manual color sampling UI from rendered slides

### State And Workflow

- `HandoutViewModel.swift`
  Coordinates import, color detection, rendering, regeneration, and error handling

### Importers

- `SlideSourceImporter.swift`
  Shared importer protocol
- `PDFSlideImporter.swift`
  Production importer for PDF decks
- `PowerPointSlideImporter.swift`
  Explicit unsupported path for PowerPoint files in this version

### Layout And Rendering

- `TwoColumnLayoutEngine.swift`
  Deterministic slide placement
- `GeneratedPageLayout.swift`
  Layout models used during rendering
- `PDFHandoutRenderer.swift`
  Final PDF output generation

### Models And Utilities

- `SlideImage.swift`
  Rendered slide representation
- `LayoutSettings.swift`
  All user-configurable paper and layout options
- `DeckColorAnalyzer.swift`
  Estimates deck color for paper tinting

## Local Device Install

You can run the app on your own iPhone or iPad from Xcode without paying for the Apple Developer Program, using a free `Personal Team`.

Typical setup:

1. Add your Apple account in `Xcode > Settings > Accounts`
2. Select your `Personal Team` in `Signing & Capabilities`
3. Use a unique bundle identifier such as `com.yourname.jassynote`
4. Connect the device to your Mac
5. Trust the Mac on the device if prompted
6. Select the device as the run destination
7. Press `Run`

This is suitable for personal testing, not public distribution.

## Current Limitations

- Native PowerPoint rendering is not implemented yet
- `PPT` / `PPTX` users must export to `PDF` first
- The app currently focuses on local-device processing
- Free Xcode personal signing is limited to local testing workflows

## Roadmap

- Real PowerPoint conversion through a backend or LibreOffice-based pipeline
- More paper presets and handout layouts
- Notes lines or writing space beside slides
- Saved presets
- Mac Catalyst or native macOS support
- Batch export workflows

## Status

The current version is already useful as a working first release for PDF-based lecture handouts.

It is honest about what works today:

- PDF import works
- PDF output works
- PowerPoint conversion is not faked
- unsupported files fail gracefully

## License

No license file has been added yet.

If you plan to publish the repository publicly, add a license that matches how you want others to use the project.
