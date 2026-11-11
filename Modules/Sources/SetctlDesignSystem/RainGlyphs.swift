//
//  RainGlyphs.swift
//  SetctlModules
//
//  Created by Samuel Meads on 11/10/26.
//

/// The characters the rain draws, grouped by script.
enum RainGlyphs {
    private static let halfWidthKatakana = Array("ｱｲｳｴｵｶｷｸｹｺｻｼｽｾｿﾀﾁﾂﾃﾄﾅﾆﾇﾈﾉﾊﾋﾌﾍﾎﾏﾐﾑﾒﾓﾔﾕﾖﾗﾘﾙﾚﾛﾜｦﾝ")
    private static let katakana = Array("アイウエオカキクケコサシスセソタチツテトナニヌネノハヒフヘホマミムメモヤユヨラリルレロワヲン")
    // Strength-themed: power, weight, iron, muscle, train, strong, sweat, victory, body, healthy, fire.
    private static let kanji = Array("力重鉄筋練強汗勝体健火")
    private static let hanzi = Array("力重铁肌练强汗胜身健举")
    private static let cyrillic = Array("БГДЖЗИЛПФЦЧШЭЮЯ")
    private static let greek = Array("ΓΔΘΛΞΠΣΦΨΩ")
    private static let devanagari = Array("कखगघचजटडतदनपबमयरलवसह")
    private static let digits = Array("0123456789")
    private static let latin = Array("ABCDEFGHJKLMNPRSTUVWXYZ")

    private static let sets: [(glyphs: [Character], weight: Int)] = [
        (halfWidthKatakana, 3), (katakana, 2), (kanji, 3), (hanzi, 3), (cyrillic, 2),
        (greek, 1), (devanagari, 1), (digits, 2), (latin, 2),
    ]

    static let all = sets.flatMap(\.glyphs)

    /// A random glyph; a script is picked by weight first, so no single script dominates.
    static func random(using generator: inout some RandomNumberGenerator) -> Character {
        let total = sets.reduce(0) { $0 + $1.weight }
        var roll = Int.random(in: 0 ..< total, using: &generator)
        for set in sets {
            if roll < set.weight {
                return set.glyphs.randomElement(using: &generator) ?? "0"
            }
            roll -= set.weight
        }
        return "0"
    }
}
