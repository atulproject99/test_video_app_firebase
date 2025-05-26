import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:test_video_app_firebase/signaling.dart';

class CallPage extends StatefulWidget {
  const CallPage({super.key});

  @override
  State<CallPage> createState() => _CallPageState();
}

class _CallPageState extends State<CallPage> {
  /// Crete object of signaling

  Signaling signaling = Signaling();

  /// Two renderer for one for local and remote
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();

  /// Create a textediting controller

  final TextEditingController _textEditingController = TextEditingController(
    text: '',
  );
  @override
  void initState() {
    super.initState();

    /// Initialize both renderer
    _initializeRenderers();

    signaling.onAddRemoteStream = (stream) {
      log("getting stream");
      _remoteRenderer.srcObject = stream;
      setState(() {});
    };
  }

  _initializeRenderers() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
  }

  @override
  void dispose() {
    _localRenderer.dispose();
    _remoteRenderer.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Webrtc realtime communication demo"),
        backgroundColor: Colors.purple,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 20,
          children: [
            SizedBox(height: 20),
            Expanded(
              child: _CustomButtonHandler(
                onTapOpenCameraAndAudio: () {
                  signaling.openMedia(_localRenderer, _remoteRenderer);
                },
                onTapCreateRoom: () async {
                  await signaling.createRoom();
                },
                onTapJoinRoom: () {
                  signaling.joinRoom(_textEditingController.text);
                },
                onTapHangup: () {
                  signaling.hangup(_localRenderer);
                },
              ),
            ),

            Expanded(
              child: Row(
                spacing: 20,
                children: [
                  Expanded(child: RTCVideoView(_localRenderer, mirror: true)),
                  Expanded(child: RTCVideoView(_remoteRenderer)),
                ],
              ),
            ),
            Row(
              spacing: 20,
              children: [
                Text("Join the following room"),
                Expanded(
                  child: TextFormField(
                    controller: _textEditingController,
                    decoration: InputDecoration(border: OutlineInputBorder()),
                  ),
                ),
              ],
            ),
            SizedBox(height: 50),
          ],
        ),
      ),
    );
  }
}

class _CustomButtonHandler extends StatelessWidget {
  const _CustomButtonHandler({
    required this.onTapOpenCameraAndAudio,
    required this.onTapCreateRoom,
    required this.onTapJoinRoom,
    required this.onTapHangup,
  });
  final VoidCallback onTapOpenCameraAndAudio;
  final VoidCallback onTapCreateRoom;
  final VoidCallback onTapJoinRoom;
  final VoidCallback onTapHangup;

  @override
  Widget build(BuildContext context) {
    return Row(
      spacing: 20,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: ElevatedButton(
            onPressed: onTapOpenCameraAndAudio,

            child: Text("Open camera and audio"),
          ),
        ),
        Expanded(
          child: ElevatedButton(
            onPressed: onTapCreateRoom,
            child: Text("Create Room"),
          ),
        ),
        Expanded(
          child: ElevatedButton(
            onPressed: onTapJoinRoom,
            child: Text("Join Room"),
          ),
        ),
        Expanded(
          child: ElevatedButton(onPressed: onTapHangup, child: Text("Hangup")),
        ),
      ],
    );
  }
}
