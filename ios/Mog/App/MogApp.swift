import SwiftUI

/// Dev-only host for the spike-1 tools. The product is the Exact app in app/; this target never ships.
@main
struct MogApp: App {
    var body: some Scene {
        WindowGroup {
            NavigationStack {
                List {
                    #if DEBUG
                    NavigationLink("Vertex picker") { VertexPickerView() }
                    NavigationLink("Landmark dump") { LandmarkDumpView() }
                    #endif
                    Text("Picked landmark indices: \(GeometryPipeline.landmarker.pickedCount) / 38")
                }
                .navigationTitle("Spike tools")
            }
        }
    }
}
