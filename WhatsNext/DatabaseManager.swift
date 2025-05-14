import SwiftUI
import CloudKit

protocol TodoItem
where Self: Identifiable {
    var record: CKRecord { get }
    var id: CKRecord.ID { get }
    var title: String { get set }
    var isCompleted: Bool { get set }
}

struct TodoItemImpl: TodoItem {
    let record: CKRecord // Store the entire record
    
    var id: CKRecord.ID { record.recordID }
    var title: String {
        get { record["title"] as? String ?? "" }
        set { record["title"] = newValue as CKRecordValue }
    }
    var isCompleted: Bool {
        get { (record["isCompleted"] as? Int ?? 0) == 1 }
        set { record["isCompleted"] = (newValue ? 1 : 0) as CKRecordValue }
    }
    
    // Initialize from an existing CKRecord (for fetched items)
    init(record: CKRecord) {
        self.record = record
    }
    
    // Initialize a new item (for creation)
    init(title: String, isCompleted: Bool = false) {
        let recordID = CKRecord.ID(recordName: UUID().uuidString)
        let record = CKRecord(recordType: "ToDoItem", recordID: recordID)
        record["title"] = title as CKRecordValue
        record["isCompleted"] = (isCompleted ? 1 : 0) as CKRecordValue
        self.record = record
    }
}

@MainActor
protocol DatabaseManager
where Self: Observable {
    var todos: [any TodoItem] { get }
    var newTask: String { get set }
    var output: LocalizedStringKey { get set }
    var alertPresented: Bool { get set }
    
    func addTask()
    func toggleTask(_ task: any TodoItem)
    func deleteTask(at offsets: IndexSet)
    
    func fetchTasks() async
}

@Observable
final class DatabaseManagerImpl: DatabaseManager {
    var todos: [any TodoItem] = []
    var newTask = ""
    var output: LocalizedStringKey = ""
    var alertPresented: Bool = false
    // MARK: - Private properties
    private let ckManager = CloudKitManager()
    
    init() {
        Task {
            await fetchTasks()
        }
    }
    
    func addTask() {
        let task = TodoItemImpl(title: newTask.trimmingCharacters(in: .whitespaces))
        Task {
            do {
                try await ckManager.save(task)
                newTask = ""
                todos.append(task)
            } catch {
                output = LocalizedStringKey(error.localizedDescription)
                alertPresented = true
            }
        }
    }
    
    func toggleTask(_ task: any TodoItem) {
        Task {
            do {
                // Create a mutable copy of the record
                let updatedRecord = task.record
                
                // Toggle the isCompleted field directly on the record
                let currentValue = (updatedRecord["isCompleted"] as? Int ?? 0)
                updatedRecord["isCompleted"] = (currentValue == 0 ? 1 : 0) as CKRecordValue
                
                // Save the updated record
                try await ckManager.save(TodoItemImpl(record: updatedRecord))
                await fetchTasks() // Refresh data
            } catch {
                output = LocalizedStringKey(error.localizedDescription)
                alertPresented = true
            }
        }
    }
    
    func deleteTask(at offsets: IndexSet) {
        let toDelete = offsets.map { todos[$0] }
        Task { // New task for deletion
            do {
                for item in toDelete {
                    try await ckManager.remove(item)
                }
                await fetchTasks() // Refresh after deletion
            } catch {
                output = LocalizedStringKey(error.localizedDescription)
                alertPresented = true
            }
        }
    }
    
    // MARK: - Private methods
    
    func fetchTasks() async {
        do {
            let fetchedTodos = try await ckManager.fetchAll()
            todos = fetchedTodos
        } catch {
            output = LocalizedStringKey(error.localizedDescription)
            alertPresented = true
        }
    }
}


