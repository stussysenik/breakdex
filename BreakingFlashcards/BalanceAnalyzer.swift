// BalanceAnalyzer.swift — Biomechanical Balance Inference for Breakdex
//
// Computes balance metrics from 3D pose data using biomechanical principles.
// Given a VNHumanBodyPose3DObservation (17 joints in meters), this module:
//   1. Estimates center of mass using de Leva (1996) body segment percentages
//   2. Identifies the support base (ground contact points)
//   3. Calculates stability margin (CoM projection vs support polygon)
//   4. Computes tilt angle from vertical alignment
//   5. Generates human-readable feedback
//
// DE LEVA (1996) BODY SEGMENT PARAMETERS:
//   The gold standard for estimating body segment masses as a percentage of
//   total body mass. Originally published in "Adjustments to Zatsiorsky-
//   Seluyanov's segment inertia parameters" (Journal of Biomechanics, 1996).
//   Each segment's CoM is estimated as the midpoint of its bounding joints.
//
// COORDINATE SYSTEM (Vision 3D):
//   - X: positive = right of the person
//   - Y: positive = up
//   - Z: positive = toward the camera
//   Positions are in meters relative to the root (hip center) joint.
//
// CONNECTED FILES:
//   - PoseAnalyzer.swift: Provides the 3D pose observation consumed here
//   - MoveDetailView.swift: Displays the BalanceResult as a score badge

import Vision
import simd

@available(iOS 17.0, *)
enum BalanceAnalyzer {

    // MARK: - Result Type

    struct BalanceResult {
        /// Overall balance score from 0.0 (falling) to 1.0 (rock solid).
        /// Computed as weighted combination of stability margin and joint alignment.
        let score: Double

        /// Estimated whole-body center of mass in meters (Vision model space).
        let centerOfMass: SIMD3<Float>

        /// Ground contact points — the joints closest to the ground plane.
        /// For a standing pose: both ankles. For a freeze: could be one hand + head.
        let supportBase: [SIMD3<Float>]

        /// Degrees off vertical (0 = perfectly balanced upright/inverted).
        /// Measured as the angle between the root→spine vector and the Y axis.
        let tiltAngle: Double

        /// Human-readable feedback for the dancer.
        let feedback: String
    }

    // MARK: - Analysis Entry Point

    /// Compute balance from a 3D pose observation.
    ///
    /// Extracts joint positions, computes biomechanical metrics, and returns
    /// a structured BalanceResult. Throws if required joints can't be read.
    ///
    /// - Parameter pose: A VNHumanBodyPose3DObservation from PoseAnalyzer.
    /// - Returns: A BalanceResult with score, CoM, tilt, and feedback.
    static func analyze(pose: VNHumanBodyPose3DObservation) throws -> BalanceResult {
        // 1. Extract all joint positions into a dictionary
        let joints = try extractJointPositions(from: pose)

        // 2. Compute center of mass using de Leva segment masses
        let com = computeCenterOfMass(joints: joints)

        // 3. Identify support base (ground contact points)
        let support = identifySupportBase(joints: joints)

        // 4. Calculate stability margin
        let stabilityMargin = computeStabilityMargin(com: com, supportBase: support)

        // 5. Compute tilt angle from vertical
        let tilt = computeTiltAngle(joints: joints)

        // 6. Compute overall score
        let normalizedMargin = min(max(Double(stabilityMargin) / 0.15, 0), 1)
        let normalizedAlignment = min(max(1.0 - (tilt / 45.0), 0), 1)
        let score = 0.6 * normalizedMargin + 0.4 * normalizedAlignment

        // 7. Generate feedback
        let feedback = generateFeedback(tilt: tilt, stabilityMargin: stabilityMargin, joints: joints)

        return BalanceResult(
            score: score,
            centerOfMass: com,
            supportBase: support,
            tiltAngle: tilt,
            feedback: feedback
        )
    }

    // MARK: - Joint Extraction

    /// Extract 3D positions for all available joints.
    ///
    /// Each joint position is extracted from the 4x4 transform matrix returned
    /// by Vision. The translation component sits in column 3 of the matrix.
    private static func extractJointPositions(
        from pose: VNHumanBodyPose3DObservation
    ) throws -> [VNHumanBodyPose3DObservation.JointName: SIMD3<Float>] {
        var positions: [VNHumanBodyPose3DObservation.JointName: SIMD3<Float>] = [:]

        let jointNames: [VNHumanBodyPose3DObservation.JointName] = [
            .root,
            .centerHead, .topHead,
            .spine, .centerShoulder,
            .leftShoulder, .rightShoulder,
            .leftElbow, .rightElbow,
            .leftWrist, .rightWrist,
            .leftHip, .rightHip,
            .leftKnee, .rightKnee,
            .leftAnkle, .rightAnkle
        ]

        for name in jointNames {
            if let point = try? pose.recognizedPoint(name) {
                let col = point.position.columns.3
                positions[name] = SIMD3<Float>(col.x, col.y, col.z)
            }
        }

        return positions
    }

    // MARK: - Center of Mass (de Leva 1996)

    /// Computes whole-body center of mass using de Leva segment mass percentages.
    ///
    /// Each body segment's CoM is approximated as the midpoint of its two
    /// bounding joints, weighted by the segment's percentage of total body mass.
    /// The sum of all weighted segment positions gives the whole-body CoM.
    private static func computeCenterOfMass(
        joints: [VNHumanBodyPose3DObservation.JointName: SIMD3<Float>]
    ) -> SIMD3<Float> {
        // De Leva (1996) segment mass percentages (male averages)
        // Segment: (proximal joint, distal joint, % body mass)
        let segments: [(VNHumanBodyPose3DObservation.JointName, VNHumanBodyPose3DObservation.JointName, Float)] = [
            // Head + Neck: centerHead → topHead (6.94%)
            (.centerHead, .topHead, 0.0694),
            // Upper trunk: centerShoulder → spine (15.96%)
            (.centerShoulder, .spine, 0.1596),
            // Lower trunk: spine → root (27.50% — combined mid+lower trunk)
            (.spine, .root, 0.2750),
            // Left upper arm: leftShoulder → leftElbow (2.71%)
            (.leftShoulder, .leftElbow, 0.0271),
            // Right upper arm: rightShoulder → rightElbow (2.71%)
            (.rightShoulder, .rightElbow, 0.0271),
            // Left forearm + hand: leftElbow → leftWrist (2.23%)
            (.leftElbow, .leftWrist, 0.0223),
            // Right forearm + hand: rightElbow → rightWrist (2.23%)
            (.rightElbow, .rightWrist, 0.0223),
            // Left thigh: leftHip → leftKnee (14.16%)
            (.leftHip, .leftKnee, 0.1416),
            // Right thigh: rightHip → rightKnee (14.16%)
            (.rightHip, .rightKnee, 0.1416),
            // Left shank + foot: leftKnee → leftAnkle (5.70%)
            (.leftKnee, .leftAnkle, 0.0570),
            // Right shank + foot: rightKnee → rightAnkle (5.70%)
            (.rightKnee, .rightAnkle, 0.0570),
        ]

        var weightedSum = SIMD3<Float>(0, 0, 0)
        var totalWeight: Float = 0

        for (proximal, distal, mass) in segments {
            guard let p1 = joints[proximal], let p2 = joints[distal] else { continue }
            let midpoint = (p1 + p2) / 2.0
            weightedSum += midpoint * mass
            totalWeight += mass
        }

        guard totalWeight > 0 else {
            return joints[.root] ?? SIMD3<Float>(0, 0, 0)
        }

        return weightedSum / totalWeight
    }

    // MARK: - Support Base Identification

    /// Identifies the ground contact points from the detected joints.
    ///
    /// The support base is defined as joints that are within a threshold distance
    /// of the lowest detected joint (the ground plane). In a standing pose, this
    /// is typically both ankles. In a freeze, it could be one hand + head.
    ///
    /// The threshold (0.15m = 15cm) accounts for:
    /// - Foot length beyond the ankle joint
    /// - Measurement noise in the 3D pose estimation
    /// - Slight elevation differences in multi-point contact
    private static func identifySupportBase(
        joints: [VNHumanBodyPose3DObservation.JointName: SIMD3<Float>]
    ) -> [SIMD3<Float>] {
        // Candidate contact joints — extremities that could touch the ground
        let contactCandidates: [VNHumanBodyPose3DObservation.JointName] = [
            .leftAnkle, .rightAnkle,
            .leftWrist, .rightWrist,
            .centerHead, .topHead
        ]

        let candidatePositions = contactCandidates.compactMap { joints[$0] }
        guard !candidatePositions.isEmpty else { return [] }

        // Find the lowest Y value (closest to ground)
        let lowestY = candidatePositions.map(\.y).min() ?? 0

        // Ground threshold: within 15cm of the lowest point
        let threshold: Float = 0.15

        return candidatePositions.filter { $0.y <= lowestY + threshold }
    }

    // MARK: - Stability Margin

    /// Computes the stability margin: how far the CoM projection is from
    /// the edge of the support polygon.
    ///
    /// Projects the CoM onto the ground plane (XZ), then measures the minimum
    /// distance from this projection to the nearest support point. A larger
    /// margin means more stable — the CoM is well within the support base.
    ///
    /// For a single support point: the margin is simply the horizontal distance
    /// from the projected CoM to that point (inverted, so closer = more stable).
    ///
    /// Returns distance in meters. Typical ranges:
    ///   - Standing: 0.05-0.15m (feet are shoulder-width, CoM is centered)
    ///   - Baby freeze: 0.02-0.08m (small support triangle)
    ///   - One-hand freeze: 0.0-0.03m (minimal support)
    private static func computeStabilityMargin(
        com: SIMD3<Float>,
        supportBase: [SIMD3<Float>]
    ) -> Float {
        guard !supportBase.isEmpty else { return 0 }

        // Project CoM onto the ground plane (XZ)
        let comXZ = SIMD2<Float>(com.x, com.z)

        // Compute the centroid of the support base
        let supportCentroid: SIMD2<Float> = {
            let sum = supportBase.reduce(SIMD2<Float>(0, 0)) { acc, pt in
                acc + SIMD2<Float>(pt.x, pt.z)
            }
            return sum / Float(supportBase.count)
        }()

        // Distance from CoM projection to support centroid
        let distToCentroid = simd_distance(comXZ, supportCentroid)

        // For a single-point support, the "radius" is effectively 0
        // For multi-point, compute the average distance from centroid to support points
        let supportRadius: Float = {
            if supportBase.count <= 1 { return 0.05 } // Approximate foot radius
            let distances = supportBase.map { pt in
                simd_distance(SIMD2<Float>(pt.x, pt.z), supportCentroid)
            }
            return distances.reduce(0, +) / Float(distances.count)
        }()

        // Stability margin = how much room the CoM has before exiting the support polygon
        // Positive = inside (stable), negative = outside (unstable)
        return max(supportRadius - distToCentroid, 0)
    }

    // MARK: - Tilt Angle

    /// Computes the tilt angle: how far the torso deviates from vertical.
    ///
    /// Measures the angle between the root→spine vector and the Y axis (up).
    /// 0° = perfectly upright (or perfectly inverted — both are balanced).
    /// 90° = horizontal (definitely not balanced).
    ///
    /// For inverted poses (freezes/headstands), we measure from the negative Y
    /// axis so that a perfect headstand also reads as ~0° tilt.
    private static func computeTiltAngle(
        joints: [VNHumanBodyPose3DObservation.JointName: SIMD3<Float>]
    ) -> Double {
        guard let root = joints[.root], let spine = joints[.spine] else { return 0 }

        let torsoVec = simd_normalize(spine - root)
        let upVec = SIMD3<Float>(0, 1, 0)

        // Angle between torso vector and up
        let dotProduct = simd_dot(torsoVec, upVec)
        let angleFromUp = acos(simd_clamp(dotProduct, -1, 1))

        // If inverted (spine below root), measure from down vector instead
        let angleFromDown = Float.pi - angleFromUp

        // Take the smaller angle — a perfect headstand is 0° tilt, same as standing
        let tiltRadians = min(angleFromUp, angleFromDown)

        return Double(tiltRadians) * 180.0 / .pi
    }

    // MARK: - Feedback Generation

    /// Generates a human-readable feedback string based on the analysis.
    private static func generateFeedback(
        tilt: Double,
        stabilityMargin: Float,
        joints: [VNHumanBodyPose3DObservation.JointName: SIMD3<Float>]
    ) -> String {
        // Determine lateral lean direction from root→spine vector
        let lateralDirection: String = {
            guard let root = joints[.root], let spine = joints[.spine] else { return "" }
            let diff = spine - root
            if abs(diff.x) < 0.02 { return "" }
            return diff.x > 0 ? "right" : "left"
        }()

        if tilt < 5 {
            return "Solid alignment"
        } else if tilt < 15 {
            let direction = lateralDirection.isEmpty ? "" : " \(lateralDirection)"
            return "Slight lean\(direction) (\(Int(tilt))°)"
        } else if tilt < 30 {
            let direction = lateralDirection.isEmpty ? "" : " \(lateralDirection)"
            return "Leaning\(direction) \(Int(tilt))°"
        } else {
            return "Significant tilt (\(Int(tilt))°)"
        }
    }
}
