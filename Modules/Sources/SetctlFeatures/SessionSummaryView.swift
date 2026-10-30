//
//  SessionSummaryView.swift
//  SetctlModules
//
//  Created by Samuel Meads on 8/5/26.
//

import SetctlCore
import SetctlDesignSystem
import SwiftUI

struct SessionSummaryView: View {
    let duration: TimeInterval
    let totalSets: Int
    let totalVolume: Double
    let unit: WeightUnit

    var body: some View {
        ZStack {
            Palette.black.ignoresSafeArea()

            VStack(spacing: Spacing.md) {
                Text("DONE")
                    .font(Typography.title)
                    .foregroundStyle(Palette.green)

                Text(DurationFormat.clock(duration))
                    .font(Typography.body)
                    .foregroundStyle(Palette.greenDim)

                Text("\(totalSets) sets")
                    .font(Typography.body)
                    .foregroundStyle(Palette.greenDim)

                Text("\(unit.format(kilograms: totalVolume)) total")
                    .font(Typography.body)
                    .foregroundStyle(Palette.greenDim)
            }
        }
    }
}
