//
//  main.swift
//  Send Message Bot
//
//  Created by Anton Nagornyi on 5.3.25..
//

import Foundation

func sendMessage(token: String, chatId: Int, text: String) {
    let urlString = "https://api.telegram.org/bot\(token)/sendMessage"
    var urlComponents = URLComponents(string: urlString)!
    urlComponents.queryItems = [
        URLQueryItem(name: "chat_id", value: "\(chatId)"),
        URLQueryItem(name: "text", value: text)
    ]
    
    guard let url = urlComponents.url else {
//        print("Ошибка формирования URL")
        return
    }
    
    let task = URLSession.shared.dataTask(with: url) { data, response, error in
        if let error = error {
//            print("Ошибка: \(error.localizedDescription)")
            return
        }
        if let data = data, let responseString = String(data: data, encoding: .utf8) {
//            print("Ответ API: \(responseString)")
        }
    }
    task.resume()
}
//// Пример вызова функции:
let token = "7691790161:AAEYGFJE6t1Qcmlh-GKwBrZ7zHtvKTpdnmI"
let chatId = 298645304

func fetchData(completion: @escaping (Result<String, Error>) -> Void) {
    let url = URL(string: "https://search.tw1.ru/api.php")!
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")

    // Тело запроса
    let requestBody: [String: Any] = [
        "key": "ecTR4mutvKXwLLq6wwmJDvdqCQbxvOm3OjKLMlI63wa7UKoaVT6JF2WGd6ZGMsV6"
    ]

    request.httpBody = try? JSONSerialization.data(withJSONObject: requestBody, options: [])

    // Выполняем запрос
    let task = URLSession.shared.dataTask(with: request) { data, response, error in
        if let error = error {
            completion(.failure(error))
            return
        }

        guard let data = data else {
            completion(.failure(NSError(domain: "No data", code: -1, userInfo: nil)))
            return
        }

        // Преобразуем данные в строку
        let responseString = String(data: data, encoding: .utf8) ?? "Ошибка кодировки"
        
        completion(.success(responseString))
            
    }

    task.resume()
}

struct Location: Equatable {
    var lat: Double
    var lon: Double
    var power: Int
    var timestamp: String
}

func parseLocations(from jsonString: String) -> [Location]? {
    // Преобразуем JSON-строку в Data
    guard let data = jsonString.data(using: .utf8) else { return nil }
    
    do {
        // Декодируем JSON в словарь
        if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
           let dataArray = json["DATA"] as? [[String: Any]] {
            
            var locations: [Location] = []
            
            // Перебираем элементы массива "DATA"
            for locationData in dataArray {
                if let latString = locationData["lat"] as? String,
                   let lonString = locationData["lon"] as? String,
                   let powerString = locationData["power"] as? String,
                   let timestamp = locationData["timestamp"] as? String {
                    
                    // Преобразуем данные в нужные типы
                    if let lat = Double(latString),
                       let lon = Double(lonString),
                       let power = Int(powerString) {
                        let location = Location(lat: lat, lon: lon, power: power, timestamp: timestamp)
                        locations.append(location)
                    }
                }
            }
            return locations
        }
    } catch {
//        print("Ошибка при обработке JSON: \(error.localizedDescription)")
    }
    
    return nil
}

var locationsArray = [Location]()

// Переменная для хранения времени последнего обновления
var lastUpdateTime: Date? = nil
var lastBattery = 0
var battery20 = false
var battery10 = false
var battery5 = false
var sheIsLost = false
var backOnline = false
// Таймер для обновления данных каждые 5 секунд
var updateTimer: Timer?

// Функция для обновления данных
func updateLocations() {
    fetchData { result in
        switch result {
        case .success(let response):
            let newLocations = parseLocations(from: response) ?? []
            
            checkIfDataUnchanged()
                
            // Проверяем, были ли изменения
            if newLocations != locationsArray {
                locationsArray = newLocations
//                checkIfDataUnchanged()
                lastUpdateTime = Date() // Обновляем время последнего обновления
                lastBattery = locationsArray[0].power
                if lastBattery > 20 {
                    battery5 = false
                    battery10 = false
                    battery20 = false
                }
                if lastBattery <= 5 && !battery5 {
                    battery5 = true
                    sendMessage(token: token, chatId: chatId, text: """
                    Она так и не добралась до зарядки🤦🏻‍♂️
                    Сейчас \(lastBattery)%
                    
                    В данный момент она тут
                    https://maps.google.com/?q=\(locationsArray[0].lat),\(locationsArray[0].lon)
                    """)
                } else if lastBattery <= 10 && !battery10 {
                    battery10 = true
                    sendMessage(token: token, chatId: chatId, text: """
                    Надеюсь она скоро поставит телефон на зарядку😕
                    Сейчас там \(lastBattery)%
                    
                    В данный момент она тут
                    https://maps.google.com/?q=\(locationsArray[0].lat),\(locationsArray[0].lon)
                    """)
                } else if lastBattery <= 20 && !battery20 {
                    battery20 = true
                    sendMessage(token: token, chatId: chatId, text: """
                    Так! У Жени скоро сядет телефон.
                    Сейчас там \(lastBattery)%
                    
                    В данный момент она тут
                    https://maps.google.com/?q=\(locationsArray[0].lat),\(locationsArray[0].lon)
                    """)
                }
//                print("Данные обновлены.")
//                for loc in locationsArray {
//                    print(loc)
//                    print("---")
//                }
            }

        case .failure(let error):
//            print("Ошибка: \(error.localizedDescription)")
        }
    }
}

func stringToDate(_ dateString: String) -> Date? {
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
    dateFormatter.timeZone = TimeZone(identifier: "UTC") // Указываем временную зону

    return dateFormatter.date(from: dateString)
}

// Функция для проверки, изменились ли данные за последние 5 минут
func checkIfDataUnchanged() {
    
    guard !locationsArray.isEmpty && lastUpdateTime != nil else {return}
    // Проверяем, прошло ли 5 минут с последнего обновления
    let timeDifference = Date().timeIntervalSince(lastUpdateTime!)
//    print("timeDifference \(timeDifference)")
    let lastDate = stringToDate(locationsArray[0].timestamp)
    let nextDate = stringToDate(locationsArray[1].timestamp)
    let firtToSecondDifference = nextDate!.timeIntervalSince(lastDate!)
//    print("firtToSecondDifference - \(firtToSecondDifference)")
    
    if timeDifference >= 300 && !sheIsLost { // 300 секунд = 5 минут
        // Данные не изменились в течение 5 минут
        sheIsLost = true
        sendMessage(token: token, chatId: chatId, text: """
                    ПИЗДЕЦ!!! ВСЁ ПРОПАЛО!!!! МЫ ЕЁ ПОТЕРЯЛИ!!!!
                    На телефоне было \(lastBattery)%
                    
                    Последний раз её видели тут!!!
                    https://maps.google.com/?q=\(locationsArray[0].lat),\(locationsArray[0].lon)
                    """)
        // Обновляем время последнего обновления
        lastUpdateTime = Date()
    } else {
        sheIsLost = false
        if firtToSecondDifference <= -300 && !backOnline {
            backOnline = true
            sendMessage(token: token, chatId: chatId, text: """
                        Она снова онлайн!
                        На телефоне сейчас \(lastBattery)%
                        
                        В данный момент она тут
                        https://maps.google.com/?q=\(locationsArray[0].lat),\(locationsArray[0].lon)
                        """)
        } else if firtToSecondDifference > -300 {
            backOnline = false
        }
    }
//    print("lastUpdateTime \(lastUpdateTime)")
}

updateLocations()

// Таймер обновления массива locationsArray каждые 5 секунд
updateTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
    updateLocations()
//    print("updateLocations")
//    checkIfDataUnchanged()
//    print("checkIfDataUnchanged")
    

}

// Запускаем RunLoop для работы таймера
RunLoop.current.run()

