import SwiftUI
import UIKit

struct ContentView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @StateObject private var viewModel = HandoutViewModel()
    @State private var showingImporter = false
    @State private var showingColorPicker = false
    @State private var showingCompactSettings = false

    var body: some View {
        Group {
            if usesCompactLayout {
                compactLayout
            } else {
                regularLayout
            }
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
        .sheet(isPresented: $showingCompactSettings) {
            compactSettingsSheet
        }
    }

    private var usesCompactLayout: Bool {
        UIDevice.current.userInterfaceIdiom == .phone || horizontalSizeClass == .compact
    }

    private var regularLayout: some View {
        NavigationSplitView {
            settingsForm(includeActions: true)
                .navigationTitle("Paper Notes")
        } detail: {
            previewPanel
                .navigationTitle("Preview")
                .toolbar {
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        regenerateButton(style: .titleOnly)

                        if let generatedPDFURL = viewModel.generatedPDFURL {
                            ShareLink(item: generatedPDFURL) {
                                Image(systemName: "square.and.arrow.up")
                            }
                        }
                    }
                }
        }
    }

    private var compactLayout: some View {
        NavigationStack {
            ZStack {
                Color(uiColor: .systemGroupedBackground)
                    .ignoresSafeArea()

                compactPreviewPanel
            }
            .navigationTitle("JassyNote")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showingImporter = true
                    } label: {
                        Label("Import", systemImage: "square.and.arrow.down")
                    }
                    .disabled(viewModel.isImporting || viewModel.isGenerating)
                }

                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        showingCompactSettings = true
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                    }

                    if let generatedPDFURL = viewModel.generatedPDFURL {
                        ShareLink(item: generatedPDFURL) {
                            Image(systemName: "square.and.arrow.up")
                        }
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                compactBottomBar
            }
        }
    }

    private var compactSettingsSheet: some View {
        NavigationStack {
            settingsForm(includeActions: false)
                .navigationTitle("Layout")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Close") {
                            showingCompactSettings = false
                        }
                    }

                    ToolbarItem(placement: .topBarTrailing) {
                        regenerateButton(style: .titleOnly)
                    }
                }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private func settingsForm(includeActions: Bool) -> some View {
        Form {
            sourceSection
            layoutSection

            if includeActions {
                actionsSection
            }
        }
    }

    private var sourceSection: some View {
        Section("Source") {
            Button {
                showingImporter = true
            } label: {
                Label("Import PDF or PowerPoint", systemImage: "square.and.arrow.down")
            }
            .disabled(viewModel.isImporting || viewModel.isGenerating)

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

            if let readabilityStatus = viewModel.readabilityStatus {
                Text(readabilityStatus)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
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
                Slider(value: $viewModel.settings.minimumReadableSlideHeight.doubleBinding, in: 72...220, step: 2)
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

            Picker("PDF Quality", selection: $viewModel.settings.outputQuality) {
                ForEach(OutputQualityOption.allCases) { quality in
                    Text(quality.rawValue).tag(quality)
                }
            }
        }
    }

    private var actionsSection: some View {
        Section("Actions") {
            regenerateButton(style: .titleOnly)

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

    private var previewPanel: some View {
        Group {
            if let generatedPDFURL = viewModel.generatedPDFURL {
                PDFPreviewView(url: generatedPDFURL)
                    .ignoresSafeArea(edges: .bottom)
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

    private var compactPreviewPanel: some View {
        Group {
            if let generatedPDFURL = viewModel.generatedPDFURL {
                ZStack(alignment: .top) {
                    PDFPreviewView(url: generatedPDFURL)

                    compactStatusCard
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                }
            } else if viewModel.isImporting || viewModel.isGenerating {
                ProgressView("Working…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Readable notes from dense slide decks.")
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                                .fixedSize(horizontal: false, vertical: true)

                            Text("Import a lecture deck, keep small text legible, and export a lighter PDF that is easier to share.")
                                .font(.body)
                                .foregroundStyle(.secondary)
                        }

                        VStack(spacing: 12) {
                            compactFeatureRow(
                                title: "Readability-first layout",
                                message: "The app will reduce columns automatically when your minimum slide height would otherwise be violated."
                            )

                            compactFeatureRow(
                                title: "Smaller shared files",
                                message: "Export quality stays adjustable so you can trade some sharpness for a lower file size when needed."
                            )
                        }

                        Button {
                            showingImporter = true
                        } label: {
                            Label("Import a Deck", systemImage: "square.and.arrow.down")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .disabled(viewModel.isImporting || viewModel.isGenerating)
                    }
                    .padding(20)
                }
            }
        }
    }

    private var compactStatusCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(viewModel.sourceFileName)
                        .font(.headline)
                        .lineLimit(1)

                    Text(viewModel.slideCountDescription)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    showingCompactSettings = true
                } label: {
                    Label("Layout", systemImage: "slider.horizontal.3")
                }
                .buttonStyle(.bordered)
            }

            if let readabilityStatus = viewModel.readabilityStatus {
                Label(readabilityStatus, systemImage: "textformat.size")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.white.opacity(0.16), lineWidth: 1)
        )
    }

    private func compactFeatureRow(title: String, message: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.headline)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var compactBottomBar: some View {
        VStack(spacing: 10) {
            if viewModel.isGenerating {
                ProgressView("Generating PDF…")
            }

            HStack(spacing: 10) {
                Button {
                    showingCompactSettings = true
                } label: {
                    Label("Layout", systemImage: "slider.horizontal.3")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)

                regenerateButton(style: .titleAndIcon)
                    .frame(maxWidth: .infinity)

                if let generatedPDFURL = viewModel.generatedPDFURL {
                    ShareLink(item: generatedPDFURL) {
                        Label("Share", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(.thinMaterial)
    }

    private func regenerateButton(style: ButtonLabelStyle) -> some View {
        Group {
            if style == .titleOnly {
                Button {
                    Task {
                        await viewModel.regenerate()
                    }
                } label: {
                    buttonLabel("Regenerate", systemImage: "arrow.clockwise", style: style)
                }
            } else {
                Button {
                    Task {
                        await viewModel.regenerate()
                    }
                } label: {
                    buttonLabel("Regenerate", systemImage: "arrow.clockwise", style: style)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
        }
        .disabled(!viewModel.canGenerate)
    }

    @ViewBuilder
    private func buttonLabel(_ title: String, systemImage: String, style: ButtonLabelStyle) -> some View {
        switch style {
        case .titleOnly:
            Text(title)
        case .titleAndIcon:
            Label(title, systemImage: systemImage)
        }
    }
}

private enum ButtonLabelStyle: Equatable {
    case titleOnly
    case titleAndIcon
}

private extension Binding where Value == CGFloat {
    var doubleBinding: Binding<Double> {
        Binding<Double>(
            get: { Double(wrappedValue) },
            set: { wrappedValue = CGFloat($0) }
        )
    }
}
