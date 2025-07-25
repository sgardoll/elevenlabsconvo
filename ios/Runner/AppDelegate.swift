import UIKit
import Flutter
import AVFoundation

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    
    // Configure AVAudioSession for conversational AI with echo cancellation
    do {
        let session = AVAudioSession.sharedInstance()
        
        // Set category to playAndRecord with voiceChat mode for optimal echo cancellation
        try session.setCategory(.playAndRecord,
                               mode: .voiceChat,
                               options: [.allowBluetoothA2DP, .defaultToSpeaker])
        
        // Set preferred sample rate to 16kHz (matches ElevenLabs requirements)
        try session.setPreferredSampleRate(16000)
        
        // Set preferred buffer duration for low latency
        try session.setPreferredIOBufferDuration(0.005) // 5ms buffer
        
        // Activate the audio session
        try session.setActive(true)
        
        print("✅ iOS AVAudioSession configured for conversational AI with echo cancellation")
        print("  Category: .playAndRecord")
        print("  Mode: .voiceChat")
        print("  Sample Rate: 16kHz")
        print("  Buffer Duration: 5ms")
        
    } catch {
        print("❌ Failed to set up iOS audio session for echo cancellation: \(error)")
    }
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
