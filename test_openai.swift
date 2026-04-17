import Foundation

let apiKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"] ?? ""
if apiKey.isEmpty {
    print("NO OPENAI_API_KEY")
    exit(1)
}

let requestJSON: [String: Any] = [
    "model": "gpt-4o",
    "stream": true,
    "input": [
        [
            "type": "message",
            "role": "user",
            "content": "Hello! Say test."
        ]
    ]
]
let requestData = try JSONSerialization.data(withJSONObject: requestJSON)

var request = URLRequest(url: URL(string: "https://api.openai.com/v1/responses")!)
request.httpMethod = "POST"
request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
request.addValue("application/json", forHTTPHeaderField: "Content-Type")

let semaphore = DispatchSemaphore(value: 0)

let task = URLSession.shared.dataTask(with: request) { data, response, error in
    if let error = error {
        print("Error: \(error)")
    } else if let response = response as? HTTPURLResponse {
        print("Status: \(response.statusCode)")
        if let data = data, let str = String(data: data, encoding: .utf8) {
            print("Response length: \(data.count)")
            print(String(str.prefix(500)))
        }
    }
    semaphore.signal()
}
task.resume()
semaphore.wait()
