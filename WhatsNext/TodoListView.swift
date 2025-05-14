import SwiftUI

struct TodoListView: View {
    @State private var database: DatabaseManager = .init()

    var body: some View {
        NavigationView {
            VStack {
                // Input field
                HStack {
                    TextField("Enter new task", text: $database.newTask)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding(.vertical, 8)

                    Button(action: database.addTask) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.green)
                            .font(.title2)
                    }
                    .disabled(database.newTask.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .padding(.horizontal)

                // Task List
                List {
                    ForEach(database.todos) { todo in
                        HStack {
                            Image(systemName: todo.isCompleted ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(todo.isCompleted ? .green : .gray)
                                .onTapGesture {
                                    database.toggleTask(todo)
                                }

                            Text(todo.title)
                                .strikethrough(todo.isCompleted, color: .gray)
                                .foregroundColor(todo.isCompleted ? .gray : .primary)
                        }
                    }
                    .onDelete(perform: database.deleteTask)
                }
                .listStyle(PlainListStyle())
                .refreshable {
                    await database.fetchTasks()
                }
            }
            .navigationTitle("What's Next?")
        }
        .alert(database.output, isPresented: $database.alertPresented) {
            Button("Ok") {
                database.alertPresented = false
            }
        }
    }
}

#Preview {
    TodoListView()
}
