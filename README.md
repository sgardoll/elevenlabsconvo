# ElevenLabs Conversational AI v2 Library for FlutterFlow

![ElevenLabs Conversational AI](https://github.com/user-attachments/assets/7b9f384f-7885-4853-b01c-5fa7be4017c2)

## Add real-time voice conversations to your FlutterFlow app with ElevenLabs Agents

This library is built for **FlutterFlow users** who want to add natural, speech-to-speech AI conversations to their app without exposing secret keys in the client. It connects your FlutterFlow project to **ElevenLabs Conversational AI v2** using the official ElevenLabs Flutter SDK under the hood, while keeping the setup focused on what you can actually configure inside the **FlutterFlow interface**.

---

## Who this is for

This README is written for a **FlutterFlow builder** who is:

- installing the library from the **FlutterFlow Marketplace**
- configuring values in **App State**, **API Calls**, **page actions**, and **widgets**
- avoiding direct code edits unless FlutterFlow explicitly asks for platform configuration

If you are using this library in FlutterFlow, the supported install path is the **Marketplace import flow**.

---

## 🔐 Secure architecture

This library is designed so your **ElevenLabs API key never lives in FlutterFlow App State, page state, custom actions, or client-side code**.

### How the secure flow works

1. You create an agent in **ElevenLabs**
2. You store your ElevenLabs API key in a secure backend service such as **BuildShip**
3. Your FlutterFlow app calls that backend to request a temporary **conversation token**
4. The library uses that token to start a secure real-time conversation
5. Audio streams through WebRTC without exposing your secret key in the app

### Why this matters

- Your API key is not shipped in the app
- Your FlutterFlow project remains safe to share with collaborators
- You can rotate backend secrets without changing app screens
- Tokens are short-lived and safer than using a raw API key on-device

---

## 🚀 Features

### Voice conversation features

- **Real-time speech-to-speech AI conversations**
- **Low-latency streaming audio** powered by WebRTC
- **Interruptions and turn-taking** for more natural conversations
- **Transcripts and conversation state** exposed to FlutterFlow
- **Automatic reconnect behavior** for unstable connections
- **Playback-aware recording behavior** to reduce audio feedback

### FlutterFlow-friendly features

- **Custom widget** for recording interaction
- **Custom actions** to initialize and stop the session
- **App State integration** so your UI can react visually
- **Theme-aware behavior** for FlutterFlow UI styling
- **Permission handling support** for microphone and audio routing

---

## 🛍️ Installation

### Install from the FlutterFlow Marketplace

1. Open the library in the **FlutterFlow Marketplace**:
   [ElevenLabs Conversational AI v2](https://marketplace.flutterflow.io/item/6iqd6d7dIphUrTANELHe)
2. Click **Add to Project**
3. Complete the FlutterFlow import flow
4. Wait for FlutterFlow to finish syncing dependencies

That is the installation path FlutterFlow users should follow.

---

## 🧩 What you need before setup

Before configuring the library in FlutterFlow, make sure you have:

- an **ElevenLabs account**
- an **ElevenLabs Agent ID**
- a secure backend endpoint that returns a **conversation token**
- a FlutterFlow project with the marketplace library added

### Recommended backend option

The easiest low-code pattern is:

- **FlutterFlow** → sends request to your backend
- **BuildShip** → uses your ElevenLabs API key securely
- **BuildShip** → returns a temporary `conversationToken`
- **FlutterFlow** → starts the conversation using that token

---

## ⚙️ FlutterFlow setup

## Step 1: Create your ElevenLabs agent

In ElevenLabs:

1. Open **Conversational AI**
2. Create or select your agent
3. Copy the **Agent ID**

You will store this value in FlutterFlow App State later.

---

## Step 2: Create your secure token endpoint

Use a backend platform such as **BuildShip** to create an endpoint that:

- accepts your `agentId`
- uses your secret ElevenLabs API key on the server
- returns a temporary **conversation token**

### Important

Do **not** put your ElevenLabs API key into:

- FlutterFlow App State
- page parameters
- custom action inputs
- API call headers inside FlutterFlow
- local storage on the device

Only the backend should know the API key.

---

## Step 3: Add App State variables in FlutterFlow

In FlutterFlow, go to **App State** and add these variables.

### Required App State variables

| Variable | Type | Default | Purpose |
|---|---|---:|---|
| `wsConnectionState` | String | `disconnected` | Tracks connection status |
| `elevenLabsAgentId` | String | empty | Stores your ElevenLabs Agent ID |
| `elevenLabsConversationTokenEndpoint` | String | empty | Stores your backend token endpoint URL |
| `isRecording` | bool | `false` | Tracks whether the user is currently recording |
| `conversationMessages` | List < JSON > or List < dynamic > | empty list | Stores transcript/message history |
| `isAgentSpeaking` | bool | `false` | Tracks whether the AI is currently speaking |
| `isInitializing` | bool | `false` | Tracks initialization state |

### What to paste into App State

- Set `elevenLabsAgentId` to your real ElevenLabs Agent ID
- Set `elevenLabsConversationTokenEndpoint` to your deployed backend URL

---

## Step 4: Add your API Call in FlutterFlow

In FlutterFlow, create an **API Call** that requests a conversation token from your backend.

### Example low-code flow

- **Method:** `POST`
- **URL:** `FFAppState().elevenLabsConversationTokenEndpoint`
- **Body:** send the `agentId`

### Recommended request body

```json
{
  "agentId": "[your agent id from App State]"
}
```

### Expected response

Your backend should return a field containing the token, for example:

```json
{
  "conversationToken": "your-temporary-token"
}
```

In FlutterFlow, create a response mapping so you can read that token in your action flow.

---

## Step 5: Configure permissions in FlutterFlow project settings

This library needs microphone access and may also rely on Bluetooth/audio routing behavior depending on the device.

### Android permissions

Make sure your generated Android app includes:

- `RECORD_AUDIO`
- `INTERNET`
- `MODIFY_AUDIO_SETTINGS`
- `ACCESS_NETWORK_STATE`
- Bluetooth permissions if your audio path depends on them
- foreground audio service support if your app uses ongoing conversation flows

### iOS permissions

Make sure your generated iOS app includes:

- microphone usage description
- Bluetooth usage description if applicable
- audio background modes if your use case requires it

If FlutterFlow exposes these through project settings, configure them there. If your project requires platform-specific config outside the UI, use the generated platform settings carefully after export.

---

## 🎯 Build the conversation flow in FlutterFlow

## Page load setup

On the page where the conversation should start, configure your action flow in FlutterFlow.

### Recommended order

1. **Request microphone permission**
2. **Call your token API**
3. **Read the returned `conversationToken`**
4. **Run the custom action to initialize the conversation**

### Conceptual flow inside FlutterFlow

- Action 1: Request microphone permission
- Action 2: Execute your token API call
- Action 3: If token exists, run `initializeConversationService`
- Action 4: If initialization fails, show an error message or snackbar

### Inputs you will use

The initialize action should receive:

- `conversationToken`
- your `agentId`
- current page context as required by FlutterFlow

---

## Add the recording widget

Place the included recording widget on your page.

### What it does for you

- gives the user a clear talk button
- reacts to conversation state
- helps prevent recording while the agent is already speaking
- supports a cleaner low-code setup than manually wiring recording state yourself

You can place it inside:

- a floating action area
- a chat composer area
- a bottom sheet
- a persistent footer on a conversation screen

---

## Show conversation messages in the UI

Use a **ListView** or repeating UI pattern in FlutterFlow and bind it to:

- `FFAppState().conversationMessages`

Recommended display ideas:

- user messages on one side
- agent messages on the other side
- loading indicator when `isInitializing` is true
- speaking indicator when `isAgentSpeaking` is true
- connection status badge using `wsConnectionState`

---

## Clean up when leaving the page

On **Page Dispose** or when the user exits the conversation screen:

- run `stopConversationService`

This helps avoid leaving audio sessions active after navigation.

---

## 🧪 Testing guidance for FlutterFlow users

### Test on a real device

If you are testing iOS voice input, use a **physical iPhone**.

### iOS Simulator limitation

The underlying WebRTC stack used by the ElevenLabs SDK does **not reliably capture microphone input in iOS Simulator**.

That means:

- your UI may load correctly
- your connection may still initialize
- but voice capture and transcript behavior may fail or show incomplete results

For final validation, always test on a real device.

---

## 🔒 Best practices for FlutterFlow builders

### Do this

- keep your API key on the backend only
- store only the **Agent ID** and **token endpoint URL** in App State
- use FlutterFlow API Calls for the token request
- show UI feedback for connecting, speaking, recording, and errors
- test microphone permissions on both Android and iOS

### Do not do this

- do not paste your ElevenLabs API key into FlutterFlow
- do not hardcode secrets into custom actions
- do not rely on simulator testing for final audio validation
- do not skip the backend token step

---

## 🧠 Why the marketplace version uses compatibility fixes internally

FlutterFlow projects include internal package constraints that are not always compatible with the default dependency chain used by the public ElevenLabs Flutter SDK.

This library includes the compatibility work needed to make the integration function cleanly in a FlutterFlow environment.

As a FlutterFlow user, you do **not** need to manually manage those package-level fixes through the FlutterFlow interface. The important part for you is:

- install from the Marketplace
- configure App State
- set up your token API call
- wire the provided actions and widget into your page

---

## Troubleshooting

| Problem | What to check in FlutterFlow |
|---|---|
| Conversation does not start | Confirm your token API call returns a valid `conversationToken` |
| Permission error | Confirm microphone permissions are enabled in project settings and granted on device |
| No transcript on iPhone simulator | Test on a physical device |
| Agent does not respond | Confirm `elevenLabsAgentId` is correct |
| UI never leaves loading state | Check whether `isInitializing` is being reset and whether the token call succeeded |
| Connection drops | Check network conditions and show state from `wsConnectionState` in the UI |

---

## ElevenLabs resources

- [Conversational AI Overview](https://elevenlabs.io/docs/conversational-ai/overview)
- [Agent Configuration Guide](https://elevenlabs.io/docs/conversational-ai/agents)
- [API Reference](https://elevenlabs.io/docs/api-reference)

---

## Final setup checklist

Before you test, confirm all of the following:

- Marketplace library added to your FlutterFlow project
- ElevenLabs Agent created
- backend token endpoint deployed
- `elevenLabsAgentId` added to App State
- `elevenLabsConversationTokenEndpoint` added to App State
- token API Call created in FlutterFlow
- page action flow wired for permission → token → initialize
- recording widget added to the page
- `stopConversationService` added on exit/dispose
- tested on a real mobile device

---

Ready to build voice-native experiences in FlutterFlow? Install the Library from Marketplace and get conversing!