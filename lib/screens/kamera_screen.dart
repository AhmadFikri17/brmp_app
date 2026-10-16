import 'dart:async';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import '../services/camera_service.dart';

class KameraScreen extends StatefulWidget {
  const KameraScreen({super.key});

  @override
  State<KameraScreen> createState() => _KameraScreenState();
}

class _KameraScreenState extends State<KameraScreen> {
  String? _cameraUrl;
  String? _cameraError;
  bool _isWebViewReady = false;
  bool _hasStartedLoading = false;
  String? _lastLoadedIp;

  final CameraService _cameraService = CameraService();
  late final WebViewController _webViewController;
  StreamSubscription<String?>? _cameraIpSubscription;
  Timer? _loadingTimeoutTimer;

  @override
  void initState() {
    super.initState();

    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF000000))
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            if (progress > 10 && !_hasStartedLoading) {
              _hasStartedLoading = true;
              debugPrint('📹 Stream mulai ter-load ($progress%)');
              if (mounted) {
                setState(() => _isWebViewReady = true);
              }
              _loadingTimeoutTimer?.cancel();
            }
          },
          onPageStarted: (String url) {
            debugPrint('🌐 Page started: $url');
            if (mounted) {
              setState(() {
                _isWebViewReady = false;
                _hasStartedLoading = false;
              });
            }
            _loadingTimeoutTimer?.cancel();
            _loadingTimeoutTimer = Timer(const Duration(seconds: 20), () {
              if (!_hasStartedLoading && mounted) {
                setState(() {
                  _cameraError = 'Timeout memuat stream.\n'
                      'Chrome bisa buka, tapi WebView tidak.\n'
                      'Cek AndroidManifest usesCleartextTraffic.';
                });
                debugPrint('❌ Timeout loading stream');
              }
            });
          },
          onPageFinished: (String url) {
            debugPrint('✅ Page finished: $url');
            if (mounted) {
              setState(() => _isWebViewReady = true);
            }
            _loadingTimeoutTimer?.cancel();
          },
          onWebResourceError: (WebResourceError error) {
            // Abaikan ERR_ABORTED — normal untuk MJPEG
            if (error.errorCode == -10 ||
                error.description.contains('ERR_ABORTED')) {
              return;
            }
            debugPrint('❌ WebView error: ${error.description} '
                '(code: ${error.errorCode})');
            if (mounted) {
              setState(() {
                _cameraError = 'Gagal memuat stream: ${error.description}';
              });
            }
          },
        ),
      );

    // ✅ KUNCI PERBAIKAN: Set mixed content mode untuk Android
    if (_webViewController.platform is AndroidWebViewController) {
      final androidController =
          _webViewController.platform as AndroidWebViewController;
      androidController.setMediaPlaybackRequiresUserGesture(false);
      androidController.setMixedContentMode(MixedContentMode.alwaysAllow);
      debugPrint('✅ Android WebView: MixedContentMode = alwaysAllow');
    } else {
      debugPrint('⚠️ Bukan Android WebView, skip mixed content mode');
    }

    _initializeCamera();
  }

  void _initializeCamera() {
    _cameraIpSubscription?.cancel();
    _cameraIpSubscription = _cameraService.getCameraIpStream().listen((ip) {
      if (!mounted) return;
      if (ip == _lastLoadedIp) return;

      if (ip != null && ip.isNotEmpty) {
        _lastLoadedIp = ip;
        final url = 'http://$ip:81/stream';

        setState(() {
          _cameraUrl = url;
          _cameraError = null;
          _isWebViewReady = false;
          _hasStartedLoading = false;
        });

        debugPrint('📷 Loading stream: $url');
        _webViewController.loadRequest(Uri.parse(url));

        _loadingTimeoutTimer?.cancel();
        _loadingTimeoutTimer = Timer(const Duration(seconds: 20), () {
          if (!_hasStartedLoading && mounted) {
            debugPrint('⚠️ Timeout loading. Cek AndroidManifest.');
            setState(() {
              _cameraError = 'Stream tidak merespon.\n'
                  'Cek: usesCleartextTraffic di AndroidManifest.';
            });
          }
        });
      } else {
        setState(() {
          _cameraError = 'Menunggu IP kamera...';
        });
      }
    });
  }

  @override
  void dispose() {
    _cameraIpSubscription?.cancel();
    _loadingTimeoutTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F9F9),
      appBar: AppBar(
        title: const Text('Kamera'),
        backgroundColor: const Color(0xFF2D6A4F),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _reloadStream,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  void _reloadStream() {
    setState(() {
      _cameraError = null;
      _isWebViewReady = false;
      _hasStartedLoading = false;
    });
    _loadingTimeoutTimer?.cancel();

    if (_cameraUrl != null) {
      _webViewController.loadRequest(Uri.parse(_cameraUrl!));
    } else {
      _initializeCamera();
    }
  }

  Widget _buildBody() {
    if (_cameraError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.videocam_off, size: 60, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              Text(
                _cameraError!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade700),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _reloadStream,
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2D6A4F),
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_cameraUrl == null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Menunggu IP kamera...'),
          ],
        ),
      );
    }

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
          color:
              _isWebViewReady ? Colors.green.shade50 : Colors.orange.shade50,
          child: Row(
            children: [
              Icon(
                Icons.circle,
                size: 8,
                color: _isWebViewReady ? Colors.green : Colors.orange,
              ),
              const SizedBox(width: 8),
              Text(
                _isWebViewReady ? '🟢 Live Stream' : '🟠 Memuat stream...',
                style: TextStyle(
                  fontSize: 12,
                  color: _isWebViewReady
                      ? Colors.green.shade700
                      : Colors.orange.shade700,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              Flexible(
                child: Text(
                  _cameraUrl ?? '',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Stack(
            children: [
              WebViewWidget(controller: _webViewController),
              if (!_isWebViewReady)
                Container(
                  color: Colors.black,
                  child: const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: Colors.white),
                        SizedBox(height: 16),
                        Text(
                          'Memuat stream kamera...',
                          style: TextStyle(color: Colors.white),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Butuh 5-15 detik saat pertama kali',
                          style:
                              TextStyle(color: Colors.white70, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}