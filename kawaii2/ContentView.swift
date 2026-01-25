<<<<<<< HEAD
//
//  ContentView.swift
//  kawaii2
//
//  Created by Zhongzhi on 25.01.2026.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("Hello, world!")
        }
        .padding()
=======
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
                    VStack(spacing: 16) {
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text("Zurich")
                                .font(.largeTitle).bold()
                            Text(weather.time)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        VStack(spacing: 8) {
                            Text(String(format: "%.1f ℃", weather.temperature))
                                .font(.system(size: 56, weight: .semibold, design: .rounded))
                            Text(WeatherService.description(for: weather.weathercode))
                                .font(.title3)
                                .foregroundStyle(.secondary)
                        }

                        HStack(spacing: 24) {
                            Label(String(format: "%.0f km/h", weather.windspeed), systemImage: "wind")
                            Label(String(format: "%.0f°", weather.winddirection), systemImage: "location.north.line")
                        }
                        .font(.headline)
                    }
                    .padding()
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
>>>>>>> c51a071 (Initial Commit)
    }
}

#Preview {
    ContentView()
}
