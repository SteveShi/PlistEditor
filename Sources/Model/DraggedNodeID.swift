import SwiftUI

/// A lightweight transferable reference to a node, used for outline drag-and-drop.
/// Only the node's identity travels (as its UUID string); the move is resolved
/// against the live tree on drop.
struct DraggedNodeID: Transferable {
    let id: UUID

    static var transferRepresentation: some TransferRepresentation {
        ProxyRepresentation(
            exporting: { $0.id.uuidString },
            importing: { DraggedNodeID(id: UUID(uuidString: $0) ?? UUID()) }
        )
    }
}
