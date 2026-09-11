import Core
import Foundation
import SwiftUI

/// The ephemeral pan/zoom camera transform (`docs/domains/map.md` § W1 step 2, D44). Maps bundle
/// coordinate space (`[0, 1] × [0, 1]`, per `Point`'s doc comment) to screen space and back. Holds no
/// domain state (I14) — only the pan offset and the zoom multiple, relative to a whole-continent overview
/// of `1.0`, the same unit `MapViewModel.labelSet(atZoom:)` expects.
struct MapCamera: Equatable {
    var pan: CGSize
    var zoomScale: Double

    /// The committed pan/zoom at the start of an in-flight drag or magnification gesture, `nil` between
    /// gestures. Lets `applyDrag(translation:)`/`applyMagnification(_:)` update `pan`/`zoomScale` live on
    /// every `.onChanged` call (relative to the gesture's start, per `DragGesture`/`MagnificationGesture`'s
    /// cumulative-since-start semantics) while the camera itself stays the only new state `MapCanvasView`
    /// needs (AC1: no new stored property, no `@GestureState`).
    var panAtGestureStart: CGSize? = nil
    var zoomAtGestureStart: Double? = nil

    // [ESTIMATE: bounds on how far the student can zoom in/out; tunable during simulator review, D29/C3]
    static let minZoomScale: Double = 0.5
    static let maxZoomScale: Double = 8.0

    /// Trail-first framing (D44): centres the camera on `focusFrame` with a margin so "the continent is
    /// visible around it" (map W1 step 2). Called once per newly opened map by `MapCanvasView`.
    static func initial(focusFrame: FocusFrame, canvasSize: CGSize) -> MapCamera {
        let frameWidth = max(focusFrame.maxX - focusFrame.minX, 0.0001)
        let frameHeight = max(focusFrame.maxY - focusFrame.minY, 0.0001)
        // [ESTIMATE: the margin that keeps "the continent visible around it" (map W1 step 2); tunable]
        let paddingMultiplier = 3.0
        let targetSpan = min(1.0, max(frameWidth, frameHeight) * paddingMultiplier)
        let zoomScale = min(maxZoomScale, max(minZoomScale, 1.0 / targetSpan))

        let centerX = (focusFrame.minX + focusFrame.maxX) / 2
        let centerY = (focusFrame.minY + focusFrame.maxY) / 2
        let scale = zoomScale * min(canvasSize.width, canvasSize.height)
        let origin = CGPoint(
            x: (canvasSize.width - scale) / 2, y: (canvasSize.height - scale) / 2)
        let centerScreen = CGPoint(x: origin.x + centerX * scale, y: origin.y + centerY * scale)
        let pan = CGSize(
            width: canvasSize.width / 2 - centerScreen.x,
            height: canvasSize.height / 2 - centerScreen.y)
        return MapCamera(pan: pan, zoomScale: zoomScale)
    }

    /// Forward transform: bundle coordinate space to screen space (§4 step 2).
    func screenPoint(for bundlePoint: Point, canvasSize: CGSize) -> CGPoint {
        let scale = zoomScale * min(canvasSize.width, canvasSize.height)
        let origin = CGPoint(
            x: (canvasSize.width - scale) / 2, y: (canvasSize.height - scale) / 2)
        return CGPoint(
            x: origin.x + bundlePoint.x * scale + pan.width,
            y: origin.y + bundlePoint.y * scale + pan.height)
    }

    /// Inverse transform: screen space to bundle coordinate space — undoes `screenPoint(for:canvasSize:)`
    /// exactly. Returns a `CGPoint` (bundle-space `x`/`y` packed into its two fields) rather than `Core
    /// .Point`: `Core.Point` has no initializer visible outside the `Core` module (`Ids.swift`'s
    /// synthesized memberwise initializer is `internal`), and `Ids.swift` is out of this task's file scope
    /// (§2) — this task never constructs a `Core.Point`, only reads the ones `MapViewModel` already
    /// provides.
    func bundlePoint(for screenPoint: CGPoint, canvasSize: CGSize) -> CGPoint {
        let scale = zoomScale * min(canvasSize.width, canvasSize.height)
        let origin = CGPoint(
            x: (canvasSize.width - scale) / 2, y: (canvasSize.height - scale) / 2)
        let x = (screenPoint.x - pan.width - origin.x) / scale
        let y = (screenPoint.y - pan.height - origin.y) / scale
        return CGPoint(x: x, y: y)
    }

    /// The forward transform over a raw bundle-space `(x, y)` pair, used by `MapCanvasView` to convert a
    /// `bundlePoint(for:canvasSize:)` result back to screen space without constructing a `Core.Point`.
    func screenPoint(forBundleX x: Double, y: Double, canvasSize: CGSize) -> CGPoint {
        let scale = zoomScale * min(canvasSize.width, canvasSize.height)
        let origin = CGPoint(
            x: (canvasSize.width - scale) / 2, y: (canvasSize.height - scale) / 2)
        return CGPoint(x: origin.x + x * scale + pan.width, y: origin.y + y * scale + pan.height)
    }

    /// Live drag update: applies `translation` (cumulative since the gesture began, per `DragGesture`'s own
    /// semantics) relative to the pan committed when the drag started, so the map tracks the finger on
    /// every `.onChanged` call instead of jumping on release.
    mutating func applyDrag(translation: CGSize) {
        let base = panAtGestureStart ?? pan
        panAtGestureStart = base
        pan = CGSize(width: base.width + translation.width, height: base.height + translation.height)
    }

    /// Live magnification update: applies `magnification` (cumulative since the gesture began, per
    /// `MagnificationGesture`'s own semantics) relative to the zoom committed when the gesture started,
    /// clamped to `minZoomScale`/`maxZoomScale` on every `.onChanged` call.
    mutating func applyMagnification(_ magnification: Double) {
        let base = zoomAtGestureStart ?? zoomScale
        zoomAtGestureStart = base
        let candidate = base * magnification
        zoomScale = min(Self.maxZoomScale, max(Self.minZoomScale, candidate))
    }

    /// Clears the gesture baseline once a drag or magnification gesture ends, so the next gesture starts
    /// fresh from the now-committed `pan`/`zoomScale`.
    mutating func endGesture() {
        panAtGestureStart = nil
        zoomAtGestureStart = nil
    }
}
