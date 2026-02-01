//
//  SettingsView.swift
//  kawaii2
//
//  Created by Zhongzhi on 25.01.2026.
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var temperatureUnitRaw: String
    @Binding var precipitationUnitRaw: String

    private var selectedUnit: Binding<TemperatureUnit> {
        Binding(
            get: {
                TemperatureUnit(rawValue: temperatureUnitRaw)
                    ?? (Locale.current.usesMetricSystem ? .celsius : .fahrenheit)
            },
            set: { newValue in
                temperatureUnitRaw = newValue.rawValue
            }
        )
    }

    private var selectedPrecipitationUnit: Binding<PrecipitationUnit> {
        Binding(
            get: {
                PrecipitationUnit(rawValue: precipitationUnitRaw)
                    ?? (Locale.current.usesMetricSystem ? .millimeters : .inches)
            },
            set: { newValue in
                precipitationUnitRaw = newValue.rawValue
            }
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    SettingsCard(title: "Units") {
                        VStack(alignment: .leading, spacing: 16) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Temperature")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                Picker("Temperature", selection: selectedUnit) {
                                    ForEach(TemperatureUnit.allCases) { unit in
                                        Text(unit.label).tag(unit)
                                    }
                                }
                                .pickerStyle(.segmented)
                            }

                            VStack(alignment: .leading, spacing: 8) {
                                Text("Precipitation")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                Picker("Precipitation", selection: selectedPrecipitationUnit) {
                                    ForEach(PrecipitationUnit.allCases) { unit in
                                        Text(unit.label).tag(unit)
                                    }
                                }
                                .pickerStyle(.segmented)
                            }
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

private struct SettingsCard<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.primary)

            content
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.08))
        )
    }
}

enum TemperatureUnit: String, CaseIterable, Identifiable {
    case celsius
    case fahrenheit

    var id: String { rawValue }

    var label: String {
        switch self {
        case .celsius:
            return "Celsius"
        case .fahrenheit:
            return "Fahrenheit"
        }
    }

    func formatted(temperatureInCelsius: Double) -> String {
        let value: Double
        switch self {
        case .celsius:
            value = temperatureInCelsius
        case .fahrenheit:
            value = (temperatureInCelsius * 9 / 5) + 32
        }
        return String(format: "%.0f°", value)
    }
}

enum PrecipitationUnit: String, CaseIterable, Identifiable {
    case millimeters
    case inches

    var id: String { rawValue }

    var label: String {
        switch self {
        case .millimeters:
            return "Millimeters"
        case .inches:
            return "Inches"
        }
    }

    var symbol: String {
        switch self {
        case .millimeters:
            return "mm"
        case .inches:
            return "in"
        }
    }

    func formattedLabel(precipitationInMillimeters: Double) -> String {
        let value: Double
        switch self {
        case .millimeters:
            value = precipitationInMillimeters
        case .inches:
            value = precipitationInMillimeters / 25.4
        }
        return String(format: "Today %.1f %@", value, symbol)
    }

    func formattedAmount(precipitationInMillimeters: Double) -> String {
        let value: Double
        switch self {
        case .millimeters:
            value = precipitationInMillimeters
        case .inches:
            value = precipitationInMillimeters / 25.4
        }
        return String(format: "%.1f %@", value, symbol)
    }
}
