import SwiftUI
import TycoonCore

struct RoomScene: View {
    let game: GameState
    let laptop: () -> Void
    let rack: (UUID) -> Void
    let door: () -> Void
    let cooling: () -> Void
    var garage: Bool { game.location == .garage }
    var body: some View {
        GeometryReader { geometry in
            let w = geometry.size.width
            ZStack(alignment: .topLeading) {
                RoomBackdrop(garage: garage)
                VStack(alignment: .leading, spacing: 4) {
                    Text(garage ? "GARAGE / 02" : "HOME LAB / 01").font(.caption2.monospaced().bold()).tracking(2)
                    Text(garage ? "Das Auto steht jetzt draußen." : "Große Träume. Kleines Zimmer.").font(.caption)
                }.foregroundStyle(Theme.ink.opacity(0.7)).position(x: w*0.36, y: 33)
                Button(action: door) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 5).fill(garage ? Color.gray.opacity(0.25) : Color(red: 0.61, green: 0.68, blue: 0.59))
                        VStack(spacing: 10) { Image(systemName: "door.left.hand.open").font(.title); Text(garage ? "Standort" : "GARAGE").font(.caption2.bold()) }
                    }.foregroundStyle(Theme.ink).frame(width: 67, height: 115)
                }.accessibilityLabel("Standort und Garage öffnen").accessibilityIdentifier("door").position(x: w*0.86, y: 130)
                if !garage {
                    BedDrawing().frame(width: w*0.29, height: 100).position(x: w*0.19, y: 230)
                    VStack(spacing: 2) { Image(systemName: "moon.stars.fill"); Text("UPTIME\nIS A LIFESTYLE").font(.system(size: 8, weight: .black, design: .monospaced)).multilineTextAlignment(.center) }
                        .foregroundStyle(.white).padding(10).background(Theme.teal).rotationEffect(.degrees(-5)).position(x: w*0.19, y: 113).accessibilityHidden(true)
                } else {
                    HStack { Image(systemName: "wrench.and.screwdriver"); Text("WERKBANK").font(.caption2.bold()) }
                        .frame(width: w*0.43, height: 35).background(Color.brown.opacity(0.45), in: RoundedRectangle(cornerRadius: 5)).position(x: w*0.29, y: 125).accessibilityHidden(true)
                }
                Button(action: laptop) {
                    VStack(spacing: 0) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 6).fill(Theme.ink).frame(width: 76, height: 51)
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 3) { Circle().fill(Color.orange); Circle().fill(Color.yellow); Circle().fill(Color.green) }.frame(width: 20,height: 4)
                                Text("> rack & rich_").font(.system(size: 7, design: .monospaced)).foregroundStyle(Color.mint)
                                RoundedRectangle(cornerRadius: 2).fill(Color.mint.opacity(0.6)).frame(width: 38,height: 3)
                            }
                        }
                        Trapezoid().fill(Color(red: 0.46, green: 0.53, blue: 0.51)).frame(width: 92, height: 12)
                        Text("LAPTOP  ↗").font(.caption2.bold()).padding(.top, 7)
                    }.foregroundStyle(Theme.ink).frame(width: 125, height: 95).background(Color(red: 0.78, green: 0.61, blue: 0.40), in: RoundedRectangle(cornerRadius: 9))
                }.accessibilityIdentifier("laptop").accessibilityLabel("Laptop öffnen").position(x: w*0.49, y: garage ? 218 : 172)
                let columns = garage ? 4 : 2
                ForEach(Array(game.racks.enumerated()), id: \.element.id) { index, item in
                    Button { rack(item.id) } label: {
                        VStack(spacing: 5) {
                            RackDrawing(rack: item).frame(width: garage ? w*0.17 : w*0.20, height: garage ? 120 : 132)
                            Text("RACK \(index+1)").font(.caption2.monospaced().bold()).foregroundStyle(Theme.ink)
                        }
                    }.accessibilityIdentifier("rack-\(index)").accessibilityLabel("Rack \(index+1), \(item.servers.count) Server")
                        .position(x: garage ? w*(0.16+Double(index)*0.225) : w*(0.57+Double(index)*0.25), y: garage ? 335 : 300)
                }
                ForEach(game.racks.count..<columns, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 8).stroke(Theme.ink.opacity(0.2), style: StrokeStyle(lineWidth: 2, dash: [4]))
                        .frame(width: w*0.16, height: 30)
                        .overlay(Text("+ Rack").font(.caption2).foregroundStyle(Theme.muted))
                        .position(x: garage ? w*(0.16+Double(index)*0.225) : w*(0.57+Double(index)*0.25), y: garage ? 391 : 359).accessibilityHidden(true)
                }
                Button(action: cooling) {
                    Label("\(game.coolingLevel == 0 ? "Raumluft" : "Kühlung +\(game.coolingLevel)")", systemImage: "fanblades.fill").font(.caption.bold()).padding(10).background(.white.opacity(0.8), in: Capsule())
                }.accessibilityLabel("Kühlung verwalten").position(x: w*0.25, y: 410)
            }.clipShape(RoundedRectangle(cornerRadius: 25))
        }.frame(height: 445)
    }
}
struct Trapezoid: Shape {
    func path(in r: CGRect) -> Path { Path { p in p.move(to: CGPoint(x: r.width*0.12,y: 0)); p.addLine(to: CGPoint(x: r.width*0.88,y: 0)); p.addLine(to: CGPoint(x:r.width,y:r.height)); p.addLine(to: CGPoint(x:0,y:r.height)); p.closeSubpath() } }
}
struct RoomBackdrop: View {
    let garage: Bool
    var body: some View {
        Canvas { c, size in
            let w = size.width, h = size.height
            c.fill(Path(CGRect(origin: .zero, size: size)), with: .color(garage ? Color(red:0.81,green:0.84,blue:0.80) : Color(red:0.90,green:0.85,blue:0.71)))
            var floor = Path(); floor.move(to: CGPoint(x:0,y:h*0.48)); floor.addLine(to:CGPoint(x:w,y:h*0.42)); floor.addLine(to:CGPoint(x:w,y:h)); floor.addLine(to:CGPoint(x:0,y:h)); floor.closeSubpath()
            c.fill(floor, with: .color(garage ? Color(red:0.70,green:0.74,blue:0.71) : Color(red:0.77,green:0.66,blue:0.51)))
            for i in 0..<10 {
                var p = Path(); p.move(to:CGPoint(x:0,y:h*0.5+Double(i)*28)); p.addLine(to:CGPoint(x:w,y:h*0.44+Double(i)*28))
                c.stroke(p, with:.color(.white.opacity(0.15)), lineWidth:1)
            }
            var cable = Path(); cable.move(to:CGPoint(x:w*0.48,y:h*0.5)); cable.addCurve(to:CGPoint(x:w*0.70,y:h*0.84),control1:CGPoint(x:w*0.3,y:h*0.95),control2:CGPoint(x:w*0.9,y:h*0.7))
            c.stroke(cable, with:.color(Theme.ink.opacity(0.6)), style:StrokeStyle(lineWidth:3,lineCap:.round))
        }.accessibilityHidden(true)
    }
}
struct BedDrawing: View {
    var body: some View {
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: 9).fill(Color.brown.opacity(0.65)).offset(y:8)
            RoundedRectangle(cornerRadius: 9).fill(Color(red:0.95,green:0.92,blue:0.83))
            RoundedRectangle(cornerRadius: 7).fill(.white).frame(height: 25).padding(7)
            RoundedRectangle(cornerRadius: 7).fill(Color(red:0.37,green:0.55,blue:0.59)).padding(.top,37)
        }.rotationEffect(.degrees(-4)).accessibilityHidden(true)
    }
}
struct RackDrawing: View {
    let rack: Rack
    var body: some View {
        VStack(spacing: 5) {
            HStack { Text("R&R").font(.system(size: 8, weight:.black, design:.monospaced)); Spacer(); Circle().fill(Color.mint).frame(width:4,height:4) }.foregroundStyle(.white.opacity(0.6))
            ForEach(0..<Catalog.rack(rack.specID).slots, id: \.self) { index in
                HStack(spacing: 3) {
                    if index < rack.servers.count {
                        let server = rack.servers[index]
                        Circle().fill(server.fault != nil ? Color.red : server.online ? Color.mint : Color.gray).frame(width:5,height:5)
                        ForEach(0..<4, id: \.self) { _ in RoundedRectangle(cornerRadius:1).fill(.black.opacity(0.4)).frame(width:3) }
                        Spacer(minLength:0)
                    } else { Rectangle().fill(.black.opacity(0.3)).frame(height:2) }
                }.padding(5).frame(maxHeight:.infinity).background(index < rack.servers.count ? Color(red:0.40,green:0.47,blue:0.46) : .black.opacity(0.2), in:RoundedRectangle(cornerRadius:3))
            }
        }.padding(8).background(Theme.ink, in:RoundedRectangle(cornerRadius:7)).overlay(RoundedRectangle(cornerRadius:7).stroke(.white.opacity(0.15),lineWidth:2)).shadow(color:.black.opacity(0.2),radius:1,x:5,y:6)
    }
}
