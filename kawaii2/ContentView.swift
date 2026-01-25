//
//  ContentView.swift
//  kawaii2
//
//  Created by Zhongzhi on 25.01.2026.
//

import SwiftUI

struct ContentView: View {
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var weather: CurrentWeather?
    @State private var nextHourPrecipitation: Double?
    @State private var todayPrecipitationSum: Double?

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
                    ProgressView("Loading Zurich weather…")
                } else if let weather {
                    VStack(alignment: .leading, spacing: 16) {
                        ZStack(alignment: .topLeading) {
                            Image("zurich_1")
                                .resizable()
                                .scaledToFill()
                                .frame(width: 200, height: 200)
                                .clipped()
                                .overlay(Color.black.opacity(0.15))

                            VStack(alignment: .leading, spacing: 12) {
                                HStack(alignment: .firstTextBaseline, spacing: 10) {
                                    Text("Zurich")
                                        .font(.headline)
                                        .foregroundStyle(.white.opacity(0.85))

                                    Text(String(format: "%.0f ℃", weather.temperature))
                                        .font(.title2.weight(.semibold))
                                        .foregroundStyle(.white)
                                }

                                Text(WeatherService.description(for: weather.weathercode))
                                    .font(.title3)
                                    .foregroundStyle(.white.opacity(0.9))

                                if let nextHourPrecipitation {
                                    HStack(spacing: 8) {
                                        Image(systemName: "cloud.rain")
                                            .foregroundStyle(.white.opacity(0.85))
                                        Text(String(format: "Next hour %.1f mm", nextHourPrecipitation))
                                            .font(.subheadline)
                                            .foregroundStyle(.white.opacity(0.9))
                                    }
                                }

                                if let todayPrecipitationSum {
                                    HStack(spacing: 8) {
                                        Image(systemName: "drop")
                                            .foregroundStyle(.white.opacity(0.85))
                                        Text(String(format: "Today %.1f mm", todayPrecipitationSum))
                                            .font(.subheadline)
                                            .foregroundStyle(.white.opacity(0.9))
                                    }
                                }
                            }
                            .padding(16)
                        }
                        .frame(width: 200, height: 200, alignment: .topLeading)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(.white.opacity(0.2))
                        )
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    .frame(maxHeight: .infinity, alignment: .topLeading)
                } else {
                    ContentUnavailableView("No data", systemImage: "cloud.slash")
                }
            }
            .navigationTitle("Weather")
        }
        .task {
            await loadZurichWeather()
        }
    }

    @MainActor
    private func loadZurichWeather() async {
        isLoading = true
        errorMessage = nil
        do {
            // Zurich coordinates
            let lat = 47.3769
            let lon = 8.5417
            let snapshot = try await WeatherService.shared.fetchWeatherSnapshot(latitude: lat, longitude: lon)
            self.weather = snapshot.current
            self.nextHourPrecipitation = snapshot.nextHourPrecipitation
            self.todayPrecipitationSum = snapshot.todayPrecipitationSum
        } catch {
            self.errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

#Preview {
    ContentView()
}
