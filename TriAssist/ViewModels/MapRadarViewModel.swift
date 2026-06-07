//
//  MapRadarViewModel.swift
//  TriAssist
//

import Foundation
import SwiftUI
import MapKit
import CoreLocation
import SwiftData

@MainActor
@Observable
final class MapRadarViewModel: NSObject {
    var cameraPosition: MapCameraPosition = .automatic
    var annotations: [POIAnnotation] = []
    var selectedAnnotation: POIAnnotation? = nil
    var isScanning = false
    var isGeneratingDescriptions = false
    var searchText = ""
    private var scanGeneration = 0
    var showPermissionAlert = false
    var locationAuthStatus: CLAuthorizationStatus = .notDetermined
    private(set) var userCoordinate: CLLocationCoordinate2D? = nil

    private let locationManager = CLLocationManager()
    private var locationContinuation: CheckedContinuation<CLLocationCoordinate2D, Error>?
    private var apiKey: String { UserDefaults.standard.string(forKey: "customApiKey") ?? "" }

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        locationAuthStatus = locationManager.authorizationStatus
    }

    func requestLocationPermission() {
        switch locationManager.authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            showPermissionAlert = true
        default:
            break
        }
    }

    func scanNearby(todos: [TodoTask], shoppingItems: [ShoppingItem]) async {
        guard !isScanning else { return }

        if locationManager.authorizationStatus == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
            return
        }
        guard locationManager.authorizationStatus == .authorizedWhenInUse ||
              locationManager.authorizationStatus == .authorizedAlways else {
            showPermissionAlert = true
            return
        }

        scanGeneration += 1
        let generation = scanGeneration
        isScanning = true
        isGeneratingDescriptions = false
        annotations = []

        do {
            let coord = try await fetchCurrentLocation()
            userCoordinate = coord
            cameraPosition = .region(MKCoordinateRegion(
                center: coord,
                latitudinalMeters: 1200,
                longitudinalMeters: 1200
            ))

            let queries = generateQueries(todos: todos, shoppingItems: shoppingItems)
            var found: [POIAnnotation] = []

            for query in queries {
                let request = MKLocalSearch.Request()
                request.naturalLanguageQuery = query
                request.region = MKCoordinateRegion(
                    center: coord,
                    latitudinalMeters: 700,
                    longitudinalMeters: 700
                )
                request.resultTypes = .pointOfInterest

                if let response = try? await MKLocalSearch(request: request).start() {
                    let userLoc = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
                    for item in response.mapItems.prefix(5) {
                        let itemLoc = CLLocation(
                            latitude: item.placemark.coordinate.latitude,
                            longitude: item.placemark.coordinate.longitude
                        )
                        let dist = userLoc.distance(from: itemLoc)
                        guard dist <= 500 else { continue }
                        guard !found.contains(where: { $0.mapItem.name == item.name }) else { continue }

                        let matched = matchedItems(for: item, todos: todos, shoppingItems: shoppingItems)
                        found.append(POIAnnotation(mapItem: item, matchedItems: matched, distance: dist))
                    }
                }
            }

            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                annotations = found.sorted { $0.distance < $1.distance }
            }

            if !found.isEmpty {
                isGeneratingDescriptions = true
                Task { await generateDescriptions(generation: generation) }
            }

        } catch {
            print("❌ 定位失敗: \(error)")
        }

        isScanning = false
    }

    func manualSearch() async {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }

        // Require location for 500m search; prompt if not yet determined
        if locationManager.authorizationStatus == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
            return
        }
        guard locationManager.authorizationStatus == .authorizedWhenInUse ||
              locationManager.authorizationStatus == .authorizedAlways else {
            showPermissionAlert = true
            return
        }

        scanGeneration += 1
        let generation = scanGeneration
        isScanning = true
        isGeneratingDescriptions = false
        annotations = []

        do {
            let coord = try await fetchCurrentLocation()
            userCoordinate = coord

            let request = MKLocalSearch.Request()
            request.naturalLanguageQuery = query
            request.region = MKCoordinateRegion(
                center: coord,
                latitudinalMeters: 700,
                longitudinalMeters: 700
            )
            request.resultTypes = .pointOfInterest

            if let response = try? await MKLocalSearch(request: request).start() {
                let userLoc = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
                let results: [POIAnnotation] = response.mapItems.compactMap { item in
                    let itemLoc = CLLocation(latitude: item.placemark.coordinate.latitude,
                                             longitude: item.placemark.coordinate.longitude)
                    let dist = userLoc.distance(from: itemLoc)
                    guard dist <= 500 else { return nil }
                    return POIAnnotation(mapItem: item, matchedItems: [], distance: dist)
                }
                .sorted { $0.distance < $1.distance }

                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                    annotations = results
                }
                cameraPosition = .region(MKCoordinateRegion(
                    center: coord,
                    latitudinalMeters: 1200,
                    longitudinalMeters: 1200
                ))

                if !results.isEmpty {
                    isGeneratingDescriptions = true
                    Task { await generateDescriptions(generation: generation) }
                }
            }
        } catch {
            print("❌ 手動搜尋定位失敗: \(error)")
        }

        isScanning = false
    }

    func selectAnnotation(_ poi: POIAnnotation) {
        withAnimation { selectedAnnotation = poi }
    }

    // MARK: - AI Descriptions

    private func generateDescriptions(generation: Int) async {
        defer {
            if scanGeneration == generation { isGeneratingDescriptions = false }
        }

        guard scanGeneration == generation, !annotations.isEmpty else { return }

        let key = apiKey
        if key.isEmpty {
            applyFallbackDescriptions()
            return
        }

        let lines = annotations.enumerated().map { i, poi in
            let items = poi.matchedItems.isEmpty
                ? "（無特定待辦配對）"
                : "可完成：\(poi.matchedItems.joined(separator: "、"))"
            return "\(i). \(poi.name)（\(poi.categoryLabel)，步行\(poi.walkingMinutes)分鐘，停留約\(poi.stayMinutes)分鐘）- \(items)"
        }.joined(separator: "\n")

        let prompt = """
        以下是使用者附近 500 公尺內的地點清單，請為每個地點寫一句繁體中文推薦說明（20～30字），
        說明這個地點的實用價值、能完成哪些事、或為何值得前往。語氣要親切自然。
        只回傳 JSON 陣列，格式：[{"index":0,"desc":"..."},...]

        地點清單：
        \(lines)
        """

        guard let jsonString = await callGemini(prompt),
              let data = jsonString.data(using: .utf8) else {
            applyFallbackDescriptions()
            return
        }

        // Discard result if a newer scan has already started
        guard scanGeneration == generation else { return }

        struct DescItem: Codable { let index: Int; let desc: String }
        guard let results = try? JSONDecoder().decode([DescItem].self, from: data) else {
            applyFallbackDescriptions()
            return
        }

        for item in results {
            guard item.index < annotations.count else { continue }
            annotations[item.index].aiDescription = item.desc
        }
    }

    private func applyFallbackDescriptions() {
        for i in annotations.indices {
            let poi = annotations[i]
            if !poi.matchedItems.isEmpty {
                annotations[i].aiDescription = "在此可完成 \(poi.matchedItems.prefix(2).joined(separator: "、")) 等待辦事項，步行僅需 \(poi.walkingMinutes) 分鐘。"
            } else {
                annotations[i].aiDescription = "附近的\(poi.categoryLabel)，距您 \(poi.distanceText)，值得順路前往。"
            }
        }
    }

    private func callGemini(_ prompt: String) async -> String? {
        let key = apiKey
        guard !key.isEmpty,
              let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=\(key)") else { return nil }

        let body: [String: Any] = [
            "contents": [["parts": [["text": prompt]]]],
            "generationConfig": ["responseMimeType": "application/json"]
        ]
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse, http.statusCode == 200 else { return nil }

        struct GResp: Codable {
            struct C: Codable { struct Ct: Codable { struct P: Codable { let text: String }; let parts: [P] }; let content: Ct }
            let candidates: [C]
        }
        return (try? JSONDecoder().decode(GResp.self, from: data))?.candidates.first?.content.parts.first?.text
    }

    // MARK: - Private helpers

    private func fetchCurrentLocation() async throws -> CLLocationCoordinate2D {
        return try await withCheckedThrowingContinuation { continuation in
            self.locationContinuation = continuation
            locationManager.requestLocation()
        }
    }

    private func generateQueries(todos: [TodoTask], shoppingItems: [ShoppingItem]) -> [String] {
        var queries = Set<String>()
        let keywords: [(String, String)] = [
            ("牛奶", "全聯"), ("蛋", "全聯"), ("菜", "全聯"), ("水果", "全聯"),
            ("藥", "藥局"), ("感冒", "藥局"), ("維他命", "藥局"),
            ("書", "書店"), ("文具", "文具店"), ("筆", "文具店"),
            ("咖啡", "咖啡廳"), ("飲料", "便利商店"), ("零食", "便利商店"),
            ("列印", "便利商店"), ("影印", "便利商店"), ("包裹", "便利商店"),
            ("超商", "便利商店"), ("全家", "便利商店"), ("7-11", "便利商店"),
        ]
        let allTitles = todos.filter { !$0.isCompleted }.map(\.title)
            + shoppingItems.filter { !$0.isChecked }.map(\.name)
        for title in allTitles {
            for (kw, store) in keywords where title.contains(kw) {
                queries.insert(store)
            }
        }
        if queries.isEmpty { queries.insert("便利商店") }
        return Array(queries)
    }

    private func matchedItems(for mapItem: MKMapItem, todos: [TodoTask], shoppingItems: [ShoppingItem]) -> [String] {
        let name = mapItem.name?.lowercased() ?? ""
        let storeToKeywords: [String: [String]] = [
            "全聯": ["牛奶", "蛋", "菜", "水果", "食材", "日用品"],
            "藥局": ["藥", "感冒", "維他命", "保健"],
            "書店": ["書", "閱讀"],
            "文具": ["文具", "筆", "紙"],
            "便利": ["飲料", "零食", "列印", "影印", "包裹"],
            "咖啡": ["咖啡"],
        ]
        let allItems = todos.filter { !$0.isCompleted }.map(\.title)
            + shoppingItems.filter { !$0.isChecked }.map(\.name)
        var matched: [String] = []
        for (storeKw, itemKws) in storeToKeywords where name.contains(storeKw) {
            for item in allItems where itemKws.contains(where: { item.contains($0) }) {
                matched.append(item)
            }
        }
        return matched.isEmpty ? allItems.prefix(2).map { $0 } : matched
    }
}

// MARK: - CLLocationManagerDelegate

extension MapRadarViewModel: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor [weak self] in
            self?.locationAuthStatus = manager.authorizationStatus
            if manager.authorizationStatus == .denied || manager.authorizationStatus == .restricted {
                self?.showPermissionAlert = true
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task { @MainActor [weak self] in
            self?.locationContinuation?.resume(returning: location.coordinate)
            self?.locationContinuation = nil
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor [weak self] in
            self?.locationContinuation?.resume(throwing: error)
            self?.locationContinuation = nil
        }
    }
}
