import SwiftUI
import AVFoundation

struct CameraPreviewView: UIViewRepresentable {
    
    let session: AVCaptureSession
    let detectedObjects: [DetectedObject]
    
    func makeUIView(context: Context) -> CameraPreviewUIView {
        let view = CameraPreviewUIView()
        view.session = session
        return view
    }
    
    func updateUIView(_ uiView: CameraPreviewUIView, context: Context) {
        uiView.updateDetections(detectedObjects)
    }
}


final class CameraPreviewUIView: UIView {
    
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private let overlayLayer = CAShapeLayer()
    private var labelLayers: [CATextLayer] = []
    var session: AVCaptureSession? {
        didSet {
            setupPreviewLayer()
        }
    }
    
    
    private func setupPreviewLayer() {
        guard let session = session else { return }
        
        previewLayer?.removeFromSuperlayer()
        
        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.videoGravity = .resizeAspectFill
        preview.frame = bounds
        layer.addSublayer(preview)
        previewLayer = preview
        
        overlayLayer.frame = bounds
        overlayLayer.strokeColor = UIColor.systemYellow.cgColor
        overlayLayer.fillColor = UIColor.clear.cgColor
        overlayLayer.lineWidth = 3
        layer.addSublayer(overlayLayer)
        
        isAccessibilityElement = true
        accessibilityLabel = "Vista de cámara"
        accessibilityHint = "Muestra lo que la cámara está capturando"
        accessibilityTraits = .image
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        previewLayer?.frame = bounds
        overlayLayer.frame = bounds
    }
    
    
    func updateDetections(_ objects: [DetectedObject]) {
        labelLayers.forEach { $0.removeFromSuperlayer() }
        labelLayers.removeAll()
        
        let path = CGMutablePath()
        
        for object in objects {
            let rect = CGRect(
                x: object.boundingBox.origin.x * bounds.width,
                y: object.boundingBox.origin.y * bounds.height,
                width: object.boundingBox.width * bounds.width,
                height: object.boundingBox.height * bounds.height
            )
            
            path.addRect(rect)
            
            let textLayer = CATextLayer()
            textLayer.string = "\(object.label) (\(Int(object.confidence * 100))%)"
            textLayer.fontSize = 14
            textLayer.foregroundColor = UIColor.white.cgColor
            textLayer.backgroundColor = UIColor.black.withAlphaComponent(0.7).cgColor
            textLayer.cornerRadius = 4
            textLayer.alignmentMode = .center
            textLayer.contentsScale = UIScreen.main.scale
            
            let textSize = CGSize(width: max(rect.width, 100), height: 22)
            textLayer.frame = CGRect(
                x: rect.origin.x,
                y: max(0, rect.origin.y - 24),
                width: textSize.width,
                height: textSize.height
            )
            
            layer.addSublayer(textLayer)
            labelLayers.append(textLayer)
        }
        
        overlayLayer.path = path
        
        if !objects.isEmpty {
            let descriptions = objects.map { $0.spokenDescription }
            accessibilityValue = "Objetos detectados: \(descriptions.joined(separator: ". "))"
        } else {
            accessibilityValue = "No se detectan objetos"
        }
    }
}
