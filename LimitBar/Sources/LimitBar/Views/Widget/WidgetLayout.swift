import CoreGraphics

struct WidgetLayout {
    let displayMode: DisplayMode
    let widgetSize: WidgetSize

    var width: CGFloat {
        switch (displayMode, widgetSize) {
        case (.minimal, .small):
            152
        case (.minimal, .medium):
            176
        case (.normal, .small):
            240
        case (.normal, .medium):
            290
        }
    }

    var rowHeight: CGFloat {
        switch (displayMode, widgetSize) {
        case (.minimal, .small):
            22
        case (.minimal, .medium):
            26
        case (.normal, .small):
            18
        case (.normal, .medium):
            22
        }
    }

    var topAreaHeight: CGFloat {
        displayMode == .minimal ? 0 : 34
    }

    var verticalPadding: CGFloat {
        widgetSize == .small ? 28 : 36
    }

    var cardPadding: CGFloat {
        widgetSize == .small ? 14 : 18
    }

    var cornerRadius: CGFloat {
        widgetSize == .small ? 20 : 24
    }

    func height(forRowCount rowCount: Int) -> CGFloat {
        topAreaHeight + (CGFloat(max(rowCount, 1)) * rowHeight) + verticalPadding
    }
}
