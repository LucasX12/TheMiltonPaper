import PDFKit
import SwiftUI

struct ThisWeekView: View {
    @ObservedObject private var issueService = IssueService.shared
    @State private var isFullScreen = false

    var body: some View {
        ZStack {
            Color.miltonBackground.ignoresSafeArea()

            if issueService.isLoading && issueService.document == nil {
                IssueReaderSkeleton()
            } else if let message = issueService.errorMessage,
                      issueService.document == nil {
                ErrorView(message: message) {
                    Task { await issueService.load(forceRefresh: true) }
                }
            } else if let document = issueService.document {
                PDFKitView(document: document)
                    .ignoresSafeArea(edges: .bottom)
                    .overlay(alignment: .topTrailing) {
                        IssueReaderButton(
                            icon: "arrow.up.left.and.arrow.down.right",
                            label: "Open issue full screen"
                        ) {
                            isFullScreen = true
                        }
                        .padding(12)
                    }
            }
        }
        .task { await issueService.load() }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { Task { await issueService.load(forceRefresh: true) } } label: {
                    Image(systemName: "arrow.clockwise").frame(width: 44, height: 44)
                }
                .accessibilityLabel("Refresh issue")
                .disabled(issueService.isLoading)
            }
        }
        .safeAreaInset(edge: .bottom) {
            if issueService.document != nil, issueService.errorMessage != nil {
                InlineRetryView(message: "Couldn't refresh. Showing the saved issue.") {
                    Task { await issueService.load(forceRefresh: true) }
                }.padding(.horizontal, 20).background(Color.miltonBackground)
            }
        }
        .fullScreenCover(isPresented: $isFullScreen) {
            if let document = issueService.document {
                FullScreenIssueView(document: document)
            }
        }
    }
}

struct IssuePromoView: View {
    @ObservedObject private var issueService = IssueService.shared
    @State private var isFullScreen = false

    var body: some View {
        Button {
            if issueService.document != nil {
                isFullScreen = true
            } else {
                Task {
                    await issueService.load(forceRefresh: true)
                    isFullScreen = issueService.document != nil
                }
            }
        } label: {
            HStack(alignment: .center, spacing: 18) {
                Group {
                    if let coverImage = issueService.coverImage {
                        Image(uiImage: coverImage)
                            .resizable()
                            .scaledToFill()
                    } else {
                        Rectangle()
                            .fill(Color.miltonRule.opacity(0.55))
                            .overlay {
                                Text("TMP")
                                    .font(.system(.title3, design: .serif, weight: .bold))
                                    .foregroundColor(.miltonSecondary)
                            }
                    }
                }
                .frame(width: 88, height: 116)
                .clipped()
                .overlay { Rectangle().stroke(Color.miltonRule, lineWidth: 1) }

                VStack(alignment: .leading, spacing: 7) {
                    Text("THIS WEEK'S ISSUE")
                        .font(.miltonLabel)
                        .tracking(0.7)
                        .foregroundColor(.miltonSecondary)

                    Text("Read the latest print edition")
                        .font(.miltonTitle)
                        .foregroundColor(.miltonText)
                        .multilineTextAlignment(.leading)

                    HStack(spacing: 6) {
                        Text(actionLabel)
                        Image(systemName: "arrow.up.right")
                    }
                    .font(.miltonCaption.weight(.semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(Color.miltonPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: MiltonLayout.cornerRadius, style: .continuous))
                    .padding(.top, 2)
                }

                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(issueService.isLoading && issueService.document == nil)
        .task { await issueService.load() }
        .fullScreenCover(isPresented: $isFullScreen) {
            if let document = issueService.document {
                FullScreenIssueView(document: document)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("This week's issue. \(actionLabel)")
        .accessibilityIdentifier("issue.promo")
    }

    private var actionLabel: String {
        if issueService.document != nil { return "Read full screen" }
        if issueService.isLoading { return "Loading issue…" }
        if issueService.errorMessage != nil { return "Couldn't load. Tap to retry." }
        return "Read full screen"
    }
}

private struct IssueReaderSkeleton: View {
    var body: some View {
        VStack(spacing: 12) {
            ShimmerView()
                .frame(maxWidth: 430)
                .aspectRatio(0.72, contentMode: .fit)
            Text("Loading this week's issue…")
                .font(.miltonCaption)
                .foregroundColor(.miltonSecondary)
        }
        .padding(MiltonLayout.gutter)
    }
}

private struct IssueReaderButton: View {
    let icon: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.miltonPrimary)
                .frame(width: 44, height: 44)
                .background(Color.miltonSurface)
                .clipShape(RoundedRectangle(cornerRadius: MiltonLayout.cornerRadius, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: MiltonLayout.cornerRadius, style: .continuous)
                        .stroke(Color.miltonRule, lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

struct FullScreenIssueView: View {
    @Environment(\.dismiss) private var dismiss
    let document: PDFDocument

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.miltonBackground.ignoresSafeArea()
            PDFKitView(document: document).ignoresSafeArea()
            IssueReaderButton(icon: "xmark", label: "Close full screen issue") {
                dismiss()
            }
            .safeAreaPadding(.top, 8)
            .padding(.trailing, 12)
        }
        .statusBarHidden(true)
        .persistentSystemOverlays(.hidden)
    }
}

private struct PDFKitView: UIViewRepresentable {
    let document: PDFDocument

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.displayMode = .singlePageContinuous
        view.autoScales = true
        view.displayDirection = .vertical
        view.backgroundColor = UIColor(Color.miltonBackground)
        return view
    }

    func updateUIView(_ uiView: PDFView, context: Context) {
        if uiView.document !== document {
            uiView.document = document
        }
    }
}
