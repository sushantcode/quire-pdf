import QuireKit
import SwiftUI

/// Pinned under the pages: what will be merged, how hard to compress it, and
/// the button that merges.
struct MergeBar: View {
    @Environment(MergeSession.self) private var session
    @Environment(ScreenState.self) private var screen

    var body: some View {
        @Bindable var session = session
        let pageCount = session.pages.count

        VStack(spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(pageCount.counted("page")) from \(session.files.count.counted("file"))")
                        .font(.subheadline.weight(.semibold))
                    Text(session.compression.detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                Picker("Compression", selection: $session.compression) {
                    ForEach(CompressionLevel.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.menu)
                .disabled(screen.isMerging)
                .accessibilityHint("How much to shrink the merged file")
            }

            Button {
                Task { await screen.merge(session) }
            } label: {
                HStack(spacing: 8) {
                    if screen.isMerging {
                        ProgressView().tint(.white)
                        Text("Merging…")
                    } else {
                        Image(systemName: "arrow.triangle.merge")
                        Text("Merge \(pageCount.counted("Page"))")
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(screen.isMerging || pageCount == 0)
            .accessibilityHint("Combines every page, in this order, into one PDF")
        }
        .frame(maxWidth: 640)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(.bar)
        .overlay(alignment: .top) { Divider() }
    }
}

/// Replaces the merge bar in Select mode: what is selected, and what to do with it.
struct SelectionBar: View {
    @Environment(MergeSession.self) private var session

    var body: some View {
        let ids = session.selectedPageIDs
        HStack {
            Button {
                withAnimation(.snappy) { session.movePagesToStart(ids) }
            } label: {
                Label("Move to Start", systemImage: "arrow.up.to.line")
            }
            Spacer()
            Text(ids.isEmpty ? "Select pages" : "\(ids.count.counted("page")) selected")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(ids.isEmpty ? .secondary : .primary)
            Spacer()
            Button {
                withAnimation(.snappy) { session.movePagesToEnd(ids) }
            } label: {
                Label("Move to End", systemImage: "arrow.down.to.line")
            }
            Button(role: .destructive) {
                withAnimation { session.removePages(ids) }
            } label: {
                Label("Delete", systemImage: "trash")
            }
            .padding(.leading, 12)
        }
        .labelStyle(.iconOnly)
        .font(.title3)
        .disabled(ids.isEmpty)
        .frame(maxWidth: 640)
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity)
        .background(.bar)
        .overlay(alignment: .top) { Divider() }
    }
}
