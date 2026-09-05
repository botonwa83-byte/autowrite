import SwiftUI

/// Explicit fifth tab. Keeping this in SwiftUI avoids the UIKit-generated
/// More controller, which can swallow navigation taps on device.
struct MoreView: View {
    private enum Destination: Identifiable {
        case brands, projects
        var id: Self { self }
    }
    @State private var destination: Destination?
    var body: some View {
        NavigationStack {
            List {
                Section("工作区") {
                    Button { destination = .brands } label: {
                        Label("品牌中心", systemImage: "building.2")
                    }
                    Button { destination = .projects } label: {
                        Label("我的项目", systemImage: "folder")
                    }
                }
                Section("设置") {
                    NavigationLink { AboutView() } label: {
                        Label("关于 Apex 宣传台", systemImage: "info.circle")
                    }
                }
            }
            .navigationTitle("更多")
        }
        .sheet(item: $destination) { destination in
            NavigationStack {
                switch destination {
                case .brands: BrandCenterView()
                case .projects: ProjectsView()
                }
            }
        }
    }
}

private struct AboutView: View {
    var body: some View {
        List {
            Section("Apex 宣传台") {
                Text("本地优先的品牌资料、推广项目和发布复盘工具。")
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("关于")
    }
}
