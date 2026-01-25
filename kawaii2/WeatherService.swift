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
}

public struct DailyWeather: Decodable {
    public let time: [String]
    public let precipitationSum: [Double]

    private enum CodingKeys: String, CodingKey {
        case time
        case precipitationSum = "precipitation_sum"
    }
}

public struct WeatherSnapshot {
    public let current: CurrentWeather
    public let nextHourPrecipitation: Double?
    public let todayPrecipitationSum: Double?
}

public final class WeatherService {
    public static let shared = WeatherService()

    private init() {}

    public func fetchWeatherSnapshot(latitude: Double, longitude: Double) async throws -> WeatherSnapshot {
        let urlString = "https://api.open-meteo.com/v1/forecast?latitude=\(latitude)&longitude=\(longitude)&current_weather=true&hourly=precipitation&daily=precipitation_sum&forecast_days=1&timezone=auto"
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }
        let (data, _) = try await URLSession.shared.data(from: url)
        let decoded = try JSONDecoder().decode(OpenMeteoResponse.self, from: data)
        let currentTime = decoded.currentWeather.time
        let nextHourPrecipitation = Self.nextHourPrecipitation(from: decoded.hourly, currentTime: currentTime)
        let todayPrecipitationSum = decoded.daily.precipitationSum.first
        return WeatherSnapshot(
            current: decoded.currentWeather,
            nextHourPrecipitation: nextHourPrecipitation,
            todayPrecipitationSum: todayPrecipitationSum
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

    public static func description(for code: Int) -> String {
        switch code {
        case 0:
            return "Clear sky"
        case 1...3:
            return "Mainly/partly cloudy"
        case 45, 48:
            return "Fog"
        case 51...57:
            return "Drizzle"
        case 61...67:
            return "Rain"
        case 71...77:
            return "Snow"
        case 80...82:
            return "Rain showers"
        case 85...86:
            return "Snow showers"
        case 95:
            return "Thunderstorm"
        case 96...99:
            return "Thunderstorm with hail"
        default:
            return "Unknown"
        }
    }
}
