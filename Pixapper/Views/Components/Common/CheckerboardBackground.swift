//
//  CheckerboardBackground.swift
//  Pixapper
//
//  Created by Claude on 2025-12-15.
//

import SwiftUI

/// 재사용 가능한 체커보드 배경 컴포넌트
/// 투명도를 시각적으로 표시하기 위해 사용
struct CheckerboardBackground: View {
    var squareSize: CGFloat = Constants.Layout.UI.checkerboardSquareSize
    var lightOpacity: Double = 0.2
    var darkOpacity: Double = 0.2

    var body: some View {
        GeometryReader { geometry in
            Canvas { context, size in
                let columns = Int(ceil(size.width / squareSize))
                let rows = Int(ceil(size.height / squareSize))

                for row in 0..<rows {
                    for col in 0..<columns {
                        let isLight = (row + col) % 2 == 0
                        let color = isLight ?
                            Color.white.opacity(lightOpacity) :
                            Color.black.opacity(darkOpacity)
                        let rect = CGRect(
                            x: CGFloat(col) * squareSize,
                            y: CGFloat(row) * squareSize,
                            width: squareSize,
                            height: squareSize
                        )
                        context.fill(Path(rect), with: .color(color))
                    }
                }
            }
        }
    }
}
