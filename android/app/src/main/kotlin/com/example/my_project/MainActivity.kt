package com.mycompany.elevenlabsconversationalaiv2

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import android.media.audiofx.AcousticEchoCanceler
import android.media.AudioRecord
import android.media.AudioManager
import android.content.Context

class MainActivity: FlutterActivity() {
    private var aec: AcousticEchoCanceler? = null
    
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Enable platform-level echo cancellation for conversational AI
        try {
            // Set audio mode for communication
            val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
            audioManager.mode = AudioManager.MODE_IN_COMMUNICATION
            
            // Create a temporary AudioRecord to get session ID
            val sampleRate = 16000
            val channelConfig = android.media.AudioFormat.CHANNEL_IN_MONO
            val audioFormat = android.media.AudioFormat.ENCODING_PCM_16BIT
            val bufferSize = AudioRecord.getMinBufferSize(sampleRate, channelConfig, audioFormat)
            
            if (bufferSize != AudioRecord.ERROR_BAD_VALUE) {
                val recorder = AudioRecord.Builder()
                    .setAudioSource(android.media.MediaRecorder.AudioSource.VOICE_COMMUNICATION)
                    .setAudioFormat(
                        android.media.AudioFormat.Builder()
                            .setEncoding(audioFormat)
                            .setSampleRate(sampleRate)
                            .setChannelMask(channelConfig)
                            .build()
                    )
                    .setBufferSizeInBytes(bufferSize)
                    .build()
                
                // Enable Acoustic Echo Canceler if available
                if (AcousticEchoCanceler.isAvailable()) {
                    aec = AcousticEchoCanceler.create(recorder.audioSessionId)
                    aec?.enabled = true
                    println("✅ Android AEC enabled for session: ${recorder.audioSessionId}")
                } else {
                    println("⚠️ Android AEC not available on this device")
                }
                
                // Clean up the temporary recorder
                recorder.release()
            }
        } catch (e: Exception) {
            println("❌ Error setting up Android AEC: ${e.message}")
        }
    }
    
    override fun onDestroy() {
        // Clean up AEC when activity is destroyed
        aec?.release()
        super.onDestroy()
    }
}
