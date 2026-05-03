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
                        regenerateButton

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
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                        regenerateButton
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
            regenerateButton

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
                        .ignoresSafeArea(edges: .bottom)

                    compactStatusCard
                        .padding(.horizontal, 16)
                        .padding(.top, 10)
                }
            } else if viewModel.isImporting || viewModel.isGenerating {
                compactWorkingState
            } else {
                compactEmptyState
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var compactStatusCard: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(viewModel.sourceFileName)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .truncationMode(.middle)

                Text(viewModel.slideCountDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                showingCompactSettings = true
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.body.weight(.semibold))
                    .frame(width: 34, height: 34)
            }
            .buttonStyle(.bordered)
            .accessibilityLabel("Layout")
        }
        .padding(.leading, 12)
        .padding(.trailing, 8)
        .padding(.vertical, 8)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
        )
    }

    private var compactWorkingState: some View {
        VStack(spacing: 14) {
            ProgressView()
                .controlSize(.large)

            Text(viewModel.isImporting ? "Loading slides" : "Generating handout")
                .font(.headline)

            Text(viewModel.sourceFileName)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
                .padding(.horizontal, 28)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var compactEmptyState: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Create a notes handout")
                        .font(.title2.weight(.bold))
                        .fixedSize(horizontal: false, vertical: true)

                    Text("Import a PDF deck, choose the paper layout, then export a compact handout.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                compactPreviewMockup

                Button {
                    showingImporter = true
                } label: {
                    Label("Import PDF or PowerPoint", systemImage: "square.and.arrow.down")
                        .font(.headline)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                        .frame(maxWidth: .infinity, minHeight: 48)
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isImporting || viewModel.isGenerating)

                compactSetupSummary
            }
            .padding(.horizontal, 20)
            .padding(.top, 22)
            .padding(.bottom, 18)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var compactPreviewMockup: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("Preview")
                    .font(.headline)

                Spacer()

                Text("\(viewModel.settings.columns) columns")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 12) {
                ForEach(0..<2, id: \.self) { column in
                    VStack(spacing: 8) {
                        ForEach(0..<3, id: \.self) { row in
                            compactMockSlide(column: column, row: row)
                        }
                    }
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity)
            .background(Color(uiColor: .systemBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.secondary.opacity(0.12), lineWidth: 1)
            )
        }
        .padding(14)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func compactMockSlide(column: Int, row: Int) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            RoundedRectangle(cornerRadius: 2)
                .fill(row == 0 ? Color.blue.opacity(0.85) : Color.secondary.opacity(0.32))
                .frame(width: row == 0 ? 54 : 40, height: 5)

            RoundedRectangle(cornerRadius: 2)
                .fill(Color.secondary.opacity(0.18))
                .frame(height: 4)

            RoundedRectangle(cornerRadius: 2)
                .fill(Color.secondary.opacity(0.14))
                .frame(width: column == 0 ? 70 : 58, height: 4)
        }
        .padding(8)
        .frame(maxWidth: .infinity, minHeight: 54, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.blue.opacity(row == 0 ? 0.08 : 0.04))
        )
    }

    private var compactSetupSummary: some View {
        VStack(spacing: 10) {
            compactSummaryRow(
                title: "Paper",
                value: "\(viewModel.settings.paperSize.rawValue), \(viewModel.settings.orientation.rawValue)",
                systemImage: "doc.plaintext"
            )

            compactSummaryRow(
                title: "Quality",
                value: viewModel.settings.outputQuality.rawValue,
                systemImage: "slider.horizontal.below.rectangle"
            )

            compactSummaryRow(
                title: "Background",
                value: viewModel.settings.backgroundStyle.rawValue,
                systemImage: "square.grid.3x3"
            )
        }
    }

    private func compactSummaryRow(title: String, value: String, systemImage: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.blue)
                .frame(width: 28, height: 28)
                .background(Color.blue.opacity(0.1), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            Text(title)
                .font(.subheadline)

            Spacer()

            Text(value)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var compactBottomBar: some View {
        VStack(spacing: 8) {
            if viewModel.isGenerating {
                ProgressView("Generating PDF…")
                    .font(.caption)
            }

            HStack(spacing: 8) {
                compactActionButton(
                    title: "Layout",
                    systemImage: "slider.horizontal.3",
                    isDisabled: false
                ) {
                    showingCompactSettings = true
                }

                compactActionButton(
                    title: "Regenerate",
                    systemImage: "arrow.clockwise",
                    isDisabled: !viewModel.canGenerate
                ) {
                    Task {
                        await viewModel.regenerate()
                    }
                }

                if let generatedPDFURL = viewModel.generatedPDFURL {
                    compactShareButton(url: generatedPDFURL)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 6)
        .background(.regularMaterial)
    }

    private func compactActionButton(
        title: String,
        systemImage: String,
        isDisabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            compactActionLabel(title: title, systemImage: systemImage)
        }
        .buttonStyle(.bordered)
        .disabled(isDisabled)
        .frame(maxWidth: .infinity)
    }

    private func compactShareButton(url: URL) -> some View {
        ShareLink(item: url) {
            compactActionLabel(title: "Share", systemImage: "square.and.arrow.up")
        }
        .buttonStyle(.borderedProminent)
        .frame(maxWidth: .infinity)
    }

    private func compactActionLabel(title: String, systemImage: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.subheadline.weight(.semibold))

            Text(title)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity, minHeight: 42)
        .contentShape(Rectangle())
    }

    private var regenerateButton: some View {
        Button {
            Task {
                await viewModel.regenerate()
            }
        } label: {
            Text("Regenerate")
        }
        .disabled(!viewModel.canGenerate)
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
