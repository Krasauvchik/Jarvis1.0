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
    @Published var audioLevels: [CGFloat] = Array(repeating: 0, count: 20)
    
    private let audioEngine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private lazy var recognizer: SFSpeechRecognizer? = SFSpeechRecognizer(locale: SpeechRecognizer.speechLocale)
    private let levelHistoryCount = 20
    
    /// Timer that fires when user stops speaking (silence detection)
    private var silenceTimer: Timer?
    private let silenceTimeout: TimeInterval = 1.8
    
    /// Returns the locale matching the app's language setting (ru → ru-RU, en → en-US)
    nonisolated static var speechLocale: Locale {
        let lang = UserDefaults.standard.string(forKey: "jarvis_language") ?? "ru"
        switch lang {
        case "en": return Locale(identifier: "en-US")
        default:   return Locale(identifier: "ru-RU")
        }
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
        audioLevels = Array(repeating: 0, count: levelHistoryCount)
        
        request = SFSpeechAudioBufferRecognitionRequest()
        request?.shouldReportPartialResults = true
        
        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        
        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.request?.append(buffer)
            self?.processAudioLevel(buffer: buffer)
        }
        
        do {
            try AVAudioSession.sharedInstance().setCategory(.record, mode: .measurement, options: .duckOthers)
            try AVAudioSession.sharedInstance().setActive(true)
            audioEngine.prepare()
            try audioEngine.start()
        } catch {
            errorMessage = "\(L10n.speechAudioError): \(error.localizedDescription)"
            stop()
            return
        }
        
        guard let request else {
            stop()
            return
        }
        
        task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }
            if let result {
                Task { @MainActor in
                    self.transcript = result.bestTranscription.formattedString
                    self.resetSilenceTimer()
                    if result.isFinal { self.stop() }
                }
            }
            if let error {
                let nsError = error as NSError
                // Не останавливаем на "No speech detected" — перезапускаем
                if nsError.domain == "kAFAssistantErrorDomain" && nsError.code == 1110 {
                    // 1110 = no speech detected — просто тишина, перезапустим
                    Task { @MainActor in
                        if self.isRecording {
                            self.restartRecognition()
                        }
                    }
                } else {
                    Task { @MainActor in
                        self.errorMessage = "Ошибка: \(error.localizedDescription)"
                        self.stop()
                    }
                }
            }
        }
    }
    
    /// Resets silence timer — called each time new speech is recognized
    private func resetSilenceTimer() {
        silenceTimer?.invalidate()
        guard isRecording, !transcript.isEmpty else { return }
        silenceTimer = Timer.scheduledTimer(withTimeInterval: silenceTimeout, repeats: false) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.isRecording, !self.transcript.isEmpty else { return }
                self.stop()
            }
        }
    }
    
    /// Перезапускает распознавание без остановки аудио (silent restart)
    private func restartRecognition() {
        guard isRecording, let recognizer, recognizer.isAvailable else { return }
        
        // Останавливаем только таск распознавания, аудио продолжает идти
        request?.endAudio()
        task?.cancel()
        
        request = SFSpeechAudioBufferRecognitionRequest()
        request?.shouldReportPartialResults = true
        
        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.request?.append(buffer)
            self?.processAudioLevel(buffer: buffer)
        }
        
        guard let request else { return }
        task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }
            if let result {
                Task { @MainActor in
                    self.transcript = result.bestTranscription.formattedString
                    self.resetSilenceTimer()
                    if result.isFinal { self.stop() }
                }
            }
            if let error {
                let nsError = error as NSError
                if nsError.domain == "kAFAssistantErrorDomain" && nsError.code == 1110 {
                    Task { @MainActor in
                        if self.isRecording { self.restartRecognition() }
                    }
                } else {
                    Task { @MainActor in
                        self.errorMessage = "Ошибка: \(error.localizedDescription)"
                        self.stop()
                    }
                }
            }
        }
    }
    
    func stop() {
        guard isRecording else { return }
        isRecording = false
        silenceTimer?.invalidate()
        silenceTimer = nil
        
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        // Let the recognizer deliver the final result instead of cancelling immediately
        let capturedTask = task
        let capturedRequest = request
        task = nil
        request = nil
        audioLevels = Array(repeating: 0, count: levelHistoryCount)
        
        // Clean up after giving the recognizer time to finalize
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            capturedTask?.cancel()
            _ = capturedRequest  // prevent premature dealloc
        }
        
        try? AVAudioSession.sharedInstance().setActive(false)
    }
    
    private func processAudioLevel(buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0] else { return }
        let frameLength = Int(buffer.frameLength)
        guard frameLength > 0 else { return }
        
        var sum: Float = 0
        for i in 0..<frameLength {
            sum += channelData[i] * channelData[i]
        }
        let rms = sqrt(sum / Float(frameLength))
        // Normalize: typical speech RMS is 0.01-0.3
        let normalized = CGFloat(min(rms * 5.0, 1.0))
        
        Task { @MainActor in
            self.audioLevels.append(normalized)
            if self.audioLevels.count > self.levelHistoryCount {
                self.audioLevels.removeFirst(self.audioLevels.count - self.levelHistoryCount)
            }
        }
    }
}

#elseif os(macOS)
import Foundation
import Speech
import Combine

@MainActor
final class SpeechRecognizer: NSObject, ObservableObject {
    @Published var transcript = ""
    @Published var isRecording = false
    @Published var errorMessage: String?
    @Published var audioLevels: [CGFloat] = Array(repeating: 0, count: 20)
    
    // IMPORTANT: AVAudioEngine must NOT be created eagerly — accessing inputNode
    // triggers a TCC microphone check that kills the app if permission isn't granted yet.
    private var audioEngine: AVAudioEngine?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var recognizer: SFSpeechRecognizer?
    private let levelHistoryCount = 20
    
    /// Timer that fires when user stops speaking (silence detection)
    private var silenceTimer: Timer?
    private let silenceTimeout: TimeInterval = 1.8
    
    /// Returns the locale matching the app's language setting (ru → ru-RU, en → en-US)
    nonisolated static var speechLocale: Locale {
        let lang = UserDefaults.standard.string(forKey: "jarvis_language") ?? "ru"
        switch lang {
        case "en": return Locale(identifier: "en-US")
        default:   return Locale(identifier: "ru-RU")
        }
    }
    
    deinit {
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        task?.cancel()
    }
    
    func start() {
        guard !isRecording else { return }
        
        // On macOS, do NOT call SFSpeechRecognizer.requestAuthorization —
        // it triggers a TCC check that kills ad-hoc signed apps.
        // Instead, just try to use the recognizer; macOS will show its own prompt.
        
        // Create recognizer and audio engine on demand
        if recognizer == nil {
            recognizer = SFSpeechRecognizer(locale: SpeechRecognizer.speechLocale)
        }
        
        guard let recognizer, recognizer.isAvailable else {
            errorMessage = "Распознавание речи недоступно. Проверьте Системные настройки → Конфиденциальность → Распознавание речи"
            return
        }
        
        if audioEngine == nil {
            audioEngine = AVAudioEngine()
        }
        guard let audioEngine else { return }
        
        transcript = ""
        isRecording = true
        errorMessage = nil
        audioLevels = Array(repeating: 0, count: levelHistoryCount)
        
        request = SFSpeechAudioBufferRecognitionRequest()
        request?.shouldReportPartialResults = true
        
        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        
        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.request?.append(buffer)
            self?.processAudioLevel(buffer: buffer)
        }
        
        do {
            audioEngine.prepare()
            try audioEngine.start()
        } catch {
            errorMessage = "\(L10n.speechAudioError): \(error.localizedDescription)"
            stop()
            return
        }
        
        guard let request else {
            stop()
            return
        }
        
        task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }
            if let result {
                Task { @MainActor in
                    self.transcript = result.bestTranscription.formattedString
                    self.resetSilenceTimer()
                    if result.isFinal { self.stop() }
                }
            }
            if let error {
                let nsError = error as NSError
                if nsError.domain == "kAFAssistantErrorDomain" && nsError.code == 1110 {
                    Task { @MainActor in
                        if self.isRecording { self.restartRecognition() }
                    }
                } else {
                    Task { @MainActor in
                        self.errorMessage = "Ошибка: \(error.localizedDescription)"
                        self.stop()
                    }
                }
            }
        }
    }
    
    /// Resets silence timer — called each time new speech is recognized
    private func resetSilenceTimer() {
        silenceTimer?.invalidate()
        guard isRecording, !transcript.isEmpty else { return }
        silenceTimer = Timer.scheduledTimer(withTimeInterval: silenceTimeout, repeats: false) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.isRecording, !self.transcript.isEmpty else { return }
                self.stop()
            }
        }
    }
    
    /// Перезапускает распознавание без остановки аудио (silent restart при тишине)
    private func restartRecognition() {
        guard isRecording, let recognizer, recognizer.isAvailable, let audioEngine else { return }
        
        request?.endAudio()
        task?.cancel()
        
        request = SFSpeechAudioBufferRecognitionRequest()
        request?.shouldReportPartialResults = true
        
        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.request?.append(buffer)
            self?.processAudioLevel(buffer: buffer)
        }
        
        guard let request else { return }
        task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }
            if let result {
                Task { @MainActor in
                    self.transcript = result.bestTranscription.formattedString
                    self.resetSilenceTimer()
                    if result.isFinal { self.stop() }
                }
            }
            if let error {
                let nsError = error as NSError
                if nsError.domain == "kAFAssistantErrorDomain" && nsError.code == 1110 {
                    Task { @MainActor in
                        if self.isRecording { self.restartRecognition() }
                    }
                } else {
                    Task { @MainActor in
                        self.errorMessage = "Ошибка: \(error.localizedDescription)"
                        self.stop()
                    }
                }
            }
        }
    }
    
    func stop() {
        guard isRecording else { return }
        isRecording = false
        silenceTimer?.invalidate()
        silenceTimer = nil
        
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        let capturedTask = task
        let capturedRequest = request
        task = nil
        request = nil
        audioLevels = Array(repeating: 0, count: levelHistoryCount)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            capturedTask?.cancel()
            _ = capturedRequest
        }
    }
    
    private func processAudioLevel(buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0] else { return }
        let frameLength = Int(buffer.frameLength)
        guard frameLength > 0 else { return }
        
        var sum: Float = 0
        for i in 0..<frameLength {
            sum += channelData[i] * channelData[i]
        }
        let rms = sqrt(sum / Float(frameLength))
        let normalized = CGFloat(min(rms * 5.0, 1.0))
        
        Task { @MainActor in
            self.audioLevels.append(normalized)
            if self.audioLevels.count > self.levelHistoryCount {
                self.audioLevels.removeFirst(self.audioLevels.count - self.levelHistoryCount)
            }
        }
    }
}
#endif
