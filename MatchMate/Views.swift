import SwiftUI

struct MatchListView: View {
    @StateObject private var viewModel: MatchListViewModel

    init(viewModel: MatchListViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()

                content
            }
            .navigationTitle("Profile Matches")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Label(viewModel.isOnline ? "Online" : "Offline", systemImage: viewModel.isOnline ? "wifi" : "wifi.slash")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(viewModel.isOnline ? .green : .orange)
                }
            }
            .task {
                await viewModel.load()
            }
            .refreshable {
                await viewModel.load()
            }
            .alert("Something went wrong", isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading && viewModel.profiles.isEmpty {
            ProgressView("Loading matches...")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if viewModel.profiles.isEmpty {
            ContentUnavailableView(
                "No Matches",
                systemImage: "person.2.slash",
                description: Text("Pull to refresh when you are back online.")
            )
        } else {
            List {
                ForEach(viewModel.profiles) { profile in
                    MatchCardView(profile: profile) { decision in
                        viewModel.setDecision(decision, for: profile)
                    }
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .listRowBackground(Color.clear)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
    }
}

struct MatchCardView: View {
    let profile: MatchProfile
    let onDecision: (MatchDecision) -> Void

    private let brandColor = Color(red: 0.22, green: 0.67, blue: 0.78)

    var body: some View {
        VStack(spacing: 18) {
            profileImage

            VStack(spacing: 6) {
                Text(profile.name)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(brandColor)
                    .multilineTextAlignment(.center)

                Text("\(profile.age), \(profile.address)")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Text(profile.email)
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }

            if profile.decision == .pending {
                actionButtons
            } else {
                statusBanner
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 18)
        .padding(.top, 18)
        .padding(.bottom, profile.decision == .pending ? 22 : 0)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.12), radius: 10, x: 0, y: 4)
        )
        .overlay(alignment: .topTrailing) {
            if !profile.isSynced {
                Label("Pending sync", systemImage: "arrow.triangle.2.circlepath")
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.orange.opacity(0.14), in: Capsule())
                    .foregroundStyle(.orange)
                    .padding(12)
            }
        }
    }

    private var profileImage: some View {
        AsyncImage(url: profile.imageURL) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .scaledToFill()
            case .failure:
                Image(systemName: "person.crop.square")
                    .font(.system(size: 56))
                    .foregroundStyle(.secondary)
            case .empty:
                ProgressView()
            @unknown default:
                EmptyView()
            }
        }
        .frame(width: 156, height: 156)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var actionButtons: some View {
        HStack(spacing: 56) {
            decisionButton(systemName: "xmark", tint: .red, decision: .declined)
            decisionButton(systemName: "checkmark", tint: brandColor, decision: .accepted)
        }
        .padding(.top, 4)
    }

    private func decisionButton(systemName: String, tint: Color, decision: MatchDecision) -> some View {
        Button {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
                onDecision(decision)
            }
        } label: {
            Image(systemName: systemName)
                .font(.system(size: 34, weight: .medium))
                .frame(width: 76, height: 76)
                .foregroundStyle(tint)
                .background(Circle().stroke(tint, lineWidth: 3))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(decision == .accepted ? "Accept match" : "Decline match")
    }

    private var statusBanner: some View {
        Text(profile.decision.title)
            .font(.title3.weight(.semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 22)
            .background(profile.decision == .accepted ? brandColor : Color.gray)
            .clipShape(
                .rect(
                    topLeadingRadius: 0,
                    bottomLeadingRadius: 16,
                    bottomTrailingRadius: 16,
                    topTrailingRadius: 0
                )
            )
            .padding(.horizontal, -18)
    }
}
