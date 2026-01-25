//
//  ContentView.swift
//  kawaii2
//
//  Created by Zhongzhi on 25.01.2026.
//

import SwiftUI
import UIKit

struct ContentView: View {
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var zurichWeather: CurrentWeather?
    @State private var zurichTodayPrecipitationSum: Double?
    @State private var sanFranciscoWeather: CurrentWeather?
    @State private var sanFranciscoTodayPrecipitationSum: Double?
    @State private var showsSettings = false
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
                } else if let zurichWeather, let sanFranciscoWeather {
                    GeometryReader { proxy in
                        let size = cardSize(for: proxy.size.width)
                        HStack(alignment: .top, spacing: 16) {
                            weatherCard(
                                cityName: "Zurich",
                                imageName: "zurich_1",
                                weather: zurichWeather,
                                todayPrecipitationSum: zurichTodayPrecipitationSum,
                                size: size
                            )

                            weatherCard(
                                cityName: "San Francisco",
                                imageName: "san_francisco_1",
                                weather: sanFranciscoWeather,
                                todayPrecipitationSum: sanFranciscoTodayPrecipitationSum,
                                size: size
                            )
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.horizontal)
                        .frame(maxHeight: .infinity, alignment: .top)
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

            let (zurich, sanFrancisco) = try await (zurichSnapshot, sanFranciscoSnapshot)
            self.zurichWeather = zurich.current
            self.zurichTodayPrecipitationSum = zurich.todayPrecipitationSum
            self.sanFranciscoWeather = sanFrancisco.current
            self.sanFranciscoTodayPrecipitationSum = sanFrancisco.todayPrecipitationSum
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
                        Image(systemName: "cloud.fill")
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
                        Text(precipitationUnit.formattedLabel(precipitationInMillimeters: todayPrecipitationSum))
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

#Preview {
    ContentView()
}
