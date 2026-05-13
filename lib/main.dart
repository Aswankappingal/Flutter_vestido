import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:url_launcher/url_launcher.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.white,
      ),
      home: const WebViewApp(),
    ),
  );
}

class WebViewApp extends StatefulWidget {
  const WebViewApp({super.key});

  @override
  State<WebViewApp> createState() => _WebViewAppState();
}

class _WebViewAppState extends State<WebViewApp> {
  final GlobalKey webViewKey = GlobalKey();
  InAppWebViewController? webViewController;

  // Common settings for both main and popup WebViews
  InAppWebViewSettings get _commonSettings => InAppWebViewSettings(
        isInspectable: kDebugMode,
        mediaPlaybackRequiresUserGesture: false,
        allowsInlineMediaPlayback: true,
        iframeAllow: "camera; microphone",
        iframeAllowFullscreen: true,
        javaScriptEnabled: true,
        javaScriptCanOpenWindowsAutomatically: true,
        supportMultipleWindows: true,
        domStorageEnabled: true,
        databaseEnabled: true,
        useWideViewPort: true,
        loadWithOverviewMode: true,
        mixedContentMode: MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
        allowFileAccess: true,
        allowContentAccess: true,
        thirdPartyCookiesEnabled: true,
        userAgent:
            "Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36",
      );

  // Helper method to check if URL should be opened externally.
  bool _shouldOpenExternally(String url) {
    if (url.startsWith('intent://')) return true;
    final scheme = Uri.tryParse(url)?.scheme.toLowerCase() ?? '';
    const webSchemes = {'http', 'https', 'about', 'data', 'blob', ''};
    return !webSchemes.contains(scheme);
  }

  // Unified handler for deep links and intents
  Future<NavigationActionPolicy?> _handleUrlLoading(
      InAppWebViewController controller, NavigationAction navigationAction) async {
    final url = navigationAction.request.url?.toString() ?? '';
    if (kDebugMode) print("Checking URL: $url");

    // Explicitly handle common UPI schemes as suggested
    if (url.startsWith("upi://") ||
        url.startsWith("gpay://") ||
        url.startsWith("phonepe://") ||
        url.startsWith("paytmmp://") ||
        url.startsWith("tez://") ||
        url.startsWith("paytm://")) {
      try {
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalNonBrowserApplication);
          return NavigationActionPolicy.CANCEL;
        }
      } catch (e) {
        if (kDebugMode) print('Error launching UPI scheme: $e');
      }
    }

    if (_shouldOpenExternally(url)) {
      try {
        if (url.startsWith('intent://')) {
          final uri = Uri.parse(url);
          String? scheme = uri.queryParameters['scheme'];
          
          // Try to find scheme in fragment if not in query
          if (scheme == null && uri.fragment.isNotEmpty) {
            final fragmentParts = uri.fragment.split(';');
            for (var part in fragmentParts) {
              if (part.startsWith('scheme=')) {
                scheme = part.split('=').last;
                break;
              }
            }
          }

          if (scheme != null) {
            final directUrl = url.replaceFirst('intent://', '$scheme://');
            final parsedUrl = Uri.parse(directUrl.split('#Intent').first);
            if (await canLaunchUrl(parsedUrl)) {
              await launchUrl(parsedUrl, mode: LaunchMode.externalNonBrowserApplication);
              return NavigationActionPolicy.CANCEL;
            }
          }

          // Fallback to browser_fallback_url if available
          final fallbackMatch = RegExp(r'S\.browser_fallback_url=([^;]+)').firstMatch(url);
          if (fallbackMatch != null) {
            final fallbackUrl = Uri.decodeComponent(fallbackMatch.group(1)!);
            await controller.loadUrl(urlRequest: URLRequest(url: WebUri(fallbackUrl)));
            return NavigationActionPolicy.CANCEL;
          }
        } else {
          final uri = Uri.parse(url);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalNonBrowserApplication);
            return NavigationActionPolicy.CANCEL;
          }
        }
      } catch (e) {
        if (kDebugMode) print('Error launching external URL: $e');
      }
      return NavigationActionPolicy.CANCEL;
    }
    return NavigationActionPolicy.ALLOW;
  }

  // Unified window creation logic
  Future<bool?> _handleCreateWindow(
      InAppWebViewController controller, CreateWindowAction createWindowAction) async {
    if (kDebugMode) print("Creating new window for: ${createWindowAction.request.url}");
    
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "Payment Popup",
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        return Scaffold(
          appBar: AppBar(
            leading: CloseButton(onPressed: () => Navigator.of(dialogContext).pop()),
            title: const Text("Payment Verification"),
          ),
          body: InAppWebView(
            windowId: createWindowAction.windowId,
            initialSettings: _commonSettings,
            onConsoleMessage: (controller, consoleMessage) {
              if (kDebugMode) print("Popup Console: ${consoleMessage.message}");
            },
            onLoadStart: (controller, url) {
              if (kDebugMode) print("Popup LoadStart: $url");
            },
            onPermissionRequest: (controller, request) async {
              return PermissionResponse(
                  resources: request.resources,
                  action: PermissionResponseAction.GRANT);
            },
            shouldOverrideUrlLoading: (controller, navigationAction) async {
              final policy = await _handleUrlLoading(controller, navigationAction);
              // If the URL was handled externally (UPI app launched), close this popup
              if (policy == NavigationActionPolicy.CANCEL && dialogContext.mounted) {
                if (kDebugMode) print("External app launched from popup, closing popup.");
                Navigator.of(dialogContext).pop();
              }
              return policy;
            },
            onCreateWindow: _handleCreateWindow,
            onReceivedError: (controller, request, error) {
              if (kDebugMode) print("Popup Error: ${error.description} at ${request.url}");
            },
            onReceivedHttpError: (controller, request, errorResponse) {
              if (kDebugMode) print("Popup HTTP Error: ${errorResponse.statusCode} at ${request.url}");
            },
            onCloseWindow: (controller) {
              if (dialogContext.mounted && Navigator.canPop(dialogContext)) {
                Navigator.of(dialogContext).pop();
              }
            },
          ),
        );
      },
    );
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (webViewController != null && await webViewController!.canGoBack()) {
          await webViewController!.goBack();
        } else {
          if (context.mounted) Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: InAppWebView(
            key: webViewKey,
            initialUrlRequest: URLRequest(url: WebUri("https://vestidonation.com/")),
            initialSettings: _commonSettings,
            onWebViewCreated: (controller) {
              webViewController = controller;
            },
            onConsoleMessage: (controller, consoleMessage) {
              if (kDebugMode) print("WebView Console: ${consoleMessage.message}");
            },
            onLoadStart: (controller, url) {
              if (kDebugMode) print("WebView LoadStart: $url");
            },
            onPermissionRequest: (controller, request) async {
              return PermissionResponse(
                  resources: request.resources,
                  action: PermissionResponseAction.GRANT);
            },
            onReceivedError: (controller, request, error) {
              if (kDebugMode) print("WebView Error: ${error.description} at ${request.url}");
            },
            onReceivedHttpError: (controller, request, errorResponse) {
              if (kDebugMode) print("WebView HTTP Error: ${errorResponse.statusCode} at ${request.url}");
            },
            shouldOverrideUrlLoading: _handleUrlLoading,
            onCreateWindow: _handleCreateWindow,
          ),
        ),
      ),
    );
  }
}
