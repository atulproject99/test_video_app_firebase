import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

typedef StreamStateCallback = void Function(MediaStream stream);

class Signaling {
  Map<String, dynamic> configuration = {
    /// This configuration used for know the public ip of system
    'iceServers': [
      {
        "urls": ["turn:relay1.expressturn.com:3480"],
        "username": "174826260755106479",
        "credential": "d1mnSiSsSd/N284JFYsVnHb8NMw=",
      },
    ],
  };
  RTCPeerConnection? rtcPeerConnection;
  MediaStream? localStream;
  MediaStream? remoteStream;
  StreamStateCallback? onAddRemoteStream;
  Future<void> createRoom() async {
    FirebaseFirestore db = FirebaseFirestore.instance;
    DocumentReference roomRef = db.collection('rooms').doc();

    /// Create peer connection with configuration
    debugPrint("Create peer connection with configuration");
    rtcPeerConnection = await createPeerConnection(configuration, {
      'mandatory': {'OfferToReceiveAudio': false, 'OfferToReceiveVideo': true},
      'optional': [],
    });

    /// Register peer connection listeners
    registerPeerConnectionListener();

    /// Fetch each track from local stream and add into connection

    localStream?.getTracks().forEach((track) {
      rtcPeerConnection?.addTrack(track, localStream!);
    });

    /// collection ICE candidates(all possible connection)

    final callerCandidates = roomRef.collection('callerCandidates');

    /// Get all candidates and add to firebase

    rtcPeerConnection?.onIceCandidate = (candidates) {
      callerCandidates.add(candidates.toMap());
    };

    // Finish Code for collecting ICE candidate

    /// Creating room
    /// Create offer
    RTCSessionDescription? offer = await rtcPeerConnection?.createOffer();

    ///store in local
    rtcPeerConnection?.setLocalDescription(offer!);
    debugPrint('Created offer: $offer');

    Map<String, dynamic> roomWithOffer = {'offer': offer?.toMap()};
    await roomRef.set(roomWithOffer);
    final roomId = roomRef.id;
    debugPrint('New room created with SDK offer. Room ID: $roomId');

    /// get track from connected and add to remote stream

    rtcPeerConnection?.onTrack = (RTCTrackEvent event) {
      debugPrint('Got remote track: ${event.streams[0]}');
      event.streams[0].getTracks().forEach((track) {
        debugPrint("Add a track to the remote stream $track");
        remoteStream?.addTrack(track);

        /// onAddRemoteStream?.call(event.streams[0]);
      });
    };
    // Listening for remote session description below

    roomRef.snapshots().listen((snapshot) async {
      debugPrint('Got updated room: ${snapshot.data()}');
      Map<String, dynamic> data = snapshot.data() as Map<String, dynamic>;
      if (rtcPeerConnection?.getRemoteDescription() != null &&
          data['answer'] != null) {
        debugPrint("Someone is trying to connect");
        final answer = RTCSessionDescription(
          data['answer']['sdp'],
          data['answer']['type'],
        );
        rtcPeerConnection?.setRemoteDescription(answer);
      }
    });
    // Listen for remote Ice candidates below
    roomRef.collection('calleeCandidates').snapshots().listen((snapshot) {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          Map<String, dynamic> data = change.doc.data() as Map<String, dynamic>;
          debugPrint('Got new remote ICE candidate: ${jsonEncode(data)}');
          rtcPeerConnection?.addCandidate(
            RTCIceCandidate(
              data['candidate'],
              data['sdpMid'],
              data['sdpMLineIndex'],
            ),
          );
        }
      }
    });

    debugPrint("Room id is $roomId");
  }

  Future<void> joinRoom(String roomId) async {
    debugPrint("Join room called -------");
    FirebaseFirestore db = FirebaseFirestore.instance;
    debugPrint("Room id $roomId");
    DocumentReference roomRef = db.collection('rooms').doc(roomId);
    final roomSnapshots = await roomRef.get();
    debugPrint("Room snapshots is exist ${roomSnapshots.exists}");
    if (roomSnapshots.exists) {
      /// create peer connection
      debugPrint('Create PeerConnection with configuration: $configuration');
      rtcPeerConnection = await createPeerConnection(configuration, {
        'mandatory': {
          'OfferToReceiveAudio': false,
          'OfferToReceiveVideo': true,
        },
        'optional': [],
      });

      /// Add register peer listeners
      registerPeerConnectionListener();

      /// Add local stream track to connection

      localStream?.getTracks().forEach((track) {
        rtcPeerConnection?.addTrack(track, localStream!);
      });

      // Code for collecting ICE candidates below
      final calleeCandidatesCollection = roomRef.collection('calleeCandidates');
      rtcPeerConnection!.onIceCandidate = (RTCIceCandidate? candidate) {
        if (candidate == null) {
          debugPrint('onIceCandidate: complete!');
          return;
        }
        debugPrint('onIceCandidate: ${candidate.toMap()}');
        calleeCandidatesCollection.add(candidate.toMap());
      };

      /// get track from connected and add to remote stream

      rtcPeerConnection?.onTrack = (RTCTrackEvent event) {
        debugPrint('Got remote track: ${event.streams[0]}');
        event.streams[0].getTracks().forEach((track) {
          debugPrint("Add a track to the remote stream $track");
          remoteStream?.addTrack(track);
        });
        // onAddRemoteStream?.call(event.streams[0]);
      };

      final data = roomSnapshots.data() as Map<String, dynamic>;
      debugPrint('Got offer $data');
      final offer = data['offer'];
      await rtcPeerConnection?.setRemoteDescription(
        RTCSessionDescription(offer['sdp'], offer['type']),
      );
      final answer = await rtcPeerConnection?.createAnswer();
      debugPrint("Answer created");

      await rtcPeerConnection?.setLocalDescription(answer!);
      Map<String, dynamic> roomWithAnswer = {
        'answer': {'type': answer!.type, 'sdp': answer.sdp},
      };
      await roomRef.update(roomWithAnswer);

      // Listening for remote ICE candidates below
      roomRef.collection('callerCandidates').snapshots().listen((snapshot) {
        for (var document in snapshot.docChanges) {
          var data = document.doc.data() as Map<String, dynamic>;
          debugPrint(data.toString());
          debugPrint('Got new remote ICE candidate: $data');
          rtcPeerConnection!.addCandidate(
            RTCIceCandidate(
              data['candidate'],
              data['sdpMid'],
              data['sdpMLineIndex'],
            ),
          );
        }
      });
    }
  }

  void registerPeerConnectionListener() {
    rtcPeerConnection?.onIceGatheringState = (RTCIceGatheringState state) {
      debugPrint('ICE gathering state changed: $state');
    };
    rtcPeerConnection?.onConnectionState = (RTCPeerConnectionState state) {
      debugPrint('Connection state change: $state');
    };

    rtcPeerConnection?.onSignalingState = (RTCSignalingState state) {
      debugPrint('Signaling state change: $state');
    };

    rtcPeerConnection?.onIceGatheringState = (RTCIceGatheringState state) {
      debugPrint('ICE connection state change: $state');
    };

    // rtcPeerConnection?.onTrack = (RTCTrackEvent event) {
    //   print('Got remote track: ${event.streams[0]}');

    //   if (remoteStream == null) {
    //     remoteStream = event.streams[0];
    //   } else {
    //     // Avoid duplicate tracks
    //     event.streams[0].getTracks().forEach((track) {
    //       remoteStream?.addTrack(track);
    //     });
    //   }

    //   // 👇 Assign the stream to the remote video renderer
    //   remoteVideo.srcObject = remoteStream;
    // };

    rtcPeerConnection?.onAddStream = (MediaStream stream) {
      debugPrint("Remote stream detected");
      onAddRemoteStream?.call(stream);
      remoteStream = stream;
    };

    rtcPeerConnection?.onTrack = (RTCTrackEvent event) {
      debugPrint("Remote stream detected on track");
      onAddRemoteStream?.call(event.streams[0]);
    };
  }

  void openMedia(
    RTCVideoRenderer localVideoRenderer,
    RTCVideoRenderer remoteVideoRenderer,
  ) async {
    debugPrint("Open media app called");
    try {
      final stream = await navigator.mediaDevices.getUserMedia({
        'video': true,
        'audio': true,
      });
      localVideoRenderer.srcObject = stream;
      localStream = stream;
      remoteVideoRenderer.srcObject = await createLocalMediaStream('key');
    } catch (e) {
      debugPrint("Error while get user media $e");
    }
  }
}
