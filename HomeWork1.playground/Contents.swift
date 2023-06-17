import UIKit
import Foundation

// Структура для представления дела
struct TodoItem: Codable, Equatable {
    let id: String
    let text: String
    let importance: Importance?
    let deadline: Date?
    let isDone: Bool
    let creationDate: Date
    let modificationDate: Date?

    // Перечисление для важности дела
    enum Importance: String, Codable {
        case unimportant
        case ordinary
        case important
    }

    // Ключи для кодирования и декодирования
    private enum CodingKeys: String, CodingKey {
        case id, text, importance, deadline, isDone, creationDate, modificationDate
    }

    // Инициализатор для создания дела
    init(id: String = UUID().uuidString, text: String, importance: Importance? = nil, deadline: Date? = nil, isDone: Bool, creationDate: Date = Date(), modificationDate: Date? = nil) {
        self.id = id
        self.text = text
        self.importance = importance
        self.deadline = deadline
        self.isDone = isDone
        self.creationDate = creationDate
        self.modificationDate = modificationDate
    }

    // Функция кодирования дела
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(text, forKey: .text)
        try container.encode(importance, forKey: .importance)
        try container.encode(deadline, forKey: .deadline)
        try container.encode(isDone, forKey: .isDone)
        try container.encode(creationDate, forKey: .creationDate)
        try container.encode(modificationDate, forKey: .modificationDate)
    }

    // Перегрузка оператора равенства для сравнения дел
    static func == (lhs: TodoItem, rhs: TodoItem) -> Bool {
        return lhs.id == rhs.id
    }
}

// Расширение для разбора и форматирования данных JSON
extension TodoItem {
    // Форматтер для даты
    static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()

    // Функция для разбора JSON в объект TodoItem
    static func parse(json: Any) -> TodoItem? {
        guard let jsonDict = json as? [String: Any],
            let id = jsonDict["id"] as? String,
            let text = jsonDict["text"] as? String,
            let isDone = jsonDict["isDone"] as? Bool,
            let creationDateString = jsonDict["creationDate"] as? String,
            let creationDate = dateFormatter.date(from: creationDateString)
        else {
            return nil
        }

        // Проверка наличия важности дела
        let importance: Importance? = {
            if let importanceString = jsonDict["importance"] as? String,
                let importance = Importance(rawValue: importanceString),
                importance != .ordinary {
                return importance
            }
            return nil
        }()

        // Проверка наличия дедлайна
        let deadlineDate: Date? = {
            if let deadlineDateString = jsonDict["deadline"] as? String {
                return dateFormatter.date(from: deadlineDateString)
            }
            return nil
        }()

        let modificationDateString: String? = jsonDict["modificationDate"] as? String

        // Проверка наличия даты модификации
        let modificationDate: Date? = {
            if let dateString = modificationDateString {
                return dateFormatter.date(from: dateString)
            }
            return nil
        }()

        // Создание объекта TodoItem
        return TodoItem(id: id, text: text, importance: importance, deadline: deadlineDate, isDone: isDone, creationDate: creationDate, modificationDate: modificationDate)
    }

    // Преобразование TodoItem в JSON
    var json: Any {
        var jsonDict: [String: Any] = [
            "id": id as Any,
            "text": text,
            "isDone": isDone,
            "creationDate": TodoItem.dateFormatter.string(from: creationDate)
        ]

        // Добавление важности, если она не обычная
        if let importance = importance, importance != .ordinary {
            jsonDict["importance"] = importance.rawValue
        }

        // Добавление дедлайна, если он задан
        if let deadline = deadline {
            jsonDict["deadline"] = TodoItem.dateFormatter.string(from: deadline)
        }

        // Добавление даты модификации, если она задана
        if let modificationDate = modificationDate {
            jsonDict["modificationDate"] = TodoItem.dateFormatter.string(from: modificationDate)
        }

        return simplifyDates(jsonDict)
    }

    // Рекурсивная функция для упрощения дат в JSON
    private func simplifyDates(_ json: Any) -> Any {
        if let dict = json as? [String: Any] {
            var simplifiedDict: [String: Any] = [:]
            for (key, value) in dict {
                if let date = value as? Date {
                    simplifiedDict[key] = TodoItem.dateFormatter.string(from: date)
                } else {
                    simplifiedDict[key] = simplifyDates(value)
                }
            }
            return simplifiedDict
        } else if let array = json as? [Any] {
            return array.map { simplifyDates($0) }
        }
        return json
    }

    // Получение JSON-данных из TodoItem
    func jsonData() -> Data? {
        let json = self.json
        guard JSONSerialization.isValidJSONObject(json) else {
            return nil
        }
        return try? JSONSerialization.data(withJSONObject: json, options: [])
    }

    // Создание TodoItem из JSON-данных
    static func from(jsonData: Data) -> TodoItem? {
        let json = try? JSONSerialization.jsonObject(with: jsonData, options: [])
        return parse(json: json as Any)
    }
}

// Класс для управления кэшем дел
class FileCache {
    private var todoItems: [TodoItem] = []
    private let fileURL: URL

    // Инициализация кэша с указанием файла
    init(fileURL: URL) {
        self.fileURL = fileURL
    }

    // Добавление дела в кэш
    func addTodoItem(_ todoItem: TodoItem) {
        if let existingIndex = todoItems.firstIndex(where: { $0.id == todoItem.id }) {
            // Если TodoItem с таким id уже существует, перезаписываем его данные
            todoItems[existingIndex] = todoItem
        } else {
            // В противном случае, добавляем новый TodoItem в коллекцию
            todoItems.append(todoItem)
        }
    }

    // Удаление дела из кэша по id
    func removeTodoItem(withID id: String) {
        todoItems.removeAll(where: { $0.id == id })
    }

    // Сохранение данных в файл
    func saveToFile() throws {
        let jsonData = try JSONEncoder().encode(todoItems)
        try jsonData.write(to: fileURL)
    }

    // Загрузка данных из файла
    func loadFromFile() throws {
        let jsonData = try Data(contentsOf: fileURL)
        todoItems = try JSONDecoder().decode([TodoItem].self, from: jsonData)
    }

    // Получение всех дел
    var allTodoItems: [TodoItem] {
        return todoItems
    }
}
