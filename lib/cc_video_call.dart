import 'package:flutter/material.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';
import 'dart:math';

/// Enhanced Video Call Page with improved error handling and user experience
class EnhancedVideoCallPage extends StatefulWidget {
  final String appId;
  final String channelName;
  final String userName;
  final String role;
  final String token;
  final String certificate;

  const EnhancedVideoCallPage({
    super.key, 
    required this.appId, 
    required this.channelName,
    required this.userName,
    required this.role,
    this.token = '',
    this.certificate = '',
  });

  @override
  State<EnhancedVideoCallPage> createState() => _EnhancedVideoCallPageState();
}

class _EnhancedVideoCallPageState extends State<EnhancedVideoCallPage> with SingleTickerProviderStateMixin {
  RtcEngine? _engine;
  int _remoteUid = 0;
  bool _isJoined = false;
  bool _localVideoEnabled = true;
  bool _localAudioEnabled = true;
  bool _localVideoInitialized = false;
  bool _isInitializing = true;
  bool _isReconnecting = false;
  bool _hasConnectionError = false;
  String _connectionStatus = "Initializing...";
  int _reconnectAttempts = 0;
  final int _maxReconnectAttempts = 3;
  Timer? _connectionTimer;
  Timer? _reconnectTimer;
  late AnimationController _animationController;
  String? _generatedToken;
  int _uid = 0;

  // Track if we've seen a remote user at least once
  bool _hasSeenRemoteUser = false;

  @override
  void initState() {
    super.initState();
    // Setup animation controller
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    
    // Generate a random UID for this user
    final random = Random();
    _uid = random.nextInt(100000) + 100000; // Generate a 6-digit number
    
    // Use a slight delay to ensure the widget is fully mounted
    Future.delayed(Duration.zero, () {
      if (mounted) {
        initAgora();
      }
    });
    
    // Set a timer to check if we've connected to anyone after 30 seconds
    _connectionTimer = Timer(const Duration(seconds: 30), () {
      if (!_hasSeenRemoteUser && mounted) {
        setState(() {
          _connectionStatus = "No one has joined yet. Waiting for other participants...";
        });
      }
    });
  }

  @override
  void dispose() {
    _connectionTimer?.cancel();
    _reconnectTimer?.cancel();
    _animationController.dispose();
    
    // Clean up Agora resources
    _engine?.leaveChannel();
    _engine?.release();
    
    super.dispose();
  }

  Future<void> initAgora() async {
    if (!mounted) return;
    
    setState(() {
      _isInitializing = true;
      _connectionStatus = "Initializing video call...";
    });
    
    try {
      // Validate App ID first
      if (widget.appId.isEmpty) {
        debugPrint("Error: Empty Agora App ID");
        if (mounted) {
          setState(() {
            _hasConnectionError = true;
            _connectionStatus = "Invalid App ID. Please configure a valid App ID.";
            _isInitializing = false;
          });
        }
        return;
      }
      
      // Retrieve or request camera and microphone permissions
      final status = await [Permission.camera, Permission.microphone].request();
      
      if (status[Permission.camera]!.isDenied || status[Permission.microphone]!.isDenied) {
        if (mounted) {
          setState(() {
            _connectionStatus = "Camera or microphone permission denied";
            _hasConnectionError = true;
            _isInitializing = false;
          });
        }
        return;
      }

      // Create RTC engine instance with error handling
      try {
        // Initialize the engine with a try-catch block
        _engine = createAgoraRtcEngine();
        
        // Add a small delay to ensure proper initialization
        await Future.delayed(const Duration(milliseconds: 100));
        
        await _engine!.initialize(RtcEngineContext(
          appId: widget.appId,
          channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
        ));
        
        // Enable detailed logs for debugging
        await _engine!.setLogFilter(LogFilterType.logFilterDebug);
        
        // Set up event handlers immediately after initialization
        _setupEventHandlers();
        
        // Configure video settings
        await _engine!.enableVideo();
        await _engine!.setVideoEncoderConfiguration(
          const VideoEncoderConfiguration(
            dimensions: VideoDimensions(width: 640, height: 360),
            frameRate: 15,
            bitrate: 800,
          ),
        );
      } catch (e) {
        debugPrint("Error initializing Agora engine: $e");
        if (mounted) {
          setState(() {
            _hasConnectionError = true;
            if (e.toString().contains("-17")) {
              _connectionStatus = "Error setting up video call: Invalid App ID or permission denied. Please check your configuration.";
            } else if (e.toString().contains("createIrisApiEngine")) {
              _connectionStatus = "Error initializing video engine. Please try restarting the app.";
            } else {
              _connectionStatus = "Error setting up video call: $e";
            }
            _isInitializing = false;
          });
        }
        return;
      }
        
      // Start camera preview
      await _engine!.startPreview();
        
      if (mounted) {
        setState(() {
          _localVideoInitialized = true;
          _connectionStatus = "Camera initialized. Joining call...";
        });
      }

      // Set client role
      await _engine!.setClientRole(role: ClientRoleType.clientRoleBroadcaster);
      
      // Log the channel info
      debugPrint("Channel name: ${widget.channelName}");
      debugPrint("UID: $_uid");
        
      // Join channel without token (App ID only mode)
      await _engine!.joinChannel(
        token: '', // Empty token for App ID only mode
        channelId: widget.channelName,
        uid: _uid,
        options: const ChannelMediaOptions(
          channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
          publishCameraTrack: true,
          publishMicrophoneTrack: true,
        ),
      );
    } catch (e) {
      debugPrint("Error initializing Agora: $e");
      if (mounted) {
        setState(() {
          _hasConnectionError = true;
          _connectionStatus = "Error initializing video call: $e";
          _isInitializing = false;
        });
      }
    }
  }

  // Add this method to set up event handlers separately for better organization
  void _setupEventHandlers() {
    if (_engine == null) {
      debugPrint("Cannot set up event handlers: engine is null");
      return;
    }
    
    _engine!.registerEventHandler(RtcEngineEventHandler(
      onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
        debugPrint("local user ${connection.localUid} joined channel");
        if (mounted) {
          setState(() {
            _isJoined = true;
            _connectionStatus = "Connected to channel. Waiting for others...";
            _isInitializing = false;
            _isReconnecting = false;
          });
        }
      },
      onLeaveChannel: (RtcConnection connection, RtcStats stats) {
        debugPrint("local user ${connection.localUid} left channel");
        if (mounted) {
          setState(() {
            _isJoined = false;
            _remoteUid = 0;
          });
        }
      },
      onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
        debugPrint("remote user $remoteUid joined channel");
        if (mounted) {
          setState(() {
            _remoteUid = remoteUid;
            _hasSeenRemoteUser = true;
            _connectionStatus = "Connected with other participant";
          });
        }
      },
      onUserOffline: (RtcConnection connection, int remoteUid, UserOfflineReasonType reason) {
        debugPrint("remote user $remoteUid left channel");
        if (mounted) {
          setState(() {
            _remoteUid = 0;
            _connectionStatus = "Other participant left the call";
          });
        }
      },
      onConnectionStateChanged: (RtcConnection connection, ConnectionStateType state, ConnectionChangedReasonType reason) {
        debugPrint("Connection state changed to: $state, reason: $reason");
        
        if (!mounted) return;
        
        if (state == ConnectionStateType.connectionStateConnecting) {
          setState(() {
            _connectionStatus = "Connecting to call...";
          });
        } else if (state == ConnectionStateType.connectionStateConnected) {
          setState(() {
            _connectionStatus = "Connected to call";
            _isReconnecting = false;
          });
        } else if (state == ConnectionStateType.connectionStateReconnecting) {
          setState(() {
            _connectionStatus = "Connection lost. Reconnecting...";
            _isReconnecting = true;
          });
          
          // Try to rejoin after a delay if reconnection takes too long
          _reconnectTimer?.cancel();
          _reconnectTimer = Timer(const Duration(seconds: 10), () {
            if (_isReconnecting && _reconnectAttempts < _maxReconnectAttempts && mounted) {
              _reconnectAttempts++;
              _rejoinChannel();
            } else if (_reconnectAttempts >= _maxReconnectAttempts && mounted) {
              setState(() {
                _hasConnectionError = true;
                _connectionStatus = "Connection failed after multiple attempts";
              });
            }
          });
        } else if (state == ConnectionStateType.connectionStateFailed) {
          setState(() {
            _connectionStatus = "Connection failed. Please try again.";
            _hasConnectionError = true;
          });
        }
      },
      onError: (ErrorCodeType err, String msg) {
        debugPrint("Agora error: $err, $msg");
        
        if (!mounted) return;
        
        // Handle specific error codes
        if (err == ErrorCodeType.errInvalidAppId) {
          setState(() {
            _hasConnectionError = true;
            _connectionStatus = "Invalid App ID. Please check your configuration.";
          });
          return;
        }
        
        if (err == ErrorCodeType.errNotReady) {
          // These are recoverable errors, try to rejoin
          if (_reconnectAttempts < _maxReconnectAttempts) {
            _reconnectAttempts++;
            _rejoinChannel();
          } else {
            setState(() {
              _hasConnectionError = true;
              _connectionStatus = "Connection error: $msg";
            });
          }
        } else {
          setState(() {
            _hasConnectionError = true;
            _connectionStatus = "Connection error: $msg";
          });
        }
      },
    ));
  }

  // Rejoin channel after connection issues
  Future<void> _rejoinChannel() async {
    if (_engine == null || !mounted) return;
    
    try {
      setState(() {
        _connectionStatus = "Attempting to reconnect (${_reconnectAttempts}/${_maxReconnectAttempts})...";
        _isReconnecting = true;
      });
      
      await _engine!.leaveChannel();
      
      // Short delay before rejoining
      await Future.delayed(const Duration(seconds: 1));
      
      await _engine!.joinChannel(
        token: _generatedToken ?? widget.token,
        channelId: widget.channelName,
        uid: _uid,
        options: const ChannelMediaOptions(
          channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
          publishCameraTrack: true,
          publishMicrophoneTrack: true,
        ),
      );
    } catch (e) {
      debugPrint("Error rejoining channel: $e");
      if (mounted) {
        setState(() {
          _hasConnectionError = true;
          _connectionStatus = "Failed to reconnect: $e";
        });
      }
    }
  }

  // Toggle camera
  void _toggleCamera() {
    if (_engine == null || !mounted) return;
    
    setState(() {
      _localVideoEnabled = !_localVideoEnabled;
    });
    _engine!.enableLocalVideo(_localVideoEnabled);
  }

  // Toggle microphone
  void _toggleMicrophone() {
    if (_engine == null || !mounted) return;
    
    setState(() {
      _localAudioEnabled = !_localAudioEnabled;
    });
    _engine!.enableLocalAudio(_localAudioEnabled);
  }

  // Retry connection after error
  void _retryConnection() {
    if (!mounted) return;
    
    setState(() {
      _hasConnectionError = false;
      _reconnectAttempts = 0;
      _engine = null; // Reset engine to avoid initialization errors
      _connectionStatus = "Retrying connection...";
    });
    
    // Add a short delay before reinitializing
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        initAgora();
      }
    });
  }

  // Create UI with local view and remote view
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Virtual Visitation Room'),
        actions: [
          // Add a help button
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: () {
              _showHelpDialog();
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          // Main video area (remote user)
          Center(
            child: _remoteVideo(),
          ),
          
          // Local video preview
          Positioned(
            top: 10,
            right: 10,
            child: Container(
              width: 120,
              height: 160,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.blue, width: 2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: _localUserView(),
              ),
            ),
          ),
          
          // Connection status indicator
          if (_isInitializing || _isReconnecting || _hasConnectionError || (_isJoined && _remoteUid == 0))
            Positioned(
              top: 20,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: _hasConnectionError 
                        ? Colors.red.withAlpha((0.8 * 255).round())
                        : Colors.black.withAlpha((0.6 * 255).round()),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_isInitializing || _isReconnecting)
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        ),
                      if (_hasConnectionError)
                        const Icon(Icons.error_outline, color: Colors.white, size: 16),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          _connectionStatus,
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 2,
                        ),
                      ),
                      if (_hasConnectionError) ...[
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: _retryConnection,
                          style: TextButton.styleFrom(
                            backgroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            minimumSize: Size.zero,
                          ),
                          child: const Text('Retry', style: TextStyle(fontSize: 12)),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          
          // Controls overlay
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // End call button
                FloatingActionButton(
                  onPressed: () {
                    _engine?.leaveChannel();
                    Navigator.pop(context);
                  },
                  backgroundColor: Colors.red,
                  child: const Icon(Icons.call_end, color: Colors.white),
                ),
                
                const SizedBox(width: 20),
                
                // Toggle camera - available immediately
                FloatingActionButton(
                  onPressed: _isInitializing ? null : _toggleCamera,
                  backgroundColor: _localVideoEnabled ? Colors.blue : Colors.grey,
                  child: Icon(
                    _localVideoEnabled ? Icons.videocam : Icons.videocam_off,
                    color: Colors.white,
                  ),
                ),
                
                const SizedBox(width: 20),
                
                // Toggle microphone
                FloatingActionButton(
                  onPressed: _isInitializing ? null : _toggleMicrophone,
                  backgroundColor: _localAudioEnabled ? Colors.blue : Colors.grey,
                  child: Icon(
                    _localAudioEnabled ? Icons.mic : Icons.mic_off,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          
          // Waiting for others indicator
          if (_isJoined && _remoteUid == 0 && !_hasConnectionError && !_isInitializing)
            Container(
              color: Colors.black.withAlpha(100),
              child: Center(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Waiting for others to join...',
                          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Your camera is ${_localVideoEnabled ? 'ON' : 'OFF'}',
                          style: TextStyle(
                            color: _localVideoEnabled ? Colors.green : Colors.orange,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 10),
                        ElevatedButton.icon(
                          onPressed: _toggleCamera,
                          icon: Icon(_localVideoEnabled ? Icons.videocam_off : Icons.videocam),
                          label: Text(_localVideoEnabled ? 'Turn Camera Off' : 'Turn Camera On'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _localVideoEnabled ? Colors.orange : Colors.green,
                            foregroundColor: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 20),
                        // Display user role and name
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue.withAlpha((0.2 * 255).round()),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            children: [
                              Text(
                                'You are joining as: ${widget.role}',
                                style: const TextStyle(color: Colors.white, fontSize: 14),
                              ),
                              Text(
                                'Name: ${widget.userName}',
                                style: const TextStyle(color: Colors.white, fontSize: 14),
                              ),
                              Text(
                                'Room Code: ${widget.channelName}',
                                style: const TextStyle(color: Colors.white, fontSize: 14),
                              ),
                              Text(
                                'Your UID: $_uid',
                                style: const TextStyle(color: Colors.white, fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          
          // Connecting indicator
          if (!_isJoined && !_hasConnectionError)
            Container(
              color: Colors.black.withAlpha(100),
              child: Center(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(color: Colors.white),
                        const SizedBox(height: 20),
                        Text(
                          _connectionStatus,
                          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        if (_localVideoInitialized) ...[
                          Text(
                            'Your camera is ${_localVideoEnabled ? 'ON' : 'OFF'}',
                            style: TextStyle(
                              color: _localVideoEnabled ? Colors.green : Colors.orange,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 10),
                          ElevatedButton.icon(
                            onPressed: _toggleCamera,
                            icon: Icon(_localVideoEnabled ? Icons.videocam_off : Icons.videocam),
                            label: Text(_localVideoEnabled ? 'Turn Camera Off' : 'Turn Camera On'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _localVideoEnabled ? Colors.orange : Colors.green,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // Display remote user video
  Widget _remoteVideo() {
    if (_engine != null && _remoteUid != 0) {
      try {
        return AgoraVideoView(
          controller: VideoViewController.remote(
            rtcEngine: _engine!,
            canvas: VideoCanvas(uid: _remoteUid),
            connection: RtcConnection(channelId: widget.channelName),
          ),
        );
      } catch (e) {
        debugPrint("Error rendering remote video: $e");
        return Container(
          color: Colors.black.withAlpha(150),
          child: const Center(
            child: Text(
              'Error displaying remote video',
              style: TextStyle(color: Colors.white, fontSize: 18),
              textAlign: TextAlign.center,
            ),
          ),
        );
      }
    } else {
      return Container(
        color: Colors.black.withAlpha(150),
        child: const Center(
          child: Text(
            'Waiting for other participants to join...',
            style: TextStyle(color: Colors.white, fontSize: 18),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
  }

  // Display local video preview
  Widget _localUserView() {
    if (_engine == null) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: Text(
            'Video engine not initialized',
            style: TextStyle(color: Colors.white, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    
    if (_localVideoInitialized) {
      try {
        return _localVideoEnabled
            ? AgoraVideoView(
                controller: VideoViewController(
                  rtcEngine: _engine!,
                  canvas: const VideoCanvas(uid: 0),
                ),
              )
            : Container(
                color: Colors.black,
                child: const Center(
                  child: Icon(Icons.videocam_off, color: Colors.white, size: 40),
                ),
              );
      } catch (e) {
        debugPrint("Error rendering local video: $e");
        return Container(
          color: Colors.black,
          child: const Center(
            child: Text(
              'Camera error',
              style: TextStyle(color: Colors.white, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ),
        );
      }
    } else {
      return Container(
        color: Colors.black,
        child: const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }
  }

  // Show help dialog with troubleshooting tips
  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Video Call Help'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Troubleshooting Tips:', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              Text('• Make sure you have a stable internet connection'),
              Text('• Check that your camera and microphone permissions are granted'),
              Text('• Try turning your camera off and on again'),
              Text('• If the other person can\'t see you, try leaving and rejoining'),
              Text('• Make sure the other person has also joined the correct room'),
              Text('• Make sure both users are using the same channel name'),
              Text('• Your UID: $_uid - Share this with support if needed'),
              if (_connectionStatus.contains("-17") || _connectionStatus.contains("Invalid App ID"))
                Text('• Error -17 usually indicates an invalid App ID or permission issue. Contact support if this persists.', 
                     style: TextStyle(color: Colors.red)),
              SizedBox(height: 16),
              Text('Controls:', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              Text('• Red button: End call'),
              Text('• Blue camera button: Toggle camera on/off'),
              Text('• Blue microphone button: Toggle microphone on/off'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _retryConnection();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
            ),
            child: const Text('Retry Connection'),
          ),
        ],
      ),
    );
  }
}
