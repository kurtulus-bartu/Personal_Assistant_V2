// ContentView.swift
import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0
    @State private var pomodoroEvents: [PlannerEvent] = []
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass: UserInterfaceSizeClass?
    
    var body: some View {
        ZStack(alignment: .bottom) {
            currentView
            
            // Alt, sabit boyutlu yüzen cam navigator (telefon + tablet)
            BottomNavigator(selectedTab: $selectedTab)
                .padding(.bottom, 4)  // biraz daha aşağıda dursun
                .zIndex(10)
        }
        .background(Color(UIColor.systemBackground).ignoresSafeArea())
    }
    
    // MARK: - Current View
    @ViewBuilder
    private var currentView: some View {
        switch selectedTab {
        case 0: PlannerView(selectedTab: $selectedTab)
        case 1: PomodoroView(events: $pomodoroEvents)
        case 2: placeholderView(title: "Today", icon: "sun.max")
        case 3: placeholderView(title: "Health", icon: "heart")
        case 4: placeholderView(title: "Notes", icon: "note.text")
        case 5: placeholderView(title: "AI Assistant", icon: "sparkles")
        default: PlannerView(selectedTab: $selectedTab)
        }
    }
    
    private func placeholderView(title: String, icon: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: icon)
                .font(.system(size: 80, weight: .light))
                .foregroundColor(.blue.opacity(0.5))
            Text(title).font(.largeTitle).fontWeight(.semibold)
            Text("Yakında").font(.title3).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(UIColor.systemBackground))
    }
}

/// Alt navigator: 3 ana tab + sağda daire Others.
/// Sabit genişlik/yükseklik; büyük ekranda büyümez, küçükte güvenli kısılır.
struct BottomNavigator: View {
    @Binding var selectedTab: Int
    @State private var showingOthers = false
    
    private struct TabItem: Identifiable {
        let id = UUID()
        let title: String
        let systemImage: String
        let tag: Int
    }
    
    private let primary: [TabItem] = [
        .init(title: "Planner",  systemImage: "calendar",  tag: 0),
        .init(title: "Pomodoro", systemImage: "timer",     tag: 1),
        .init(title: "Today",    systemImage: "sun.max",   tag: 2),
    ]
    private let secondary: [TabItem] = [
        .init(title: "Health",   systemImage: "heart",     tag: 3),
        .init(title: "Notes",    systemImage: "note.text", tag: 4),
        .init(title: "AI",       systemImage: "sparkles",  tag: 5),
    ]
    
    var body: some View {
        GeometryReader { geo in
            // App Store benzeri ölçüler
            let circleSize: CGFloat   = 48
            let barHeight: CGFloat    = 54
            let targetBarWidth: CGFloat = 270
            let gap: CGFloat          = 18    // bar ↔ others arası; dokunmaları rahatlat
            let sideMargin: CGFloat   = 20
            
            // Sağdaki daireyi hesaba katarak güvenli genişlik
            let minBar: CGFloat = 220
            let safeBarWidth = min(targetBarWidth,
                                   max(minBar, geo.size.width - (circleSize + gap + sideMargin * 2)))
            
            let tabs = showingOthers ? secondary : primary
            
            HStack(spacing: gap) {
                // 3'lü bar (tam yuvarlak kapsül)
                HStack(spacing: 8) {
                    ForEach(tabs) { item in
                        tab(item)
                    }
                }
                .frame(width: safeBarWidth, height: barHeight)
                .padding(.horizontal, 8)
                .background(.ultraThinMaterial, in: Capsule())
                .overlay(Capsule().stroke(.white.opacity(0.22), lineWidth: 1))
                .shadow(color: .black.opacity(0.12), radius: 12, x: 0, y: 6)
                
                // Sağda daire: Others (yalnızca set değiştirir, kendisi değişmez)
                Button {
                    showingOthers.toggle()
                    selectedTab = (showingOthers ? secondary.first?.tag : primary.first?.tag) ?? 0
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 18, weight: .semibold))
                        .frame(width: circleSize, height: circleSize)
                        .foregroundColor(.primary.opacity(0.85))
                        .background(.ultraThinMaterial, in: Circle())
                        .overlay(Circle().stroke(.white.opacity(0.22), lineWidth: 1))
                        .shadow(color: .black.opacity(0.12), radius: 12, x: 0, y: 6)
                }
            }
            .padding(.horizontal, sideMargin)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        }
        .frame(height: 82) // alt yerleşim kapsayıcı yüksekliği
    }
    
    // Tek tab: ikon üstte, metin altta; seçilince yumuşak mavi kapsül
    private func tab(_ item: TabItem) -> some View {
        let isSelected = selectedTab == item.tag
        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedTab = item.tag
            }
        } label: {
            VStack(spacing: 3) {
                Image(systemName: item.systemImage)
                    .font(.system(size: 17, weight: .semibold))
                    .frame(height: 20)
                Text(item.title)
                    .font(.system(size: 10, weight: .medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundColor(isSelected ? .blue : .primary.opacity(0.75))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.vertical, 6)
            .padding(.horizontal, 10)
            .background(isSelected ? Capsule().fill(Color.blue.opacity(0.14)) : nil)
        }
        .contentShape(Rectangle())
    }
}

#Preview {
    ContentView()
}