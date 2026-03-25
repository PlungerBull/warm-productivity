import SwiftUI
import SharedUI
import UniformTypeIdentifiers

struct CSVImportView: View {
    @State private var viewModel: CSVImportViewModel

    init(viewModel: CSVImportViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        VStack(spacing: 0) {
            if viewModel.showSummary {
                summaryView
            } else {
                instructionsView
            }
        }
        .padding(.horizontal, WPSpacing.lg)
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

    // MARK: - Instructions

    private var instructionsView: some View {
        VStack(spacing: 0) {
            Spacer()

            Image(systemName: "doc.text")
                .font(.wpIconDecorative)
                .foregroundStyle(Color.wpTextTertiary)
                .padding(.bottom, WPSpacing.lg)

            Text("Import Transactions")
                .font(.wpTitle)
                .foregroundStyle(Color.wpTextPrimary)
                .padding(.bottom, WPSpacing.xxs)

            Text("Select a CSV file with the following columns:")
                .font(.wpCallout)
                .foregroundStyle(Color.wpTextSecondary)
                .multilineTextAlignment(.center)
                .padding(.bottom, WPSpacing.lg)

            // Column list
            VStack(alignment: .leading, spacing: WPSpacing.xs) {
                columnLabel("title", required: true)
                columnLabel("amount", required: true)
                columnLabel("account", required: true)
                columnLabel("category", required: true)
                columnLabel("date", required: true)
                Divider()
                columnLabel("currency", required: false)
                columnLabel("hashtags", required: false)
                columnLabel("exchange_rate", required: false)
                columnLabel("notes", required: false)
            }
            .padding(.horizontal, WPSpacing.md)
            .padding(.vertical, WPSpacing.sm)
            .background(Color.wpSurface)
            .clipShape(RoundedRectangle(cornerRadius: WPCornerRadius.medium))
            .overlay(
                RoundedRectangle(cornerRadius: WPCornerRadius.medium)
                    .stroke(Color.wpBorder, lineWidth: 0.5)
            )

            if let error = viewModel.errorMessage {
                ErrorBanner(message: error) {
                    viewModel.errorMessage = nil
                }
                .padding(.top, WPSpacing.md)
            }

            Spacer()
            Spacer()

            // CTA button
            Button {
                viewModel.showFilePicker = true
            } label: {
                if viewModel.isImporting {
                    ProgressView()
                        .tint(Color.wpOnPrimary)
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
            .clipShape(RoundedRectangle(cornerRadius: WPCornerRadius.medium))
            .disabled(viewModel.isImporting)
            .padding(.bottom, WPSpacing.xl)
        }
    }

    // MARK: - Summary

    private var summaryView: some View {
        VStack(spacing: 0) {
            Spacer()

            Image(systemName: viewModel.errorCount == 0 ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .font(.wpIconDecorative)
                .foregroundStyle(viewModel.errorCount == 0 ? Color.wpSuccess : Color.wpWarning)
                .padding(.bottom, WPSpacing.lg)

            Text("Import Complete")
                .font(.wpTitle)
                .foregroundStyle(Color.wpTextPrimary)
                .padding(.bottom, WPSpacing.lg)

            // Summary card
            VStack(spacing: 0) {
                summaryRow("Imported", count: viewModel.importedCount, color: Color.wpSuccess)
                Divider()
                summaryRow("Duplicates skipped", count: viewModel.duplicateCount, color: Color.wpTextSecondary)
                Divider()
                summaryRow("Errors", count: viewModel.errorCount, color: Color.wpError)
            }
            .padding(.horizontal, WPSpacing.md)
            .background(Color.wpSurface)
            .clipShape(RoundedRectangle(cornerRadius: WPCornerRadius.medium))
            .overlay(
                RoundedRectangle(cornerRadius: WPCornerRadius.medium)
                    .stroke(Color.wpBorder, lineWidth: 0.5)
            )

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
                .clipShape(RoundedRectangle(cornerRadius: WPCornerRadius.medium))
                .overlay(
                    RoundedRectangle(cornerRadius: WPCornerRadius.medium)
                        .stroke(Color.wpBorder, lineWidth: 0.5)
                )
                .padding(.top, WPSpacing.sm)
            }

            Spacer()
            Spacer()

            // Action button
            Button {
                viewModel.reset()
            } label: {
                Text("Import Another File")
                    .font(.wpHeadline)
                    .foregroundStyle(Color.wpPrimary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
            }
            .background(Color.wpPrimary.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: WPCornerRadius.medium))
            .padding(.bottom, WPSpacing.xl)
        }
    }

    // MARK: - Components

    private func columnLabel(_ name: String, required: Bool) -> some View {
        HStack(spacing: WPSpacing.xs) {
            Text(name)
                .font(.wpBody.monospaced())
                .foregroundStyle(Color.wpTextPrimary)
            Spacer()
            if required {
                Text("required")
                    .font(.wpCaption)
                    .foregroundStyle(Color.wpPrimary)
            } else {
                Text("optional")
                    .font(.wpCaption)
                    .foregroundStyle(Color.wpTextTertiary)
            }
        }
        .padding(.vertical, 2)
    }

    private func summaryRow(_ label: String, count: Int, color: Color) -> some View {
        HStack {
            Text(label)
                .font(.wpBody)
                .foregroundStyle(Color.wpTextPrimary)
            Spacer()
            Text("\(count)")
                .font(.wpHeadline)
                .foregroundStyle(color)
        }
        .padding(.vertical, WPSpacing.sm)
    }
}
