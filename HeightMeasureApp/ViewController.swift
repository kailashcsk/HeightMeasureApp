import UIKit
import ARKit
import SceneKit

class ViewController: UIViewController, ARSCNViewDelegate, ARSessionDelegate {
    
    @IBOutlet var sceneView: ARSCNView!
    

    private var measurementPoints: [simd_float3] = []
    private var pointNodes: [SCNNode] = []
    private var lineNode: SCNNode?
    private var textNode: SCNNode?
    private var isLiDARAvailable: Bool = false
    private var currentPlaneAnchors: [ARPlaneAnchor] = []
    private var crosshairNode: SCNNode!
    
    private var statusLabel: UILabel!
    private var instructionLabel: UILabel!
    private var measurementLabel: UILabel!
    private var resetButton: UIButton!
    private var addButton: UIButton!
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupARView()
        setupUI()
        setupCrosshair()
        checkLiDARAvailability()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        startARSession()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        sceneView.session.pause()
    }
    
    
    private func setupARView() {
        sceneView.delegate = self
        sceneView.session.delegate = self
        sceneView.showsStatistics = false
        sceneView.debugOptions = []
        sceneView.automaticallyUpdatesLighting = true
    }
    
    private func setupCrosshair() {
        
        let crosshairGeometry = SCNSphere(radius: 0.003)
        crosshairGeometry.firstMaterial?.diffuse.contents = UIColor.white
        crosshairGeometry.firstMaterial?.emission.contents = UIColor.white
        crosshairGeometry.firstMaterial?.lightingModel = .constant
        
        crosshairNode = SCNNode(geometry: crosshairGeometry)
        
        
        let ringGeometry = SCNTorus(ringRadius: 0.01, pipeRadius: 0.001)
        ringGeometry.firstMaterial?.diffuse.contents = UIColor.white.withAlphaComponent(0.7)
        ringGeometry.firstMaterial?.lightingModel = .constant
        
        let ringNode = SCNNode(geometry: ringGeometry)
        crosshairNode.addChildNode(ringNode)
        
        sceneView.scene.rootNode.addChildNode(crosshairNode)
    }
    
    private func updateCrosshair() {
    
        let screenCenter = CGPoint(x: sceneView.bounds.midX, y: sceneView.bounds.midY)
        
        if let query = sceneView.raycastQuery(from: screenCenter, allowing: .estimatedPlane, alignment: .any) {
            let results = sceneView.session.raycast(query)
            
            if let result = results.first {
                let position = result.worldTransform.columns.3
                crosshairNode.simdPosition = simd_float3(position.x, position.y, position.z)
                crosshairNode.isHidden = false
            } else {
                crosshairNode.isHidden = true
            }
        } else {
            crosshairNode.isHidden = true
        }
    }
    
    private func setupUI() {
        
        statusLabel = UILabel()
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        statusLabel.textColor = .white
        statusLabel.layer.cornerRadius = 8
        statusLabel.clipsToBounds = true
        statusLabel.textAlignment = .center
        statusLabel.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        statusLabel.text = "Move to find a surface"
        view.addSubview(statusLabel)
        
        instructionLabel = UILabel()
        instructionLabel.translatesAutoresizingMaskIntoConstraints = false
        instructionLabel.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        instructionLabel.textColor = .white
        instructionLabel.numberOfLines = 0
        instructionLabel.layer.cornerRadius = 8
        instructionLabel.clipsToBounds = true
        instructionLabel.textAlignment = .center
        instructionLabel.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        instructionLabel.text = "Point at a surface and tap + to start"
        view.addSubview(instructionLabel)        
        
        measurementLabel = UILabel()
        measurementLabel.translatesAutoresizingMaskIntoConstraints = false
        measurementLabel.backgroundColor = UIColor.clear
        measurementLabel.textColor = .white
        measurementLabel.textAlignment = .center
        measurementLabel.font = UIFont.systemFont(ofSize: 24, weight: .bold)
        measurementLabel.isHidden = true
        view.addSubview(measurementLabel)
        
        addButton = UIButton(type: .system)
        addButton.translatesAutoresizingMaskIntoConstraints = false
        addButton.backgroundColor = UIColor.white
        addButton.layer.cornerRadius = 30
        addButton.setTitle("+", for: .normal)
        addButton.setTitleColor(.black, for: .normal)
        addButton.titleLabel?.font = UIFont.systemFont(ofSize: 24, weight: .bold)
        addButton.addTarget(self, action: #selector(addPoint), for: .touchUpInside)
        view.addSubview(addButton)
        
        resetButton = UIButton(type: .system)
        resetButton.translatesAutoresizingMaskIntoConstraints = false
        resetButton.backgroundColor = UIColor.systemRed.withAlphaComponent(0.8)
        resetButton.setTitleColor(.white, for: .normal)
        resetButton.layer.cornerRadius = 20
        resetButton.setTitle("Clear", for: .normal)
        resetButton.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .bold)
        resetButton.addTarget(self, action: #selector(resetMeasurement), for: .touchUpInside)
        view.addSubview(resetButton)
        
        setupConstraints()
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            statusLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            statusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            statusLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            statusLabel.heightAnchor.constraint(equalToConstant: 40),
            
            instructionLabel.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 10),
            instructionLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            instructionLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            measurementLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            measurementLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -50),
            measurementLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            measurementLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            addButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            addButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -40),
            addButton.widthAnchor.constraint(equalToConstant: 60),
            addButton.heightAnchor.constraint(equalToConstant: 60),
            
            resetButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            resetButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -50),
            resetButton.widthAnchor.constraint(equalToConstant: 60),
            resetButton.heightAnchor.constraint(equalToConstant: 40)
        ])
    }
    
    private func checkLiDARAvailability() {
        isLiDARAvailable = ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh)
    }
    
    private func startARSession() {
        let configuration = ARWorldTrackingConfiguration()
        
        configuration.planeDetection = [.horizontal, .vertical]
        
        if isLiDARAvailable {
            configuration.sceneReconstruction = .mesh
        }
        
        configuration.environmentTexturing = .automatic
        
        sceneView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
    }
    

    @objc private func addPoint() {
        let screenCenter = CGPoint(x: sceneView.bounds.midX, y: sceneView.bounds.midY)
        
        guard let query = sceneView.raycastQuery(from: screenCenter, allowing: .estimatedPlane, alignment: .any) else {
            showFeedback("No surface detected", isError: true)
            return
        }
        
        let results = sceneView.session.raycast(query)
        guard let result = results.first else {
            showFeedback("Point the camera at a surface", isError: true)
            return
        }
        
        guard measurementPoints.count < 2 else { return }
        
        let worldPosition = result.worldTransform.columns.3
        let position = simd_float3(worldPosition.x, worldPosition.y, worldPosition.z)
        
        measurementPoints.append(position)
        
        let pointNode = createPointNode(at: position, index: measurementPoints.count)
        sceneView.scene.rootNode.addChildNode(pointNode)
        pointNodes.append(pointNode)
        

        updateInstructions()
        
        
        if measurementPoints.count == 2 {
            calculateMeasurement()
        }
        
        
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()
    }
    
    private func createPointNode(at position: simd_float3, index: Int) -> SCNNode {
        
        let sphere = SCNSphere(radius: 0.006)
        sphere.firstMaterial?.diffuse.contents = UIColor.white
        sphere.firstMaterial?.emission.contents = UIColor.white
        sphere.firstMaterial?.lightingModel = .constant
        
        let pointNode = SCNNode(geometry: sphere)
        pointNode.simdPosition = position
        
        
        let ring = SCNTorus(ringRadius: 0.02, pipeRadius: 0.002)
        ring.firstMaterial?.diffuse.contents = UIColor.white.withAlphaComponent(0.8)
        ring.firstMaterial?.lightingModel = .constant
        
        let ringNode = SCNNode(geometry: ring)
        pointNode.addChildNode(ringNode)
        
        
        let scaleAction = SCNAction.sequence([
            SCNAction.scale(to: 1.5, duration: 0.5),
            SCNAction.scale(to: 1.0, duration: 0.5)
        ])
        let fadeAction = SCNAction.sequence([
            SCNAction.fadeOut(duration: 0.5),
            SCNAction.fadeIn(duration: 0.5)
        ])
        
        ringNode.runAction(SCNAction.repeatForever(scaleAction))
        ringNode.runAction(SCNAction.repeatForever(fadeAction))
        
        return pointNode
    }
    
    private func calculateMeasurement() {
        guard measurementPoints.count == 2 else { return }
        
        let point1 = measurementPoints[0]
        let point2 = measurementPoints[1]

        let distance = simd_distance(point1, point2)
        
        drawLine(from: point1, to: point2, distance: distance)
        
        displayMeasurement(distance: distance)
    }
    
    private func drawLine(from startPoint: simd_float3, to endPoint: simd_float3, distance: Float) {
        
        let startSCN = SCNVector3(startPoint.x, startPoint.y, startPoint.z)
        let endSCN = SCNVector3(endPoint.x, endPoint.y, endPoint.z)
        
        let vertices = [startSCN, endSCN]
        let source = SCNGeometrySource(vertices: vertices)
        let indices: [Int32] = [0, 1]
        let element = SCNGeometryElement(indices: indices, primitiveType: .line)
        
        let lineGeometry = SCNGeometry(sources: [source], elements: [element])
        lineGeometry.firstMaterial?.diffuse.contents = UIColor.white
        lineGeometry.firstMaterial?.lightingModel = .constant
        
        lineNode = SCNNode(geometry: lineGeometry)
        sceneView.scene.rootNode.addChildNode(lineNode!)
        
        add3DMeasurementText(distance: distance, midPoint: (startPoint + endPoint) / 2)
    }
    
    private func add3DMeasurementText(distance: Float, midPoint: simd_float3) {
        let distanceInCm = distance * 100
        let distanceInInches = distance * 39.3701
        
        let cmText = String(format: "%.0f cm", distanceInCm)
        let inchText = String(format: "%.1f\"", distanceInInches)
        let displayText = "\(cmText)"
        
        let textGeometry = SCNText(string: displayText, extrusionDepth: 0)
        textGeometry.font = UIFont.systemFont(ofSize: 8, weight: .bold)
        textGeometry.firstMaterial?.diffuse.contents = UIColor.white
        textGeometry.firstMaterial?.lightingModel = .constant
        textGeometry.isWrapped = true
        textGeometry.alignmentMode = CATextLayerAlignmentMode.center.rawValue
        
        textNode = SCNNode(geometry: textGeometry)
        textNode!.simdPosition = midPoint + simd_float3(0, 0.05, 0)
        textNode!.scale = SCNVector3(0.01, 0.01, 0.01)
    
        let constraint = SCNBillboardConstraint()
        textNode!.constraints = [constraint]
        
        sceneView.scene.rootNode.addChildNode(textNode!)
    }
    
    private func displayMeasurement(distance: Float) {
        let distanceInCm = distance * 100
        let distanceInFeet = Double(distance) * 3.28084
        let feet = Int(distanceInFeet)
        let inches = (distanceInFeet - Double(feet)) * 12
        
        let cmText = String(format: "%.0f cm", distanceInCm)
        let feetText = String(format: "%d' %.1f\"", feet, inches)
        
        DispatchQueue.main.async {
            self.measurementLabel.text = cmText
            self.measurementLabel.isHidden = false
        }
        
        showFeedback("Height: \(cmText) (\(feetText))", isError: false)
    }
    
    private func updateInstructions() {
        DispatchQueue.main.async {
            switch self.measurementPoints.count {
            case 0:
                self.instructionLabel.text = "Point at person's feet and tap +"
            case 1:
                self.instructionLabel.text = "Now point at person's head and tap +"
            default:
                self.instructionLabel.text = "Measurement complete"
            }
        }
    }
    
    @objc private func resetMeasurement() {
        measurementPoints.removeAll()
        
        pointNodes.forEach { $0.removeFromParentNode() }
        pointNodes.removeAll()
        
        lineNode?.removeFromParentNode()
        lineNode = nil
        
        textNode?.removeFromParentNode()
        textNode = nil
        
        measurementLabel.isHidden = true
        updateInstructions()
        
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()
    }
    
    private func showFeedback(_ message: String, isError: Bool) {
        DispatchQueue.main.async {
            self.statusLabel.text = message
            self.statusLabel.backgroundColor = isError ?
                UIColor.systemRed.withAlphaComponent(0.8) :
                UIColor.systemGreen.withAlphaComponent(0.8)
        
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                self.statusLabel.backgroundColor = UIColor.black.withAlphaComponent(0.6)
            }
        }
    }
}

extension ViewController {
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        DispatchQueue.main.async {
            self.updateCrosshair()
        }
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        guard let _ = anchor as? ARPlaneAnchor else { return }
        
        DispatchQueue.main.async {
            self.statusLabel.text = "Surface detected - ready to measure"
            self.statusLabel.backgroundColor = UIColor.systemGreen.withAlphaComponent(0.6)
        }
    }
}


extension ViewController {
    func session(_ session: ARSession, didFailWithError error: Error) {
        showFeedback("AR Error: \(error.localizedDescription)", isError: true)
    }
    
    func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
        DispatchQueue.main.async {
            switch camera.trackingState {
            case .normal:
                if self.currentPlaneAnchors.isEmpty {
                    self.statusLabel.text = "Move to find surfaces"
                }
            case .limited(let reason):
                switch reason {
                case .excessiveMotion:
                    self.statusLabel.text = "Move more slowly"
                case .insufficientFeatures:
                    self.statusLabel.text = "Point at surfaces with more detail"
                case .initializing:
                    self.statusLabel.text = "Starting AR..."
                default:
                    self.statusLabel.text = "Limited tracking"
                }
                self.statusLabel.backgroundColor = UIColor.systemOrange.withAlphaComponent(0.6)
            case .notAvailable:
                self.statusLabel.text = "AR not available"
                self.statusLabel.backgroundColor = UIColor.systemRed.withAlphaComponent(0.6)
            }
        }
    }
}
