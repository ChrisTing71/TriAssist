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
    var noMatchMessage = ""
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
        noMatchMessage = ""

        do {
            let coord = try await fetchCurrentLocation()
            userCoordinate = coord
            cameraPosition = .region(MKCoordinateRegion(
                center: coord,
                latitudinalMeters: 1200,
                longitudinalMeters: 1200
            ))

            let queries = generateQueries(todos: todos, shoppingItems: shoppingItems)

            guard !queries.isEmpty else {
                noMatchMessage = "目前待辦事項不需要前往特定地點，完成後再來看看吧！"
                isScanning = false
                return
            }

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

        let activeTodos    = todos.filter { !$0.isCompleted }.map(\.title)
        let activeShipping = shoppingItems.filter { !$0.isChecked }.map(\.name)

        // 有購物清單 → 搜超市＋便利商店
        if !activeShipping.isEmpty {
            queries.insert("全聯超市")
            queries.insert("便利商店")
        }

        // 待辦關鍵字 → 對應店型（只有真正匹配才加）
        let keywords: [(String, String)] = [
            ("牛奶", "全聯超市"), ("蛋", "全聯超市"), ("菜", "全聯超市"), ("水果", "全聯超市"),
            ("洗", "大賣場"), ("清潔", "大賣場"), ("衛生", "大賣場"),
            ("藥", "藥局"), ("感冒", "藥局"), ("維他命", "藥局"), ("保健", "藥局"),
            ("書", "書店"), ("文具", "文具店"), ("筆", "文具店"),
            ("咖啡", "咖啡廳"),
            ("飲料", "便利商店"), ("零食", "便利商店"),
            ("列印", "便利商店"), ("影印", "便利商店"), ("包裹", "便利商店"),
            ("手機", "手機維修"), ("維修", "維修店"), ("電腦", "電腦維修"),
            ("剪髮", "理髮廳"), ("理髮", "理髮廳"), ("美髮", "美髮沙龍"),
            ("眼鏡", "眼鏡行"), ("配鏡", "眼鏡行"),
            ("郵局", "郵局"), ("掛號", "郵局"),
        ]
        for title in activeTodos {
            for (kw, store) in keywords where title.contains(kw) {
                queries.insert(store)
            }
        }

        // 不再強制 fallback — 沒有匹配就不搜尋任何店
        return Array(queries)
    }

    private func matchedItems(for mapItem: MKMapItem, todos: [TodoTask], shoppingItems: [ShoppingItem]) -> [String] {
        let name = mapItem.name?.lowercased() ?? ""
        let activeTodos    = todos.filter { !$0.isCompleted }.map(\.title)
        let activeShipping = shoppingItems.filter { !$0.isChecked }.map(\.name)

        // 超市 → 只顯示購物清單
        let isGrocery = name.contains("全聯") || name.contains("超市") || name.contains("大潤發")
            || name.contains("家樂福") || name.contains("costco") || name.contains("大賣場")
        if isGrocery { return activeShipping }

        // 便利商店 → 購物清單 + 真正有超商相關的待辦（包裹、列印、飲料、零食）
        let isConvenience = name.contains("便利") || name.contains("全家")
            || name.contains("7-") || name.contains("seven") || name.contains("ok mart")
            || name.contains("萊爾富") || name.contains("hi-life")
        if isConvenience {
            let convKws = ["包裹", "列印", "影印", "飲料", "零食", "繳費", "超商"]
            let relevantTodos = activeTodos.filter { t in convKws.contains(where: { t.contains($0) }) }
            return activeShipping + relevantTodos
        }

        // 其他店型 → 嚴格關鍵字比對，沒有匹配就回傳空陣列
        let storeToKeywords: [String: [String]] = [
            "藥局": ["藥", "感冒", "維他命", "保健"],
            "藥妝": ["藥", "保健", "洗", "清潔"],
            "書店": ["書", "閱讀"],
            "文具": ["文具", "筆", "紙"],
            "咖啡": ["咖啡"],
            "手機": ["手機", "維修"],
            "3c": ["手機", "電腦", "維修"],
            "理髮": ["剪髮", "理髮", "美髮"],
            "美髮": ["剪髮", "理髮", "美髮"],
            "眼鏡": ["眼鏡", "配鏡"],
            "郵局": ["郵局", "包裹", "掛號"],
        ]
        let allItems = activeTodos + activeShipping
        var matched: [String] = []
        for (storeKw, itemKws) in storeToKeywords where name.contains(storeKw) {
            for item in allItems where itemKws.contains(where: { item.contains($0) }) {
                if !matched.contains(item) { matched.append(item) }
            }
        }
        return matched
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
