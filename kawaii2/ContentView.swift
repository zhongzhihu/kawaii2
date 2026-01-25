//
//  ContentView.swift
//  kawaii2
//
//  Created by Zhongzhi on 25.01.2026.
//

import SwiftUI
import UIKit

struct ContentView: View {
    private enum SelectedCity: String {
        case zurich
        case sanFrancisco
        case miami
    }

    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var zurichWeather: CurrentWeather?
    @State private var zurichTodayPrecipitationSum: Double?
    @State private var zurichForecasts: [DailyForecast] = []
    @State private var zurichHourlyForecasts: [HourlyForecast] = []
    @State private var sanFranciscoWeather: CurrentWeather?
    @State private var sanFranciscoTodayPrecipitationSum: Double?
    @State private var sanFranciscoForecasts: [DailyForecast] = []
    @State private var sanFranciscoHourlyForecasts: [HourlyForecast] = []
    @State private var miamiWeather: CurrentWeather?
    @State private var miamiTodayPrecipitationSum: Double?
    @State private var miamiForecasts: [DailyForecast] = []
    @State private var miamiHourlyForecasts: [HourlyForecast] = []
    @State private var showsSettings = false
    @State private var selectedCity: SelectedCity = .zurich
    @AppStorage("temperatureUnit") private var temperatureUnitRaw: String = ""
    @AppStorage("precipitationUnit") private var precipitationUnitRaw: String = ""

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
        NavigationStack {
            Group {
                if let errorMessage {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundStyle(.orange)
                        Text("Failed to load weather")
                            .font(.headline)
                        Text(errorMessage)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .multilineTextAlignment(.center)
                    .padding()
                } else if isLoading {
                    ProgressView("Loading weather…")
                } else if let zurichWeather, let sanFranciscoWeather, let miamiWeather {
                    ScrollView {
                        VStack(spacing: 20) {
                            let size = cardSize(for: UIScreen.main.bounds.width)
                            ScrollView(.horizontal, showsIndicators: true) {
                                HStack(alignment: .top, spacing: 16) {
                                    weatherCard(
                                        cityName: "Zurich",
                                        imageName: "zurich_1",
                                        weather: zurichWeather,
                                        todayPrecipitationSum: zurichTodayPrecipitationSum,
                                        size: size
                                    )
                                    .onTapGesture {
                                        selectedCity = .zurich
                                    }
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            .stroke(
                                                selectedCity == .zurich ? Color.white.opacity(0.75) : .clear,
                                                lineWidth: 2
                                            )
                                    )

                                    weatherCard(
                                        cityName: "San Francisco",
                                        imageName: "san_francisco_1",
                                        weather: sanFranciscoWeather,
                                        todayPrecipitationSum: sanFranciscoTodayPrecipitationSum,
                                        size: size
                                    )
                                    .onTapGesture {
                                        selectedCity = .sanFrancisco
                                    }
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            .stroke(
                                                selectedCity == .sanFrancisco ? Color.white.opacity(0.75) : .clear,
                                                lineWidth: 2
                                            )
                                    )

                                    weatherCard(
                                        cityName: "Miami",
                                        imageName: "miami",
                                        weather: miamiWeather,
                                        todayPrecipitationSum: miamiTodayPrecipitationSum,
                                        size: size
                                    )
                                    .onTapGesture {
                                        selectedCity = .miami
                                    }
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            .stroke(
                                                selectedCity == .miami ? Color.white.opacity(0.75) : .clear,
                                                lineWidth: 2
                                            )
                                    )
                                }
                                .padding(.horizontal)
                                .frame(height: size)
                            }
                            .frame(height: size)

                            switch selectedCity {
                            case .zurich:
                                if !zurichForecasts.isEmpty {
                                    cityForecastSection(
                                        cityName: "Zurich",
                                        forecasts: zurichForecasts,
                                        current: zurichWeather,
                                        hourlyForecasts: zurichHourlyForecasts
                                    )
                                    .padding(.horizontal)
                                }
                            case .sanFrancisco:
                                if !sanFranciscoForecasts.isEmpty {
                                    cityForecastSection(
                                        cityName: "San Francisco",
                                        forecasts: sanFranciscoForecasts,
                                        current: sanFranciscoWeather,
                                        hourlyForecasts: sanFranciscoHourlyForecasts
                                    )
                                    .padding(.horizontal)
                                }
                            case .miami:
                                if !miamiForecasts.isEmpty {
                                    cityForecastSection(
                                        cityName: "Miami",
                                        forecasts: miamiForecasts,
                                        current: miamiWeather,
                                        hourlyForecasts: miamiHourlyForecasts
                                    )
                                    .padding(.horizontal)
                                }
                            }
                        }
                        .padding(.top, 8)
                        .padding(.bottom, 24)
                    }
                } else {
                    ContentUnavailableView("No data", systemImage: "cloud.slash")
                }
            }
            .navigationTitle("Weather")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showsSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("Settings")
                }
            }
        }
        .sheet(isPresented: $showsSettings) {
            SettingsView(
                temperatureUnitRaw: $temperatureUnitRaw,
                precipitationUnitRaw: $precipitationUnitRaw
            )
        }
        .task {
            await loadWeather()
        }
    }

    @MainActor
    private func loadWeather() async {
        isLoading = true
        errorMessage = nil
        do {
            async let zurichSnapshot = WeatherService.shared.fetchWeatherSnapshot(
                latitude: 47.3769,
                longitude: 8.5417
            )
            async let sanFranciscoSnapshot = WeatherService.shared.fetchWeatherSnapshot(
                latitude: 37.7749,
                longitude: -122.4194
            )
            async let miamiSnapshot = WeatherService.shared.fetchWeatherSnapshot(
                latitude: 25.7617,
                longitude: -80.1918
            )

            let (zurich, sanFrancisco, miami) = try await (zurichSnapshot, sanFranciscoSnapshot, miamiSnapshot)
            self.zurichWeather = zurich.current
            self.zurichTodayPrecipitationSum = zurich.todayPrecipitationSum
            self.zurichForecasts = zurich.dailyForecasts
            self.zurichHourlyForecasts = zurich.hourlyForecasts
            self.sanFranciscoWeather = sanFrancisco.current
            self.sanFranciscoTodayPrecipitationSum = sanFrancisco.todayPrecipitationSum
            self.sanFranciscoForecasts = sanFrancisco.dailyForecasts
            self.sanFranciscoHourlyForecasts = sanFrancisco.hourlyForecasts
            self.miamiWeather = miami.current
            self.miamiTodayPrecipitationSum = miami.todayPrecipitationSum
            self.miamiForecasts = miami.dailyForecasts
            self.miamiHourlyForecasts = miami.hourlyForecasts
        } catch {
            self.errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    @ViewBuilder
    private func weatherCard(
        cityName: String,
        imageName: String,
        weather: CurrentWeather,
        todayPrecipitationSum: Double?,
        size: CGFloat
    ) -> some View {
        let temperatureUnit = TemperatureUnit(rawValue: temperatureUnitRaw)
            ?? (Locale.current.usesMetricSystem ? .celsius : .fahrenheit)
        let precipitationUnit = PrecipitationUnit(rawValue: precipitationUnitRaw)
            ?? (Locale.current.usesMetricSystem ? .millimeters : .inches)

        ZStack(alignment: .topLeading) {
            if let uiImage = loadImage(named: imageName) {
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

    @ViewBuilder
    private func cityForecastSection(
        cityName: String,
        forecasts: [DailyForecast],
        current: CurrentWeather,
        hourlyForecasts: [HourlyForecast]
    ) -> some View {
        let temperatureUnit = TemperatureUnit(rawValue: temperatureUnitRaw)
            ?? (Locale.current.usesMetricSystem ? .celsius : .fahrenheit)
        let precipitationUnit = PrecipitationUnit(rawValue: precipitationUnitRaw)
            ?? (Locale.current.usesMetricSystem ? .millimeters : .inches)

        let upcoming = Array(forecasts.dropFirst().prefix(7))

        VStack(alignment: .leading, spacing: 14) {
            if let today = forecasts.first {
                todayDetailCard(
                    cityName: cityName,
                    forecast: today,
                    current: current,
                    hourlyForecasts: hourlyForecasts,
                    temperatureUnit: temperatureUnit,
                    precipitationUnit: precipitationUnit
                )
            }

            VStack(spacing: 0) {
                ForEach(upcoming) { forecast in
                    forecastRow(
                        forecast: forecast,
                        temperatureUnit: temperatureUnit,
                        precipitationUnit: precipitationUnit
                    )

                    if forecast.id != upcoming.last?.id {
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

    private func todayDetailCard(
        cityName: String,
        forecast: DailyForecast,
        current: CurrentWeather,
        hourlyForecasts: [HourlyForecast],
        temperatureUnit: TemperatureUnit,
        precipitationUnit: PrecipitationUnit
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                weatherIcon(for: forecast.weathercode, size: 30)
                VStack(alignment: .leading, spacing: 4) {
                    Text(cityName)
                        .font(.headline)
                    Text("Today")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(WeatherService.description(for: forecast.weathercode))
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

                labelWithIcon(
                    icon: "wind",
                    text: String(format: "%.0f km/h", current.windspeed)
                )
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)

            if !hourlyForecasts.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(Array(hourlyForecasts.enumerated()), id: \.element.id) { index, forecast in
                            hourlyForecastCard(
                                forecast: forecast,
                                isFirst: index == 0,
                                temperatureUnit: temperatureUnit,
                                precipitationUnit: precipitationUnit
                            )
                        }
                    }
                    .padding(.vertical, 4)
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
    }

    private func dayLabel(for dateString: String) -> String {
        if let date = Self.isoDateFormatter.date(from: dateString),
           Calendar.current.isDateInToday(date) {
            return "Today"
        }
        if let date = Self.isoDateFormatter.date(from: dateString) {
            return Self.weekdayFormatter.string(from: date)
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

    private func weatherIcon(for code: Int, size: CGFloat) -> some View {
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

    private func hourlyForecastCard(
        forecast: HourlyForecast,
        isFirst: Bool,
        temperatureUnit: TemperatureUnit,
        precipitationUnit: PrecipitationUnit
    ) -> some View {
        VStack(spacing: 6) {
            Text(hourLabel(for: forecast.time))
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(temperatureValue(forecast.temperature, unit: temperatureUnit))
                .font(.subheadline.weight(.semibold))

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

            if precipitationText != nil || probabilityText != nil {
                VStack(spacing: 2) {
                    if let precipitationText {
                        Text(precipitationText)
                    }
                    if let probabilityText {
                        Text(probabilityText)
                    }
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            } else {
                Text("—")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(uiColor: .tertiarySystemGroupedBackground))
        )
    }

    private func hourLabel(for dateTime: String) -> String {
        if let date = Self.isoDateTimeFormatter.date(from: dateTime) {
            return Self.hourFormatter.string(from: date)
        }
        return dateTime
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

#Preview {
    ContentView()
}
