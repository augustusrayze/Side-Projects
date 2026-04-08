import SwiftUI

extension Font {
    static let saintDisplay = Font.system(size: 34, weight: .light, design: .serif).tracking(1.5)
    static let saintTitle   = Font.system(size: 28, weight: .semibold, design: .serif).tracking(0.5)
    static let saintHeading = Font.system(size: 20, weight: .medium, design: .serif).tracking(0.2)
    static let saintBody    = Font.system(size: 17, weight: .regular, design: .serif)
    static let saintCaption = Font.system(size: 13, weight: .regular, design: .serif).italic().tracking(0.1)
}
