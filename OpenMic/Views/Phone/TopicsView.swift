import SwiftUI

struct TopicsView: View {
    let onSelectPrompt: (String) -> Void
    @State private var searchText = ""
    @State private var appeared = false

    private var filteredCategories: [TopicCategory] {
        guard !searchText.isEmpty else {
            return TopicCatalog.categories
        }

        let query = searchText.lowercased()
        return TopicCatalog.categories.compactMap { category in
            let matchesCategory = category.name.lowercased().contains(query)

            let filteredSubs = category.subcategories.compactMap { sub in
                let matchesSub = sub.name.lowercased().contains(query)
                    || sub.description.lowercased().contains(query)

                let filteredPrompts = sub.prompts.filter {
                    $0.label.lowercased().contains(query)
                        || $0.text.lowercased().contains(query)
                }

                if matchesSub || !filteredPrompts.isEmpty {
                    return TopicSubcategory(
                        id: sub.id,
                        name: sub.name,
                        description: sub.description,
                        prompts: filteredPrompts.isEmpty ? sub.prompts : filteredPrompts
                    )
                }
                return nil
            }

            if matchesCategory {
                return category
            }

            if !filteredSubs.isEmpty {
                return TopicCategory(
                    id: category.id,
                    name: category.name,
                    icon: category.icon,
                    color: category.color,
                    subcategories: filteredSubs
                )
            }

            return nil
        }
    }

    private let columns = [
        GridItem(.flexible(), spacing: OpenMicTheme.Spacing.sm),
        GridItem(.flexible(), spacing: OpenMicTheme.Spacing.sm)
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                OpenMicTheme.Colors.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: OpenMicTheme.Spacing.md) {
                        if filteredCategories.isEmpty {
                            emptyState
                        } else {
                            LazyVGrid(columns: columns, spacing: OpenMicTheme.Spacing.sm) {
                                ForEach(Array(filteredCategories.enumerated()), id: \.element.id) { index, category in
                                    NavigationLink {
                                        TopicCategoryDetailView(
                                            category: category,
                                            onSelectPrompt: onSelectPrompt
                                        )
                                    } label: {
                                        TopicCategoryCard(category: category)
                                    }
                                    .buttonStyle(.plain)
                                    .opacity(appeared ? 1 : 0)
                                    .offset(y: appeared ? 0 : 16)
                                    .animation(
                                        .spring(response: 0.5, dampingFraction: 0.8)
                                            .delay(Double(index) * 0.04),
                                        value: appeared
                                    )
                                }
                            }
                        }
                    }
                    .padding(.horizontal, OpenMicTheme.Spacing.md)
                    .padding(.top, OpenMicTheme.Spacing.sm)
                    .padding(.bottom, OpenMicTheme.Spacing.xxxl)
                }
            }
            .navigationTitle("Topics")
            .searchable(
                text: $searchText,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Search topics and prompts"
            )
            .onAppear {
                withAnimation(.easeOut(duration: 0.4).delay(0.1)) {
                    appeared = true
                }
            }
        }
    }

    // MARK: - Empty State

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: OpenMicTheme.Spacing.md) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(OpenMicTheme.Colors.textTertiary)

            Text("No topics found")
                .font(OpenMicTheme.Typography.headline)
                .foregroundStyle(OpenMicTheme.Colors.textSecondary)

            Text("Try a different search term")
                .font(OpenMicTheme.Typography.caption)
                .foregroundStyle(OpenMicTheme.Colors.textTertiary)
        }
        .padding(.top, OpenMicTheme.Spacing.xxxl)
    }
}
