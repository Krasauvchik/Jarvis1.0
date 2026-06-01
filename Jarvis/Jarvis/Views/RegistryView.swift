import SwiftUI

// MARK: - Registry List View

/// Top-level view showing all registries with add/edit/delete.
struct RegistryListView: View {
    @StateObject private var registryStore = RegistryStore.shared
    @State private var showNewRegistry = false
    @State private var newRegistryName = ""
    
    private var theme: JarvisTheme {
        JarvisTheme.current(for: ThemeManager.shared.currentTheme.colorScheme ?? .light)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Label(L10n.registries, systemImage: "tablecells")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(theme.textPrimary)
                Spacer()
                Button(action: { showNewRegistry = true }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(JarvisTheme.accent)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            
            if registryStore.registries.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(registryStore.registries) { registry in
                            NavigationLink(value: registry.id) {
                                registryCard(registry)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
        .background(theme.background)
        .navigationDestination(for: UUID.self) { registryId in
            if let registry = registryStore.registries.first(where: { $0.id == registryId }) {
                RegistryDetailView(registryId: registry.id)
            }
        }
        .alert(L10n.registryNew, isPresented: $showNewRegistry) {
            TextField(L10n.registryColumnName, text: $newRegistryName)
            Button(L10n.cancel, role: .cancel) { newRegistryName = "" }
            Button(L10n.save) {
                guard !newRegistryName.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                let registry = Registry(name: newRegistryName.trimmingCharacters(in: .whitespaces))
                registryStore.add(registry)
                newRegistryName = ""
            }
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "tablecells")
                .font(.system(size: 48))
                .foregroundColor(theme.textTertiary)
            Text(L10n.registryEmptyState)
                .font(.system(size: 16))
                .foregroundColor(theme.textSecondary)
                .multilineTextAlignment(.center)
            Button(action: { showNewRegistry = true }) {
                Label(L10n.registryNew, systemImage: "plus")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(JarvisTheme.accent))
            }
            .buttonStyle(.plain)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
    
    private func registryCard(_ registry: Registry) -> some View {
        HStack(spacing: 14) {
            Image(systemName: registry.icon)
                .font(.system(size: 20))
                .foregroundColor(JarvisTheme.accentTeal)
                .frame(width: 36, height: 36)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(JarvisTheme.accentTeal.opacity(0.15))
                )
            
            VStack(alignment: .leading, spacing: 3) {
                Text(registry.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(theme.textPrimary)
                HStack(spacing: 8) {
                    Text("\(registry.columns.count) \(registry.columns.count == 1 ? "column" : "columns")")
                    Text("•")
                    Text("\(registry.rows.count) \(registry.rows.count == 1 ? "row" : "rows")")
                }
                .font(.system(size: 12))
                .foregroundColor(theme.textSecondary)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.system(size: 14))
                .foregroundColor(theme.textTertiary)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(theme.cardBackground)
        )
    }
}

// MARK: - Registry Detail View

/// Shows columns + rows for a single registry. Supports add/edit rows & columns.
struct RegistryDetailView: View {
    let registryId: UUID
    @StateObject private var registryStore = RegistryStore.shared
    @State private var showAddColumn = false
    @State private var showAddRow = false
    @State private var editingRowId: UUID?
    
    private var theme: JarvisTheme {
        JarvisTheme.current(for: ThemeManager.shared.currentTheme.colorScheme ?? .light)
    }
    
    private var registry: Registry? {
        registryStore.registries.first { $0.id == registryId }
    }
    
    var body: some View {
        Group {
            if let registry = registry {
                registryContent(registry)
            } else {
                Text("Registry not found")
                    .foregroundColor(theme.textSecondary)
            }
        }
        .background(theme.background)
        .sheet(isPresented: $showAddColumn) {
            AddColumnSheet(registryId: registryId)
        }
        .sheet(isPresented: $showAddRow) {
            if let reg = registry {
                AddRowSheet(registry: reg)
            }
        }
    }
    
    @ViewBuilder
    private func registryContent(_ registry: Registry) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Toolbar
            HStack {
                Text(registry.name)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(theme.textPrimary)
                Spacer()
                Button(action: { showAddColumn = true }) {
                    Label(L10n.registryAddColumn, systemImage: "plus.rectangle.on.rectangle")
                        .font(.system(size: 13, weight: .medium))
                }
                .buttonStyle(.plain)
                Button(action: { showAddRow = true }) {
                    Label(L10n.registryAddRow, systemImage: "plus.circle")
                        .font(.system(size: 13, weight: .medium))
                }
                .buttonStyle(.plain)
                .disabled(registry.columns.isEmpty)
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            
            if registry.columns.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Text(L10n.registryAddColumn)
                        .font(.system(size: 15))
                        .foregroundColor(theme.textSecondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                registryTable(registry)
            }
        }
    }
    
    @ViewBuilder
    private func registryTable(_ registry: Registry) -> some View {
        ScrollView(.horizontal, showsIndicators: true) {
            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 0) {
                    // Header row
                    HStack(spacing: 0) {
                        Text("#")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(theme.textSecondary)
                            .frame(width: 40, alignment: .center)
                        
                        ForEach(registry.columns) { col in
                            Text(col.name)
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(theme.textPrimary)
                                .frame(minWidth: 120, alignment: .leading)
                                .padding(.horizontal, 8)
                            
                            if col.id != registry.columns.last?.id {
                                Divider().frame(height: 20)
                            }
                        }
                    }
                    .padding(.vertical, 10)
                    .background(theme.cardBackground.opacity(0.7))
                    
                    Divider()
                    
                    // Data rows
                    ForEach(Array(registry.rows.enumerated()), id: \.element.id) { index, row in
                        HStack(spacing: 0) {
                            Text("\(index + 1)")
                                .font(.system(size: 12))
                                .foregroundColor(theme.textTertiary)
                                .frame(width: 40, alignment: .center)
                            
                            ForEach(registry.columns) { col in
                                Text(row.cells[col.id.uuidString] ?? "—")
                                    .font(.system(size: 13))
                                    .foregroundColor(theme.textPrimary)
                                    .frame(minWidth: 120, alignment: .leading)
                                    .padding(.horizontal, 8)
                                
                                if col.id != registry.columns.last?.id {
                                    Divider().frame(height: 20)
                                }
                            }
                        }
                        .padding(.vertical, 8)
                        .background(index % 2 == 0 ? Color.clear : theme.cardBackground.opacity(0.3))
                        .contextMenu {
                            Button(role: .destructive) {
                                registryStore.deleteRow(in: registryId, rowId: row.id)
                            } label: {
                                Label(L10n.deleteAction, systemImage: "trash")
                            }
                        }
                    }
                    
                    if registry.rows.isEmpty {
                        Text(L10n.registryEmptyState)
                            .font(.system(size: 13))
                            .foregroundColor(theme.textSecondary)
                            .padding(16)
                    }
                }
            }
        }
        .padding(.horizontal, 20)
    }
}

// MARK: - Add Column Sheet

struct AddColumnSheet: View {
    let registryId: UUID
    @StateObject private var registryStore = RegistryStore.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var columnName = ""
    @State private var columnType: RegistryColumn.ColumnType = .text
    @State private var choiceOptions = ""
    
    private var theme: JarvisTheme {
        JarvisTheme.current(for: ThemeManager.shared.currentTheme.colorScheme ?? .light)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section(L10n.registryColumnName) {
                    TextField(L10n.registryColumnName, text: $columnName)
                }
                Section(L10n.registryColumnType) {
                    Picker(L10n.registryColumnType, selection: $columnType) {
                        ForEach(RegistryColumn.ColumnType.allCases, id: \.self) { ct in
                            Text(ct.displayName).tag(ct)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                if columnType == .singleChoice {
                    Section("Options (comma-separated)") {
                        TextField("Option 1, Option 2, …", text: $choiceOptions)
                    }
                }
            }
            .navigationTitle(L10n.registryAddColumn)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.save) {
                        let opts = columnType == .singleChoice
                            ? choiceOptions.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                            : []
                        let col = RegistryColumn(name: columnName.trimmingCharacters(in: .whitespaces), type: columnType, options: opts)
                        registryStore.addColumn(to: registryId, column: col)
                        dismiss()
                    }
                    .disabled(columnName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Add Row Sheet

struct AddRowSheet: View {
    let registry: Registry
    @StateObject private var registryStore = RegistryStore.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var cellValues: [String: String] = [:]
    
    private var theme: JarvisTheme {
        JarvisTheme.current(for: ThemeManager.shared.currentTheme.colorScheme ?? .light)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                ForEach(registry.columns) { col in
                    Section(col.name) {
                        cellEditor(for: col)
                    }
                }
            }
            .navigationTitle(L10n.registryAddRow)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.save) {
                        let row = RegistryRow(cells: cellValues)
                        registryStore.addRow(to: registry.id, row: row)
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
    
    @ViewBuilder
    private func cellEditor(for col: RegistryColumn) -> some View {
        let key = col.id.uuidString
        switch col.type {
        case .text:
            TextField(col.name, text: binding(for: key))
        case .number:
            TextField(col.name, text: binding(for: key))
                #if os(iOS)
                .keyboardType(.decimalPad)
                #endif
        case .date:
            DatePicker(col.name, selection: dateBinding(for: key), displayedComponents: .date)
        case .checkbox:
            Toggle(col.name, isOn: boolBinding(for: key))
        case .singleChoice:
            Picker(col.name, selection: binding(for: key)) {
                Text("—").tag("")
                ForEach(col.options, id: \.self) { opt in
                    Text(opt).tag(opt)
                }
            }
        }
    }
    
    private func binding(for key: String) -> Binding<String> {
        Binding(
            get: { cellValues[key] ?? "" },
            set: { cellValues[key] = $0 }
        )
    }
    
    private func boolBinding(for key: String) -> Binding<Bool> {
        Binding(
            get: { cellValues[key] == "true" },
            set: { cellValues[key] = $0 ? "true" : "false" }
        )
    }
    
    private func dateBinding(for key: String) -> Binding<Date> {
        Binding(
            get: {
                if let str = cellValues[key], let ti = TimeInterval(str) {
                    return Date(timeIntervalSince1970: ti)
                }
                return Date()
            },
            set: { cellValues[key] = String($0.timeIntervalSince1970) }
        )
    }
}
