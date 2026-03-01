#if os(iOS)
import Foundation
import Speech
import AVFoundation
import Combine

@MainActor
final class SpeechRecognizer: NSObject, ObservableObject {
    @Published var transcript = ""
    @Published var isRecording = false
    @Published var errorMessage: String?
    
    private let audioEngine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private let recognizer = SFSpeechRecognizer(locale: .autoupdatingCurrent)
    
    override init() {
        super.init()
        SFSpeechRecognizer.requestAuthorization { _ in }
    }
    
    deinit {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        task?.cancel()
    }
    
    func start() {
        guard !isRecording, let recognizer, recognizer.isAvailable else { return }
        
        transcript = ""
        isRecording = true
        
        request = SFSpeechAudioBufferRecognitionRequest()
        request?.shouldReportPartialResults = true
        
        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        
        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.request?.append(buffer)
        }
        
        do {
            try AVAudioSession.sharedInstance().setCategory(.record, mode: .measurement, options: .duckOthers)
            try AVAudioSession.sharedInstance().setActive(true)
            audioEngine.prepare()
            try audioEngine.start()
        } catch {
            errorMessage = "Ошибка аудио: \(error.localizedDescription)"
            stop()
            return
        }
        
        task = recognizer.recognitionTask(with: request!) { [weak self] result, error in
            guard let self else { return }
            if let result {
                Task { @MainActor in
                    self.transcript = result.bestTranscription.formattedString
                    if result.isFinal { self.stop() }
                }
            }
            if error != nil {
                Task { @MainActor in self.stop() }
            }
        }
    }
    
    func stop() {
        guard isRecording else { return }
        isRecording = false
        
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        task?.cancel()
        request = nil
        task = nil
        
        try? AVAudioSession.sharedInstance().setActive(false)
    }
}
#endif
