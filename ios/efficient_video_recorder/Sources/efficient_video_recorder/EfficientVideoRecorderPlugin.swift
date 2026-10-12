import Flutter
import UIKit
import AVFoundation

public class EfficientVideoRecorderPlugin: NSObject, FlutterPlugin, FlutterStreamHandler, AVCaptureFileOutputRecordingDelegate {

    private var methodChannel: FlutterMethodChannel?
    private var eventChannel: FlutterEventChannel?
    private var eventSink: FlutterEventSink?

    private var captureSession: AVCaptureSession?
    private var movieFileOutput: AVCaptureMovieFileOutput?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var isRecording = false
    private var pendingStopResult: FlutterResult?
    private var targetOutputFile: URL?

    public static func register(with registrar: FlutterPluginRegistrar) {
        let methodChannel = FlutterMethodChannel(
            name: "org.evergreenlabs.efficient_video_recorder/methods",
            binaryMessenger: registrar.messenger()
        )
        let eventChannel = FlutterEventChannel(
            name: "org.evergreenlabs.efficient_video_recorder/events",
            binaryMessenger: registrar.messenger()
        )
        let instance = EfficientVideoRecorderPlugin()
        instance.methodChannel = methodChannel
        instance.eventChannel = eventChannel

        registrar.addMethodCallDelegate(instance, channel: methodChannel)
        eventChannel.setStreamHandler(instance)

        let factory = IOSRecorderPreviewViewFactory(plugin: instance)
        registrar.register(factory, withId: "org.evergreenlabs.efficient_video_recorder/preview")
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "initialize":
            let args = call.arguments as? [String: Any]
            let quality = args?["quality"] as? String ?? "sd"
            let facing = args?["facing"] as? String ?? "back"
            let fps = args?["fps"] as? Int ?? 24
            setupSession(quality: quality, facing: facing, fps: fps, result: result)

        case "startRecording":
            guard let args = call.arguments as? [String: Any],
                  let path = args["path"] as? String else {
                result(FlutterError(code: "INVALID_ARG", message: "Path is required", details: nil))
                return
            }
            startRecording(path: path, result: result)

        case "stopRecording":
            stopRecording(result: result)

        case "setQuality":
            result(true)

        case "setTargetRotation":
            result(true)

        case "pause":
            captureSession?.stopRunning()
            result(true)

        case "resume":
            if let session = captureSession, !session.isRunning {
                DispatchQueue.global(qos: .userInitiated).async {
                    session.startRunning()
                }
            }
            result(true)

        case "isRecording":
            result(isRecording)

        case "isInitialized":
            result(captureSession != nil)

        case "dispose":
            tearDownSession()
            result(true)

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func setupSession(quality: String, facing: String, fps: Int, result: @escaping FlutterResult) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            let session = AVCaptureSession()
            session.beginConfiguration()

            switch quality.lowercased() {
            case "fhd":
                session.sessionPreset = .hd1920x1080
            case "hd":
                session.sessionPreset = .hd1280x720
            default:
                session.sessionPreset = .vga640x480
            }

            let position: AVCaptureDevice.Position = (facing == "front") ? .front : .back
            guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position),
                  let videoInput = try? AVCaptureDeviceInput(device: device),
                  session.canAddInput(videoInput) else {
                DispatchQueue.main.async {
                    result(FlutterError(code: "INIT_FAILED", message: "Cannot access camera device", details: nil))
                }
                return
            }

            session.addInput(videoInput)

            // Limit FPS to 24 if supported
            if fps > 0 {
                do {
                    try device.lockForConfiguration()
                    let duration = CMTime(value: 1, timescale: Int32(fps))
                    device.activeVideoMinFrameDuration = duration
                    device.activeVideoMaxFrameDuration = duration
                    device.unlockForConfiguration()
                } catch {}
            }

            let output = AVCaptureMovieFileOutput()
            if session.canAddOutput(output) {
                session.addOutput(output)
            }

            session.commitConfiguration()
            session.startRunning()

            DispatchQueue.main.async {
                self.captureSession = session
                self.movieFileOutput = output
                result(true)
            }
        }
    }

    private func startRecording(path: String, result: @escaping FlutterResult) {
        guard let output = movieFileOutput else {
            result(FlutterError(code: "NOT_INITIALIZED", message: "Recorder not initialized", details: nil))
            return
        }

        let fileUrl = URL(fileURLWithPath: path)
        try? FileManager.default.removeItem(at: fileUrl)
        self.targetOutputFile = fileUrl

        output.startRecording(to: fileUrl, recordingDelegate: self)
        isRecording = true
        result(true)
    }

    private func stopRecording(result: @escaping FlutterResult) {
        guard isRecording, let output = movieFileOutput else {
            result(nil)
            return
        }

        self.pendingStopResult = result
        output.stopRecording()
    }

    public func fileOutput(_ output: AVCaptureFileOutput, didStartRecordingTo fileURL: URL, from connections: [AVCaptureConnection]) {
        eventSink?([
            "event": "started",
            "path": fileURL.path
        ])
    }

    public func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        isRecording = false
        let stopResult = pendingStopResult
        pendingStopResult = nil

        if let err = error {
            eventSink?([
                "event": "error",
                "error": err.localizedDescription
            ])
            stopResult?(FlutterError(code: "RECORDING_ERROR", message: err.localizedDescription, details: nil))
        } else {
            eventSink?([
                "event": "finalized",
                "path": outputFileURL.path
            ])
            stopResult?(outputFileURL.path)
        }
    }

    private func tearDownSession() {
        captureSession?.stopRunning()
        captureSession = nil
        movieFileOutput = nil
        previewLayer = nil
        isRecording = false
        pendingStopResult = nil
    }

    public func attachPreviewLayer(to view: UIView) {
        guard let session = captureSession else { return }
        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        layer.frame = view.bounds
        view.layer.addSublayer(layer)
        self.previewLayer = layer
    }

    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events
        return nil
    }

    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        self.eventSink = nil
        return nil
    }
}

class IOSRecorderPreviewViewFactory: NSObject, FlutterPlatformViewFactory {
    private weak var plugin: EfficientVideoRecorderPlugin?

    init(plugin: EfficientVideoRecorderPlugin) {
        self.plugin = plugin
        super.init()
    }

    func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?) -> FlutterPlatformView {
        return IOSRecorderPlatformView(frame: frame, plugin: plugin)
    }
}

class IOSRecorderPlatformView: NSObject, FlutterPlatformView {
    private let containerView: UIView

    init(frame: CGRect, plugin: EfficientVideoRecorderPlugin?) {
        self.containerView = UIView(frame: frame)
        super.init()
        plugin?.attachPreviewLayer(to: containerView)
    }

    func view() -> UIView {
        return containerView
    }
}
