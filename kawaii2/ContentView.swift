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
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Zurich")
                                .font(.headline)
                                .foregroundStyle(.secondary)

                            Text(String(format: "%.0f ℃", weather.temperature))
                                .font(.system(size: 56, weight: .semibold, design: .rounded))

                            Text(WeatherService.description(for: weather.weathercode))
                                .font(.title3)
                                .foregroundStyle(.secondary)

                            HStack(spacing: 8) {
                                Image(systemName: "wind")
                                    .foregroundStyle(.secondary)
                                Text(String(format: "Wind %.0f km/h", weather.windspeed))
                                    .font(.subheadline)
                            }
                        }
                        .padding(16)
                        .frame(width: 200, height: 200, alignment: .topLeading)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
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
            let current = try await WeatherService.shared.fetchCurrentWeather(latitude: lat, longitude: lon)
            self.weather = current
        } catch {
            self.errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

#Preview {
    ContentView()
}
