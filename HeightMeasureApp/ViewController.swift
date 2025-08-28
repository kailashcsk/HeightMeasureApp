import UIKit
import ARKit
import SceneKit

// MARK: - Data Models
struct MeasurementRecord {
    let id = UUID()
    let timestamp: Date
    let heightCM: Float
    let heightFeet: String
    let imagePath: String?
    let notes: String?
    
    init(heightCM: Float, heightFeet: String, imagePath: String? = nil, notes: String? = nil) {
        self.timestamp = Date()
        self.heightCM = heightCM
        self.heightFeet = heightFeet
        self.imagePath = imagePath
        self.notes = notes
    }
}

class ViewController: UIViewController, ARSCNViewDelegate, ARSessionDelegate {
    
    @IBOutlet var sceneView: ARSCNView!
    
    // MARK: - Measurement Properties
    private var measurementPoints: [simd_float3] = []
    private var pointNodes: [SCNNode] = []
    private var lineNode: SCNNode?
    private var textNode: SCNNode?
    private var isLiDARAvailable: Bool = false
    private var currentPlaneAnchors: [ARPlaneAnchor] = []
    private var crosshairNode: SCNNode!
    
    // MARK: - New Properties for Enhanced Features
    private var measurementRecords: [MeasurementRecord] = []
    private var currentMeasurementImage: UIImage?
    private var dynamicLineNode: SCNNode?
    
    // MARK: - UI Elements
    private var statusLabel: UILabel!
    private var instructionLabel: UILabel!
    private var measurementLabel: UILabel!
    private var resetButton: UIButton!
    private var addButton: UIButton!
    private var exportButton: UIButton!
    private var captureButton: UIButton!
    private var recordCountLabel: UILabel!
    
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
    
    // MARK: - AR Setup
    private func setupARView() {
        sceneView.delegate = self
        sceneView.session.delegate = self
        sceneView.showsStatistics = false
        sceneView.debugOptions = []
        sceneView.automaticallyUpdatesLighting = true
    }
    
    private func setupCrosshair() {
        // Main crosshair dot
        let crosshairGeometry = SCNSphere(radius: 0.002)
        crosshairGeometry.firstMaterial?.diffuse.contents = UIColor.systemYellow
        crosshairGeometry.firstMaterial?.emission.contents = UIColor.systemYellow
        crosshairGeometry.firstMaterial?.lightingModel = .constant
        
        crosshairNode = SCNNode(geometry: crosshairGeometry)
        
        // Animated ring around crosshair
        let ringGeometry = SCNTorus(ringRadius: 0.008, pipeRadius: 0.0008)
        ringGeometry.firstMaterial?.diffuse.contents = UIColor.systemYellow.withAlphaComponent(0.8)
        ringGeometry.firstMaterial?.lightingModel = .constant
        
        let ringNode = SCNNode(geometry: ringGeometry)
        crosshairNode.addChildNode(ringNode)
        
        // Pulse animation for the ring
        let pulseAction = SCNAction.sequence([
            SCNAction.scale(to: 1.3, duration: 1.0),
            SCNAction.scale(to: 1.0, duration: 1.0)
        ])
        ringNode.runAction(SCNAction.repeatForever(pulseAction))
        
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
                
                if measurementPoints.count == 1 {
                    updateDynamicLine(to: simd_float3(position.x, position.y, position.z))
                }
            } else {
                crosshairNode.isHidden = true
                removeDynamicLine()
            }
        } else {
            crosshairNode.isHidden = true
            removeDynamicLine()
        }
    }
    
    // MARK: - Dynamic Measurement Line
    private func updateDynamicLine(to endPoint: simd_float3) {
        guard measurementPoints.count == 1 else { return }
        
        removeDynamicLine()
        
        let startPoint = measurementPoints[0]
        let startSCN = SCNVector3(startPoint.x, startPoint.y, startPoint.z)
        let endSCN = SCNVector3(endPoint.x, endPoint.y, endPoint.z)
        
        let vertices = [startSCN, endSCN]
        let source = SCNGeometrySource(vertices: vertices)
        let indices: [Int32] = [0, 1]
        let element = SCNGeometryElement(indices: indices, primitiveType: .line)
        
        let lineGeometry = SCNGeometry(sources: [source], elements: [element])
        lineGeometry.firstMaterial?.diffuse.contents = UIColor.systemYellow.withAlphaComponent(0.7)
        lineGeometry.firstMaterial?.lightingModel = .constant
        
        dynamicLineNode = SCNNode(geometry: lineGeometry)
        sceneView.scene.rootNode.addChildNode(dynamicLineNode!)
    }
    
    private func removeDynamicLine() {
        dynamicLineNode?.removeFromParentNode()
        dynamicLineNode = nil
    }
    
    private func setupUI() {
        // Status label
        statusLabel = UILabel()
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        statusLabel.textColor = .white
        statusLabel.layer.cornerRadius = 8
        statusLabel.clipsToBounds = true
        statusLabel.textAlignment = .center
        statusLabel.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        statusLabel.text = "Move to find a surface"
        view.addSubview(statusLabel)
        
        // Instruction label
        instructionLabel = UILabel()
        instructionLabel.translatesAutoresizingMaskIntoConstraints = false
        instructionLabel.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        instructionLabel.textColor = .white
        instructionLabel.numberOfLines = 0
        instructionLabel.layer.cornerRadius = 8
        instructionLabel.clipsToBounds = true
        instructionLabel.textAlignment = .center
        instructionLabel.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        instructionLabel.text = "Point at a surface and tap + to start"
        view.addSubview(instructionLabel)
        
        // Measurement label
        measurementLabel = UILabel()
        measurementLabel.translatesAutoresizingMaskIntoConstraints = false
        measurementLabel.backgroundColor = UIColor.black.withAlphaComponent(0.8)
        measurementLabel.textColor = .white
        measurementLabel.textAlignment = .center
        measurementLabel.font = UIFont.systemFont(ofSize: 28, weight: .bold)
        measurementLabel.layer.cornerRadius = 12
        measurementLabel.clipsToBounds = true
        measurementLabel.isHidden = true
        view.addSubview(measurementLabel)
        
        // Record count label
        recordCountLabel = UILabel()
        recordCountLabel.translatesAutoresizingMaskIntoConstraints = false
        recordCountLabel.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.8)
        recordCountLabel.textColor = .white
        recordCountLabel.textAlignment = .center
        recordCountLabel.font = UIFont.systemFont(ofSize: 14, weight: .bold)
        recordCountLabel.layer.cornerRadius = 15
        recordCountLabel.clipsToBounds = true
        recordCountLabel.text = "Records: 0"
        view.addSubview(recordCountLabel)
        
        // Add button to add a new measurement point
        addButton = UIButton(type: .system)
        addButton.translatesAutoresizingMaskIntoConstraints = false
        addButton.backgroundColor = UIColor.systemYellow
        addButton.layer.cornerRadius = 35
        addButton.setTitle("+", for: .normal)
        addButton.setTitleColor(.black, for: .normal)
        addButton.titleLabel?.font = UIFont.systemFont(ofSize: 28, weight: .bold)
        addButton.addTarget(self, action: #selector(addPoint), for: .touchUpInside)
        addButton.layer.shadowColor = UIColor.black.cgColor
        addButton.layer.shadowOffset = CGSize(width: 0, height: 2)
        addButton.layer.shadowOpacity = 0.3
        addButton.layer.shadowRadius = 4
        view.addSubview(addButton)
        
        // Capture button
        captureButton = UIButton(type: .system)
        captureButton.translatesAutoresizingMaskIntoConstraints = false
        captureButton.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.9)
        captureButton.setTitleColor(.white, for: .normal)
        captureButton.layer.cornerRadius = 25
        captureButton.setTitle("📷", for: .normal)
        captureButton.titleLabel?.font = UIFont.systemFont(ofSize: 20)
        captureButton.addTarget(self, action: #selector(captureImage), for: .touchUpInside)
        captureButton.isHidden = true
        view.addSubview(captureButton)
        
        // Reset button
        resetButton = UIButton(type: .system)
        resetButton.translatesAutoresizingMaskIntoConstraints = false
        resetButton.backgroundColor = UIColor.systemRed.withAlphaComponent(0.9)
        resetButton.setTitleColor(.white, for: .normal)
        resetButton.layer.cornerRadius = 22
        resetButton.setTitle("Clear", for: .normal)
        resetButton.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .bold)
        resetButton.addTarget(self, action: #selector(resetMeasurement), for: .touchUpInside)
        view.addSubview(resetButton)
        
        // Export button
        exportButton = UIButton(type: .system)
        exportButton.translatesAutoresizingMaskIntoConstraints = false
        exportButton.backgroundColor = UIColor.systemGreen.withAlphaComponent(0.9)
        exportButton.setTitleColor(.white, for: .normal)
        exportButton.layer.cornerRadius = 22
        exportButton.setTitle("Export CSV", for: .normal)
        exportButton.titleLabel?.font = UIFont.systemFont(ofSize: 12, weight: .bold)
        exportButton.addTarget(self, action: #selector(exportToCSV), for: .touchUpInside)
        view.addSubview(exportButton)
        
        setupConstraints()
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // Status label
            statusLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            statusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            statusLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            statusLabel.heightAnchor.constraint(equalToConstant: 44),
            
            // Instruction label
            instructionLabel.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 10),
            instructionLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            instructionLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            // Record count label
            recordCountLabel.topAnchor.constraint(equalTo: instructionLabel.bottomAnchor, constant: 10),
            recordCountLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            recordCountLabel.widthAnchor.constraint(equalToConstant: 100),
            recordCountLabel.heightAnchor.constraint(equalToConstant: 30),
            
            // Measurement label
            measurementLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            measurementLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -80),
            measurementLabel.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 40),
            measurementLabel.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -40),
            measurementLabel.heightAnchor.constraint(equalToConstant: 60),
            
            // Add button
            addButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            addButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -40),
            addButton.widthAnchor.constraint(equalToConstant: 70),
            addButton.heightAnchor.constraint(equalToConstant: 70),
            
            // Capture button
            captureButton.trailingAnchor.constraint(equalTo: addButton.leadingAnchor, constant: -20),
            captureButton.centerYAnchor.constraint(equalTo: addButton.centerYAnchor),
            captureButton.widthAnchor.constraint(equalToConstant: 50),
            captureButton.heightAnchor.constraint(equalToConstant: 50),
            
            // Reset button
            resetButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            resetButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -60),
            resetButton.widthAnchor.constraint(equalToConstant: 70),
            resetButton.heightAnchor.constraint(equalToConstant: 44),
            
            // Export button
            exportButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            exportButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -60),
            exportButton.widthAnchor.constraint(equalToConstant: 90),
            exportButton.heightAnchor.constraint(equalToConstant: 44)
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
    
    // MARK: - Measurement Actions
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
            removeDynamicLine()
            calculateMeasurement()
            captureButton.isHidden = false
        }
        
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()
    }
    
    @objc private func captureImage() {
        // Capture the current AR scene
        currentMeasurementImage = sceneView.snapshot()
        
        // Save measurement to records
        guard measurementPoints.count == 2 else { return }
        
        let distance = simd_distance(measurementPoints[0], measurementPoints[1])
        let distanceInCm = distance * 100
        let distanceInFeet = Double(distance) * 3.28084
        let feet = Int(distanceInFeet)
        let inches = (distanceInFeet - Double(feet)) * 12
        let feetText = String(format: "%d' %.1f\"", feet, inches)
        
        // Save image to documents directory
        let imagePath = saveImageToDocuments(image: currentMeasurementImage!)
        
        let record = MeasurementRecord(
            heightCM: distanceInCm,
            heightFeet: feetText,
            imagePath: imagePath
        )
        
        measurementRecords.append(record)
        updateRecordCountLabel()
        
        showFeedback("Measurement saved! (\(measurementRecords.count) total)", isError: false)
        
        // Auto-reset for next measurement
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            self.resetMeasurement()
        }
        
        let success = UINotificationFeedbackGenerator()
        success.notificationOccurred(.success)
    }
    
    @objc private func exportToCSV() {
        guard !measurementRecords.isEmpty else {
            showFeedback("No measurements to export", isError: true)
            return
        }
        
        let csvContent = generateCSVContent()
        let fileName = "height_measurements_\(DateFormatter.filenameDateFormatter.string(from: Date())).csv"
        
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        
        do {
            try csvContent.write(to: tempURL, atomically: true, encoding: .utf8)
            
            let activityVC = UIActivityViewController(activityItems: [tempURL], applicationActivities: nil)
            activityVC.popoverPresentationController?.sourceView = exportButton
            present(activityVC, animated: true)
            
            showFeedback("CSV exported successfully", isError: false)
        } catch {
            showFeedback("Export failed: \(error.localizedDescription)", isError: true)
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
        
        removeDynamicLine()
        
        measurementLabel.isHidden = true
        captureButton.isHidden = true
        currentMeasurementImage = nil
        
        updateInstructions()
        
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()
    }
    
    // MARK: - Point and Line Creation
    private func createPointNode(at position: simd_float3, index: Int) -> SCNNode {
        // Main point sphere
        let sphere = SCNSphere(radius: 0.008)
        sphere.firstMaterial?.diffuse.contents = UIColor.white
        sphere.firstMaterial?.emission.contents = UIColor.white
        sphere.firstMaterial?.lightingModel = .constant
        
        let pointNode = SCNNode(geometry: sphere)
        pointNode.simdPosition = position
        
        // Outer ring
        let ring = SCNTorus(ringRadius: 0.025, pipeRadius: 0.003)
        ring.firstMaterial?.diffuse.contents = UIColor.white.withAlphaComponent(0.9)
        ring.firstMaterial?.lightingModel = .constant
        
        let ringNode = SCNNode(geometry: ring)
        pointNode.addChildNode(ringNode)
        
        let scaleAction = SCNAction.sequence([
            SCNAction.scale(to: 1.2, duration: 0.3),
            SCNAction.scale(to: 1.0, duration: 0.3)
        ])
        pointNode.runAction(scaleAction)
        
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
        let displayText = String(format: "%.0f cm", distanceInCm)
        
        let textGeometry = SCNText(string: displayText, extrusionDepth: 0)
        textGeometry.font = UIFont.systemFont(ofSize: 10, weight: .bold)
        textGeometry.firstMaterial?.diffuse.contents = UIColor.white
        textGeometry.firstMaterial?.emission.contents = UIColor.white
        textGeometry.firstMaterial?.lightingModel = .constant
        textGeometry.alignmentMode = CATextLayerAlignmentMode.center.rawValue
        
        textNode = SCNNode(geometry: textGeometry)
        textNode!.simdPosition = midPoint + simd_float3(0, 0.05, 0)
        textNode!.scale = SCNVector3(0.008, 0.008, 0.008)
        
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
            self.measurementLabel.text = "  \(cmText)  "
            self.measurementLabel.isHidden = false
        }
        
        showFeedback("Height: \(cmText) (\(feetText)) - Tap 📷 to save", isError: false)
    }
    
    private func updateInstructions() {
        DispatchQueue.main.async {
            switch self.measurementPoints.count {
            case 0:
                self.instructionLabel.text = "Point at person's feet and tap +"
            case 1:
                self.instructionLabel.text = "Now point at person's head and tap +"
            default:
                self.instructionLabel.text = "Tap 📷 to save measurement"
            }
        }
    }
    
    private func updateRecordCountLabel() {
        DispatchQueue.main.async {
            self.recordCountLabel.text = "Records: \(self.measurementRecords.count)"
        }
    }
    
    // MARK: - File Management
    private func saveImageToDocuments(image: UIImage) -> String? {
        guard let data = image.jpegData(compressionQuality: 0.8) else { return nil }
        
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileName = "measurement_\(UUID().uuidString).jpg"
        let fileURL = documentsDirectory.appendingPathComponent(fileName)
        
        do {
            try data.write(to: fileURL)
            return fileName
        } catch {
            print("Failed to save image: \(error)")
            return nil
        }
    }
    
    private func generateCSVContent() -> String {
        var csv = "Timestamp,Height_CM,Height_Feet_Inches,Image_Filename,Notes\n"
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        
        for record in measurementRecords {
            let timestamp = dateFormatter.string(from: record.timestamp)
            let heightCM = String(format: "%.1f", record.heightCM)
            let heightFeet = record.heightFeet
            let imagePath = record.imagePath ?? ""
            let notes = record.notes ?? ""
            
            csv += "\"\(timestamp)\",\(heightCM),\"\(heightFeet)\",\"\(imagePath)\",\"\(notes)\"\n"
        }
        
        return csv
    }
    
    private func showFeedback(_ message: String, isError: Bool) {
        DispatchQueue.main.async {
            self.statusLabel.text = message
            self.statusLabel.backgroundColor = isError ?
                UIColor.systemRed.withAlphaComponent(0.8) :
                UIColor.systemGreen.withAlphaComponent(0.8)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                self.statusLabel.backgroundColor = UIColor.black.withAlphaComponent(0.7)
                if self.currentPlaneAnchors.isEmpty {
                    self.statusLabel.text = "Move to find surfaces"
                } else {
                    self.statusLabel.text = "Surface detected - ready to measure"
                }
            }
        }
    }
}

// MARK: - SceneKit Renderer Delegate
extension ViewController {
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        DispatchQueue.main.async {
            self.updateCrosshair()
        }
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        guard let planeAnchor = anchor as? ARPlaneAnchor else { return }
        
        currentPlaneAnchors.append(planeAnchor)
        
        DispatchQueue.main.async {
            self.statusLabel.text = "Surface detected - ready to measure"
            self.statusLabel.backgroundColor = UIColor.systemGreen.withAlphaComponent(0.7)
        }
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didRemove node: SCNNode, for anchor: ARAnchor) {
        if let planeAnchor = anchor as? ARPlaneAnchor,
           let index = currentPlaneAnchors.firstIndex(of: planeAnchor) {
            currentPlaneAnchors.remove(at: index)
        }
    }
}

// MARK: - AR Session Delegate
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
                self.statusLabel.backgroundColor = UIColor.systemOrange.withAlphaComponent(0.7)
            case .notAvailable:
                self.statusLabel.text = "AR not available"
                self.statusLabel.backgroundColor = UIColor.systemRed.withAlphaComponent(0.7)
            }
        }
    }
}

// MARK: - Extensions
extension DateFormatter {
    static let filenameDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        return formatter
    }()
}
