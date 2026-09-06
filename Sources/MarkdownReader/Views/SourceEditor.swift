import AppKit
import SwiftUI

/// Plain text editor built on `NSTextView` (TextKit 1), with line numbers,
/// Markdown syntax highlighting and automatic substitutions switched off:
/// smart quotes or em dashes would corrupt the file.
struct SourceEditor: NSViewRepresentable {
    @Binding var text: String
    var fontSize: Double
    var showLineNumbers: Bool
    var highlight: Bool
    var softWrap: Bool
    @Binding var scrollToLine: Int?

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSScrollView {
        // TextKit 1: the text view creates and retains its own stack (storage,
        // layout manager and container), which is what the line number ruler
        // and the attribute-based highlighting need.
        let textView = NSTextView(usingTextLayoutManager: false)
        textView.delegate = context.coordinator
        textView.isRichText = false
        textView.allowsUndo = true
        textView.isEditable = true
        textView.isSelectable = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isAutomaticLinkDetectionEnabled = false
        textView.isContinuousSpellCheckingEnabled = false
        textView.isGrammarCheckingEnabled = false
        textView.usesFindBar = true
        textView.isIncrementalSearchingEnabled = true
        textView.textContainerInset = NSSize(width: 12, height: 14)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.backgroundColor = .textBackgroundColor
        textView.textContainer?.widthTracksTextView = true
        textView.string = text

        let scrollView = NSScrollView()
        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = true
        scrollView.backgroundColor = .textBackgroundColor
        scrollView.automaticallyAdjustsContentInsets = false
        scrollView.contentInsets = NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        scrollView.contentView.postsFrameChangedNotifications = true
        NotificationCenter.default.addObserver(context.coordinator,
                                               selector: #selector(Coordinator.clipViewResized(_:)),
                                               name: NSView.frameDidChangeNotification,
                                               object: scrollView.contentView)

        let ruler = LineNumberRuler(textView: textView, scrollView: scrollView)
        scrollView.verticalRulerView = ruler
        scrollView.hasVerticalRuler = true
        scrollView.rulersVisible = showLineNumbers

        context.coordinator.textView = textView
        context.coordinator.ruler = ruler
        context.coordinator.configure(fontSize: fontSize, softWrap: softWrap, highlight: highlight)
        DispatchQueue.main.async {
            context.coordinator.syncWidth()
            context.coordinator.normalizeOrigin()
        }
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        context.coordinator.parent = self
        guard let textView = context.coordinator.textView else { return }

        if textView.string != text {
            let selected = textView.selectedRange()
            context.coordinator.isApplyingExternalChange = true
            textView.string = text
            let length = (text as NSString).length
            textView.setSelectedRange(NSRange(location: min(selected.location, length), length: 0))
            context.coordinator.isApplyingExternalChange = false
            context.coordinator.applyHighlight(immediately: true)
        }

        scrollView.rulersVisible = showLineNumbers
        context.coordinator.configure(fontSize: fontSize, softWrap: softWrap, highlight: highlight)
        context.coordinator.syncWidth()

        if let line = scrollToLine {
            context.coordinator.scroll(to: line)
            DispatchQueue.main.async { self.scrollToLine = nil }
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: SourceEditor
        weak var textView: NSTextView?
        weak var ruler: LineNumberRuler?
        var isApplyingExternalChange = false

        private var currentFontSize: Double = 0
        private var currentWrap: Bool?
        private var currentHighlight: Bool?
        private var pendingHighlight: DispatchWorkItem?

        init(_ parent: SourceEditor) {
            self.parent = parent
        }

        deinit {
            NotificationCenter.default.removeObserver(self)
            pendingHighlight?.cancel()
        }

        var font: NSFont {
            NSFont.monospacedSystemFont(ofSize: CGFloat(currentFontSize), weight: .regular)
        }

        func configure(fontSize: Double, softWrap: Bool, highlight: Bool) {
            guard let textView else { return }
            var needsHighlight = false

            if fontSize != currentFontSize {
                currentFontSize = fontSize
                textView.font = font
                ruler?.font = NSFont.monospacedDigitSystemFont(ofSize: max(9, CGFloat(fontSize) * 0.85), weight: .regular)
                needsHighlight = true
            }

            if softWrap != currentWrap {
                currentWrap = softWrap
                applyWrap(softWrap, to: textView)
            }

            if highlight != currentHighlight {
                currentHighlight = highlight
                needsHighlight = true
            }

            if needsHighlight { applyHighlight(immediately: true) }
            ruler?.needsDisplay = true
        }

        private func applyWrap(_ wrap: Bool, to textView: NSTextView) {
            guard let container = textView.textContainer, let scrollView = textView.enclosingScrollView else { return }
            if wrap {
                container.widthTracksTextView = true
                let width = scrollView.contentView.bounds.maxX
                container.size = NSSize(width: width, height: CGFloat.greatestFiniteMagnitude)
                textView.isHorizontallyResizable = false
                textView.autoresizingMask = [.width]
                if width > 0 { textView.frame.size.width = width }
                scrollView.hasHorizontalScroller = false
            } else {
                container.widthTracksTextView = false
                container.size = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
                textView.isHorizontallyResizable = true
                textView.autoresizingMask = [.width, .height]
                scrollView.hasHorizontalScroller = true
            }
        }

        @objc func clipViewResized(_ notification: Notification) {
            syncWidth()
        }

        /// The text view can end up with a negative origin inside the clip
        /// view (it grows vertically before SwiftUI gives it a size). Put it
        /// back at the origin and leave the scroll position at the top.
        func normalizeOrigin() {
            guard let textView, let clip = textView.enclosingScrollView?.contentView else { return }
            if textView.frame.origin.y != 0 {
                textView.setFrameOrigin(NSPoint(x: 0, y: 0))
            }
            if clip.bounds.origin.y != 0 {
                clip.setBoundsOrigin(NSPoint(x: clip.bounds.origin.x, y: 0))
                textView.enclosingScrollView?.reflectScrolledClipView(clip)
            }
            ruler?.needsDisplay = true
        }

        /// Keeps the `NSTextView` as wide as the visible area while soft wrap
        /// is on: autoresizing misbehaves when the view is born zero-width
        /// inside SwiftUI.
        func syncWidth() {
            guard currentWrap != false,
                  let textView,
                  let clip = textView.enclosingScrollView?.contentView else { return }
            // `bounds.maxX` accounts for the ruler, which shifts the clip
            // view's origin to the left.
            let width = clip.bounds.maxX
            guard width > 0, abs(textView.frame.width - width) > 0.5 else { return }
            textView.frame.size.width = width
            textView.textContainer?.size = NSSize(width: width, height: CGFloat.greatestFiniteMagnitude)
            ruler?.needsDisplay = true
        }

        func textDidChange(_ notification: Notification) {
            guard !isApplyingExternalChange, let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
            applyHighlight(immediately: false)
            ruler?.needsDisplay = true
        }

        func applyHighlight(immediately: Bool) {
            pendingHighlight?.cancel()
            let work = DispatchWorkItem { [weak self] in
                guard let self, let textView = self.textView, let storage = textView.textStorage else { return }
                MarkdownSourceHighlighter.apply(to: storage,
                                                font: self.font,
                                                enabled: self.currentHighlight ?? true)
            }
            pendingHighlight = work
            if immediately {
                work.perform()
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.12, execute: work)
            }
        }

        func scroll(to line: Int) {
            guard let textView, line >= 0 else { return }
            let ns = textView.string as NSString
            var current = 0
            var location = 0
            while current < line, location < ns.length {
                let lineRange = ns.lineRange(for: NSRange(location: location, length: 0))
                location = NSMaxRange(lineRange)
                current += 1
            }
            let range = NSRange(location: min(location, ns.length), length: 0)
            textView.setSelectedRange(range)
            textView.scrollRangeToVisible(NSRange(location: range.location,
                                                  length: min(80, ns.length - range.location)))
            textView.window?.makeFirstResponder(textView)
        }
    }
}

/// Side ruler that draws the line numbers.
final class LineNumberRuler: NSRulerView {
    var font: NSFont = .monospacedDigitSystemFont(ofSize: 11, weight: .regular) {
        didSet { needsDisplay = true }
    }

    init(textView: NSTextView, scrollView: NSScrollView) {
        super.init(scrollView: scrollView, orientation: .verticalRuler)
        clientView = textView
        ruleThickness = 42
        NotificationCenter.default.addObserver(self, selector: #selector(refresh),
                                               name: NSText.didChangeNotification, object: textView)
        NotificationCenter.default.addObserver(self, selector: #selector(refresh),
                                               name: NSView.boundsDidChangeNotification,
                                               object: scrollView.contentView)
    }

    required init(coder: NSCoder) { fatalError("not supported") }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func refresh() { needsDisplay = true }

    override func drawHashMarksAndLabels(in rect: NSRect) {
        guard let textView = clientView as? NSTextView,
              let layoutManager = textView.layoutManager,
              let container = textView.textContainer,
              let scrollView else { return }

        // Careful: `rect` can be far larger than the ruler (AppKit passes the
        // whole dirty area), so everything is drawn clamped to `bounds`.
        let area = bounds.intersection(rect)
        guard !area.isEmpty else { return }

        NSColor.textBackgroundColor.setFill()
        area.fill()

        let separator = NSBezierPath()
        separator.move(to: NSPoint(x: bounds.maxX - 0.5, y: area.minY))
        separator.line(to: NSPoint(x: bounds.maxX - 0.5, y: area.maxY))
        separator.lineWidth = 1
        NSColor.separatorColor.setStroke()
        separator.stroke()

        let content = textView.string as NSString
        guard content.length > 0 else { return }

        let visible = scrollView.documentVisibleRect
        let glyphRange = layoutManager.glyphRange(forBoundingRect: visible, in: container)
        let charRange = layoutManager.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)

        var lineNumber = 1
        if charRange.location > 0 {
            content.enumerateSubstrings(in: NSRange(location: 0, length: charRange.location),
                                        options: [.byLines, .substringNotRequired]) { _, _, _, _ in
                lineNumber += 1
            }
        }

        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.tertiaryLabelColor
        ]
        let inset = textView.textContainerInset.height
        var index = charRange.location
        var iterations = 0

        while index <= NSMaxRange(charRange), index <= content.length, iterations < 20_000 {
            iterations += 1
            let lineRange = content.lineRange(for: NSRange(location: index, length: 0))
            let glyphIndex = layoutManager.glyphIndexForCharacter(at: lineRange.location)
            var effective = NSRange()
            let fragment = layoutManager.lineFragmentRect(forGlyphAt: glyphIndex, effectiveRange: &effective)
            let y = fragment.minY + inset - visible.minY
            if y > bounds.maxY { break }
            if fragment.height > 0, y + fragment.height >= bounds.minY {
                let label = "\(lineNumber)" as NSString
                let size = label.size(withAttributes: attributes)
                label.draw(at: NSPoint(x: bounds.maxX - size.width - 8,
                                       y: y + (fragment.height - size.height) / 2),
                           withAttributes: attributes)
            }
            lineNumber += 1
            let next = NSMaxRange(lineRange)
            if next <= index { break }
            index = next
        }
    }
}
