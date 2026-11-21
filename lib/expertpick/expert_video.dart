import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import 'expert_scrip.dart';

bool get showExpertPlayer {
  final binding = WidgetsBinding.instance.runtimeType.toString();
  return !binding.contains('Test');
}

class ExpertVideo extends StatefulWidget {
  const ExpertVideo({super.key, required this.url});

  final String url;

  @override
  State<ExpertVideo> createState() => _ExpertVideoState();
}

class _ExpertVideoState extends State<ExpertVideo> {
  WebViewController? _controller;

  @override
  void initState() {
    super.initState();
    final videoId = youtubeVideoId(widget.url);
    if (videoId == null || !showExpertPlayer) return;
    final embed = Uri.https('www.youtube-nocookie.com', '/embed/$videoId', {
      'playsinline': '1',
      'fs': '0',
      'rel': '0',
      'controls': '1',
      'autoplay': '0',
      'modestbranding': '1',
      'iv_load_policy': '3',
    });
    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF000000))
      ..setNavigationDelegate(
        NavigationDelegate(onNavigationRequest: _keepInsidePlayer),
      )
      ..loadRequest(
        embed,
        headers: const {'Referer': 'https://www.youtube-nocookie.com/'},
      );
    final platform = controller.platform;
    if (platform is AndroidWebViewController) {
      platform.setMediaPlaybackRequiresUserGesture(true);
      platform.setCustomWidgetCallbacks(
        onShowCustomWidget: (_, hide) => hide(),
        onHideCustomWidget: () {},
      );
    }
    _controller = controller;
  }

  NavigationDecision _keepInsidePlayer(NavigationRequest request) {
    final uri = Uri.tryParse(request.url);
    if (uri == null) return NavigationDecision.prevent;
    if (uri.scheme == 'about' || uri.scheme == 'blob' || uri.scheme == 'data') {
      return NavigationDecision.navigate;
    }
    if (uri.scheme != 'https') return NavigationDecision.prevent;
    final host = uri.host.toLowerCase();
    const suffixes = [
      'youtube.com',
      'youtube-nocookie.com',
      'googlevideo.com',
      'ytimg.com',
      'ggpht.com',
      'googleapis.com',
      'gstatic.com',
      'google.com',
      'googleusercontent.com',
    ];
    final allowed = suffixes.any(
      (suffix) => host == suffix || host.endsWith('.$suffix'),
    );
    if (!allowed) return NavigationDecision.prevent;
    if (host == 'youtu.be' ||
        uri.path == '/watch' ||
        uri.path.startsWith('/redirect') ||
        uri.path.startsWith('/signin')) {
      return NavigationDecision.prevent;
    }
    return NavigationDecision.navigate;
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return Semantics(
      label: 'Expert video',
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: ColoredBox(
          color: const Color(0xFF000000),
          child: controller == null
              ? const SizedBox.expand()
              : WebViewWidget(
                  controller: controller,
                  gestureRecognizers: {
                    Factory<OneSequenceGestureRecognizer>(
                      EagerGestureRecognizer.new,
                    ),
                  },
                ),
        ),
      ),
    );
  }
}
