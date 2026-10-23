import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../models/server_config.dart';
import '../services/media_prefs.dart';
import '../services/storage_service.dart';
import '../services/notification_service.dart';
import 'home_shell.dart';
import 'settings_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  VideoPlayerController? _videoController;
  Future<List<ServerConfig>?>? _profilesFuture;
  bool _isVideoInitialized = false;
  bool _isNavigating = false;
  bool _skipRequested = false;
  int _navigationGeneration = 0;

  @override
  void initState() {
    super.initState();
    _initVideoAndBootstrap();
  }

  Future<void> _initVideoAndBootstrap() async {
    _profilesFuture = _loadProfiles();
    _initializeNotifications();

    try {
      final mode = await MediaPrefs.splashMode();
      if (mode != MediaMode.off) {
        final customPath =
            mode == MediaMode.custom ? await MediaPrefs.splashPath() : null;
        final controller = customPath == null
            ? VideoPlayerController.asset('assets/video/splash_video.mp4')
            : VideoPlayerController.file(File(customPath));
        _videoController = controller;
        try {
          await controller.initialize().timeout(
                const Duration(seconds: 4),
              );
          await controller.setLooping(false);
          await controller.setVolume(1);
          if (mounted) {
            setState(() => _isVideoInitialized = true);
            await controller.play();
          }
        } catch (error) {
          debugPrint('Splash video failed to load: $error');
          await controller.dispose();
          _videoController = null;
        }
      }
    } catch (error) {
      debugPrint('Could not load splash settings: $error');
    }

    if (!_isNavigating && _isVideoInitialized) {
      final remainingDuration =
          _videoController!.value.duration - _videoController!.value.position;
      if (remainingDuration > Duration.zero) {
        await Future.delayed(
          remainingDuration > const Duration(seconds: 7)
              ? const Duration(seconds: 7)
              : remainingDuration,
        );
      }
    } else if (!_isNavigating) {
      await Future.delayed(const Duration(milliseconds: 700));
    }

    await _navigate();
  }

  Future<void> _navigate({bool skip = false}) async {
    if (!mounted || (_isNavigating && !skip) || (skip && _skipRequested)) {
      return;
    }
    _isNavigating = true;
    final generation = ++_navigationGeneration;
    _videoController?.pause();
    if (skip) {
      _skipRequested = true;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeShell()),
      );
      return;
    }
    final profiles = await (_profilesFuture ?? _loadProfiles());
    if (!mounted || generation != _navigationGeneration) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => profiles == null || profiles.isNotEmpty
            ? const HomeShell()
            : const SettingsScreen(firstRun: true),
      ),
    );
  }

  Future<List<ServerConfig>?> _loadProfiles() async {
    try {
      return await StorageService().loadProfiles().timeout(
            const Duration(seconds: 5),
          );
    } catch (e) {
      debugPrint('Error loading saved server profiles: $e');
      return null;
    }
  }

  void _initializeNotifications() {
    NotificationService.instance
        .init()
        .timeout(const Duration(seconds: 4))
        .catchError((Object error) {
      debugPrint('Notification initialization failed: $error');
    });
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (_isVideoInitialized)
            FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: _videoController!.value.size.width,
                height: _videoController!.value.size.height,
                child: VideoPlayer(_videoController!),
              ),
            )
          else
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: Image.asset(
                      'assets/icon/app_icon.png',
                      width: 132,
                      height: 132,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'RFMonitor',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 18),
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Color(0xFF00F2FE),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Positioned(
              right: 16,
              bottom: 16,
              child: SafeArea(
                child: FilledButton.icon(
                  onPressed: () => _navigate(skip: true),
                  icon: const Icon(Icons.skip_next_rounded),
                  label: const Text('Lewati'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(120, 46),
                    backgroundColor: const Color(0xFF00BFD4),
                    foregroundColor: Colors.black,
                  ),
                ),
              )),
        ],
      ),
    );
  }
}
