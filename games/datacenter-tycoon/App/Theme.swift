import SwiftUI
import TycoonCore

enum Theme {
    static let ink = Color(red: 0.13, green: 0.22, blue: 0.24)
    static let teal = Color(red: 0.08, green: 0.40, blue: 0.37)
    static let cream = Color(red: 0.97, green: 0.95, blue: 0.89)
    static let orange = Color(red: 0.83, green: 0.34, blue: 0.13)
    static let muted = Color(red: 0.39, green: 0.45, blue: 0.43)
}
func euro(_ value: Double) -> String { value.formatted(.currency(code: "EUR").precision(.fractionLength(0)).locale(Locale(identifier: "de_DE"))) }
func number(_ value: Double) -> String { value.formatted(.number.precision(.fractionLength(0...1)).locale(Locale(identifier: "de_DE"))) }
func energyRate(_ value: Double) -> String { value.formatted(.number.precision(.fractionLength(2)).locale(Locale(identifier: "de_DE"))) }
struct Panel<Content: View>: View {
    @ViewBuilder let content: Content
    var body: some View { VStack(alignment: .leading, spacing: 12) { content }.padding(18).frame(maxWidth: .infinity, alignment: .leading).background(.white.opacity(0.88), in: RoundedRectangle(cornerRadius: 22)).overlay(RoundedRectangle(cornerRadius: 22).stroke(Theme.ink.opacity(0.06))) }
}
struct Meter: View {
    let title: String
    let used: Double
    let capacity: Double
    var unit = ""
    var ratio: Double { ResourceSystem.ratio(used, capacity) }
    var body: some View {
        VStack(spacing: 5) {
            HStack { Text(title).font(.subheadline.weight(.medium)); Spacer(); Text("\(number(used)) / \(number(capacity)) \(unit)").font(.caption.monospacedDigit()) }
            GeometryReader { g in
                Capsule().fill(Theme.ink.opacity(0.08))
                    .overlay(alignment: .leading) { Capsule().fill(ratio > 1 ? Color.red : ratio > 0.8 ? Theme.orange : Theme.teal).frame(width: g.size.width*min(1,max(0,ratio))) }
            }.frame(height: 7)
        }.accessibilityElement(children: .combine)
    }
}
struct Page<Content: View>: View {
    @ViewBuilder let content: Content
    var body: some View {
        ScrollView { VStack(alignment: .leading, spacing: 16) { content }.padding(18).frame(maxWidth: 700).frame(maxWidth: .infinity) }.background(Theme.cream).foregroundStyle(Theme.ink)
    }
}
struct ActionButton: View {
    let title: String
    var icon = "arrow.right"
    let action: () -> Void
    var body: some View { Button(action: action) { Label(title, systemImage: icon).font(.subheadline.bold()).frame(maxWidth: .infinity, minHeight: 34) }.buttonStyle(.borderedProminent).controlSize(.large) }
}
struct StatLine: View {
    let label: String
    let value: String
    var body: some View { HStack(alignment: .firstTextBaseline) { Text(label).foregroundStyle(Theme.muted); Spacer(); Text(value).bold().multilineTextAlignment(.trailing) }.font(.subheadline) }
}
