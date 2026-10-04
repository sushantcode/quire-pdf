import SwiftUI

/// The first screen, before any PDF is loaded.
struct EmptyStateView: View {
    @Environment(ScreenState.self) private var screen

    var body: some View {
        ContentUnavailableView {
            Label {
                Text("Merge PDFs")
            } icon: {
                Image("Logo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 88, height: 88)
                    .accessibilityHidden(true)
            }
        } description: {
            Text("Choose PDFs to combine. Arrange their pages in any order, then merge them into one file.")
        } actions: {
            Button {
                screen.isImporting = true
            } label: {
                Text("Choose PDFs")
                    .padding(.horizontal, 12)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            Text("You can also share a PDF to Quire PDF from Files, Mail or Safari.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.top, 8)
        }
    }
}
