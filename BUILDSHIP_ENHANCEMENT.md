RR# BuildShip Node Template Enhancement for Echo Cancellation

## Overview

This enhancement adds an `allow_interrupt` parameter to the BuildShip cloud function to improve echo cancellation and reduce agent speech duration before device recovery.

## Current BuildShip Function

The existing BuildShip function already securely handles API key hiding and returns signed URLs. This enhancement adds client-side barge-in support.

## Enhanced BuildShip Function

### Add Query Parameter Support

Update your BuildShip cloud function to accept and forward the `allow_interrupt` parameter:

```typescript
// In your BuildShip node
const allowInterrupt = req.query.allow_interrupt === "true";
const AGENT_ID = "your_agent_id_here"; // Replace with your actual agent ID

const url = `https://api.elevenlabs.io/v1/convai/conversation/get_signed_url?agent_id=${AGENT_ID}&allow_interrupt=${allowInterrupt}`;

const response = await fetch(url, {
  method: "GET",
  headers: {
    "xi-api-key": process.env.ELEVENLABS_API_KEY,
  },
});

const data = await response.json();
return data;
```

### FlutterFlow Integration

Update your FlutterFlow initialization to include the parameter:

```dart
// In your FlutterFlow action or page load
final endpoint = 'https://your-buildship-url.buildship.run/GetSignedUrl?allow_interrupt=true';
```

## Benefits

1. **Reduced Echo Duration**: Agent speech is shorter, allowing faster microphone recovery
2. **Better Responsiveness**: Users can interrupt the agent more naturally
3. **Enhanced User Experience**: More conversational and responsive interactions

## Testing

1. Test with `allow_interrupt=true` - verify faster turnaround times
2. Test with `allow_interrupt=false` - verify traditional behavior
3. Compare echo cancellation effectiveness between modes

## Implementation Status

- ✅ Platform-level AEC (Android/iOS)
- ✅ Enhanced Dart-side mic gating
- ✅ Soft speaker ducking
- ✅ VAD enhancement with amplitude monitoring
- ✅ Public muteMic() action for FlutterFlow
- 📋 BuildShip enhancement (documented here)

The BuildShip enhancement is optional but recommended for optimal echo cancellation performance.
