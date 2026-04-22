import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:intl/intl.dart';

class TelehealthScreen extends StatefulWidget {
  final String userId;
  final String? initialSdp;
  final String doctorId;

  const TelehealthScreen({
    super.key,
    required this.userId,
    this.initialSdp,
    required this.doctorId,
  });

  @override
  State<TelehealthScreen> createState() => _TelehealthScreenState();
}

class _TelehealthScreenState extends State<TelehealthScreen> {
  late WebSocketChannel _channel;
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;

  final TextEditingController _msgController = TextEditingController();
  final List<Map<String, dynamic>> _messages = [];
  bool _isVideoActive = false;
  bool _isMuted = false;
  bool _isCamOff = false;

  @override
  void initState() {
    super.initState();
    _initWebRTC();
    _connectWS();
    if (widget.initialSdp != null) {
      _isVideoActive = true;
      _handleOffer(widget.initialSdp!);
    }
  }

  void _connectWS() {
    _channel = WebSocketChannel.connect(
      Uri.parse('ws://localhost:8000/ws/telehealth/${widget.userId}'),
    );
    _channel.stream.listen((message) {
      final data = jsonDecode(message);
      if (data['type'] == 'chat') {
        setState(() {
          _messages.add({'from': data['from'], 'text': data['data']['text'], 'isMe': false});
        });
      } else if (data['type'] == 'signal') {
        _handleSignaling(data['data']);
      }
    });
  }

  Future<void> _initWebRTC() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
  }

  Future<void> _handleSignaling(Map<String, dynamic> data) async {
    if (data['sdp'] != null && data['sdp']['type'] == 'offer') {
      setState(() => _isVideoActive = true);
      await _handleOffer(data['sdp']);
    } else if (data['ice'] != null) {
      await _peerConnection?.addCandidate(
        RTCIceCandidate(data['ice']['candidate'], data['ice']['sdpMid'], data['ice']['sdpMLineIndex']),
      );
    }
  }

  Future<void> _handleOffer(dynamic sdp) async {
    _peerConnection = await createPeerConnection({
      'iceServers': [{'urls': 'stun:stun.l.google.com:19302'}]
    });

    _peerConnection!.onIceCandidate = (candidate) {
      _channel.sink.add(jsonEncode({
        'type': 'signal',
        'to': widget.doctorId,
        'data': {'ice': candidate.toMap()}
      }));
    };

    _peerConnection!.onTrack = (event) {
      if (event.streams.isNotEmpty) {
        _remoteRenderer.srcObject = event.streams[0];
      }
    };

    _localStream = await navigator.mediaDevices.getUserMedia({'video': true, 'audio': true});
    _localRenderer.srcObject = _localStream;
    _localStream!.getTracks().forEach((track) {
      _peerConnection!.addTrack(track, _localStream!);
    });

    await _peerConnection!.setRemoteDescription(RTCSessionDescription(sdp['sdp'], sdp['type']));
    final answer = await _peerConnection!.createAnswer();
    await _peerConnection!.setLocalDescription(answer);

    _channel.sink.add(jsonEncode({
      'type': 'signal',
      'to': widget.doctorId,
      'data': {'sdp': answer.toMap()}
    }));
  }

  void _sendMsg() {
    if (_msgController.text.trim().isEmpty) return;
    final text = _msgController.text.trim();
    _channel.sink.add(jsonEncode({
      'type': 'chat',
      'to': widget.doctorId,
      'data': {'text': text}
    }));
    setState(() {
      _messages.add({'from': 'Me', 'text': text, 'isMe': true});
    });
    _msgController.clear();
  }

  void _toggleMute() {
    setState(() => _isMuted = !_isMuted);
    _localStream?.getAudioTracks().forEach((t) => t.enabled = !_isMuted);
  }

  void _toggleCam() {
    setState(() => _isCamOff = !_isCamOff);
    _localStream?.getVideoTracks().forEach((t) => t.enabled = !_isCamOff);
  }

  void _endCall() {
    _localStream?.dispose();
    _peerConnection?.close();
    setState(() {
      _isVideoActive = false;
      _localRenderer.srcObject = null;
      _remoteRenderer.srcObject = null;
    });
  }

  @override
  void dispose() {
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    _localStream?.dispose();
    _peerConnection?.close();
    _channel.sink.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Telehealth Consult', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
        actions: [
          if (!_isVideoActive)
            IconButton(
              icon: const Icon(Icons.videocam_rounded, color: Color(0xFFB6171E)),
              onPressed: () { /* In this flow, doctor initiates video */ },
            ),
        ],
      ),
      body: Column(
        children: [
          if (_isVideoActive)
            Container(
              height: 250,
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(20)),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                children: [
                  RTCVideoView(_remoteRenderer, objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover),
                  Positioned(
                    right: 10, bottom: 10,
                    child: Container(
                      width: 100, height: 130,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white24, width: 2),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: RTCVideoView(_localRenderer, mirror: true, objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover),
                    ),
                  ),
                  Positioned(
                    bottom: 10, left: 10,
                    child: Row(
                      children: [
                        _CircleBtn(icon: _isMuted ? Icons.mic_off : Icons.mic, color: _isMuted ? Colors.red : Colors.white24, onTap: _toggleMute),
                        const SizedBox(width: 8),
                        _CircleBtn(icon: _isCamOff ? Icons.videocam_off : Icons.videocam, color: _isCamOff ? Colors.red : Colors.white24, onTap: _toggleCam),
                        const SizedBox(width: 8),
                        _CircleBtn(icon: Icons.call_end, color: Colors.red, onTap: _endCall),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, i) {
                final m = _messages[i];
                final isMe = m['isMe'];
                return Align(
                  alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: isMe ? const Color(0xFFB6171E) : const Color(0xFFF3F3F3),
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(16),
                        topRight: const Radius.circular(16),
                        bottomLeft: Radius.circular(isMe ? 16 : 0),
                        bottomRight: Radius.circular(isMe ? 0 : 16),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                      children: [
                        Text(m['text'], style: TextStyle(color: isMe ? Colors.white : Colors.black87, fontSize: 14)),
                        const SizedBox(height: 4),
                        Text(DateFormat('hh:mm a').format(DateTime.now()), style: TextStyle(color: isMe ? Colors.white70 : Colors.black45, fontSize: 9)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))]),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _msgController,
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
                        filled: true,
                        fillColor: const Color(0xFFF9F9F9),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(25), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                      ),
                      onSubmitted: (_) => _sendMsg(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.send_rounded, color: Color(0xFFB6171E)),
                    onPressed: _sendMsg,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CircleBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _CircleBtn({required this.icon, required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 40, height: 40,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: Icon(icon, color: Colors.white, size: 20),
    ),
  );
}
