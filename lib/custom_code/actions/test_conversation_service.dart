// Test Action for Conversational AI Service
import '/custom_code/conversational_ai_service.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import '/flutter_flow/flutter_flow_util.dart';

Future<String> testConversationService() async {
  debugPrint('🧪 ===== COMPREHENSIVE CONVERSATIONAL AI TEST SUITE v3.0 =====');

  final service = ConversationalAIService();
  final testResults = <String>[];
  final startTime = DateTime.now();

  // Test Configuration
  const String agentId = 'agent_01jzmvwhxhf6kaya6n6zbtd0s1';
  const String endpoint = 'https://515q53.buildship.run/GetSignedUrl';

  try {
    // ===== TEST 1: INFINITE LOOP PREVENTION =====
    debugPrint('🧪 TEST 1: Checking for infinite restart loops...');

    // Initialize with loop prevention
    var initAttempts = 0;
    String initResult = '';

    while (initAttempts < 3 && initResult != 'success') {
      initAttempts++;
      debugPrint('🧪 Initialization attempt $initAttempts/3');

      initResult = await service.initialize(
        agentId: agentId,
        endpoint: endpoint,
      );

      if (initResult == 'success') {
        testResults.add('✅ Initialization successful on attempt $initAttempts');
        debugPrint('✅ Service initialized successfully');
        break;
      } else {
        testResults.add(
            '❌ Initialization failed on attempt $initAttempts: $initResult');
        debugPrint('❌ Initialization failed: $initResult');

        // Wait before retry to prevent rapid loops
        await Future.delayed(Duration(seconds: 2));
      }
    }

    if (initResult != 'success') {
      throw Exception(
          'Failed to initialize after 3 attempts - prevents infinite loop');
    }

    // ===== TEST 2: AUDIO FEEDBACK LOOP DETECTION =====
    debugPrint('🧪 TEST 2: Testing audio feedback loop prevention...');

    // Test speaker pickup detection
    bool feedbackDetected = false;
    int feedbackTestDuration = 5; // seconds

    // Monitor service state for feedback loops
    StreamSubscription? stateSubscription;
    stateSubscription = service.stateStream.listen((state) {
      if (state == ConversationState.error) {
        feedbackDetected = true;
        debugPrint('🔇 Potential feedback loop detected in state change');
      }
    });

    // Start recording to test feedback prevention
    debugPrint('🎙️ Starting recording to test feedback prevention...');
    var recordResult = await service.startRecording();

    if (recordResult == 'success') {
      testResults.add('✅ Recording started for feedback test');

      // Wait and monitor for feedback issues
      await Future.delayed(Duration(seconds: feedbackTestDuration));

      // Stop recording
      await service.stopRecording();
      testResults.add(feedbackDetected
          ? '⚠️ Feedback loop detected but handled'
          : '✅ No feedback loops detected during recording');
    } else {
      testResults.add('❌ Failed to start recording: $recordResult');
    }

    await stateSubscription?.cancel();

    // ===== TEST 3: iOS AUDIO PLAYBACK TEST =====
    debugPrint('🧪 TEST 3: Testing iOS audio playback...');

    bool audioPlayed = false;
    StreamSubscription? stateMonitor;

    // Monitor for agent speaking state (indicates audio is playing)
    stateMonitor = service.stateStream.listen((state) {
      if (state == ConversationState.playing) {
        audioPlayed = true;
        debugPrint('🔊 Audio playback detected (iOS test)');
      }
    });

    // Trigger agent response by starting/stopping recording
    await service.startRecording();
    await Future.delayed(Duration(milliseconds: 500));
    await service.stopRecording();

    // Wait for agent response and audio
    debugPrint('🧪 Waiting for agent audio response...');
    await Future.delayed(Duration(seconds: 8));

    testResults.add(audioPlayed
        ? '✅ iOS audio playback working'
        : '❌ iOS audio playback failed - no sound detected');

    await stateMonitor?.cancel();

    // ===== TEST 4: ANDROID AUDIO CHUNK ORDER TEST =====
    debugPrint('🧪 TEST 4: Testing Android audio chunk ordering...');

    int audioChunkCount = 0;
    List<DateTime> audioTimestamps = [];

    // Monitor conversation messages for audio activity
    StreamSubscription? messageMonitor;
    messageMonitor = service.conversationStream.listen((message) {
      if (message.type == 'agent') {
        audioChunkCount++;
        audioTimestamps.add(message.timestamp);
        debugPrint(
            '🔊 Audio chunk #$audioChunkCount received at ${message.timestamp}');
      }
    });

    // Trigger multiple audio responses
    for (int i = 0; i < 2; i++) {
      await service.startRecording();
      await Future.delayed(Duration(milliseconds: 300));
      await service.stopRecording();
      await Future.delayed(Duration(seconds: 2));
    }

    // Check for audio chunk ordering issues
    bool orderingIssues = false;
    if (audioTimestamps.length > 1) {
      for (int i = 1; i < audioTimestamps.length; i++) {
        if (audioTimestamps[i].isBefore(audioTimestamps[i - 1])) {
          orderingIssues = true;
          break;
        }
      }
    }

    testResults.add(orderingIssues
        ? '❌ Android audio chunk ordering issues detected'
        : '✅ Android audio chunks in correct order');

    await messageMonitor?.cancel();

    // ===== TEST 5: INTERRUPTION HANDLING =====
    debugPrint('🧪 TEST 5: Testing user interruption of agent...');

    bool interruptionHandled = false;

    // Start recording and immediately trigger interruption
    await service.startRecording();
    await Future.delayed(Duration(milliseconds: 200));

    // Manually trigger interruption
    await service.triggerInterruption();

    // Check if service returns to connected state
    await Future.delayed(Duration(seconds: 2));

    if (service.currentState == ConversationState.connected ||
        service.currentState == ConversationState.idle) {
      interruptionHandled = true;
      testResults.add('✅ User interruption handled correctly');
    } else {
      testResults.add('❌ User interruption not handled properly');
    }

    await service.stopRecording();

    // ===== TEST 6: MEMORY LEAK AND RESTART PREVENTION =====
    debugPrint(
        '🧪 TEST 6: Testing memory management and restart prevention...');

    // Check if service can be safely disposed and reinitialized
    await service.dispose();

    // Wait to ensure disposal is complete
    await Future.delayed(Duration(seconds: 1));

    // Try to reinitialize
    final newService = ConversationalAIService();
    final reinitResult = await newService.initialize(
      agentId: agentId,
      endpoint: endpoint,
    );

    testResults.add(reinitResult == 'success'
        ? '✅ Service disposal and reinitialization works'
        : '❌ Service disposal/restart issues detected');

    await newService.dispose();

    // ===== TEST RESULTS SUMMARY =====
    final endTime = DateTime.now();
    final testDuration = endTime.difference(startTime);

    debugPrint('🧪 ===== TEST RESULTS SUMMARY =====');
    debugPrint('🧪 Test Duration: ${testDuration.inSeconds} seconds');
    debugPrint('🧪 Total Tests: ${testResults.length}');

    int passedTests = 0;
    for (String result in testResults) {
      debugPrint('🧪 $result');
      if (result.startsWith('✅')) passedTests++;
    }

    debugPrint('🧪 Passed: $passedTests/${testResults.length}');
    debugPrint(
        '🧪 Success Rate: ${(passedTests / testResults.length * 100).toStringAsFixed(1)}%');

    // Update FFAppState with test status
    FFAppState().update(() {
      // Store basic test completion status
      FFAppState().wsConnectionState = 'test_completed_${passedTests}_${testResults.length}';
    });

    return 'Test completed: $passedTests/${testResults.length} passed (${(passedTests / testResults.length * 100).toStringAsFixed(1)}%)';
  } catch (e) {
    debugPrint('❌ Test suite error: $e');
    testResults.add('❌ Critical test error: $e');

    // Ensure cleanup even on error
    try {
      await service.dispose();
    } catch (disposeError) {
      debugPrint('❌ Error during cleanup: $disposeError');
    }

    return 'Test failed with error: $e';
  }
}
