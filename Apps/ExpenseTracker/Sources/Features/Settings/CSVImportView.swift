import SwiftUI
import SharedUI
import UniformTypeIdentifiers

struct CSVImportView: View {
    @State private var viewModel: CSVImportViewModel

    init(viewModel: CSVImportViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        VStack(spacing: WPSpacing.lg) {
            if viewModel.showSummary {
                summaryView
            } else {
                instructionsView
            }
        }
        .padding(WPSpacing.md)
        .navigationTitle("Import CSV")
        .navigationBarTitleDisplayMode(.inline)
        .fileImporter(
            isPresented: $viewModel.showFilePicker,
            allowedContentTypes: [UTType.commaSeparatedText],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    viewModel.importCSV(url: url)
                }
            case .failure(let error):
                viewModel.errorMessage = error.localizedDescription
            }
        }
    }

    private var instructionsView: some View {
        VStack(spacing: WPSpacing.lg) {
            Image(systemName: "doc.text")
                .font(.wpIconDecorative)
                .foregroundStyle(Color.wpTextTertiary)

            VStack(spacing: WPSpacing.xs) {
                Text("Import Transactions")
                    .font(.wpHeadline)
                Text("Select a CSV file with the following columns:")
                    .font(.wpCallout)
                    .foregroundStyle(Color.wpTextSecondary)
                    .multilineTextAlignment(.center)
            }

            VStack(alignment: .leading, spacing: WPSpacing.xs) {
                columnLabel("title", required: true)
                columnLabel("amount", required: true)
                columnLabel("account", required: true)
                columnLabel("category", required: true)
                columnLabel("date", required: true)
                columnLabel("currency", required: false)
                columnLabel("hashtags", required: false)
                columnLabel("exchange_rate", required: false)
                columnLabel("notes", required: false)
            }
            .padding(WPSpacing.md)
            .background(Color.wpSurface)
            .clipShape(RoundedRectangle(cornerRadius: WPCornerRadius.small))

            if let error = viewModel.errorMessage {
                ErrorBanner(message: error) {
                    viewModel.errorMessage = nil
                }
            }

            Spacer()

            Button {
                viewModel.showFilePicker = true
            } label: {
                if viewModel.isImporting {
                    ProgressView()
                        .tint(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                } else {
                    Text("Select CSV File")
                        .font(.wpHeadline)
                        .foregroundStyle(Color.wpOnPrimary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                }
            }
            .background(Color.wpPrimary)
            .clipShape(RoundedRectangle(cornerRadius: WPCornerRadius.small))
            .disabled(viewModel.isImporting)
        }
    }

    private var summaryView: some View {
        VStack(spacing: WPSpacing.lg) {
            Image(systemName: viewModel.errorCount == 0 ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .font(.wpIconDecorative)
                .foregroundStyle(viewModel.errorCount == 0 ? Color.wpSuccess : Color.wpWarning)

            Text("Import Complete")
                .font(.wpTitle)

            VStack(spacing: WPSpacing.sm) {
                summaryRow("Imported", count: viewModel.importedCount, color: Color.wpSuccess)
                summaryRow("Duplicates skipped", count: viewModel.duplicateCount, color: Color.wpTextSecondary)
                summaryRow("Errors", count: viewModel.errorCount, color: Color.wpError)
            }
            .padding(WPSpacing.md)
            .background(Color.wpSurface)
            .clipShape(RoundedRectangle(cornerRadius: WPCornerRadius.small))

            if !viewModel.errorDetails.isEmpty {
                ScrollView {
                    VStack(alignment: .leading, spacing: WPSpacing.xxs) {
                        ForEach(viewModel.errorDetails.prefix(20), id: \.self) { detail in
                            Text(detail)
                                .font(.wpCaption)
                                .foregroundStyle(Color.wpError)
                        }
                        if viewModel.errorDetails.count > 20 {
                            Text("...and \(viewModel.errorDetails.count - 20) more")
                                .font(.wpCaption)
                                .foregroundStyle(Color.wpTextTertiary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 150)
                .padding(WPSpacing.sm)
                .background(Color.wpSurface)
                .clipShape(RoundedRectangle(cornerRadius: WPCornerRadius.small))
            }

            Spacer()

            Button {
                viewModel.reset()
            } label: {
                Text("Import Another File")
                    .font(.wpHeadline)
                    .foregroundStyle(Color.wpOnPrimary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
            }
            .background(Color.wpPrimary)
            .clipShape(RoundedRectangle(cornerRadius: WPCornerRadius.small))
        }
    }

    private func columnLabel(_ name: String, required: Bool) -> some View {
        HStack(spacing: WPSpacing.xs) {
            Text(name)
                .font(.wpBody.monospaced())
                .foregroundStyle(Color.wpTextPrimary)
            if required {
                Text("required")
                    .font(.wpCaption)
                    .foregroundStyle(Color.wpError)
            } else {
                Text("optional")
                    .font(.wpCaption)
                    .foregroundStyle(Color.wpTextTertiary)
            }
        }
    }

    private func summaryRow(_ label: String, count: Int, color: Color) -> some View {
        HStack {
            Text(label)
                .font(.wpBody)
            Spacer()
            Text("\(count)")
                .font(.wpHeadline)
                .foregroundStyle(color)
        }
    }
}
