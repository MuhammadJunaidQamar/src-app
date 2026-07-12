import 'dart:async';

import 'package:flutter/material.dart';
import 'package:src/utils/connection/connection_config.dart';
import 'package:src/utils/constants/constants.dart';
import 'package:src/utils/global/global.dart';
import 'package:src/utils/responsive.dart';
import 'package:src/utils/routing/routes.dart';
import 'package:src/view_model/view_model.dart';
import 'package:src/widgets/info_widget.dart';
import 'package:src/widgets/side_menu_widget.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  Timer? _linkTimer;
  bool _showDisconnectBanner = false;
  String _bannerText = '';

  bool _shouldShowEndDrawer(BuildContext context) =>
      Responsive.isMobile(context) || Global.pageIdx != 0;

  void _closeEndDrawerIfHidden() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final scaffold = _scaffoldKey.currentState;
      if (!mounted || scaffold == null || !scaffold.isEndDrawerOpen) return;
      if (!_shouldShowEndDrawer(context)) {
        scaffold.closeEndDrawer();
      }
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _linkTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (ConnectionConfig.usesSimulation) {
        if (_showDisconnectBanner) {
          setState(() {
            _showDisconnectBanner = false;
            _bannerText = '';
          });
        }
        return;
      }
      final vm = ViewModel();
      final show = !vm.isConnected;
      final text = ConnectionConfig.usesBle
          ? _bleBannerText(vm.bleStatus)
          : _wsBannerText(vm.linkStatus);
      if (show != _showDisconnectBanner || text != _bannerText) {
        setState(() {
          _showDisconnectBanner = show;
          _bannerText = text;
        });
      }
    });
  }

  String _bleBannerText(BleStatus s) {
    return switch (s) {
      BleStatus.scanning => 'Bluetooth: scanning…',
      BleStatus.connecting => 'Bluetooth: connecting…',
      BleStatus.disconnected => 'Bluetooth disconnected — retrying…',
      BleStatus.error => 'Bluetooth error — retrying…',
      _ => 'Bluetooth not connected',
    };
  }

  String _wsBannerText(LinkStatus s) {
    return switch (s) {
      LinkStatus.connecting => 'WebSocket: connecting…',
      LinkStatus.disconnected => 'WebSocket disconnected — retrying…',
      LinkStatus.error => 'WebSocket error — retrying…',
      _ => 'Telemetry link down',
    };
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _linkTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    _closeEndDrawerIfHidden();
  }

  void _onPageSelected(int index) {
    final scaffold = _scaffoldKey.currentState;
    scaffold?.closeEndDrawer();
    scaffold?.closeDrawer();
    setState(() => Global.pageIdx = index);
  }

  void _closeEndDrawer() {
    _scaffoldKey.currentState?.closeEndDrawer();
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = Responsive.isDesktop(context);
    final showEndDrawer = _shouldShowEndDrawer(context);
    if (!showEndDrawer) {
      _closeEndDrawerIfHidden();
    }

    return SafeArea(
      child: Scaffold(
        key: _scaffoldKey,
        endDrawer: showEndDrawer
            ? Stack(
                alignment: AlignmentDirectional.topEnd,
                children: [
                  const SingleChildScrollView(
                    scrollDirection: Axis.vertical,
                    child: Padding(
                      padding: EdgeInsets.only(top: 56),
                      child: InfoWidget(),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 20),
                    child: IconButton(
                      onPressed: _closeEndDrawer,
                      icon: const Icon(Icons.cancel_outlined),
                    ),
                  ),
                ],
              )
            : null,
        drawer: !isDesktop
            ? SizedBox(
                width: 250,
                child: SideMenuWidget(onPageSelected: _onPageSelected),
              )
            : null,
        body: Column(
          children: [
            if (_showDisconnectBanner) _LinkBanner(text: _bannerText),
            Expanded(
              child: Row(
                children: [
                  if (isDesktop)
                    Expanded(
                      flex: 2,
                      child: SideMenuWidget(onPageSelected: _onPageSelected),
                    ),
                  Expanded(
                    flex: 10,
                    child: Routes.getPage(pages[Global.pageIdx]),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LinkBanner extends StatelessWidget {
  const _LinkBanner({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.orange.withValues(alpha: 0.15),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                color: Colors.orange,
                strokeWidth: 2,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(
                  color: Colors.orange,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
