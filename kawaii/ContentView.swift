//
//  ContentView.swift
//  kawaii2
//
//  Created by Zhongzhi on 25.01.2026.
//

import SwiftUI
import UIKit
import CoreLocation
import MapKit
import Combine
import UniformTypeIdentifiers

struct ContentView: View {
    private enum WidgetSelection: Hashable {
        case location
        case city(UUID)
    }

    @State private var showsSettings = false
    @StateObject private var locationManager = LocationManager()
    @State private var locationWeather: CurrentWeather?
    @State private var locationTodayPrecipitationSum: Double?
    @State private var locationForecasts: [DailyForecast] = []
    @State private var locationHourlyForecasts: [HourlyForecast] = []
    @State private var locationAllHourlyForecasts: [HourlyForecast] = []
    @State private var locationName: String = "Current Location"
    @State private var locationImageName: String?
    @State private var locationError: String?
    @State private var lastFetchedLocation: CLLocation?
    @State private var customCities: [CityWeatherEntry] = []
    @State private var selectedWidget: WidgetSelection = .location
    @State private var searchQuery: String = ""
    @State private var isSearching = false
    @State private var searchError: String?
    @State private var showsSearch = false
    @StateObject private var searchCompleter = CitySearchCompleter()
    @AppStorage("temperatureUnit") private var temperatureUnitRaw: String = ""
    @AppStorage("precipitationUnit") private var precipitationUnitRaw: String = ""
    @AppStorage("customCitiesData") private var customCitiesData: Data = Data()
    @State private var hasLoadedSavedCities = false
    @State private var draggedCityId: UUID?
    private let cityGeocoder = CLGeocoder()

    init() {
        if UserDefaults.standard.string(forKey: "temperatureUnit") == nil {
            let defaultUnit: TemperatureUnit = Locale.current.usesMetricSystem ? .celsius : .fahrenheit
            UserDefaults.standard.set(defaultUnit.rawValue, forKey: "temperatureUnit")
        }
        if UserDefaults.standard.string(forKey: "precipitationUnit") == nil {
            let defaultUnit: PrecipitationUnit = Locale.current.usesMetricSystem ? .millimeters : .inches
            UserDefaults.standard.set(defaultUnit.rawValue, forKey: "precipitationUnit")
        }
    }

    var body: some View {
        contentView
    }

    private var contentView: some View {
        NavigationStack {
            mainScroll
        }
        .sheet(isPresented: $showsSettings) {
            SettingsView(
                temperatureUnitRaw: $temperatureUnitRaw,
                precipitationUnitRaw: $precipitationUnitRaw
            )
        }
        .task {
            locationManager.requestAuthorization()
            if let location = locationManager.lastLocation {
                await loadLocationWeather(for: location)
            }
            if !hasLoadedSavedCities {
                hasLoadedSavedCities = true
                await loadSavedCities()
            }
        }
        .onChange(of: locationManager.lastLocation) { _, newLocation in
            guard let newLocation else { return }
            Task {
                await loadLocationWeather(for: newLocation)
            }
        }
        .onChange(of: locationManager.placemark) { _, newPlacemark in
            updateLocationMetadata(from: newPlacemark)
        }
        .onChange(of: customCities) { _, _ in
            persistCustomCities()
        }
    }

    private var mainScroll: some View {
        ScrollView {
            mainStack
        }
        .navigationTitle("Weather")
        .toolbar {
            mainToolbar
        }
    }

    private var mainStack: some View {
        VStack(spacing: 20) {
            if showsSearch {
                searchSection
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            cardsScroll

            selectedForecastView
        }
        .padding(.top, 8)
        .padding(.bottom, 24)
    }

    @ToolbarContentBuilder
    private var mainToolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                showsSettings = true
            } label: {
                Image(systemName: "gearshape")
            }
            .accessibilityLabel("Settings")
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                withAnimation(.easeInOut) {
                    showsSearch.toggle()
                }
            } label: {
                Image(systemName: "square.and.pencil")
            }
            .accessibilityLabel("Edit cities")
        }
    }

    private var cardsScroll: some View {
        let size = cardSize(for: UIScreen.main.bounds.width)
        return ScrollView(.horizontal, showsIndicators: true) {
            HStack(alignment: .top, spacing: 16) {
                locationCard(size: size)
                    .onTapGesture {
                        selectedWidget = .location
                    }
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(
                                selectedWidget == .location ? Color.white.opacity(0.75) : .clear,
                                lineWidth: 2
                            )
                    )

                ForEach(Array(customCities.enumerated()), id: \.element.id) { index, city in
                    Group {
                        let card = weatherCard(
                            cityName: city.name,
                            imageName: city.imageName,
                            weather: city.weather,
                            todayPrecipitationSum: city.todayPrecipitationSum,
                            size: size
                        )
                        .onTapGesture {
                            selectedWidget = .city(city.id)
                        }
                        .overlay(alignment: .topTrailing) {
                            if showsSearch {
                                Button {
                                    withAnimation(.easeInOut) {
                                        removeCity(id: city.id)
                                    }
                                } label: {
                                    Image(systemName: "minus.circle.fill")
                                        .font(.system(size: 20, weight: .semibold))
                                        .foregroundStyle(.red)
                                        .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)
                                }
                                .buttonStyle(.plain)
                                .padding(8)
                                .accessibilityLabel("Delete city")
                            }
                        }
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(
                                    selectedWidget == .city(city.id) ? Color.white.opacity(0.75) : .clear,
                                    lineWidth: 2
                                )
                        )

                        if showsSearch {
                            card
                                .onDrag {
                                    draggedCityId = city.id
                                    return NSItemProvider(object: city.id.uuidString as NSString)
                                }
                                .onDrop(
                                    of: [UTType.text],
                                    delegate: CityReorderDropDelegate(
                                        targetId: city.id,
                                        targetIndex: index,
                                        cardWidth: size,
                                        draggedCityId: $draggedCityId,
                                        moveAction: { id, targetIndex, insertAfter in
                                            moveCity(id: id, targetIndex: targetIndex, insertAfter: insertAfter)
                                        }
                                    )
                                )
                        } else {
                            card
                        }
                    }
                }
            }
            .padding(.horizontal)
            .frame(height: size)
        }
        .frame(height: size)
    }

    @ViewBuilder
    private var selectedForecastView: some View {
        switch selectedWidget {
        case .location:
            if let locationWeather, !locationForecasts.isEmpty {
                CityForecastView(
                    cityName: locationName,
                    forecasts: locationForecasts,
                    current: locationWeather,
                    upcomingHourlyForecasts: locationHourlyForecasts,
                    allHourlyForecasts: locationAllHourlyForecasts
                )
                .padding(.horizontal)
            }
        case .city(let id):
            if let city = customCities.first(where: { $0.id == id }) {
                CityForecastView(
                    cityName: city.name,
                    forecasts: city.forecasts,
                    current: city.weather,
                    upcomingHourlyForecasts: city.hourlyForecasts,
                    allHourlyForecasts: city.allHourlyForecasts
                )
                .padding(.horizontal)
            }
        }
    }

    @ViewBuilder
    private var searchSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)

                    TextField("Search", text: $searchQuery)
                        .textInputAutocapitalization(.words)
                        .disableAutocorrection(true)
                        .onChange(of: searchQuery) { _, newValue in
                            searchCompleter.query = newValue
                        }

                    if !searchQuery.isEmpty {
                        Button {
                            searchQuery = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Clear search")
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)
                .background(Color(uiColor: .secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.white.opacity(0.06))
                )

                Button {
                    Task {
                        await addCity(named: searchQuery)
                    }
                } label: {
                    if isSearching {
                        ProgressView()
                            .tint(.white)
                            .frame(width: 18, height: 18)
                    } else {
                        Image(systemName: "plus")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isSearching || searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .accessibilityLabel("Add city")
            }

            if !searchCompleter.results.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(searchCompleter.results.prefix(5), id: \.self) { result in
                        Button {
                            let suggestion = result.title.isEmpty ? result.subtitle : "\(result.title), \(result.subtitle)"
                            searchQuery = suggestion
                            Task {
                                await addCity(named: suggestion)
                            }
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(result.title)
                                    .font(.subheadline)
                                    .foregroundStyle(.primary)
                                if !result.subtitle.isEmpty {
                                    Text(result.subtitle)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 6)
                        }
                        .buttonStyle(.plain)

                        if result != searchCompleter.results.prefix(5).last {
                            Divider()
                        }
                    }
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(uiColor: .secondarySystemGroupedBackground))
                )
            }

            if let searchError {
                Text(searchError)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal)
    }

    @MainActor
    private func addCity(named name: String) async {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        isSearching = true
        searchError = nil
        cityGeocoder.cancelGeocode()

        do {
            let placemarks = try await cityGeocoder.geocodeAddressString(trimmed)
            guard let placemark = placemarks.first, let location = placemark.location else {
                throw CitySearchError.notFound
            }

            let displayName = placemark.locality
                ?? placemark.subAdministrativeArea
                ?? placemark.administrativeArea
                ?? placemark.name
                ?? trimmed

            let snapshot = try await WeatherService.shared.fetchWeatherSnapshot(
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude
            )

            let entry = CityWeatherEntry(
                name: displayName,
                normalizedKey: normalizedCityKey(displayName),
                imageName: imageNameForCity(displayName),
                coordinate: location.coordinate,
                weather: snapshot.current,
                todayPrecipitationSum: snapshot.todayPrecipitationSum,
                forecasts: snapshot.dailyForecasts,
                hourlyForecasts: snapshot.hourlyForecasts,
                allHourlyForecasts: snapshot.allHourlyForecasts
            )

            if let index = customCities.firstIndex(where: { $0.normalizedKey == entry.normalizedKey }) {
                customCities[index] = entry
            } else {
                customCities.append(entry)
            }

            selectedWidget = .city(entry.id)
            searchQuery = ""
        } catch {
            searchError = error.localizedDescription
        }

        isSearching = false
    }

    @MainActor
    private func loadSavedCities() async {
        guard !customCitiesData.isEmpty else { return }
        let stored: [StoredCity]
        do {
            stored = try JSONDecoder().decode([StoredCity].self, from: customCitiesData)
        } catch {
            return
        }

        var loaded: [CityWeatherEntry] = []
        for city in stored {
            do {
                let snapshot = try await WeatherService.shared.fetchWeatherSnapshot(
                    latitude: city.latitude,
                    longitude: city.longitude
                )
                let entry = CityWeatherEntry(
                    name: city.name,
                    normalizedKey: city.normalizedKey,
                    imageName: imageNameForCity(city.name),
                    coordinate: CLLocationCoordinate2D(latitude: city.latitude, longitude: city.longitude),
                    weather: snapshot.current,
                    todayPrecipitationSum: snapshot.todayPrecipitationSum,
                    forecasts: snapshot.dailyForecasts,
                    hourlyForecasts: snapshot.hourlyForecasts,
                    allHourlyForecasts: snapshot.allHourlyForecasts
                )
                loaded.append(entry)
            } catch {
                continue
            }
        }

        customCities = loaded
        selectedWidget = .location
    }

    private func persistCustomCities() {
        let stored = customCities.map { city in
            StoredCity(
                name: city.name,
                normalizedKey: city.normalizedKey,
                imageName: city.imageName,
                latitude: city.coordinate.latitude,
                longitude: city.coordinate.longitude
            )
        }

        guard let data = try? JSONEncoder().encode(stored) else { return }
        customCitiesData = data
    }

    private func removeCity(id: UUID) {
        guard let index = customCities.firstIndex(where: { $0.id == id }) else { return }
        customCities.remove(at: index)
        if case .city(let selectedId) = selectedWidget, selectedId == id {
            selectedWidget = .location
        }
    }

    private func moveCity(id: UUID, targetIndex: Int, insertAfter: Bool) {
        guard let fromIndex = customCities.firstIndex(where: { $0.id == id }) else { return }

        let destinationIndex = insertAfter ? targetIndex + 1 : targetIndex
        let clampedIndex = max(0, min(destinationIndex, customCities.count))

        if fromIndex < clampedIndex {
            if fromIndex == clampedIndex - 1 { return }
        } else {
            if fromIndex == clampedIndex { return }
        }

        withAnimation(.easeInOut) {
            customCities.move(
                fromOffsets: IndexSet(integer: fromIndex),
                toOffset: clampedIndex
            )
        }
    }

    private struct CityReorderDropDelegate: DropDelegate {
        let targetId: UUID
        let targetIndex: Int
        let cardWidth: CGFloat
        @Binding var draggedCityId: UUID?
        let moveAction: (UUID, Int, Bool) -> Void

        func dropEntered(info: DropInfo) {
            reorderIfNeeded(info: info)
        }

        func dropUpdated(info: DropInfo) -> DropProposal? {
            reorderIfNeeded(info: info)
            return DropProposal(operation: .move)
        }

        func performDrop(info: DropInfo) -> Bool {
            draggedCityId = nil
            return true
        }

        private func reorderIfNeeded(info: DropInfo) {
            guard let draggedId = draggedCityId,
                  draggedId != targetId else {
                return
            }

            let shouldInsertAfter = info.location.x > cardWidth / 2
            moveAction(draggedId, targetIndex, shouldInsertAfter)
        }
    }

    @ViewBuilder
    private func dropInsertionZone(
        targetIndex: Int,
        size: CGFloat,
        width: CGFloat,
        offsetX: CGFloat
    ) -> some View {
        Color.clear
            .frame(width: width, height: size)
            .contentShape(Rectangle())
            .offset(x: offsetX)
            .dropDestination(for: String.self) { items, _ in
                guard let idString = items.first,
                      let id = UUID(uuidString: idString) else {
                    return false
                }
                moveCity(id: id, targetIndex: targetIndex, insertAfter: false)
                return true
            }
    }

    private func weatherCard(
        cityName: String,
        imageName: String?,
        weather: CurrentWeather,
        todayPrecipitationSum: Double?,
        size: CGFloat
    ) -> some View {
        let temperatureUnit = TemperatureUnit(rawValue: temperatureUnitRaw)
            ?? (Locale.current.usesMetricSystem ? .celsius : .fahrenheit)
        let precipitationUnit = PrecipitationUnit(rawValue: precipitationUnitRaw)
            ?? (Locale.current.usesMetricSystem ? .millimeters : .inches)

        return ZStack(alignment: .topLeading) {
            if let imageName, let uiImage = loadImage(named: imageName) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipped()
                    .overlay(Color.black.opacity(0.15))
            } else {
                Color.black
                    .frame(width: size, height: size)
            }

            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(cityName)
                        .font(.title2)
                        .foregroundStyle(.white.opacity(0.85))
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                        .allowsTightening(true)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(temperatureUnit.formatted(temperatureInCelsius: weather.temperature))
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(.white)
                }

                Spacer()

                HStack(spacing: 8) {
                    if UIImage(named: WeatherService.iconName(for: weather.weathercode)) != nil {
                        Image(WeatherService.iconName(for: weather.weathercode))
                            .resizable()
                            .scaledToFit()
                            .frame(width: 18, height: 18)
                            .foregroundStyle(.white.opacity(0.9))
                    } else {
                        Image(systemName: WeatherService.symbolName(for: weather.weathercode))
                            .resizable()
                            .scaledToFit()
                            .frame(width: 18, height: 18)
                            .foregroundStyle(.white.opacity(0.9))
                    }
                    Text(WeatherService.description(for: weather.weathercode))
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.9))
                }

                if let todayPrecipitationSum {
                    HStack(spacing: 8) {
                        Image(systemName: "drop")
                            .foregroundStyle(.white.opacity(0.85))
                            .font(.system(size: 18))
                        Text(precipitationUnit.formattedAmount(precipitationInMillimeters: todayPrecipitationSum))
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.9))
                    }
                }
            }
            .padding(16)
            .frame(width: size, height: size, alignment: .leading)
        }
        .frame(width: size, height: size, alignment: .topLeading)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(.white.opacity(0.2))
        )
    }

    private func cardSize(for availableWidth: CGFloat) -> CGFloat {
        let horizontalPadding: CGFloat = 32
        let spacing: CGFloat = 16
        let maxSize = (availableWidth - horizontalPadding - spacing) / 2
        return min(190, max(170, maxSize))
    }

    @MainActor
    private func loadLocationWeather(for location: CLLocation) async {
        if let lastFetchedLocation, lastFetchedLocation.distance(from: location) < 1000 {
            return
        }
        lastFetchedLocation = location
        do {
            let snapshot = try await WeatherService.shared.fetchWeatherSnapshot(
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude
            )
            locationWeather = snapshot.current
            locationTodayPrecipitationSum = snapshot.todayPrecipitationSum
            locationForecasts = snapshot.dailyForecasts
            locationHourlyForecasts = snapshot.hourlyForecasts
            locationAllHourlyForecasts = snapshot.allHourlyForecasts
            locationError = nil
        } catch {
            locationError = error.localizedDescription
        }
    }

    private func updateLocationMetadata(from placemark: CLPlacemark?) {
        let fallback = "Current Location"
        guard let placemark else {
            locationName = fallback
            locationImageName = nil
            return
        }

        let locality = placemark.locality ?? placemark.subAdministrativeArea ?? placemark.administrativeArea
        locationName = locality ?? fallback
        locationImageName = imageNameForCity(locationName)
    }

    private func imageNameForCity(_ cityName: String) -> String? {
        cityName
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .components(separatedBy: .alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: "_")
    }

    private func normalizedCityKey(_ cityName: String) -> String {
        cityName
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    @ViewBuilder
    private func locationCard(size: CGFloat) -> some View {
        Group {
            let status = locationManager.authorizationStatus

            if let locationWeather,
               status == .authorizedWhenInUse || status == .authorizedAlways {
                weatherCard(
                    cityName: locationName,
                    imageName: locationImageName,
                    weather: locationWeather,
                    todayPrecipitationSum: locationTodayPrecipitationSum,
                    size: size
                )
            } else {
                ZStack(alignment: .topLeading) {
                    if let imageName = locationImageName,
                       let uiImage = loadImage(named: imageName) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: size, height: size)
                            .clipped()
                            .overlay(Color.black.opacity(0.2))
                    } else {
                        Color.black
                            .frame(width: size, height: size)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Current Location")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.white)

                        switch status {
                        case .notDetermined:
                            HStack(spacing: 8) {
                                ProgressView()
                                    .tint(.white)
                                Text("Requesting permission…")
                                    .font(.subheadline)
                                    .foregroundStyle(.white.opacity(0.85))
                            }
                        case .denied, .restricted:
                            Text("Location access is off")
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.85))
                        default:
                            if let locationError {
                                Text(locationError)
                                    .font(.subheadline)
                                    .foregroundStyle(.white.opacity(0.85))
                            } else {
                                Text("Fetching local weather…")
                                    .font(.subheadline)
                                    .foregroundStyle(.white.opacity(0.85))
                            }
                        }
                    }
                    .padding(16)
                    .frame(width: size, height: size, alignment: .leading)
                }
                .frame(width: size, height: size, alignment: .topLeading)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(.white.opacity(0.2))
                )
            }
        }
    }

    private func loadImage(named name: String) -> UIImage? {
        if let assetImage = UIImage(named: name) {
            return assetImage
        }
        if let url = Bundle.main.url(forResource: name, withExtension: "png"),
           let image = UIImage(contentsOfFile: url.path) {
            return image
        }
        if let url = Bundle.main.url(forResource: name, withExtension: nil),
           let image = UIImage(contentsOfFile: url.path) {
            return image
        }
        return nil
    }
}

private struct CityWeatherEntry: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let normalizedKey: String
    let imageName: String?
    let coordinate: CLLocationCoordinate2D
    let weather: CurrentWeather
    let todayPrecipitationSum: Double?
    let forecasts: [DailyForecast]
    let hourlyForecasts: [HourlyForecast]
    let allHourlyForecasts: [HourlyForecast]

    static func == (lhs: CityWeatherEntry, rhs: CityWeatherEntry) -> Bool {
        lhs.normalizedKey == rhs.normalizedKey
            && lhs.name == rhs.name
            && lhs.imageName == rhs.imageName
            && lhs.coordinate.latitude == rhs.coordinate.latitude
            && lhs.coordinate.longitude == rhs.coordinate.longitude
    }
}


private struct StoredCity: Codable, Hashable {
    let name: String
    let normalizedKey: String
    let imageName: String?
    let latitude: Double
    let longitude: Double
}

private final class CitySearchCompleter: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {
    @Published var results: [MKLocalSearchCompletion] = []
    var query: String = "" {
        didSet {
            let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                results = []
                return
            }
            completer.queryFragment = trimmed
        }
    }

    private let completer: MKLocalSearchCompleter = {
        let completer = MKLocalSearchCompleter()
        completer.resultTypes = .address
        return completer
    }()

    override init() {
        super.init()
        completer.delegate = self
    }

    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        results = completer.results
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        results = []
    }
}

private enum CitySearchError: LocalizedError {
    case notFound

    var errorDescription: String? {
        switch self {
        case .notFound:
            return "No matching city found."
        }
    }
}

private extension ContentView {
    static let isoDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .iso8601)
        formatter.locale = Locale.current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    static let weekdayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.setLocalizedDateFormatFromTemplate("EEE")
        return formatter
    }()

    static let isoDateTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .iso8601)
        formatter.locale = Locale.autoupdatingCurrent
        formatter.timeZone = .autoupdatingCurrent
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm"
        return formatter
    }()

    static let hourFormatter: DateFormatter = {
        let formatter = DateFormatter()
        let locale = Locale.autoupdatingCurrent
        let template = DateFormatter.dateFormat(fromTemplate: "j", options: 0, locale: locale) ?? "HH"
        let usesAmPm = template.contains("a")
        formatter.locale = locale
        formatter.dateFormat = usesAmPm ? "h a" : "HH"
        return formatter
    }()
}

struct CityForecastView: View {
    let cityName: String
    let forecasts: [DailyForecast]
    let current: CurrentWeather
    let upcomingHourlyForecasts: [HourlyForecast]
    let allHourlyForecasts: [HourlyForecast]

    @AppStorage("temperatureUnit") private var temperatureUnitRaw: String = ""
    @AppStorage("precipitationUnit") private var precipitationUnitRaw: String = ""

    @State private var selectedDate: String?

    var body: some View {
        let temperatureUnit = TemperatureUnit(rawValue: temperatureUnitRaw)
            ?? (Locale.current.usesMetricSystem ? .celsius : .fahrenheit)
        let precipitationUnit = PrecipitationUnit(rawValue: precipitationUnitRaw)
            ?? (Locale.current.usesMetricSystem ? .millimeters : .inches)

        let selectedForecast = forecasts.first(where: { $0.date == selectedDate }) ?? forecasts.first

        let hourlyData: [HourlyForecast] = {
            guard let selected = selectedForecast else { return [] }
            if selected.id == forecasts.first?.id {
                return upcomingHourlyForecasts
            } else {
                return allHourlyForecasts.filter { $0.time.hasPrefix(selected.date) }
            }
        }()

        VStack(alignment: .leading, spacing: 14) {
            if let selected = selectedForecast {
                detailCard(
                    cityName: cityName,
                    forecast: selected,
                    current: current,
                    hourlyForecasts: hourlyData,
                    isToday: selected.id == forecasts.first?.id,
                    temperatureUnit: temperatureUnit,
                    precipitationUnit: precipitationUnit
                )
            }

            VStack(spacing: 0) {
                ForEach(forecasts) { forecast in
                    forecastRow(
                        forecast: forecast,
                        isSelected: selectedForecast?.id == forecast.id,
                        temperatureUnit: temperatureUnit,
                        precipitationUnit: precipitationUnit
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation {
                            selectedDate = forecast.date
                        }
                    }

                    if forecast.id != forecasts.last?.id {
                        Divider()
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(uiColor: .secondarySystemGroupedBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(0.08))
            )
        }
    }

    private func detailCard(
        cityName: String,
        forecast: DailyForecast,
        current: CurrentWeather,
        hourlyForecasts: [HourlyForecast],
        isToday: Bool,
        temperatureUnit: TemperatureUnit,
        precipitationUnit: PrecipitationUnit
    ) -> some View {
        let overviewCode: Int
        if isToday {
            overviewCode = todayOverviewCode(forecast: forecast, current: current, hourlyForecasts: hourlyForecasts)
        } else {
            overviewCode = forecast.weathercode
        }

        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                weatherIcon(for: overviewCode, size: 30)
                VStack(alignment: .leading, spacing: 4) {
                    Text(cityName)
                        .font(.headline)
                    Text(isToday ? "Today" : dayLabel(for: forecast.date))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(WeatherService.description(for: overviewCode))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(temperatureValue(forecast.temperatureMax, unit: temperatureUnit))
                        .font(.headline)
                    Text(temperatureValue(forecast.temperatureMin, unit: temperatureUnit))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 16) {
                if let precipitationSum = forecast.precipitationSum {
                    labelWithIcon(
                        icon: "drop",
                        text: precipitationUnit.formattedAmount(precipitationInMillimeters: precipitationSum)
                    )
                }

                if let probability = forecast.precipitationProbabilityMax, probability > 0 {
                    labelWithIcon(
                        icon: "cloud.rain",
                        text: String(format: "%.0f%%", probability)
                    )
                }

                if isToday {
                    labelWithIcon(
                        icon: "wind",
                        text: String(format: "%.0f km/h", current.windspeed)
                    )
                }
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)

            if !hourlyForecasts.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 12) {
                        ForEach(Array(hourlyForecasts.enumerated()), id: \.element.id) { index, forecast in
                            hourlyForecastCard(
                                forecast: forecast,
                                temperatureUnit: temperatureUnit,
                                precipitationUnit: precipitationUnit
                            )
                        }
                    }
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color(uiColor: .tertiarySystemGroupedBackground))
                    )
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.08))
        )
    }

    private func forecastRow(
        forecast: DailyForecast,
        isSelected: Bool,
        temperatureUnit: TemperatureUnit,
        precipitationUnit: PrecipitationUnit
    ) -> some View {
        HStack(spacing: 12) {
            Text(dayLabel(for: forecast.date))
                .font(.subheadline)
                .foregroundStyle(.primary)
                .frame(width: 48, alignment: .leading)

            weatherIcon(for: forecast.weathercode, size: 22)

            Text(WeatherService.description(for: forecast.weathercode))
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            if let probability = forecast.precipitationProbabilityMax, probability > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "drop.fill")
                        .font(.caption)
                    Text(String(format: "%.0f%%", probability))
                        .font(.caption)
                }
                .foregroundStyle(.blue)
            }

            if let precipitationSum = forecast.precipitationSum, precipitationSum > 0 {
                Text(precipitationUnit.formattedAmount(precipitationInMillimeters: precipitationSum))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(temperatureValue(forecast.temperatureMin, unit: temperatureUnit))
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text(temperatureValue(forecast.temperatureMax, unit: temperatureUnit))
                .font(.subheadline.weight(.semibold))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(isSelected ? Color.white.opacity(0.1) : Color.clear)
    }

    private func todayOverviewCode(
        forecast: DailyForecast,
        current: CurrentWeather,
        hourlyForecasts: [HourlyForecast]
    ) -> Int {
        let upcoming = hourlyForecasts

        if upcoming.isEmpty {
            return forecast.weathercode
        }

        let precipitationLikely = upcoming.contains { forecast in
            if let precipitation = forecast.precipitation, precipitation > 0.1 {
                return true
            }
            if let probability = forecast.precipitationProbability, probability >= 40 {
                return true
            }
            return false
        }

        if precipitationLikely {
            let dominant = dominantWeatherCode(in: upcoming) ?? current.weathercode
            return dominant
        }

        let nonWetCodes = upcoming.filter { !isWetWeatherCode($0.weathercode) }
        let dominant = dominantWeatherCode(in: nonWetCodes.isEmpty ? upcoming : nonWetCodes) ?? current.weathercode
        return dominant
    }

    private func dominantWeatherCode(in hourly: [HourlyForecast]) -> Int? {
        guard !hourly.isEmpty else {
            return nil
        }
        let counts = hourly.reduce(into: [Int: Int]()) { result, forecast in
            result[forecast.weathercode, default: 0] += 1
        }
        return counts.max { lhs, rhs in
            if lhs.value == rhs.value {
                return lhs.key > rhs.key
            }
            return lhs.value < rhs.value
        }?.key
    }

    private func isWetWeatherCode(_ code: Int) -> Bool {
        switch code {
        case 51, 53, 55, 56, 57, 61, 63, 65, 66, 67, 80, 81, 82, 85, 86, 95, 96, 99:
            return true
        default:
            return false
        }
    }

    private func hourlyForecastCard(
        forecast: HourlyForecast,
        temperatureUnit: TemperatureUnit,
        precipitationUnit: PrecipitationUnit
    ) -> some View {
        VStack(spacing: 6) {
            Text(hourLabel(for: forecast.time))
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(temperatureValue(forecast.temperature, unit: temperatureUnit))
                .font(.subheadline.weight(.semibold))

            weatherIcon(
                for: forecast.weathercode,
                size: 18,
                isNight: isNightTime(for: forecast.time)
            )

            let precipitationText: String? = {
                if let precipitation = forecast.precipitation, precipitation > 0 {
                    return precipitationUnit.formattedAmount(precipitationInMillimeters: precipitation)
                }
                return nil
            }()

            let probabilityText: String? = {
                if let probability = forecast.precipitationProbability, probability > 0 {
                    return String(format: "%.0f%%", probability)
                }
                return nil
            }()

            let hasPrecipInfo = precipitationText != nil || probabilityText != nil

            VStack(spacing: 2) {
                Text(precipitationText ?? " ")
                Text(probabilityText ?? " ")
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
            .opacity(hasPrecipInfo ? 1 : 0)
            .frame(height: 26, alignment: .top)
            .accessibilityHidden(!hasPrecipInfo)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
    }

    private func dayLabel(for dateString: String) -> String {
        if let date = ContentView.isoDateFormatter.date(from: dateString),
           Calendar.current.isDateInToday(date) {
            return "Today"
        }
        if let date = ContentView.isoDateFormatter.date(from: dateString) {
            return ContentView.weekdayFormatter.string(from: date)
        }
        return dateString
    }

    private func temperatureValue(_ value: Double, unit: TemperatureUnit) -> String {
        let converted: Double
        switch unit {
        case .celsius:
            converted = value
        case .fahrenheit:
            converted = (value * 9 / 5) + 32
        }
        return String(format: "%.0f%@", converted, unit.symbol)
    }

    private func weatherIcon(for code: Int, size: CGFloat, isNight: Bool = false) -> some View {
        if isNight, let nightSymbolName = nightSymbolName(for: code) {
            return AnyView(
                Image(systemName: nightSymbolName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: size, height: size)
                    .foregroundStyle(.secondary)
            )
        }

        if UIImage(named: WeatherService.iconName(for: code)) != nil {
            return AnyView(
                Image(WeatherService.iconName(for: code))
                    .resizable()
                    .scaledToFit()
                    .frame(width: size, height: size)
            )
        }
        return AnyView(
            Image(systemName: WeatherService.symbolName(for: code))
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
                .foregroundStyle(.secondary)
        )
    }

    private func labelWithIcon(icon: String, text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
            Text(text)
        }
    }

    private func hourLabel(for dateTime: String) -> String {
        if let date = ContentView.isoDateTimeFormatter.date(from: dateTime) {
            return ContentView.hourFormatter.string(from: date)
        }
        return dateTime
    }

    private func isNightTime(for dateTime: String) -> Bool {
        guard let date = ContentView.isoDateTimeFormatter.date(from: dateTime) else {
            return false
        }
        let hour = Calendar.autoupdatingCurrent.component(.hour, from: date)
        return hour < 6 || hour >= 19
    }

    private func nightSymbolName(for code: Int) -> String? {
        switch code {
        case 0:
            return "moon.stars.fill"
        case 1, 2:
            return "cloud.moon.fill"
        case 3:
            return "cloud.fill"
        case 45, 48:
            return "cloud.fog.fill"
        case 51, 53:
            return "cloud.drizzle.fill"
        case 55:
            return "cloud.heavyrain.fill"
        case 56, 57:
            return "cloud.sleet.fill"
        case 61, 63:
            return "cloud.rain.fill"
        case 65:
            return "cloud.heavyrain.fill"
        case 66, 67:
            return "cloud.sleet.fill"
        case 71, 73:
            return "cloud.snow.fill"
        case 75, 77:
            return "snowflake"
        case 80, 81:
            return "cloud.rain.fill"
        case 82:
            return "cloud.heavyrain.fill"
        case 85, 86:
            return "cloud.snow.fill"
        case 95, 96, 99:
            return "cloud.bolt.rain.fill"
        default:
            return nil
        }
    }
}

#Preview {
    ContentView()
}
