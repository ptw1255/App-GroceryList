import SwiftUI
import PhotosUI
import UIKit

struct ContentView: View {
    @StateObject private var viewModel = GroceryDashboardViewModel()
    @State private var photoPickerItems: [PhotosPickerItem] = []

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [
                        Color(hex: "0B1016"),
                        Color(hex: "101824"),
                        Color(hex: "161B22")
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        heroSection
                        metricsSection
                        actionSection
                        selectedImagesSection
                        statusSection
                        shoppingListSection
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 28)
                }
            }
            .navigationTitle("Grocery OCR")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onChange(of: photoPickerItems) { _, _ in
            Task {
                await importPickedImages()
            }
        }
    }

    private var heroSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Grocery OCR")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Text("Scan recipe images, review the extracted ingredients, and ship a clean Imperial shopping list.")
                .font(.system(size: 15, weight: .regular, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.72))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(hex: "151D29").opacity(0.94))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
    }

    private var metricsSection: some View {
        HStack(spacing: 12) {
            MetricCard(title: "Images", value: "\(viewModel.selectedImages.count)", tint: Color(hex: "7FD1B9"))
            MetricCard(title: "Rows", value: "\(viewModel.shoppingEntries.count)", tint: Color(hex: "F6C177"))
            MetricCard(title: "Review", value: "\(reviewCount)", tint: Color(hex: "E56B6F"))
        }
    }

    private var actionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                PhotosPicker(selection: $photoPickerItems, matching: .images) {
                    ActionButtonLabel(
                        icon: "photo.on.rectangle.angled",
                        title: "Add images",
                        subtitle: "Choose recipe pages"
                    )
                }

                Button {
                    viewModel.scanSelectedImages()
                } label: {
                    ActionButtonLabel(
                        icon: "sparkles",
                        title: "Run scan",
                        subtitle: "Parse and group"
                    )
                }
                .buttonStyle(.plain)
                .disabled(!viewModel.hasSelectedImages)
                .opacity(viewModel.hasSelectedImages ? 1 : 0.5)
            }

            HStack(spacing: 12) {
                if let exportURL = viewModel.exportURL {
                    ShareLink(item: exportURL) {
                        ActionButtonLabel(
                            icon: "square.and.arrow.up",
                            title: "Export CSV",
                            subtitle: "Share the list"
                        )
                    }
                    .buttonStyle(.plain)
                } else {
                    ActionButtonLabel(
                        icon: "square.and.arrow.up",
                        title: "Export CSV",
                        subtitle: "Available after scan"
                    )
                    .opacity(0.45)
                }

                Button(role: .destructive) {
                    viewModel.clearAll()
                } label: {
                    ActionButtonLabel(
                        icon: "trash",
                        title: "Clear local data",
                        subtitle: "Reset scan history"
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var selectedImagesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Selected Images", subtitle: "Tap the x to remove a page")

            if viewModel.selectedImages.isEmpty {
                EmptyStateCard(
                    title: "No images selected",
                    subtitle: "Import a recipe page or ingredient card to start."
                )
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(Array(viewModel.selectedImages.enumerated()), id: \.offset) { index, image in
                            SelectedImageCard(image: image) {
                                viewModel.removeImage(at: index)
                            }
                        }
                    }
                }
            }
        }
    }

    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Scan Status", subtitle: viewModel.latestSummary)

            statusCard

            if let errorMessage = viewModel.errorMessage {
                ErrorCard(message: errorMessage)
            }
        }
    }

    @ViewBuilder
    private var statusCard: some View {
        switch viewModel.scanState {
        case .idle:
            StatusCard(title: "Idle", detail: "Ready when you are.", icon: "circle.dashed")
        case .empty:
            StatusCard(title: "Nothing to scan", detail: "Select at least one image.", icon: "photo")
        case .ready:
            StatusCard(title: "Ready", detail: "Shopping rows are loaded and ready.", icon: "checkmark.seal")
        case .failed(let message):
            StatusCard(title: "Scan failed", detail: message, icon: "exclamationmark.triangle")
        case .processing(let progress, let total):
            ProcessingCard(progress: progress, total: total)
        }
    }

    private var shoppingListSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Shopping List", subtitle: "Imperial shopping output with traceable demand")

            if viewModel.shoppingEntries.isEmpty {
                EmptyStateCard(
                    title: "No shopping rows yet",
                    subtitle: "Your grouped ingredients will appear here after a scan."
                )
            } else {
                VStack(spacing: 12) {
                    ForEach(viewModel.shoppingEntries) { entry in
                        ShoppingEntryCard(entry: entry) {
                            viewModel.deleteEntry(entry)
                        }
                    }
                }
            }
        }
    }

    private var reviewCount: Int {
        viewModel.shoppingEntries.filter { $0.ingredient.needsReview }.count
    }

    private func importPickedImages() async {
        let items = photoPickerItems
        guard !items.isEmpty else { return }

        var newImages: [UIImage] = []
        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                newImages.append(image)
            }
        }

        if !newImages.isEmpty {
            viewModel.addImages(newImages)
        }

        photoPickerItems = []
    }
}

private struct SectionHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
            Text(subtitle)
                .font(.system(size: 13, weight: .regular, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.65))
        }
    }
}

private struct MetricCard: View {
    let title: String
    let value: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.58))
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(tint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(hex: "182030"))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(tint.opacity(0.24), lineWidth: 1)
                )
        )
    }
}

private struct ActionButtonLabel: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(hex: "212A39"))
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color(hex: "F6C177"))
            }
            .frame(width: 42, height: 42)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.system(size: 12, weight: .regular, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.62))
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 76, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(hex: "161F2D"))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
    }
}

private struct EmptyStateCard: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
            Text(subtitle)
                .font(.system(size: 13, weight: .regular, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.62))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(hex: "161F2D"))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
    }
}

private struct StatusCard: View {
    let title: String
    let detail: String
    let icon: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color(hex: "7FD1B9"))
                .frame(width: 30, height: 30)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                Text(detail)
                    .font(.system(size: 13, weight: .regular, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.68))
            }

            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(hex: "161F2D"))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
    }
}

private struct ProcessingCard: View {
    let progress: Int
    let total: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Processing")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                Spacer()
                Text("\(progress)/\(max(total, 1))")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.65))
            }

            ProgressView(value: Double(progress), total: Double(max(total, 1)))
                .tint(Color(hex: "F6C177"))
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(hex: "161F2D"))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
    }
}

private struct ErrorCard: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.system(size: 13, weight: .regular, design: .rounded))
            .foregroundStyle(Color(hex: "FFB4B4"))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color(hex: "2A1719"))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(Color(hex: "E56B6F").opacity(0.25), lineWidth: 1)
                    )
            )
    }
}

private struct SelectedImageCard: View {
    let image: UIImage
    let removeAction: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 130, height: 170)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

            Button(action: removeAction) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(Color.white)
                    .shadow(radius: 4)
            }
            .padding(8)
        }
    }
}

private struct ShoppingEntryCard: View {
    let entry: ShoppingListEntry
    let deleteAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(entry.displayTitle)
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                    Text(entry.details)
                        .font(.system(size: 13, weight: .regular, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.72))
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                Text(entry.badge)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(hex: "0B1016"))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule(style: .continuous)
                            .fill(Color(hex: "F6C177"))
                    )
            }

            if entry.ingredient.needsReview {
                Text("Review needed")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color(hex: "FFB4B4"))
            }

            Text(entry.ingredient.explanation)
                .font(.system(size: 12, weight: .regular, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.56))

            HStack {
                Text("Sources: \(entry.ingredient.sourceTexts.count)")
                    .font(.system(size: 11, weight: .regular, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.55))

                Spacer()

                Button(role: .destructive, action: deleteAction) {
                    Image(systemName: "trash")
                        .font(.system(size: 14, weight: .semibold))
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(hex: "161F2D"))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
    }
}

private extension Color {
    init(hex: String) {
        let value = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: value).scanHexInt64(&int)
        let r, g, b: UInt64
        switch value.count {
        case 6:
            (r, g, b) = ((int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default:
            (r, g, b) = (0, 0, 0)
        }
        self.init(
            red: Double(r) / 255.0,
            green: Double(g) / 255.0,
            blue: Double(b) / 255.0
        )
    }
}
