// PoseOverlayView.swift — Skeleton Visualization Overlay for Breakdex
//
// A transparent SwiftUI overlay that draws detected joints and bones on top
// of a video frame. Uses Canvas for efficient GPU-accelerated rendering
// (one draw pass, no per-joint View hierarchy).
//
// COORDINATE MAPPING:
//   Vision returns 2D joint positions in normalized image coordinates where
//   (0,0) is bottom-left and (1,1) is top-right. SwiftUI's Canvas has (0,0)
//   at top-left. We flip Y and scale to the view size.
//
// VISUAL DESIGN (matching Breakdex design system):
//   - Joint circles: 6pt radius, accent color when confidence > 0.5,
//     textSecondary when low confidence
//   - Bone lines: 2pt stroke, white at 60% opacity
//   - Balance indicator (optional): CoM projected as a crosshair
//   - Colors sourced from DesignSystem.swift tokens
//
// PERFORMANCE:
//   Canvas renders in a single GPU pass — no extra View allocations per joint.
//   At 10fps update rate (MoveDetailView throttle), this adds negligible load.
//
// CONNECTED FILES:
//   - PoseAnalyzer.swift: Provides the VNHumanBodyPoseObservation consumed here
//   - BalanceAnalyzer.swift: Provides BalanceResult for the CoM indicator
//   - MoveDetailView.swift: Hosts this overlay on top of CustomVideoPlayerView
//   - DesignSystem.swift: Color.accent, .textSecondary

import SwiftUI
import Vision

struct PoseOverlayView: View {

    /// The 2D pose observation from Vision. Contains 19 recognized joints
    /// in normalized image coordinates.
    let observation: VNHumanBodyPoseObservation

    /// The video frame dimensions. Used to correctly map normalized coordinates
    /// to the overlay's view coordinate space. Vision returns coordinates in
    /// image space, not view space — aspect ratio differences matter.
    let imageSize: CGSize

    /// Optional balance result to draw a center-of-mass indicator.
    /// Only available on iOS 17+ when 3D pose analysis succeeds.
    var balanceResult: BalanceResult?

    /// Simplified balance result for the overlay (avoids @available on the struct).
    /// Contains just the projected CoM position in normalized coordinates and the score.
    struct BalanceResult {
        let normalizedX: CGFloat
        let normalizedY: CGFloat
        let score: Double
    }

    var body: some View {
        Canvas { context, size in
            // Map Vision normalized coords to Canvas coords.
            // Vision: (0,0) = bottom-left, (1,1) = top-right
            // Canvas: (0,0) = top-left, (width,height) = bottom-right
            // We need to flip Y and scale by the view size.
            //
            // Additionally, the video may have a different aspect ratio than the view.
            // We compute the fitted rect to account for letterboxing/pillarboxing.
            let fitted = fittedRect(imageSize: imageSize, viewSize: size)

            // Draw bones first (behind joints)
            drawBones(context: &context, fitted: fitted)

            // Draw joints on top
            drawJoints(context: &context, fitted: fitted)

            // Draw balance indicator if available
            if let balance = balanceResult {
                drawBalanceIndicator(context: &context, balance: balance, fitted: fitted)
            }
        }
        .allowsHitTesting(false)
    }

    // MARK: - Bones (Connected Joint Pairs)

    /// The 16 bone connections that form the human skeleton.
    /// Each pair is (parent joint, child joint) following anatomical hierarchy.
    private static let boneConnections: [(VNHumanBodyPoseObservation.JointName, VNHumanBodyPoseObservation.JointName)] = [
        // Spine
        (.root, .neck),
        (.neck, .nose),

        // Left arm
        (.neck, .leftShoulder),
        (.leftShoulder, .leftElbow),
        (.leftElbow, .leftWrist),

        // Right arm
        (.neck, .rightShoulder),
        (.rightShoulder, .rightElbow),
        (.rightElbow, .rightWrist),

        // Left leg
        (.root, .leftHip),
        (.leftHip, .leftKnee),
        (.leftKnee, .leftAnkle),

        // Right leg
        (.root, .rightHip),
        (.rightHip, .rightKnee),
        (.rightKnee, .rightAnkle),

        // Left eye/ear
        (.nose, .leftEye),
        (.nose, .rightEye),
    ]

    private func drawBones(context: inout GraphicsContext, fitted: CGRect) {
        for (joint1, joint2) in Self.boneConnections {
            guard let p1 = jointPoint(joint1, in: fitted),
                  let p2 = jointPoint(joint2, in: fitted) else { continue }

            var path = Path()
            path.move(to: p1)
            path.addLine(to: p2)

            context.stroke(
                path,
                with: .color(.white.opacity(0.6)),
                lineWidth: 2
            )
        }
    }

    // MARK: - Joints

    private func drawJoints(context: inout GraphicsContext, fitted: CGRect) {
        let allJoints: [VNHumanBodyPoseObservation.JointName] = [
            .nose, .neck, .root,
            .leftShoulder, .rightShoulder,
            .leftElbow, .rightElbow,
            .leftWrist, .rightWrist,
            .leftHip, .rightHip,
            .leftKnee, .rightKnee,
            .leftAnkle, .rightAnkle,
            .leftEye, .rightEye,
            .leftEar, .rightEar,
        ]

        for joint in allJoints {
            guard let point = try? observation.recognizedPoint(joint),
                  point.confidence > 0.1 else { continue }

            let viewPoint = visionToView(point: point.location, in: fitted)
            let radius: CGFloat = 5

            let color: Color = point.confidence > 0.5 ? .accent : .textSecondary

            let circle = Path(ellipseIn: CGRect(
                x: viewPoint.x - radius,
                y: viewPoint.y - radius,
                width: radius * 2,
                height: radius * 2
            ))

            context.fill(circle, with: .color(color))

            // White border for visibility against any background
            context.stroke(circle, with: .color(.white.opacity(0.8)), lineWidth: 1)
        }
    }

    // MARK: - Balance Indicator

    private func drawBalanceIndicator(
        context: inout GraphicsContext,
        balance: BalanceResult,
        fitted: CGRect
    ) {
        let center = visionToView(
            point: CGPoint(x: balance.normalizedX, y: balance.normalizedY),
            in: fitted
        )

        let crosshairSize: CGFloat = 12

        // Color based on balance score: red → yellow → green
        let indicatorColor: Color = {
            if balance.score > 0.6 { return .buttonGood }
            if balance.score > 0.3 { return .buttonHard }
            return .buttonAgain
        }()

        // Horizontal line
        var hLine = Path()
        hLine.move(to: CGPoint(x: center.x - crosshairSize, y: center.y))
        hLine.addLine(to: CGPoint(x: center.x + crosshairSize, y: center.y))
        context.stroke(hLine, with: .color(indicatorColor), lineWidth: 2)

        // Vertical line
        var vLine = Path()
        vLine.move(to: CGPoint(x: center.x, y: center.y - crosshairSize))
        vLine.addLine(to: CGPoint(x: center.x, y: center.y + crosshairSize))
        context.stroke(vLine, with: .color(indicatorColor), lineWidth: 2)

        // Center dot
        let dotRadius: CGFloat = 4
        let dot = Path(ellipseIn: CGRect(
            x: center.x - dotRadius,
            y: center.y - dotRadius,
            width: dotRadius * 2,
            height: dotRadius * 2
        ))
        context.fill(dot, with: .color(indicatorColor))
    }

    // MARK: - Coordinate Mapping

    /// Converts a Vision normalized point to a Canvas view point.
    ///
    /// Vision: (0,0) = bottom-left, (1,1) = top-right (image coordinates)
    /// Canvas: (0,0) = top-left, origin is the view's top-left corner
    ///
    /// The conversion flips Y and scales to the fitted rect (accounting for
    /// aspect-ratio differences between the video and the view).
    private func visionToView(point: CGPoint, in fitted: CGRect) -> CGPoint {
        CGPoint(
            x: fitted.origin.x + point.x * fitted.width,
            y: fitted.origin.y + (1 - point.y) * fitted.height
        )
    }

    /// Gets a joint's position in view coordinates, or nil if not detected.
    private func jointPoint(
        _ joint: VNHumanBodyPoseObservation.JointName,
        in fitted: CGRect
    ) -> CGPoint? {
        guard let point = try? observation.recognizedPoint(joint),
              point.confidence > 0.1 else { return nil }
        return visionToView(point: point.location, in: fitted)
    }

    /// Computes the fitted rectangle for the video within the view.
    ///
    /// When the video aspect ratio differs from the view, the video is
    /// letterboxed (black bars top/bottom) or pillarboxed (black bars left/right).
    /// This returns the actual area where the video content is displayed.
    private func fittedRect(imageSize: CGSize, viewSize: CGSize) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0 else {
            return CGRect(origin: .zero, size: viewSize)
        }

        let imageAspect = imageSize.width / imageSize.height
        let viewAspect = viewSize.width / viewSize.height

        if imageAspect > viewAspect {
            // Video is wider than view → letterbox (black bars top/bottom)
            let height = viewSize.width / imageAspect
            let y = (viewSize.height - height) / 2
            return CGRect(x: 0, y: y, width: viewSize.width, height: height)
        } else {
            // Video is taller than view → pillarbox (black bars left/right)
            let width = viewSize.height * imageAspect
            let x = (viewSize.width - width) / 2
            return CGRect(x: x, y: 0, width: width, height: viewSize.height)
        }
    }
}

#Preview("Pose Overlay") {
    ZStack {
        Color.black.opacity(0.9)
        VStack(spacing: Spacing.sm) {
            Image(systemName: "figure.mixed.cardio")
                .font(.system(size: 28))
                .foregroundStyle(.white)
            Text("PoseOverlayView requires a live VNHumanBodyPoseObservation")
                .font(.ibmPlexMono(size: 12))
                .foregroundStyle(.white.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.md)
        }
    }
    .frame(width: 320, height: 200)
}
