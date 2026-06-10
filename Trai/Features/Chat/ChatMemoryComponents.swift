//
//  ChatMemoryComponents.swift
//  Trai
//
//  Memory-related UI components for chat
//

import SwiftUI
import SwiftData

// MARK: - Memory Saved Badge

struct MemorySavedBadge: View {
    let memories: [String]
    @Environment(\.modelContext) private var modelContext
    @State private var showMemories = false
    @State private var singleMemory: CoachMemory?
    @State private var persistenceError: ChatMemoryPersistenceError?

    private var displayText: String {
        if memories.count == 1 {
            return "Remembered"
        }
        return "Remembered \(memories.count) things"
    }

    var body: some View {
        Button {
            if memories.count == 1 {
                fetchSingleMemory()
            } else {
                showMemories = true
            }
        } label: {
            HStack(spacing: 6) {
                TraiLensSymbolIcon(size: 13, variant: .nodes, color: .secondary)
                Text(displayText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.purple.opacity(0.1))
            .clipShape(.capsule)
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showMemories) {
            SavedMemoriesSheet(memoryContents: memories)
                .presentationDetents([.medium])
                .traiSheetBranding()
        }
        .sheet(item: $singleMemory) { memory in
            MemoryDetailSheet(memory: memory, onDelete: {
                memory.isActive = false
                guard saveMemoryChange(title: "Memory Not Removed") else {
                    memory.isActive = true
                    return
                }
                singleMemory = nil
                HapticManager.lightTap()
            })
            .presentationDetents([.medium])
            .traiSheetBranding()
        }
        .alert(item: $persistenceError) { error in
            Alert(
                title: Text(error.title),
                message: Text(error.message),
                dismissButton: .default(Text("OK"))
            )
        }
    }

    private func fetchSingleMemory() {
        guard let content = memories.first else { return }
        let descriptor = FetchDescriptor<CoachMemory>(
            predicate: #Predicate { $0.isActive },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        let allMemories = (try? modelContext.fetch(descriptor)) ?? []
        singleMemory = allMemories.first { $0.content == content }
    }

    private func saveMemoryChange(title: String) -> Bool {
        do {
            try modelContext.save()
            NotificationCenter.default.post(name: .coachMemoriesChanged, object: nil)
            return true
        } catch {
            modelContext.rollback()
            persistenceError = ChatMemoryPersistenceError(
                title: title,
                message: error.localizedDescription
            )
            HapticManager.error()
            return false
        }
    }
}

// MARK: - Saved Memories Sheet

struct SavedMemoriesSheet: View {
    let memoryContents: [String]
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var memories: [CoachMemory] = []
    @State private var persistenceError: ChatMemoryPersistenceError?

    var body: some View {
        NavigationStack {
            List {
                ForEach(memories) { memory in
                    MemoryListRow(memory: memory, onDelete: {
                        deleteMemory(memory)
                    }, onUpdate: {
                        fetchMemories()
                    })
                }
            }
            .navigationTitle("Saved Memories")
            .toolbarTitleDisplayMode(.inlineLarge)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", systemImage: "checkmark") {
                        dismiss()
                    }
                    .labelStyle(.iconOnly)
                }
            }
            .onAppear {
                fetchMemories()
            }
        }
        .alert(item: $persistenceError) { error in
            Alert(
                title: Text(error.title),
                message: Text(error.message),
                dismissButton: .default(Text("OK"))
            )
        }
        .traiSheetBranding()
    }

    private func fetchMemories() {
        let descriptor = FetchDescriptor<CoachMemory>(
            predicate: #Predicate { $0.isActive },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        let allMemories = (try? modelContext.fetch(descriptor)) ?? []
        memories = allMemories.filter { memoryContents.contains($0.content) }
    }

    private func deleteMemory(_ memory: CoachMemory) {
        memory.isActive = false
        do {
            try modelContext.save()
            NotificationCenter.default.post(name: .coachMemoriesChanged, object: nil)
            HapticManager.lightTap()
        } catch {
            modelContext.rollback()
            memory.isActive = true
            persistenceError = ChatMemoryPersistenceError(
                title: "Memory Not Removed",
                message: error.localizedDescription
            )
            HapticManager.error()
        }
        fetchMemories()
    }
}

private struct ChatMemoryPersistenceError: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}
