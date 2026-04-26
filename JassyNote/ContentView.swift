import SwiftUI
import UIKit

struct ContentView: View {
    @StateObject private var viewModel = HandoutViewModel()
    @State private var showingImporter = false
    @State private var showingColorPicker = false

    var body: some View {
        NavigationSplitView {
            Form {
                sourceSection
                layoutSection
                actionsSection
            }
            .navigationTitle("Paper Notes")
        } detail: {
            previewSection
                .navigationTitle("Preview")
        }
        .fileImporter(
            isPresented: $showingImporter,
            allowedContentTypes: viewModel.allowedContentTypes
        ) { result in
            switch result {
            case .success(let url):
                viewModel.importDocument(from: url)
            case .failure(let error):
                viewModel.handleImporterError(error)
            }
        }
        .alert(item: $viewModel.activeAlert) { item in
            Alert(
                title: Text(item.title),
                message: Text(item.message),
                dismissButton: .default(Text("OK"))
            )
        }
        .sheet(isPresented: $showingColorPicker) {
            SlideColorPickerView(
                slides: viewModel.importedSlides,
                selectedColor: $viewModel.pickedPaperColor
            ) {
                showingColorPicker = false
                Task {
                    await viewModel.regenerate()
                }
            }
        }
    }

    private var sourceSection: some View {
        Section("Source") {
            Button("Import PDF or PowerPoint") {
                showingImporter = true
            }

            LabeledContent("File", value: viewModel.sourceFileName)
            LabeledContent("Status", value: viewModel.slideCountDescription)

            if viewModel.isImporting {
                ProgressView("Loading slides…")
            }
        }
    }

    private var layoutSection: some View {
        Section("Layout") {
            Picker("Paper Size", selection: $viewModel.settings.paperSize) {
                ForEach(PaperSizeOption.allCases) { size in
                    Text(size.rawValue).tag(size)
                }
            }

            Picker("Orientation", selection: $viewModel.settings.orientation) {
                ForEach(PageOrientationOption.allCases) { option in
                    Text(option.rawValue).tag(option)
                }
            }

            Stepper(value: $viewModel.settings.columns, in: 1...4) {
                LabeledContent("Columns", value: "\(viewModel.settings.columns)")
            }

            VStack(alignment: .leading, spacing: 8) {
                LabeledContent("Page Margin", value: "\(Int(viewModel.settings.pageMargins.top)) pt")
                Slider(
                    value: Binding(
                        get: { Double(viewModel.settings.pageMargins.top) },
                        set: { newValue in
                            let margin = CGFloat(newValue.rounded())
                            viewModel.settings.pageMargins = PageMargins(
                                top: margin,
                                leading: margin,
                                bottom: margin,
                                trailing: margin
                            )
                        }
                    ),
                    in: 0...60,
                    step: 1
                )
            }

            VStack(alignment: .leading, spacing: 8) {
                LabeledContent("Column Gutter", value: "\(Int(viewModel.settings.columnGutter)) pt")
                Slider(value: $viewModel.settings.columnGutter.doubleBinding, in: 0...40, step: 1)
            }

            VStack(alignment: .leading, spacing: 8) {
                LabeledContent("Vertical Spacing", value: "\(Int(viewModel.settings.verticalSpacing)) pt")
                Slider(value: $viewModel.settings.verticalSpacing.doubleBinding, in: 0...32, step: 1)
            }

            VStack(alignment: .leading, spacing: 8) {
                LabeledContent("Minimum Slide Height", value: "\(Int(viewModel.settings.minimumReadableSlideHeight)) pt")
                Slider(value: $viewModel.settings.minimumReadableSlideHeight.doubleBinding, in: 48...220, step: 2)
            }

            Toggle("Slide Border", isOn: $viewModel.settings.showsSlideBorder)

            Picker("Paper Color", selection: $viewModel.settings.paperColorMode) {
                ForEach(PaperColorMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }

            if viewModel.settings.paperColorMode == .deckDominant, !viewModel.importedSlides.isEmpty {
                HStack {
                    Text("Detected Deck Color")
                    Spacer()
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(uiColor: viewModel.detectedDeckColor))
                        .frame(width: 44, height: 24)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.secondary.opacity(0.25), lineWidth: 1)
                        )
                }
            }

            if viewModel.settings.paperColorMode == .pickedFromSlide, !viewModel.importedSlides.isEmpty {
                Button("Sample Color from Slide") {
                    showingColorPicker = true
                }

                HStack {
                    Text("Picked Color")
                    Spacer()
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(uiColor: viewModel.pickedPaperColor))
                        .frame(width: 44, height: 24)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.secondary.opacity(0.25), lineWidth: 1)
                        )
                }
            }

            Picker("Paper Background", selection: $viewModel.settings.backgroundStyle) {
                ForEach(PageBackgroundStyle.allCases) { style in
                    Text(style.rawValue).tag(style)
                }
            }
        }
    }

    private var actionsSection: some View {
        Section("Actions") {
            Button("Regenerate PDF") {
                Task {
                    await viewModel.regenerate()
                }
            }
            .disabled(!viewModel.canGenerate)

            if viewModel.isGenerating {
                ProgressView("Generating PDF…")
            }

            if let generatedPDFURL = viewModel.generatedPDFURL {
                ShareLink(item: generatedPDFURL) {
                    Label("Share / Export PDF", systemImage: "square.and.arrow.up")
                }
            }
        }
    }

    private var previewSection: some View {
        Group {
            if let generatedPDFURL = viewModel.generatedPDFURL {
                PDFPreviewView(url: generatedPDFURL)
                    .ignoresSafeArea(edges: .bottom)
                    .toolbar {
                        ToolbarItemGroup(placement: .topBarTrailing) {
                            Button("Regenerate") {
                                Task {
                                    await viewModel.regenerate()
                                }
                            }
                            .disabled(!viewModel.canGenerate)

                            ShareLink(item: generatedPDFURL) {
                                Image(systemName: "square.and.arrow.up")
                            }
                        }
                    }
            } else if viewModel.isImporting || viewModel.isGenerating {
                ProgressView("Working…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ContentUnavailableView(
                    "No Preview Yet",
                    systemImage: "doc.richtext",
                    description: Text("Import a PDF to generate a printable notes handout.")
                )
            }
        }
    }
}

private extension Binding where Value == CGFloat {
    var doubleBinding: Binding<Double> {
        Binding<Double>(
            get: { Double(wrappedValue) },
            set: { wrappedValue = CGFloat($0) }
        )
    }
}
