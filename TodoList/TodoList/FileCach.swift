
import Foundation
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
