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

    private enum CodingKeys: String, CodingKey {
        case currentWeather = "current_weather"
    }
}

public final class WeatherService {
    public static let shared = WeatherService()

    private init() {}

    public func fetchCurrentWeather(latitude: Double, longitude: Double) async throws -> CurrentWeather {
        let urlString = "https://api.open-meteo.com/v1/forecast?latitude=\(latitude)&longitude=\(longitude)&current_weather=true"
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }
        let (data, _) = try await URLSession.shared.data(from: url)
        let decoded = try JSONDecoder().decode(OpenMeteoResponse.self, from: data)
        return decoded.currentWeather
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
