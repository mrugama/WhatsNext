import CloudKit

actor CloudKitManager {
    private let database: CKDatabase
    
    init() {
        let container = CKContainer(identifier: "iCloud.com.techonte.WhatsNext.ToDo")
        self.database = container.privateCloudDatabase
    }
    
    func save(_ item: any TodoItem) async throws {
        try await database.save(item.record)
    }
    
    func remove(_ item: any TodoItem) async throws {
        try await database.deleteRecord(withID: item.record.recordID)
    }
    
    func fetchAll() async throws -> [any TodoItem] {
        let query = CKQuery(
            recordType: "ToDoItem",
            predicate: NSPredicate(value: true) // Fetch all records
        )
        let result = try await database.records(matching: query)
        
        return result.matchResults.compactMap {
            guard case .success(let record) = $0.1 else { return nil }
            return TodoItemImpl(record: record) // Preserve the original record
        }
    }
}
