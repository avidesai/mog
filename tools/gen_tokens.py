"""Regenerates ios/Mog/Design/Tokens.swift from design/design-system/tokens.json.
Run from repo root: python tools/gen_tokens.py"""
import json
t=json.load(open("design/design-system/tokens.json"))
def camel(s):
    p=s.split("-"); return p[0]+"".join(x.capitalize() for x in p[1:])
def hx(h): return f'0x{h[1:]}'
out=["// GENERATED from design/design-system/tokens.json by tools/gen_tokens.py — do not edit by hand.","import SwiftUI","","public enum Tokens {","    // MARK: Colours (light / dark)","    public enum Colors {"]
for c in t["color"]["tokens"]:
    out.append(f'        /// {c["usage"]}'); out.append(f'        public static let {camel(c["name"])} = Color(light: {hx(c["value"]["light"])}, dark: {hx(c["value"]["dark"])})')
out+=["    }","    // MARK: Spacing","    public enum Space {"]
for s in t["spacing"]["tokens"]: out.append(f'        public static let {camel(s["name"]).replace("space","s")}: CGFloat = {s["value"].replace("px","")}  // {s["usage"]}')
out+=["    }","    // MARK: Radius","    public enum Radius {"]
for s in t["radius"]["tokens"]: out.append(f'        public static let {camel(s["name"])[6:].lower()}: CGFloat = {s["value"].replace("px","")}  // {s["usage"]}')
out+=["    }","    // MARK: Border","    public enum Border {"]
for s in t["border"]["tokens"]: out.append(f'        public static let {camel(s["name"])}: CGFloat = {s["value"].replace("px","")}  // {s["usage"]}')
out+=["    }","    // MARK: Motion (seconds)","    public enum Motion {"]
for s in t["motion"]["tokens"]: out.append(f'        public static let {camel(s["name"])}: Double = {int(s["value"].replace("ms",""))/1000}  // {s["usage"]}')
out+=["    }","}","","/// Text styles from tokens.json.","public struct TextStyle {","    public enum Family { case sans, serif }",
"    public let family: Family; public let size: CGFloat; public let lineHeight: CGFloat; public let weight: Font.Weight; public let tracking: CGFloat",
"    public var font: Font { Typography.font(self) }","    public var lineSpacing: CGFloat { max(0, lineHeight - size * 1.2) }","}","","public enum TypeStyle {"]
wmap={400:".regular",500:".medium",600:".semibold",700:".bold"}
for g in t["type"]["groups"]:
    fam=".serif" if g["family"]=="serif" else ".sans"
    for s in g["styles"]:
        size=float(s["fontSize"].replace("px","")); lh=float(s["lineHeight"].replace("px","")); ls=float(s["letterSpacing"].replace("em",""))
        out.append(f'    public static let {camel(s["name"])} = TextStyle(family: {fam}, size: {size:g}, lineHeight: {lh:g}, weight: {wmap[s["fontWeight"]]}, tracking: {round(size*ls,2)})')
out+=["}","","extension Color {","    init(light: UInt32, dark: UInt32) {","        self.init(uiColor: UIColor { tc in","            let v = tc.userInterfaceStyle == .dark ? dark : light",
"            return UIColor(red: CGFloat((v >> 16) & 0xFF) / 255, green: CGFloat((v >> 8) & 0xFF) / 255, blue: CGFloat(v & 0xFF) / 255, alpha: 1)","        })","    }","}"]
open("ios/Mog/Design/Tokens.swift","w").write("\n".join(out)+"\n"); print("wrote ios/Mog/Design/Tokens.swift")
