
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AppIds {
  final String appName;
  final String appId;
  final String banner;
  final String interstitial;
  final String rewarded;

  AppIds({
    required this.appName,
    required this.appId,
    required this.banner,
    required this.interstitial,
    required this.rewarded,
  });

  static Future<AppIds> load() async {
    final txt = await rootBundle.loadString('config/app_config.json');
    final m = jsonDecode(txt);
    return AppIds(
      appName: m['app_name'] ?? 'VijayAI Connect',
      appId: m['admob_app_id_android'],
      banner: m['banner_ad_unit_id_android'],
      interstitial: m['interstitial_ad_unit_id_android'],
      rewarded: m['rewarded_ad_unit_id_android'],
    );
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final ids = await AppIds.load();
  await MobileAds.instance.initialize();
  runApp(MyApp(ids: ids));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, required this.ids});
  final AppIds ids;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: ids.appName,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: HomeScreen(ids: ids),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.ids});
  final AppIds ids;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  BannerAd? _banner;
  InterstitialAd? _interstitial;
  RewardedAd? _rewarded;
  bool _isInterstitialReady = false;
  bool _isRewardedReady = false;

  @override
  void initState() {
    super.initState();
    _loadBanner();
    _loadInterstitial();
    _loadRewarded();
  }

  void _loadBanner() {
    final ad = BannerAd(
      size: AdSize.banner,
      adUnitId: widget.ids.banner,
      listener: BannerAdListener(
        onAdLoaded: (_) => setState(() {}),
        onAdFailedToLoad: (_, __) => setState(() => _banner = null),
      ),
      request: const AdRequest(),
    );
    ad.load();
    _banner = ad;
  }

  void _loadInterstitial() {
    InterstitialAd.load(
      adUnitId: widget.ids.interstitial,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitial = ad;
          _isInterstitialReady = true;
          ad.setImmersiveMode(true);
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (_) {
              _isInterstitialReady = false;
              _interstitial?.dispose();
              _loadInterstitial();
            },
            onAdFailedToShowFullScreenContent: (_, __) {
              _isInterstitialReady = false;
              _interstitial?.dispose();
              _loadInterstitial();
            },
          );
          setState(() {});
        },
        onAdFailedToLoad: (_) {
          _isInterstitialReady = false;
          setState(() {});
        },
      ),
    );
  }

  void _loadRewarded() {
    RewardedAd.load(
      adUnitId: widget.ids.rewarded,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewarded = ad;
          _isRewardedReady = true;
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (_) {
              _isRewardedReady = false;
              _rewarded?.dispose();
              _loadRewarded();
            },
            onAdFailedToShowFullScreenContent: (_, __) {
              _isRewardedReady = false;
              _rewarded?.dispose();
              _loadRewarded();
            },
          );
          setState(() {});
        },
        onAdFailedToLoad: (_) {
          _isRewardedReady = false;
          setState(() {});
        },
      ),
    );
  }

  @override
  void dispose() {
    _banner?.dispose();
    _interstitial?.dispose();
    _rewarded?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.ids.appName),
        centerTitle: true,
      ),
      bottomNavigationBar: _banner == null
          ? const SizedBox.shrink()
          : SizedBox(
              height: _banner!.size.height.toDouble(),
              child: AdWidget(ad: _banner!),
            ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            elevation: 0.5,
            child: Padding(
              padding: const EdgeInsets.all(14.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    "Welcome to VijayAI Connect",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                  ),
                  SizedBox(height: 8),
                  Text(
                    "Entertainment + Utility bundle: fun facts, quotes, and simple rewards. "
                    "Support the app by viewing ads – thank you!",
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 12),
          _Tile(
            icon: Icons.bolt,
            title: "Show Interstitial Ad",
            subtitle: "Tap to view",
            type: _TileType.interstitial,
          ),
          _Tile(
            icon: Icons.card_giftcard,
            title: "Get Reward (Rewarded Ad)",
            subtitle: "Watch to unlock reward",
            type: _TileType.rewarded,
          ),
        ],
      ),
    );
  }
}

enum _TileType { interstitial, rewarded }

class _Tile extends StatelessWidget {
  const _Tile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.type,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final _TileType type;

  @override
  Widget build(BuildContext context) {
    final state = context.findAncestorStateOfType<_HomeScreenState>()!;
    final ready = switch (type) {
      _TileType.interstitial => state._isInterstitialReady,
      _TileType.rewarded => state._isRewardedReady,
    };
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(ready ? subtitle : "Loading…"),
        trailing: const Icon(Icons.chevron_right),
        onTap: !ready
            ? null
            : () {
                if (type == _TileType.interstitial) {
                  state._interstitial?.show();
                } else {
                  state._rewarded?.show(onUserEarnedReward: (_, r) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Reward: ${r.amount} ${r.type}')),
                    );
                  });
                }
              },
      ),
    );
  }
}
