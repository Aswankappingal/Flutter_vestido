import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'dart:async';

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
      home: const SplashScreen(),
    ),
  );
}

class SplashScreen extends StatefulWidget {
  const SplashScreen ({super.key}) ;

  @override
  State<SplashScreen > createState () => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Timer(const Duration(seconds: 3), () {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const WebViewApp()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(
              color: Colors.black,
            ),
          ],
        ),
      ),
    );
  }
}

class WebViewApp extends StatefulWidget {
  const WebViewApp({super.key});

  @override
  State<WebViewApp> createState() => _WebViewAppState();
}

class _WebViewAppState extends State<WebViewApp> {
  final GlobalKey webViewKey = GlobalKey();
  InAppWebViewController? webViewController;

  InAppWebViewSettings settings = InAppWebViewSettings(
    isInspectable: kDebugMode,
    mediaPlaybackRequiresUserGesture: false,
    allowsInlineMediaPlayback: true,
    iframeAllow: "camera; microphone",
    iframeAllowFullscreen: true,
    javaScriptEnabled: true,
    javaScriptCanOpenWindowsAutomatically: true,
    supportMultipleWindows: true,
    // Clean user agent to avoid Google's "403: disallowed_useragent"
    userAgent: "Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36",
  );

  @override
  Widget build(BuildContext context) {
    
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        if (webViewController != null && await webViewController!.canGoBack()) {
          await webViewController!.goBack();
        } else {
          // If we can't go back, we can pop the app.
          if (context.mounted) {
            Navigator.of(context).pop();
          }
        }
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: InAppWebView(
            key: webViewKey,
            initialUrlRequest: URLRequest(url: WebUri("https://vestidonation.com/")),
            initialSettings: settings,
            onWebViewCreated: (controller) {
              webViewController = controller;
            },
            onCreateWindow: (controller, createWindowAction) async {
              showDialog(
                context: context,
                builder: (context) {
                  return AlertDialog(
                    contentPadding: EdgeInsets.zero,
                    content: SizedBox(
                      width: double.maxFinite,
                      height: MediaQuery.of(context).size.height * 0.8,
                      child: InAppWebView(
                        windowId: createWindowAction.windowId,
                        initialSettings: InAppWebViewSettings(
                          javaScriptEnabled: true,
                          userAgent: "Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36",
                        ),
                        onCloseWindow: (controller) async {
                          if (context.mounted) {
                            Navigator.pop(context);
                          }
                        },
                      ),
                    ),
                  );
                },
              );
              return true;
            },
          ),
        ),
      ),
    );
  }
}
