# JassyNote

Native iPadOS SwiftUI app that imports a PDF slide deck and generates a compact printable handout PDF with multi-slide two-column pages.

## Project Layout

- `JassyNote/JassyNoteApp.swift`: app entry point
- `JassyNote/ContentView.swift`: main UI, file import, settings, preview controls
- `JassyNote/HandoutViewModel.swift`: async import/generate workflow and error handling
- `JassyNote/SlideSourceImporter.swift`: importer protocol and shared errors
- `JassyNote/PDFSlideImporter.swift`: working PDF importer and page rasterizer
- `JassyNote/PowerPointSlideImporter.swift`: explicit unsupported PPT/PPTX importer
- `JassyNote/SlideImage.swift`: slide image model
- `JassyNote/LayoutSettings.swift`: paper and layout settings
- `JassyNote/DeckColorAnalyzer.swift`: dominant deck color detection for paper tinting
- `JassyNote/GeneratedPageLayout.swift`: layout output models
- `JassyNote/TwoColumnLayoutEngine.swift`: deterministic column/page packing
- `JassyNote/PDFHandoutRenderer.swift`: final PDF generation
- `JassyNote/PDFPreviewView.swift`: PDFKit preview bridge
- `JassyNote/Info.plist`: app settings and document types

## Open In Xcode

1. Open `JassyNote.xcodeproj`.
2. Choose an iPad simulator or a real iPad target.
3. Build and run.
4. Tap `Import PDF or PowerPoint`.
5. Pick a `.pdf`, `.ppt`, or `.pptx`.
6. For `.pdf`, the app imports slides and generates a handout PDF automatically.
7. For `.ppt` or `.pptx`, the app shows a clear message that PDF export is required in this version.

## Notes

- This version fully supports PDF import and PDF export.
- PowerPoint conversion is intentionally not faked. The app is structured so a future converter can replace `PowerPointSlideImporter`.
- The generated PDF is written to the app's temporary directory and can be previewed, shared, printed, or saved from the share sheet.
