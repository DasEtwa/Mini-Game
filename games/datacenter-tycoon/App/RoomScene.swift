import SwiftUI
import TycoonCore

struct RoomScene: View, Equatable {
    nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.game.location == rhs.game.location && lhs.game.racks == rhs.game.racks && lhs.game.coolingLevel == rhs.game.coolingLevel && lhs.game.operations.receipts == rhs.game.operations.receipts
    }
    let game: GameState
    let laptop: () -> Void
    let rack: (UUID) -> Void
    let door: () -> Void
    let cooling: () -> Void
    let freeRack: () -> Void
    var garage: Bool { game.location == .garage }
    var body: some View {
        GeometryReader { geometry in
            let w = geometry.size.width
            let scale = geometry.size.height / 460
            ZStack(alignment: .topLeading) {
                RoomBackdrop(garage: garage)
                roomHeading.position(x: w*0.46, y: 30*scale)
                if garage {
                    PegboardDrawing().frame(width:w*0.43,height:86).position(x:w*0.32,y:(113)*scale)
                    BoxDrawing().frame(width:38,height:30).position(x:w*0.12,y:(255)*scale)
                } else {
                    WindowDrawing().frame(width:w*0.25,height:94).position(x:w*0.18,y:(141)*scale)
                    poster.position(x:w*0.52,y:(112)*scale)
                    BedDrawing().frame(width:w*0.26,height:128).position(x:w*0.18,y:(326)*scale)
                    PlantDrawing().frame(width:31,height:59).position(x:w*0.39,y:(375)*scale)
                }
                Button(action:door) { DoorDrawing(garage:garage).frame(width:w*0.20,height:146) }
                    .buttonStyle(.plain).accessibilityLabel("Standort und Garage öffnen").accessibilityIdentifier("door")
                    .position(x:w*0.86,y:(166)*scale)
                Button(action:laptop) {
                    DeskDrawing(garage:garage).frame(width:garage ? w*0.49 : w*0.36,height:110)
                }.buttonStyle(.plain).accessibilityIdentifier("laptop").accessibilityLabel("Laptop öffnen")
                    .position(x:w*(garage ? 0.40 : 0.51),y:(garage ? 205 : 211)*scale)
                ForEach(Array(game.racks.enumerated()),id:\.element.id) { index,item in
                    Button { rack(item.id) } label: {
                        VStack(spacing:9) {
                            RackDrawing(rack:item).frame(width:garage ? w*0.165 : w*0.20,height:126)
                            Text("RACK \(index+1)").font(.system(size:10,weight:.bold,design:.monospaced)).tracking(1).foregroundStyle(Theme.ink)
                        }
                    }.buttonStyle(.plain).accessibilityIdentifier("rack-\(index)").accessibilityLabel("Rack \(index+1), \(item.servers.count) Server")
                        .overlay(alignment: .top) { RackCashBurst(receipts: game.operations.receipts.filter { $0.rackID == item.id }) }
                        .position(x:rackX(index,w:w),y:(350)*scale)
                }
                ForEach(game.racks.count..<(garage ? 4 : 2),id:\.self) { index in
                    Button(action: freeRack) { RoundedRectangle(cornerRadius:5).stroke(Theme.ink.opacity(0.17),style:StrokeStyle(lineWidth:1.5,dash:[4,4]))
                        .frame(width:w*0.17,height:44)
                        .overlay(Label("Rack", systemImage: "plus").font(.system(size:11,weight:.bold,design:.monospaced)).foregroundStyle(Theme.teal))
                        }.buttonStyle(.plain).accessibilityLabel("Freien Rackplatz ausbauen").accessibilityIdentifier("free-rack-\(index)")
                        .position(x:rackX(index,w:w),y:(401)*scale)
                }
                Button(action:cooling) {
                    Label(game.coolingLevel == 0 ? "Raumluft" : "Kühlung +\(game.coolingLevel)",systemImage:"fanblades.fill")
                        .font(.system(size:11,weight:.semibold)).padding(.horizontal,12).frame(height:36)
                        .background(.white.opacity(0.80),in:Capsule()).overlay(Capsule().stroke(Theme.ink.opacity(0.08)))
                }.buttonStyle(.plain).foregroundStyle(Theme.teal).accessibilityLabel("Kühlung verwalten")
                    .position(x:w*(garage ? 0.75 : 0.20),y:(garage ? 66 : 434)*scale)
            }.clipShape(RoundedRectangle(cornerRadius:22))
        }
    }
    func rackX(_ index:Int,w:CGFloat) -> CGFloat { w*(garage ? 0.15+Double(index)*0.23 : 0.58+Double(index)*0.25) }
    var roomHeading: some View {
        VStack(alignment:.leading,spacing:4) {
            Text(garage ? "GARAGE / 02" : "HOME LAB / 01").font(.system(size:10,weight:.bold,design:.monospaced)).tracking(2)
            Text(garage ? "Platz für größere Pläne." : "Hier fängt alles an.").font(.system(size:11))
        }.foregroundStyle(Theme.ink.opacity(0.65))
    }
    var poster: some View {
        VStack(spacing:4) { Image(systemName:"bolt.horizontal.fill").font(.system(size:17)); Text("STAY\nCONNECTED").font(.system(size:7,weight:.black,design:.monospaced)).multilineTextAlignment(.center) }
            .foregroundStyle(Color(red:0.96,green:0.84,blue:0.62)).padding(9).frame(width:59,height:68)
            .background(Theme.teal).overlay(Rectangle().stroke(.white.opacity(0.7),lineWidth:4)).rotationEffect(.degrees(-3))
            .shadow(color:.black.opacity(0.1),radius:2,y:2).accessibilityHidden(true)
    }
}
private struct RackCashBurst: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let receipts: [CashReceipt]
    @State private var amount = 0.0
    @State private var visible = false
    @State private var raised = false
    @State private var revision = 0
    var body: some View {
        Label("+\(euro(amount))", systemImage: "banknote.fill")
            .font(.caption.bold()).padding(8).background(.white, in: Capsule()).foregroundStyle(Theme.teal)
            .fixedSize().opacity(visible ? 1 : 0).offset(y: reduceMotion ? -25 : raised ? -75 : -20)
            .allowsHitTesting(false).accessibilityHidden(!visible)
            .accessibilityIdentifier("rack-cash-receipt")
            .onChange(of: receipts) { old, new in
                let oldIDs = Set(old.map(\.id))
                let incoming = new.filter { !oldIDs.contains($0.id) }.reduce(0) { $0 + $1.amount }
                guard incoming > 0 else { return }
                amount = incoming; visible = true; raised = false; revision += 1
            }
            .task(id: revision) {
                guard visible else { return }
                withAnimation(reduceMotion ? nil : .easeOut(duration: 1.8)) { raised = true }
                try? await Task.sleep(for: .seconds(2))
                guard !Task.isCancelled else { return }
                withAnimation(.easeOut(duration: 0.25)) { visible = false }
            }
    }
}
struct RoomBackdrop: View {
    let garage: Bool
    var body: some View {
        Canvas { c,s in
            let w=s.width
            c.scaleBy(x: 1, y: s.height / 460)
            c.fill(Path(CGRect(origin:.zero,size:s)),with:.linearGradient(Gradient(colors:garage ? [Color(red:0.88,green:0.89,blue:0.84),Color(red:0.75,green:0.79,blue:0.75)] : [Color(red:0.96,green:0.92,blue:0.82),Color(red:0.89,green:0.85,blue:0.74)]),startPoint:.zero,endPoint:CGPoint(x:w,y:260)))
            // Side wall and baseboards give the scene a fixed, shallow perspective.
            var side=Path();side.move(to:CGPoint(x:w*0.96,y:0));side.addLine(to:CGPoint(x:w,y:0));side.addLine(to:CGPoint(x:w,y:275));side.addLine(to:CGPoint(x:w*0.96,y:250));side.closeSubpath()
            c.fill(side,with:.color(Theme.ink.opacity(0.07)))
            let floorY=250.0
            c.fill(Path(CGRect(x:0,y:floorY,width:w,height:460-floorY)),with:.linearGradient(Gradient(colors:garage ? [Color(red:0.67,green:0.72,blue:0.70),Color(red:0.80,green:0.82,blue:0.77)] : [Color(red:0.70,green:0.52,blue:0.34),Color(red:0.85,green:0.69,blue:0.48)]),startPoint:CGPoint(x:0,y:floorY),endPoint:CGPoint(x:0,y:460)))
            c.fill(Path(CGRect(x:0,y:243,width:w,height:7)),with:.color(garage ? Color.gray.opacity(0.4) : Color(red:0.66,green:0.49,blue:0.33)))
            c.fill(Path(CGRect(x:0,y:243,width:w,height:2)),with:.color(.white.opacity(0.5)))
            for row in 0..<9 {
                let y=floorY+Double(row)*28
                var seam=Path();seam.move(to:CGPoint(x:0,y:y));seam.addLine(to:CGPoint(x:w,y:y))
                c.stroke(seam,with:.color(Theme.ink.opacity(garage ? 0.06 : 0.13)),lineWidth:1)
                if !garage {
                    for col in 0..<4 {
                        let x=Double(col)*w/3+(row%2 == 0 ? 0 : w/6)
                        var joint=Path();joint.move(to:CGPoint(x:x,y:y));joint.addLine(to:CGPoint(x:x+10,y:y+28))
                        c.stroke(joint,with:.color(Theme.ink.opacity(0.08)),lineWidth:1)
                    }
                }
            }
            // A softly lit patch from the window; cables run along the wall, never across furniture.
            if !garage {
                var light=Path();light.move(to:CGPoint(x:0,y:270));light.addLine(to:CGPoint(x:w*0.23,y:270));light.addLine(to:CGPoint(x:w*0.42,y:460));light.addLine(to:CGPoint(x:w*0.16,y:460));light.closeSubpath()
                c.fill(light,with:.color(Color.white.opacity(0.10)))
            }
            var cable=Path();cable.move(to:CGPoint(x:w*0.63,y:226));cable.addLine(to:CGPoint(x:w*0.66,y:256));cable.addQuadCurve(to:CGPoint(x:w*0.69,y:312),control:CGPoint(x:w*0.73,y:280))
            c.stroke(cable,with:.color(Theme.ink.opacity(0.55)),style:StrokeStyle(lineWidth:2,lineCap:.round))
        }.accessibilityHidden(true)
    }
}
struct WindowDrawing: View {
    var body: some View {
        GeometryReader { g in
            ZStack {
                RoundedRectangle(cornerRadius:3).fill(Color(red:0.80,green:0.73,blue:0.59)).offset(x:2,y:4)
                Rectangle().fill(LinearGradient(colors:[Color(red:0.39,green:0.63,blue:0.70),Color(red:0.83,green:0.88,blue:0.75)],startPoint:.top,endPoint:.bottom)).padding(6)
                Circle().fill(Color(red:1,green:0.94,blue:0.73)).frame(width:20,height:20).offset(x:16,y:-18)
                Ellipse().fill(Theme.teal.opacity(0.25)).frame(width:g.size.width*0.8,height:38).offset(x:-12,y:27).clipped()
                Rectangle().stroke(Color(red:0.99,green:0.97,blue:0.87),lineWidth:5).padding(3)
                Rectangle().fill(Color(red:0.99,green:0.97,blue:0.87)).frame(width:4)
                Rectangle().fill(Color(red:0.99,green:0.97,blue:0.87)).frame(height:4)
                RoundedRectangle(cornerRadius:2).fill(Color(red:0.75,green:0.60,blue:0.42)).frame(width:g.size.width+9,height:7).offset(y:g.size.height/2)
            }
        }.accessibilityHidden(true)
    }
}
struct DoorDrawing: View {
    let garage: Bool
    var body: some View {
        ZStack(alignment:.bottom) {
            RoundedRectangle(cornerRadius:4).fill(Color(red:0.51,green:0.48,blue:0.37)).offset(x:3,y:2)
            RoundedRectangle(cornerRadius:3).fill(garage ? Color(red:0.63,green:0.68,blue:0.61) : Color(red:0.64,green:0.71,blue:0.58)).padding(4)
            VStack(spacing:9) {
                RoundedRectangle(cornerRadius:2).stroke(.white.opacity(0.25),lineWidth:2).frame(height:57)
                HStack { Spacer(); Capsule().fill(Color(red:0.93,green:0.80,blue:0.51)).frame(width:13,height:4) }
                Text(garage ? "STANDORT" : "GARAGE").font(.system(size:8,weight:.bold,design:.monospaced)).tracking(1).foregroundStyle(Theme.ink)
            }.padding(13).padding(.bottom,11)
            Rectangle().fill(Color(red:0.44,green:0.40,blue:0.30)).frame(height:4)
        }
    }
}
struct DeskDrawing: View {
    let garage: Bool
    var body: some View {
        GeometryReader { g in
            ZStack {
                Ellipse().fill(.black.opacity(0.1)).frame(width:g.size.width,height:15).position(x:g.size.width/2,y:103)
                HStack { Rectangle().fill(Theme.ink.opacity(0.75)).frame(width:7); Spacer(); Rectangle().fill(Theme.ink.opacity(0.75)).frame(width:7) }.frame(height:48).padding(.horizontal,11).offset(y:27)
                RoundedRectangle(cornerRadius:3).fill(Color(red:0.65,green:0.43,blue:0.25)).frame(height:13).offset(y:9)
                RoundedRectangle(cornerRadius:4).fill(Color(red:0.83,green:0.65,blue:0.42)).frame(height:18)
                    .overlay(alignment:.top) { RoundedRectangle(cornerRadius:4).fill(Color(red:0.92,green:0.76,blue:0.53)).frame(height:4) }.offset(y:0)
                LaptopDrawing().frame(width:68,height:56).offset(x:garage ? 12 : -3,y:-28)
                VStack(spacing:0) { Ellipse().fill(Color(red:0.97,green:0.91,blue:0.76)).frame(width:10,height:4); Rectangle().fill(Theme.orange).frame(width:10,height:12) }.offset(x:g.size.width*0.36,y:-14)
                Text("LAPTOP ↗").font(.system(size:8,weight:.bold,design:.monospaced)).tracking(0.8).foregroundStyle(Theme.ink).offset(y:25)
            }
        }
    }
}
struct LaptopDrawing: View {
    var body: some View {
        VStack(spacing:0) {
            RoundedRectangle(cornerRadius:4).fill(Theme.ink)
                .overlay {
                    VStack(alignment:.leading,spacing:4) {
                        HStack(spacing:3) { Circle().fill(Color.orange);Circle().fill(Color.yellow);Circle().fill(Color.mint) }.frame(width:13,height:3)
                        Text("> home_lab").font(.system(size:6,weight:.medium,design:.monospaced)).foregroundStyle(.mint)
                        HStack(alignment:.bottom,spacing:2) { ForEach(0..<6,id:\.self) { i in Rectangle().fill(Color.mint.opacity(0.5)).frame(width:4,height:CGFloat(3+i%3*3)) } }
                    }.padding(6)
                }.frame(height:43).padding(.horizontal,5)
            Trapezoid().fill(Color(red:0.59,green:0.66,blue:0.61)).frame(height:11)
                .overlay { HStack(spacing:2) { ForEach(0..<8,id:\.self) { _ in Rectangle().fill(Theme.ink.opacity(0.25)).frame(width:4,height:3) } } }
            Capsule().fill(Theme.ink.opacity(0.7)).frame(height:2)
        }
    }
}
struct Trapezoid: Shape {
    func path(in r:CGRect) -> Path { Path { p in p.move(to:CGPoint(x:r.width*0.10,y:0));p.addLine(to:CGPoint(x:r.width*0.90,y:0));p.addLine(to:CGPoint(x:r.width,y:r.height));p.addLine(to:CGPoint(x:0,y:r.height));p.closeSubpath() } }
}
struct BedDrawing: View {
    var body: some View {
        GeometryReader { g in
            ZStack(alignment:.top) {
                RoundedRectangle(cornerRadius:9).fill(.black.opacity(0.12)).offset(x:4,y:7)
                RoundedRectangle(cornerRadius:6).fill(Color(red:0.60,green:0.43,blue:0.28))
                RoundedRectangle(cornerRadius:5).fill(Color(red:0.98,green:0.94,blue:0.83)).padding(4).padding(.bottom,6)
                RoundedRectangle(cornerRadius:6).fill(.white).frame(height:29).padding(9).shadow(color:.black.opacity(0.05),radius:1,y:2)
                VStack(spacing:0) {
                    Rectangle().fill(Color(red:0.39,green:0.61,blue:0.62)).frame(height:11)
                    RoundedRectangle(cornerRadius:4).fill(Color(red:0.26,green:0.48,blue:0.52))
                        .overlay(alignment:.trailing) { Rectangle().fill(.white.opacity(0.08)).frame(width:8).padding(.trailing,8) }
                }.padding(.top,43).padding(.horizontal,4).padding(.bottom,12)
                RoundedRectangle(cornerRadius:2).fill(Color(red:0.73,green:0.56,blue:0.37)).frame(height:7).offset(y:g.size.height-7)
            }
        }.accessibilityHidden(true)
    }
}
struct PlantDrawing: View {
    var body: some View {
        VStack(spacing:-4) {
            ZStack {
                Capsule().fill(Theme.teal.opacity(0.8)).frame(width:9,height:35).rotationEffect(.degrees(-25)).offset(x:-5)
                Capsule().fill(Color(red:0.40,green:0.57,blue:0.34)).frame(width:10,height:38).rotationEffect(.degrees(20)).offset(x:6)
            }
            Trapezoid().fill(Color(red:0.77,green:0.43,blue:0.27)).rotationEffect(.degrees(180)).frame(width:24,height:21)
        }.shadow(color:.black.opacity(0.1),radius:1,x:2,y:3).accessibilityHidden(true)
    }
}
struct PegboardDrawing: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius:4).fill(Color(red:0.67,green:0.53,blue:0.36)).shadow(color:.black.opacity(0.12),radius:2,y:2)
            Canvas { c,s in
                for x in stride(from:8.0,to:s.width,by:12) { for y in stride(from:8.0,to:s.height,by:12) { c.fill(Path(ellipseIn:CGRect(x:x,y:y,width:2,height:2)),with:.color(.black.opacity(0.2))) } }
            }
            HStack(spacing:18) { Image(systemName:"wrench.fill").rotationEffect(.degrees(-15));Image(systemName:"screwdriver.fill");Image(systemName:"hammer.fill").rotationEffect(.degrees(12)) }.font(.system(size:25)).foregroundStyle(Color(red:0.25,green:0.36,blue:0.36))
        }.accessibilityHidden(true)
    }
}
struct BoxDrawing: View {
    var body: some View {
        RoundedRectangle(cornerRadius:2).fill(Color(red:0.76,green:0.61,blue:0.41))
            .overlay { Rectangle().fill(Color(red:0.92,green:0.82,blue:0.62)).frame(width:7) }
            .overlay(alignment:.bottomLeading) { Text("SPARES").font(.system(size:5,weight:.bold,design:.monospaced)).padding(3) }
            .shadow(color:.black.opacity(0.15),radius:1,x:3,y:3).accessibilityHidden(true)
    }
}
struct RackDrawing: View {
    let rack: Rack
    var body: some View {
        GeometryReader { g in
            ZStack(alignment:.leading) {
                RoundedRectangle(cornerRadius:5).fill(Color(red:0.13,green:0.20,blue:0.20)).offset(x:6,y:-3)
                VStack(spacing:4) {
                    HStack { Text("R&R").font(.system(size:6,weight:.black,design:.monospaced));Spacer();Circle().fill(Color.mint).frame(width:3,height:3) }.foregroundStyle(.white.opacity(0.65)).padding(.bottom,3)
                    ForEach(0..<Catalog.rack(rack.specID).slots,id:\.self) { index in
                        serverSlot(index).frame(height:min(23,(g.size.height-32)/CGFloat(Catalog.rack(rack.specID).slots)-3))
                    }
                    Spacer(minLength:0)
                    HStack(spacing:3) { ForEach(0..<7,id:\.self) { _ in Rectangle().fill(.black.opacity(0.4)).frame(width:3,height:5) } }
                }.padding(7).frame(width:g.size.width,height:g.size.height)
                    .background(Color(red:0.24,green:0.33,blue:0.33),in:RoundedRectangle(cornerRadius:5))
                    .overlay(RoundedRectangle(cornerRadius:5).stroke(.white.opacity(0.15),lineWidth:1))
                HStack { Circle();Spacer();Circle() }.foregroundStyle(Theme.ink).frame(height:5).padding(.horizontal,6).offset(y:g.size.height/2+3)
            }.shadow(color:.black.opacity(0.18),radius:3,x:3,y:6)
        }
    }
    func serverSlot(_ index:Int) -> some View {
        HStack(spacing:3) {
            if index < rack.servers.count {
                let server=rack.servers[index]
                Circle().fill(server.fault != nil ? Color.red : server.online ? Color.mint : Color.gray).frame(width:3,height:3)
                VStack(spacing:2) { ForEach(0..<3,id:\.self) { _ in Rectangle().fill(Theme.ink.opacity(0.6)).frame(height:1) } }
                Spacer(minLength:0)
                RoundedRectangle(cornerRadius:1).fill(Theme.ink.opacity(0.5)).frame(width:6,height:8)
            } else {
                Rectangle().fill(.black.opacity(0.18)).frame(height:1)
            }
        }.padding(4).background(index < rack.servers.count ? Color(red:0.57,green:0.65,blue:0.61) : Color.black.opacity(0.20),in:RoundedRectangle(cornerRadius:2))
    }
}
