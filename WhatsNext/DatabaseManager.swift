import SwiftUI
import CloudKit

struct TodoItem: Identifiable {
    var id: CKRecord.ID
    var title: String
    var isCompleted: Bool

    init(id: CKRecord.ID = CKRecord.ID(recordName: UUID().uuidString), title: String, isCompleted: Bool = false) {
        self.id = id
        self.title = title
        self.isCompleted = isCompleted
    }
    
    init?(record: CKRecord) {
        guard let title = record["title"] as? String,
              let isCompleted = record["isCompleted"] as? Int else {
            print("Error initializing TodoItem - Record: \(record)")
            return nil
        }
        self.id = record.recordID
        self.title = title
        self.isCompleted = isCompleted == 1
    }

    var record: CKRecord {
        let record = CKRecord(recordType: "ToDoItem", recordID: id)
        record["title"] = title as CKRecordValue
        record["isCompleted"] = (isCompleted ? 1 : 0) as CKRecordValue
        return record
    }
}

@Observable
@MainActor
final class DatabaseManager {
    var todos: [TodoItem] = []
    var newTask = ""
    var output = ""
    var alertTitle: LocalizedStringKey = "Error message"
    var alertPresented: Bool = false
    // MARK: - Private properties
    private let ckManager = CloudKitManager()
    private var databaseTask: Task<Void, Error>?
    
    init() {
        Task {
            await fetchTasks()
        }
    }
    
    func addTask() {
            let task = TodoItem(title: newTask.trimmingCharacters(in: .whitespaces))
            Task { // Use a new Task (don't reuse databaseTask)
                do {
                    try await ckManager.save(task)
                    await MainActor.run {
                        newTask = ""
                    }
                    await fetchTasks() // Wait for fetch after save
                } catch {
                    await MainActor.run {
                        output = error.localizedDescription
                        alertTitle = "Error Saving Task"
                        alertPresented = true
                    }
                }
            }
        }

        func toggleTask(_ task: TodoItem) {
            Task { // New task for each toggle
                var updated = task
                updated.isCompleted.toggle()
                do {
                    try await ckManager.save(updated)
                    await fetchTasks() // Refresh after update
                } catch {
                    await MainActor.run {
                        output = error.localizedDescription
                        alertTitle = "Error Completing Task"
                        alertPresented = true
                    }
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
                    await MainActor.run {
                        output = error.localizedDescription
                        alertTitle = "Error Deleting Task"
                        alertPresented = true
                    }
                }
            }
            todos.remove(atOffsets: offsets) // Optimistic UI update
        }
    
    // MARK: - Private methods
    
    private func fetchTasks() async {
        do {
            let fetchedTodos = try await ckManager.fetchAll()
            await MainActor.run {
                todos = fetchedTodos
            }
        } catch {
            output = error.localizedDescription
            alertTitle = "Error Fetching Task"
            alertPresented = true
        }
    }
}

actor CloudKitManager {
    private let database: CKDatabase

    init() {
        let container = CKContainer(identifier: "iCloud.com.techonte.WhatsNext.ToDo")
        self.database = container.privateCloudDatabase
    }

    func save(_ item: TodoItem) async throws {
        let record = item.record
        print("Saving record: \(record.recordID.recordName)")
        _ = try await database.save(record)
    }
    
    func remove(_ item: TodoItem) async throws {
        print("Deleting record: \(item.id.recordName)")
        try await database.deleteRecord(withID: item.id)
    }

    func fetchAll() async throws -> [TodoItem] {
        let query = CKQuery(
            recordType: "ToDoItem",
            predicate: NSPredicate(value: true) // Fetch all records
        )
        // Sort by a queryable field (e.g., title)
        query.sortDescriptors = [NSSortDescriptor(key: "title", ascending: true)]
        
        let result = try await database.records(matching: query)
        return result.matchResults.compactMap {
            guard case .success(let record) = $0.1 else { return nil }
            return TodoItem(record: record)
        }
    }
}
