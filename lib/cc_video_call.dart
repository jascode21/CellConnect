import 'package:flutter/material.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';
import 'dart:math';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Enhanced Video Call Page with role-based call control
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
  bool _isWaitingRoomMinimized = false;
  bool _isCallEnded = false; // Track if call has been ended
  bool _hasLoggedActivity = false; // Prevent duplicate activity logs
  bool _staffEndedCall = false; // Track if staff ended the call
  bool _canVisitorExit = false; // Track if visitor can exit after staff ended call
  String _connectionStatus = "Initializing...";
  int _reconnectAttempts = 0;
  final int _maxReconnectAttempts = 3;
  Timer? _connectionTimer;
  Timer? _reconnectTimer;
  Timer? _callDurationTimer;
  late AnimationController _animationController;
  String? _generatedToken;
  int _uid = 0;
  Duration _callDuration = Duration.zero;
  int _connectionQuality = 0; // 0-5, where 5 is best

  // Track if we've seen a remote user at least once
  bool _hasSeenRemoteUser = false;
  
  // Track remote user details for activity logging
  String? _remoteUserName;
  String? _remoteUserId;
  DateTime? _callStartTime; // Track when the call actually started

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

    // Start call duration timer
    _startCallDurationTimer();
  }

  void _startCallDurationTimer() {
    _callDurationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted && !_isCallEnded) {
        setState(() {
          _callDuration += const Duration(seconds: 1);
        });
      }
    });
  }

  @override
  void dispose() {
    _connectionTimer?.cancel();
    _reconnectTimer?.cancel();
    _callDurationTimer?.cancel();
    _animationController.dispose();
    
    // Clean up Agora resources
    _cleanupAgoraResources();
    
    super.dispose();
  }

  Future<void> _cleanupAgoraResources() async {
    try {
      if (_engine != null) {
        await _engine!.leaveChannel();
        await _engine!.release();
        _engine = null;
      }
    } catch (e) {
      debugPrint("Error cleaning up Agora resources: $e");
    }
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
            // Mark call start time when both users are connected
            if (_callStartTime == null) {
              _callStartTime = DateTime.now();
            }
          });
          
          // Try to get remote user details for activity logging
          _getRemoteUserDetails(remoteUid);
        }
      },
      onUserOffline: (RtcConnection connection, int remoteUid, UserOfflineReasonType reason) {
        debugPrint("remote user $remoteUid left channel, reason: $reason");
        if (mounted) {
          setState(() {
            _remoteUid = 0;
          });
          
          // Handle different scenarios based on user role and call state
          if (_isStaffMember()) {
            // If staff member and remote user left, just update status
            setState(() {
              _connectionStatus = "Other participant left the call";
            });
            
            // Log activity if we haven't logged yet and call actually started
            if (!_hasLoggedActivity && _callStartTime != null) {
              _logVirtualSessionEnded();
            }
          } else {
            // If visitor and remote user (staff) left
            if (!_staffEndedCall) {
              // Staff left without properly ending call
              setState(() {
                _connectionStatus = "Staff member left the call";
                _staffEndedCall = true;
                _canVisitorExit = true;
              });
            }
          }
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
      onNetworkQuality: (RtcConnection connection, int remoteUid, QualityType txQuality, QualityType rxQuality) {
        if (mounted) {
          setState(() {
            // Use the better quality between tx and rx
            _connectionQuality = max(txQuality.index, rxQuality.index);
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

  // Check if current user is staff member
  bool _isStaffMember() {
    return widget.role.toLowerCase() == 'staff' || 
           widget.role.toLowerCase() == 'admin' ||
           widget.role.toLowerCase() == 'officer';
  }

  // Check if current user is visitor
  bool _isVisitor() {
    return widget.role.toLowerCase() == 'visitor';
  }

  // Get remote user details for activity logging
  Future<void> _getRemoteUserDetails(int remoteUid) async {
    try {
      // In a real implementation, you would query your user database
      // to get the user details based on the remote UID or channel name
      // For now, we'll try to get visitor details from the visit record
      
      final visitsSnapshot = await FirebaseFirestore.instance
          .collection('visits')
          .where('visitationCode', isEqualTo: widget.channelName)
          .get();
      
      if (visitsSnapshot.docs.isNotEmpty) {
        final visitData = visitsSnapshot.docs.first.data();
        _remoteUserName = visitData['visitorName'] ?? 'Unknown Visitor';
        _remoteUserId = visitData['visitorId'] ?? '';
        
        debugPrint("Remote user details: $_remoteUserName ($_remoteUserId)");
      }
    } catch (e) {
      debugPrint("Error getting remote user details: $e");
      _remoteUserName = 'Unknown Visitor';
    }
  }

  // Log virtual session ended activity - only for staff members
  Future<void> _logVirtualSessionEnded() async {
    // Prevent duplicate logging
    if (_hasLoggedActivity || !_isStaffMember()) {
      return;
    }

    _hasLoggedActivity = true; // Set flag to prevent duplicate logs

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      
      // Get current user details
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      
      String currentUserName = 'Staff';
      
      if (userDoc.exists) {
        final userData = userDoc.data()!;
        currentUserName = userData['fullName'] ?? 
                         '${userData['firstName'] ?? ''} ${userData['lastName'] ?? ''}'.trim();
      }
      
      // Determine the visitor name for the activity log
      String visitorName = _remoteUserName ?? 'Unknown Visitor';
      
      // Calculate session duration
      int sessionDurationMinutes = 0;
      if (_callStartTime != null) {
        final endTime = DateTime.now();
        sessionDurationMinutes = endTime.difference(_callStartTime!).inMinutes;
      }
      
      // Log the activity - only when staff ends the call
      await FirebaseFirestore.instance
          .collection('activities')
          .add({
        'type': 'visit_ended',
        'visitType': 'virtual',
        'userName': visitorName,
        'userId': _remoteUserId ?? 'unknown',
        'userRole': 'Visitor',
        'staffName': currentUserName,
        'staffId': user.uid,
        'channelName': widget.channelName,
        'sessionDuration': sessionDurationMinutes,
        'timestamp': FieldValue.serverTimestamp(),
        'description': 'Virtual session ended by staff with $visitorName (Duration: ${sessionDurationMinutes}min)',
        'endedBy': 'staff', // Track who ended the call
      });
      
      debugPrint("Logged virtual session ended activity for visitor: $visitorName (Duration: ${sessionDurationMinutes}min)");
    } catch (e) {
      debugPrint("Error logging virtual session ended activity: $e");
    }
  }

  // Rejoin channel after connection issues
  Future<void> _rejoinChannel() async {
    if (_engine == null || !mounted || _isCallEnded) return;
    
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
    if (_engine == null || !mounted || _isCallEnded) return;
    
    setState(() {
      _localVideoEnabled = !_localVideoEnabled;
    });
    _engine!.enableLocalVideo(_localVideoEnabled);
  }

  // Toggle microphone
  void _toggleMicrophone() {
    if (_engine == null || !mounted || _isCallEnded) return;
    
    setState(() {
      _localAudioEnabled = !_localAudioEnabled;
    });
    _engine!.enableLocalAudio(_localAudioEnabled);
  }

  // Retry connection after error
  void _retryConnection() {
    if (!mounted || _isCallEnded) return;
    
    setState(() {
      _hasConnectionError = false;
      _reconnectAttempts = 0;
      _engine = null; // Reset engine to avoid initialization errors
      _connectionStatus = "Retrying connection...";
    });
    
    // Add a short delay before reinitializing
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted && !_isCallEnded) {
        initAgora();
      }
    });
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$hours:$minutes:$seconds";
  }

  Widget _buildConnectionQualityIndicator() {
    final quality = _connectionQuality;
    final color = quality >= 4 ? Colors.green : 
                 quality >= 2 ? Colors.orange : 
                 Colors.red;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.signal_cellular_alt,
            color: color,
            size: 16,
          ),
          const SizedBox(width: 4),
          Text(
            quality >= 4 ? 'Excellent' :
            quality >= 2 ? 'Good' : 'Poor',
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  void _copyRoomCode() {
    Clipboard.setData(ClipboardData(text: widget.channelName));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Room code copied to clipboard'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  // Display waiting room with improved UI
  Widget _buildWaitingRoom() {
    if (_isWaitingRoomMinimized) {
      return Positioned(
        bottom: 20,
        right: 20,
        child: GestureDetector(
          onTap: () {
            setState(() {
              _isWaitingRoomMinimized = false;
            });
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.8),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.people_outline,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Waiting Room',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.expand_less,
                  color: Colors.white.withOpacity(0.7),
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withOpacity(0.8),
            Colors.black.withOpacity(0.6),
          ],
        ),
      ),
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          constraints: BoxConstraints(
            maxWidth: 400,
            maxHeight: MediaQuery.of(context).size.height * 0.7,
          ),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Colors.white.withOpacity(0.2),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.people_outline,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.minimize, color: Colors.white, size: 20),
                        onPressed: () {
                          setState(() {
                            _isWaitingRoomMinimized = true;
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Waiting for others to join...',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Share this room code with the other participant',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        _buildInfoRow('Role', widget.role),
                        const SizedBox(height: 12),
                        _buildInfoRow('Name', widget.userName),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.2),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Room Code',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Row(
                                children: [
                                  Text(
                                    widget.channelName,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    icon: const Icon(Icons.copy, color: Colors.white70, size: 18),
                                    onPressed: _copyRoomCode,
                                    tooltip: 'Copy Room Code',
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildInfoRow('Your ID', _uid.toString()),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton.icon(
                        onPressed: _copyRoomCode,
                        icon: const Icon(Icons.copy, size: 16),
                        label: const Text('Copy Code'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: () {
                          // TODO: Implement share functionality
                        },
                        icon: const Icon(Icons.share, size: 16),
                        label: const Text('Share'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Build call ended overlay for visitors
  Widget _buildCallEndedOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.9),
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.call_end,
                  size: 48,
                  color: Colors.orange,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Call Ended by Staff',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'The staff member has ended the virtual visit session.',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Duration: ${_formatDuration(_callDuration)}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade700,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    // Clean up and exit
                    await _cleanupAgoraResources();
                    if (mounted) {
                      Navigator.of(context).pop();
                    }
                  },
                  icon: const Icon(Icons.exit_to_app),
                  label: const Text('Exit Call'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildControlButton({
    required VoidCallback? onPressed,
    required IconData icon,
    required Color backgroundColor,
    required Color iconColor,
    bool isLarge = false,
    String? label,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: FloatingActionButton(
            onPressed: onPressed,
            backgroundColor: backgroundColor,
            elevation: 0,
            mini: !isLarge,
            child: Icon(
              icon,
              color: iconColor,
              size: isLarge ? 28 : 24,
            ),
          ),
        ),
        if (label != null) ...[
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
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

  // Show help dialog with improved styling
  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: Colors.white,
        title: Row(
          children: [
            const Icon(Icons.help_outline, color: Colors.blue),
            const SizedBox(width: 8),
            const Text(
              'Video Call Help',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Troubleshooting Tips:',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
              const SizedBox(height: 12),
              _buildHelpItem('Make sure you have a stable internet connection'),
              _buildHelpItem('Check that your camera and microphone permissions are granted'),
              _buildHelpItem('Try turning your camera off and on again'),
              _buildHelpItem('If the other person can\'t see you, try leaving and rejoining'),
              _buildHelpItem('Make sure the other person has also joined the correct room'),
              _buildHelpItem('Make sure both users are using the same channel name'),
              _buildHelpItem('Your UID: $_uid - Share this with support if needed'),
              if (_connectionStatus.contains("-17") || _connectionStatus.contains("Invalid App ID"))
                _buildHelpItem(
                  'Error -17 usually indicates an invalid App ID or permission issue. Contact support if this persists.',
                  isError: true,
                ),
              const SizedBox(height: 16),
              const Text(
                'Controls:',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
              const SizedBox(height: 12),
              if (_isStaffMember()) ...[
                _buildHelpItem('Red button: End call (Staff only)'),
                _buildHelpItem('Blue camera button: Toggle camera on/off'),
                _buildHelpItem('Blue microphone button: Toggle microphone on/off'),
              ] else ...[
                _buildHelpItem('Camera and microphone controls available'),
                _buildHelpItem('Only staff can end the call'),
                _buildHelpItem('You can exit after staff ends the call'),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Close',
              style: TextStyle(color: Colors.blue),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _retryConnection();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Retry Connection'),
          ),
        ],
      ),
    );
  }

  Widget _buildHelpItem(String text, {bool isError = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.circle,
            size: 8,
            color: isError ? Colors.red : Colors.blue,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: isError ? Colors.red : Colors.black87,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showExitConfirmation() {
    // Only staff can show exit confirmation during active call
    if (_isVisitor() && !_canVisitorExit) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Only staff can end the call. Please wait for staff to end the session.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: Colors.white,
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.orange),
            const SizedBox(width: 8),
            Text(
              _isStaffMember() ? 'End Call?' : 'Leave Call?',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Text(
          _isStaffMember() 
              ? 'Are you sure you want to end the call? This will end the video session for all participants.'
              : 'Are you sure you want to leave the call?',
          style: const TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.blue),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              // Close the confirmation dialog
              Navigator.pop(context);
              
              // End the call properly
              await _endCall();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(_isStaffMember() ? 'End Call' : 'Leave Call'),
          ),
        ],
      ),
    );
  }

  // Properly end the call with cleanup and logging
  Future<void> _endCall() async {
    if (_isCallEnded) return; // Prevent multiple calls
    
    setState(() {
      _isCallEnded = true;
    });

    try {
      // If staff is ending the call, log the activity and notify visitor
      if (_isStaffMember()) {
        // Log the virtual session ended activity
        if (!_hasLoggedActivity && _callStartTime != null) {
          await _logVirtualSessionEnded();
        }
        
        // Set flag that staff ended the call
        setState(() {
          _staffEndedCall = true;
        });
        
        // If there's a remote user (visitor), don't exit immediately
        // Let the visitor see the "call ended" message and exit themselves
        if (_remoteUid != 0) {
          // Just clean up Agora resources but stay on the page
          await _cleanupAgoraResources();
          return;
        }
      }

      // Stop timers
      _connectionTimer?.cancel();
      _reconnectTimer?.cancel();
      _callDurationTimer?.cancel();

      // Clean up Agora resources
      await _cleanupAgoraResources();

      // Exit the call screen
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      debugPrint("Error ending call: $e");
      // Still try to exit even if there's an error
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  // Update the build method to use the new waiting room
  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // Only allow back navigation if visitor can exit or if staff
        if (_isVisitor() && !_canVisitorExit) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Only staff can end the call. Please wait for staff to end the session.'),
              backgroundColor: Colors.orange,
            ),
          );
          return false;
        }
        _showExitConfirmation();
        return false; // Prevent default back button behavior
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () {
              // Only allow back navigation if visitor can exit or if staff
              if (_isVisitor() && !_canVisitorExit) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Only staff can end the call. Please wait for staff to end the session.'),
                    backgroundColor: Colors.orange,
                  ),
                );
                return;
              }
              _showExitConfirmation();
            },
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.video_call,
                      color: Colors.white.withOpacity(0.9),
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Virtual Visitation Room',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            if (_isJoined && _remoteUid != 0)
              Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: _buildConnectionQualityIndicator(),
              ),
            IconButton(
              icon: const Icon(Icons.help_outline, color: Colors.white),
              onPressed: _showHelpDialog,
            ),
          ],
        ),
        body: Stack(
          children: [
            // Main video area (remote user)
            Center(
              child: _remoteVideo(),
            ),
            
            // Local video preview with improved styling
            Positioned(
              top: 16,
              right: 16,
              child: Container(
                width: 120,
                height: 160,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white.withOpacity(0.3), width: 2),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: _localUserView(),
                    ),
                    if (!_localVideoEnabled)
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.videocam_off, color: Colors.white, size: 32),
                              SizedBox(height: 8),
                              Text(
                                'Camera Off',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            
            // Call duration indicator with improved styling
            if (_isJoined && _remoteUid != 0)
              Positioned(
                top: 20,
                left: 20,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.timer,
                        color: Colors.white,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatDuration(_callDuration),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            
            // Connection status indicator with improved styling
            if (_isInitializing || _isReconnecting || _hasConnectionError || (_isJoined && _remoteUid == 0))
              Positioned(
                top: 20,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    decoration: BoxDecoration(
                      color: _hasConnectionError 
                          ? Colors.red.withOpacity(0.9)
                          : Colors.black.withOpacity(0.8),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                        color: _hasConnectionError 
                            ? Colors.red.withOpacity(0.3)
                            : Colors.white.withOpacity(0.2),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_isInitializing || _isReconnecting)
                          const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          ),
                        if (_hasConnectionError)
                          const Icon(Icons.error_outline, color: Colors.white, size: 24),
                        const SizedBox(width: 16),
                        Flexible(
                          child: Text(
                            _connectionStatus,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0.3,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 2,
                          ),
                        ),
                        if (_hasConnectionError) ...[
                          const SizedBox(width: 16),
                          TextButton(
                            onPressed: _retryConnection,
                            style: TextButton.styleFrom(
                              backgroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              minimumSize: Size.zero,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                            child: const Text(
                              'Retry',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.red,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            
            // Waiting room with improved UI
            if (_isJoined && _remoteUid == 0 && !_hasConnectionError && !_isInitializing && !_staffEndedCall)
              _buildWaitingRoom(),

            // Call ended overlay for visitors
            if (_isVisitor() && _staffEndedCall)
              _buildCallEndedOverlay(),

            // Control buttons overlay with role-based restrictions
            if (!(_isVisitor() && _staffEndedCall))
              Positioned(
                bottom: 40,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withOpacity(0.9),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildControlButton(
                        onPressed: (_isInitializing || _isCallEnded) ? null : _toggleMicrophone,
                        icon: _localAudioEnabled ? Icons.mic : Icons.mic_off,
                        backgroundColor: _localAudioEnabled ? Colors.white : Colors.red,
                        iconColor: _localAudioEnabled ? Colors.blue : Colors.white,
                        label: _localAudioEnabled ? 'Mute' : 'Unmute',
                      ),
                      
                      const SizedBox(width: 32),
                      
                      // Only show end call button for staff, or for visitors if they can exit
                      if (_isStaffMember() || (_isVisitor() && _canVisitorExit))
                        _buildControlButton(
                          onPressed: _isCallEnded ? null : _showExitConfirmation,
                          icon: Icons.call_end,
                          backgroundColor: Colors.red,
                          iconColor: Colors.white,
                          isLarge: true,
                          label: _isStaffMember() ? 'End Call' : 'Leave Call',
                        )
                      else
                        // Show disabled button for visitors during active call
                        _buildControlButton(
                          onPressed: null,
                          icon: Icons.call_end,
                          backgroundColor: Colors.grey,
                          iconColor: Colors.white,
                          isLarge: true,
                          label: 'Staff Only',
                        ),
                      
                      const SizedBox(width: 32),
                      
                      _buildControlButton(
                        onPressed: (_isInitializing || _isCallEnded) ? null : _toggleCamera,
                        icon: _localVideoEnabled ? Icons.videocam : Icons.videocam_off,
                        backgroundColor: _localVideoEnabled ? Colors.white : Colors.red,
                        iconColor: _localVideoEnabled ? Colors.blue : Colors.white,
                        label: _localVideoEnabled ? 'Turn Off' : 'Turn On',
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
