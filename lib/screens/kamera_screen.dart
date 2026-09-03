import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../services/camera_service.dart';

class KameraScreen extends StatefulWidget {
  const KameraScreen({super.key});

  @override
  State<KameraScreen> createState() => _KameraScreenState();
}

class _KameraScreenState extends State<KameraScreen> {
  String? _cameraUrl;
  String? _cameraError;
  bool _isLoading = true;
  bool _isWebViewReady = false;
  final CameraService _cameraService = CameraService();
  late final WebViewController _webViewController;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    
    // Initialize WebView controller
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            debugPrint('WebView loading: $progress%');
          },
          onPageStarted: (String url) {
            setState(() {
              _isLoading = true;
            });
          },
          onPageFinished: (String url) {
            setState(() {
              _isLoading = false;
              _isWebViewReady = true;
            });
            debugPrint('✅ WebView loaded: $url');
          },
          onWebResourceError: (WebResourceError error) {
            setState(() {
              _cameraError = 'Gagal memuat stream: ${error.description}';
              _isLoading = false;
            });
            debugPrint('❌ WebView error: ${error.description}');
          },
        ),
      )
      ..setBackgroundColor(const Color(0xFFF5F9F9));
  }

  void _initializeCamera() {
    _cameraService.getCameraIpStream().listen((ip) {
      if (mounted) {
        setState(() {
          if (ip != null && ip.isNotEmpty) {
            _cameraUrl = 'http://$ip:81/stream';
            _cameraError = null;
            _isLoading = true;
            _isWebViewReady = false;
            debugPrint('📷 Camera URL: $_cameraUrl');
            
            // Load URL ke WebView
            _webViewController.loadRequest(Uri.parse(_cameraUrl!));
          } else {
            _cameraError = 'Menunggu IP kamera...';
            _isLoading = false;
          }
        });
      }
    });
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
            onPressed: () {
              setState(() {
                _isLoading = true;
                _cameraError = null;
                _isWebViewReady = false;
              });
              if (_cameraUrl != null) {
                _webViewController.reload();
              } else {
                _initializeCamera();
              }
            },
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading && !_isWebViewReady) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Memuat stream kamera...'),
          ],
        ),
      );
    }

    if (_cameraError != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.videocam_off, size: 60, color: Colors.grey.shade400), // 🔥 PERBAIKAN
            const SizedBox(height: 16),
            Text(
              _cameraError!,
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            Text(
              'Pastikan ESP32-CAM terhubung ke jaringan',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _isLoading = true;
                  _cameraError = null;
                });
                _initializeCamera();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2D6A4F),
                foregroundColor: Colors.white,
              ),
              child: const Text('Refresh'),
            ),
          ],
        ),
      );
    }

    if (_cameraUrl == null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.videocam_off, size: 60, color: Colors.grey),
            SizedBox(height: 16),
            Text('URL kamera tidak tersedia'),
          ],
        ),
      );
    }

    // Tampilkan WebView
    return Column(
      children: [
        if (!_isLoading && _isWebViewReady)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
            color: Colors.green.shade50,
            child: Row(
              children: [
                const Icon(Icons.circle, size: 8, color: Colors.green),
                const SizedBox(width: 8),
                Text(
                  '🟢 Live Stream',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.green.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                Text(
                  _cameraUrl?.replaceAll('http://', '').replaceAll(':81/stream', '') ?? '',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: WebViewWidget(controller: _webViewController),
        ),
      ],
    );
  }
}