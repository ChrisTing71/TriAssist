//
//  MapRadarView.swift
//  TriAssist
//

import SwiftUI
import MapKit
import SwiftData
import TipKit
import CoreLocation

struct MapRadarView: View {
    @State private var viewModel = MapRadarViewModel()
    @Query private var todos: [TodoTask]
    @Query(sort: \ShoppingItem.name) private var shoppingItems: [ShoppingItem]

    private let tip = MapRadarTip()

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                mapLayer
                    .ignoresSafeArea(edges: .bottom)

                searchBar
                    .padding(.horizontal, 16)
                    .padding(.top, 12)

                if viewModel.isScanning {
                    radarRingsOverlay
                        .frame(maxHeight: .infinity)
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                bottomPanel
                    .padding(.bottom, 12)
            }
            .navigationTitle("Task Radar")
            .navigationBarTitleDisplayMode(.inline)
            .alert("需要位置權限", isPresented: $viewModel.showPermissionAlert) {
                Button("前往設定") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text("請在「設定 > TriAssist > 位置」中開啟「使用 App 期間」權限。")
            }
        }
    }

    // MARK: - Map

    private var mapLayer: some View {
        Map(position: $viewModel.cameraPosition) {
            UserAnnotation()
            ForEach(viewModel.annotations) { poi in
                Annotation(poi.name, coordinate: poi.coordinate) {
                    MapPinView(poi: poi, isSelected: viewModel.selectedAnnotation?.id == poi.id)
                        .onTapGesture { viewModel.selectAnnotation(poi) }
                }
            }
        }
        .mapStyle(.standard(elevation: .realistic))
        .ignoresSafeArea(edges: .bottom)
    }

    // MARK: - Search bar

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField("搜尋附近地點…", text: $viewModel.searchText)
                .submitLabel(.search)
                .onSubmit {
                    Task { await viewModel.manualSearch() }
                }

            if !viewModel.searchText.isEmpty {
                Button {
                    viewModel.searchText = ""
                    viewModel.annotations = []
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Radar rings overlay

    private var radarRingsOverlay: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .stroke(Color.blue.opacity(0.3 - Double(i) * 0.08), lineWidth: 2)
                    .frame(width: CGFloat(80 + i * 60), height: CGFloat(80 + i * 60))
                    .scaleEffect(viewModel.isScanning ? 1.5 : 0.8)
                    .opacity(viewModel.isScanning ? 0 : 1)
                    .animation(
                        .easeOut(duration: 1.8)
                        .delay(Double(i) * 0.5)
                        .repeatForever(autoreverses: false),
                        value: viewModel.isScanning
                    )
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Bottom panel

    private var bottomPanel: some View {
        VStack(spacing: 12) {
            if !viewModel.annotations.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(viewModel.annotations) { poi in
                            RecommendationCard(poi: poi, isSelected: viewModel.selectedAnnotation?.id == poi.id)
                                .onTapGesture { viewModel.selectAnnotation(poi) }
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }

            Button {
                Task {
                    await viewModel.scanNearby(todos: todos, shoppingItems: shoppingItems)
                }
            } label: {
                HStack(spacing: 8) {
                    if viewModel.isScanning {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(.white)
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "location.fill.viewfinder")
                    }
                    Text(viewModel.isScanning ? "掃描中…" : viewModel.isGeneratingDescriptions ? "AI 分析中…" : "我有空")
                        .fontWeight(.semibold)
                }
                .frame(height: 48)
                .padding(.horizontal, 32)
                .background(Color.blue, in: Capsule())
                .foregroundStyle(.white)
            }
            .disabled(viewModel.isScanning)
            .popoverTip(tip)
            .padding(.horizontal, 16)
        }
    }
}

// MARK: - Map Pin

private struct MapPinView: View {
    let poi: POIAnnotation
    let isSelected: Bool

    @State private var appeared = false

    var body: some View {
        VStack(spacing: 2) {
            ZStack {
                Circle()
                    .fill(poi.categoryColor)
                    .frame(width: isSelected ? 44 : 34, height: isSelected ? 44 : 34)
                    .shadow(color: poi.categoryColor.opacity(0.5), radius: 4)

                Image(systemName: poi.categoryIcon)
                    .font(.system(size: isSelected ? 18 : 14))
                    .foregroundStyle(.white)
            }

            Image(systemName: "arrowtriangle.down.fill")
                .font(.system(size: 8))
                .foregroundStyle(poi.categoryColor)
                .offset(y: -2)
        }
        .scaleEffect(appeared ? 1 : 0.1)
        .offset(y: appeared ? 0 : -20)
        .animation(.spring(response: 0.4, dampingFraction: 0.6), value: appeared)
        .onAppear { appeared = true }
        .animation(.spring(response: 0.25), value: isSelected)
    }
}

// MARK: - Recommendation Card

private struct RecommendationCard: View {
    let poi: POIAnnotation
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // ── Header ──
            HStack(alignment: .top, spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(poi.categoryColor.opacity(0.15))
                        .frame(width: 42, height: 42)
                    Image(systemName: poi.categoryIcon)
                        .foregroundStyle(poi.categoryColor)
                        .font(.system(size: 18))
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(poi.name)
                        .font(.subheadline).fontWeight(.semibold)
                        .lineLimit(2)
                    HStack(spacing: 4) {
                        Text(poi.categoryLabel)
                            .font(.caption2)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(poi.categoryColor.opacity(0.12), in: Capsule())
                            .foregroundStyle(poi.categoryColor)
                        Image(systemName: "location.fill")
                            .font(.caption2).foregroundStyle(.secondary)
                        Text(poi.distanceText)
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                }
            }
            .padding([.horizontal, .top], 12)
            .padding(.bottom, 6)

            // ── Time estimate ──
            HStack(spacing: 6) {
                Image(systemName: "clock")
                    .font(.caption2)
                    .foregroundStyle(poi.categoryColor)
                Text("步行 \(poi.walkingMinutes) 分 + 停留約 \(poi.stayMinutes) 分")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(poi.estimatedTimeText)
                    .font(.caption2).fontWeight(.semibold)
                    .foregroundStyle(poi.categoryColor)
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 6)

            // ── Address & Phone ──
            VStack(alignment: .leading, spacing: 4) {
                if let address = poi.address {
                    Label(address, systemImage: "map")
                        .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
                if let phone = poi.phone {
                    Label(phone, systemImage: "phone")
                        .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            .padding(.horizontal, 12)

            // ── AI description ──
            if !poi.aiDescription.isEmpty {
                Divider().padding(.horizontal, 12).padding(.top, 8)
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.caption2)
                        .foregroundStyle(.purple)
                        .padding(.top, 1)
                    Text(poi.aiDescription)
                        .font(.caption)
                        .foregroundStyle(.primary.opacity(0.75))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 12)
                .padding(.top, 8)
            } else {
                // Loading shimmer while AI generates
                Divider().padding(.horizontal, 12).padding(.top, 8)
                HStack(spacing: 6) {
                    ProgressView().scaleEffect(0.6)
                    Text("AI 分析中…")
                        .font(.caption2).foregroundStyle(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.top, 8)
            }

            // ── Matched items ──
            if !poi.matchedItems.isEmpty {
                Divider().padding(.horizontal, 12).padding(.top, 8)
                VStack(alignment: .leading, spacing: 6) {
                    Label("在此可完成", systemImage: "checkmark.circle")
                        .font(.caption2).foregroundStyle(.secondary)
                    FlowTagView(tags: poi.matchedItems)
                }
                .padding(.horizontal, 12)
                .padding(.top, 8)
            }

            // ── Navigate button ──
            Divider().padding(.horizontal, 12).padding(.top, 8)
            Button {
                poi.mapItem.openInMaps(launchOptions: [
                    MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
                ])
            } label: {
                Label("導航前往", systemImage: "arrow.triangle.turn.up.right.circle.fill")
                    .font(.caption).fontWeight(.medium)
                    .foregroundStyle(poi.categoryColor)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .padding(.horizontal, 4)
        }
        .padding(.bottom, 4)
        .frame(width: 260)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.12), radius: 8, y: 3)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isSelected ? poi.categoryColor : Color.clear, lineWidth: 2)
        )
    }
}

// MARK: - Flow Tag View

private struct FlowTagView: View {
    let tags: [String]

    var body: some View {
        let displayed = tags.prefix(4)
        HStack(spacing: 4) {
            ForEach(Array(displayed.enumerated()), id: \.offset) { _, tag in
                Text(tag)
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.blue.opacity(0.12), in: Capsule())
                    .foregroundStyle(.blue)
                    .lineLimit(1)
            }
            if tags.count > 4 {
                Text("+\(tags.count - 4)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    MapRadarView()
        .modelContainer(for: [Event.self, TodoTask.self, ShoppingItem.self], inMemory: true)
}
