import SwiftUI

private struct RepositorySidebarSheetPresenterModifier<
    AddSheetContent: View,
    DirectoryPickerSheetContent: View,
    TokenInputSheetContent: View,
    EditingItem: Identifiable,
    EditSheetContent: View
>: ViewModifier {
    @Binding var isAddingRepositoryPresented: Bool
    let addRepositorySheet: () -> AddSheetContent
    @Binding var isDirectoryPickerPresented: Bool
    let directoryPickerSheet: () -> DirectoryPickerSheetContent
    @Binding var isTokenInputPresented: Bool
    let tokenInputSheet: () -> TokenInputSheetContent
    @Binding var editingItem: EditingItem?
    let editRepositorySheet: (EditingItem) -> EditSheetContent

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $isAddingRepositoryPresented) {
                addRepositorySheet()
            }
            .sheet(isPresented: $isDirectoryPickerPresented) {
                directoryPickerSheet()
            }
            .sheet(isPresented: $isTokenInputPresented) {
                tokenInputSheet()
            }
            .sheet(item: $editingItem) { item in
                editRepositorySheet(item)
            }
    }
}

public extension View {
    func repositorySidebarSheetPresenters<
        AddSheetContent: View,
        DirectoryPickerSheetContent: View,
        TokenInputSheetContent: View,
        EditingItem: Identifiable,
        EditSheetContent: View
    >(
        isAddingRepositoryPresented: Binding<Bool>,
        @ViewBuilder addRepositorySheet: @escaping () -> AddSheetContent,
        isDirectoryPickerPresented: Binding<Bool>,
        @ViewBuilder directoryPickerSheet: @escaping () -> DirectoryPickerSheetContent,
        isTokenInputPresented: Binding<Bool>,
        @ViewBuilder tokenInputSheet: @escaping () -> TokenInputSheetContent,
        editingItem: Binding<EditingItem?>,
        @ViewBuilder editRepositorySheet: @escaping (EditingItem) -> EditSheetContent
    ) -> some View {
        modifier(
            RepositorySidebarSheetPresenterModifier(
                isAddingRepositoryPresented: isAddingRepositoryPresented,
                addRepositorySheet: addRepositorySheet,
                isDirectoryPickerPresented: isDirectoryPickerPresented,
                directoryPickerSheet: directoryPickerSheet,
                isTokenInputPresented: isTokenInputPresented,
                tokenInputSheet: tokenInputSheet,
                editingItem: editingItem,
                editRepositorySheet: editRepositorySheet
            )
        )
    }
}
