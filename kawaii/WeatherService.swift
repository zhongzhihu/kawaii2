import Foundation

public struct CurrentWeather: Decodable {
    public let temperature: Double
    public let windspeed: Double
    public let winddirection: Double
    public let weathercode: Int
    public let time: String

    private enum CodingKeys: String, CodingKey {
        case temperature
        case windspeed
        case winddirection
        case weathercode
        case time
    }
}

public struct OpenMeteoResponse: Decodable {
    public let currentWeather: CurrentWeather
    public let hourly: HourlyWeather
    public let daily: DailyWeather

    private enum CodingKeys: String, CodingKey {
        case currentWeather = "current_weather"
        case hourly
        case daily
    }
}

public struct HourlyWeather: Decodable {
    public let time: [String]
    public let precipitation: [Double]
    public let temperature: [Double]
    public let weathercode: [Int]
    public let precipitationProbability: [Double]?

    private enum CodingKeys: String, CodingKey {
        case time
        case precipitation
        case temperature = "temperature_2m"
        case weathercode
        case precipitationProbability = "precipitation_probability"
    }
}

public struct DailyWeather: Decodable {
    public let time: [String]
    public let precipitationSum: [Double]
    public let weathercode: [Int]
    public let temperatureMax: [Double]
    public let temperatureMin: [Double]
    public let precipitationProbabilityMax: [Double]?

    private enum CodingKeys: String, CodingKey {
        case time
        case precipitationSum = "precipitation_sum"
        case weathercode
        case temperatureMax = "temperature_2m_max"
        case temperatureMin = "temperature_2m_min"
        case precipitationProbabilityMax = "precipitation_probability_max"
    }
}

public struct DailyForecast: Identifiable {
    public let id = UUID()
    public let date: String
    public let weathercode: Int
    public let temperatureMax: Double
    public let temperatureMin: Double
    public let precipitationSum: Double?
    public let precipitationProbabilityMax: Double?
}

public struct WeatherSnapshot {
    public let current: CurrentWeather
    public let nextHourPrecipitation: Double?
    public let todayPrecipitationSum: Double?
    public let dailyForecasts: [DailyForecast]
    public let hourlyForecasts: [HourlyForecast]
}

public struct HourlyForecast: Identifiable {
    public let id = UUID()
    public let time: String
    public let temperature: Double
    public let weathercode: Int
    public let precipitation: Double?
    public let precipitationProbability: Double?
}

public final class WeatherService {
    public static let shared = WeatherService()

    private static let hourlyDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .iso8601)
        formatter.locale = Locale.autoupdatingCurrent
        formatter.timeZone = .autoupdatingCurrent
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm"
        return formatter
    }()

    private init() {}

    public func fetchWeatherSnapshot(latitude: Double, longitude: Double) async throws -> WeatherSnapshot {
        let urlString = "https://api.open-meteo.com/v1/forecast?latitude=\(latitude)&longitude=\(longitude)&current_weather=true&hourly=temperature_2m,precipitation,precipitation_probability,weathercode&daily=precipitation_sum,weathercode,temperature_2m_max,temperature_2m_min,precipitation_probability_max&forecast_days=8&timezone=auto"
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }
        let (data, _) = try await URLSession.shared.data(from: url)
        let decoded = try JSONDecoder().decode(OpenMeteoResponse.self, from: data)
        let currentTime = decoded.currentWeather.time
        let nextHourPrecipitation = Self.nextHourPrecipitation(from: decoded.hourly, currentTime: currentTime)
        let todayPrecipitationSum = decoded.daily.precipitationSum.first
        let dailyForecasts = Self.dailyForecasts(from: decoded.daily)
        let hourlyForecasts = Self.hourlyForecasts(from: decoded.hourly, currentTime: currentTime)
        return WeatherSnapshot(
            current: decoded.currentWeather,
            nextHourPrecipitation: nextHourPrecipitation,
            todayPrecipitationSum: todayPrecipitationSum,
            dailyForecasts: dailyForecasts,
            hourlyForecasts: hourlyForecasts
        )
    }

    private static func nextHourPrecipitation(from hourly: HourlyWeather, currentTime: String) -> Double? {
        guard let currentIndex = hourly.time.firstIndex(of: currentTime) else {
            return hourly.precipitation.first
        }
        let nextIndex = hourly.time.index(after: currentIndex)
        guard nextIndex < hourly.precipitation.endIndex else {
            return nil
        }
        return hourly.precipitation[nextIndex]
    }

    private static func dailyForecasts(from daily: DailyWeather) -> [DailyForecast] {
        let count = min(
            daily.time.count,
            daily.weathercode.count,
            daily.temperatureMax.count,
            daily.temperatureMin.count,
            daily.precipitationSum.count
        )
        guard count > 0 else {
            return []
        }
        return (0..<count).map { index in
            DailyForecast(
                date: daily.time[index],
                weathercode: daily.weathercode[index],
                temperatureMax: daily.temperatureMax[index],
                temperatureMin: daily.temperatureMin[index],
                precipitationSum: daily.precipitationSum[index],
                precipitationProbabilityMax: daily.precipitationProbabilityMax?[safe: index]
            )
        }
    }

    private static func hourlyForecasts(from hourly: HourlyWeather, currentTime: String) -> [HourlyForecast] {
        let count = min(hourly.time.count, hourly.temperature.count, hourly.precipitation.count, hourly.weathercode.count)
        guard count > 0 else {
            return []
        }

        let startIndex: Int
        if let currentDate = Self.hourlyDateFormatter.date(from: currentTime) {
            if let exactIndex = hourly.time.firstIndex(of: currentTime) {
                startIndex = exactIndex
            } else {
                startIndex = hourly.time.firstIndex(where: { time in
                    guard let date = Self.hourlyDateFormatter.date(from: time) else {
                        return false
                    }
                    return date >= currentDate
                }) ?? 0
            }
        } else {
            startIndex = hourly.time.firstIndex(of: currentTime) ?? 0
        }

        guard startIndex < count else {
            return []
        }

        let endIndex = min(startIndex + 5, count - 1)
        return (startIndex...endIndex).map { index in
            HourlyForecast(
                time: hourly.time[index],
                temperature: hourly.temperature[index],
                weathercode: hourly.weathercode[index],
                precipitation: hourly.precipitation[safe: index],
                precipitationProbability: hourly.precipitationProbability?[safe: index]
            )
        }
    }

    public static func description(for code: Int) -> String {
        switch code {
        case 0:
            return "Clear sky"
        case 1:
            return "Mainly clear"
        case 2:
            return "Partly cloudy"
        case 3:
            return "Cloudy"
        case 45, 48:
            return "Fog"
        case 51:
            return "Light drizzle"
        case 53:
            return "Moderate drizzle"
        case 55:
            return "Dense drizzle"
        case 56:
            return "Light freezing drizzle"
        case 57:
            return "Dense freezing drizzle"
        case 61:
            return "Slight rain"
        case 63:
            return "Moderate rain"
        case 65:
            return "Heavy rain"
        case 66:
            return "Light freezing rain"
        case 67:
            return "Heavy freezing rain"
        case 71:
            return "Slight snow fall"
        case 73:
            return "Moderate snow fall"
        case 75:
            return "Heavy snow fall"
        case 77:
            return "Snow grains"
        case 80:
            return "Slight rain showers"
        case 81:
            return "Moderate rain showers"
        case 82:
            return "Violent rain showers"
        case 85:
            return "Slight snow showers"
        case 86:
            return "Heavy snow showers"
        case 95:
            return "Thunderstorm"
        case 96:
            return "Thunderstorm with slight hail"
        case 99:
            return "Thunderstorm with heavy hail"
        default:
            return "Unknown"
        }
    }

    public static func iconName(for code: Int) -> String {
        let baseName: String
        switch code {
        case 0:
            baseName = "wi-day-sunny"
        case 1, 2:
            baseName = "wi-day-cloudy"
        case 3:
            baseName = "wi-cloudy"
        case 45, 48:
            baseName = "wi-fog"
        case 51, 53:
            baseName = "wi-sprinkle"
        case 55:
            baseName = "wi-raindrops"
        case 56, 57:
            baseName = "wi-rain-mix"
        case 61:
            baseName = "wi-rain"
        case 63:
            baseName = "wi-rain"
        case 65:
            baseName = "wi-rain-wind"
        case 66, 67:
            baseName = "wi-rain-mix"
        case 71, 73:
            baseName = "wi-snow"
        case 75:
            baseName = "wi-snow-wind"
        case 77:
            baseName = "wi-snowflake-cold"
        case 80, 81:
            baseName = "wi-showers"
        case 82:
            baseName = "wi-showers"
        case 85, 86:
            baseName = "wi-snow"
        case 95:
            baseName = "wi-thunderstorm"
        case 96, 99:
            baseName = "wi-storm-showers"
        default:
            baseName = "wi-na"
        }
        return baseName
    }

    public static func symbolName(for code: Int) -> String {
        switch code {
        case 0:
            return "sun.max.fill"
        case 1, 2:
            return "cloud.sun.fill"
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
        case 61:
            return "cloud.rain.fill"
        case 63:
            return "cloud.rain.fill"
        case 65:
            return "cloud.heavyrain.fill"
        case 66, 67:
            return "cloud.sleet.fill"
        case 71, 73:
            return "cloud.snow.fill"
        case 75:
            return "snowflake"
        case 77:
            return "snowflake"
        case 80, 81:
            return "cloud.rain.fill"
        case 82:
            return "cloud.heavyrain.fill"
        case 85, 86:
            return "cloud.snow.fill"
        case 95:
            return "cloud.bolt.rain.fill"
        case 96, 99:
            return "cloud.bolt.rain.fill"
        default:
            return "cloud.fill"
        }
    }
}

private extension Array {
    subscript(safe index: Index) -> Element? {
        guard indices.contains(index) else {
            return nil
        }
        return self[index]
    }
}
