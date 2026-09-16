import Foundation

/// Thin client for the DSHA desktop bridge (`server/remote-api.cjs`).
struct RemoteAPI {
    var baseURL: String

    func health() async throws -> Bool {
        let data = try await request("\(baseURL)/health")
        return (try? JSONDecoder().decode(Health.self, from: data))?.ok == true
    }

    func devices() async throws -> [Device] {
        let data = try await request("\(baseURL)/devices")
        return (try? JSONDecoder().decode(DeviceList.self, from: data).devices) ?? []
    }

    func plugins() async throws -> [Plugin] {
        let data = try await request("\(baseURL)/plugins")
        return (try? JSONDecoder().decode(PluginList.self, from: data).plugins) ?? []
    }

    func install(_ package: String) async throws {
        _ = try await postJSON("\(baseURL)/install", body: ["pkg": package])
    }

    func exec(_ command: String) async throws -> ExecResult {
        let data = try await postJSON("\(baseURL)/exec", body: ["cmd": command])
        return (try? JSONDecoder().decode(ExecResult.self, from: data))
            ?? ExecResult(ok: false, stdout: "", stderr: "invalid response")
    }

    func upload(data: Data, name: String) async throws {
        var request = URLRequest(url: URL(string: "\(baseURL)/upload?name=\(name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "file")")!)
        request.httpMethod = "POST"
        request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        request.httpBody = data
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
    }

    private func request(_ urlString: String) async throws -> Data {
        let url = URL(string: urlString)!
        var request = URLRequest(url: url)
        request.setValue("dsha-ios", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        return data
    }

    private func postJSON(_ urlString: String, body: [String: Any]) async throws -> Data {
        var request = URLRequest(url: URL(string: urlString)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        return data
    }
}

struct Health: Codable { let ok: Bool }
struct Device: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let host: String
    let platform: String
}
struct DeviceList: Codable { let devices: [Device] }
struct Plugin: Codable, Identifiable {
    var id: String { name }
    let name: String
    let version: String
    let description: String?
}
struct PluginList: Codable { let plugins: [Plugin] }
struct ExecResult: Codable {
    let ok: Bool
    let stdout: String
    let stderr: String
}
