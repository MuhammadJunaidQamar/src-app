import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:src/utils/connection/connection_config.dart';
import 'package:src/utils/constants/constants.dart';
import 'package:src/utils/routing/routes_name.dart';
import 'package:src/view_model/view_model.dart';
import 'package:src/widgets/custom_card_widget.dart';
import 'package:src/widgets/window_buttons_widget.dart';

class ConnectionModeScreen extends StatefulWidget {
  const ConnectionModeScreen({super.key});

  @override
  State<ConnectionModeScreen> createState() => _ConnectionModeScreenState();
}

class _ConnectionModeScreenState extends State<ConnectionModeScreen> {
  ConnectionMode? _selectedMode;

  Color _accentForMode(ConnectionMode mode) {
    return mode == ConnectionMode.broadcast
        ? AppColors.spanishSkyBlueColor
        : AppColors.mediumSeaGreenColor;
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = !kIsWeb &&
        {
          TargetPlatform.windows,
          TargetPlatform.macOS,
          TargetPlatform.linux,
        }.contains(defaultTargetPlatform);

    final body = Scaffold(
      backgroundColor: AppColors.backgroundColor,
      body: Stack(
        children: [
          const Positioned.fill(
            child: Align(
              alignment: Alignment.topCenter,
              child: Image(
                image: AssetImage('assets/images/BackGround.png'),
                fit: BoxFit.fitWidth,
                alignment: Alignment.topCenter,
                filterQuality: FilterQuality.high,
              ),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.blackPearlColor.withOpacity(0.86),
                    AppColors.backgroundColor.withOpacity(0.9),
                    AppColors.backgroundColor,
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 860),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildHeader(context),
                      const SizedBox(height: 12),
                      _buildModeCard(ConnectionMode.broadcast, Icons.cloud_outlined),
                      const SizedBox(height: 10),
                      _buildModeCard(
                        ConnectionMode.directGroundStation,
                        Icons.router_outlined,
                      ),
                      const SizedBox(height: 14),
                      _buildContinueButton(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );

    if (!isDesktop) {
      return body;
    }

    return WindowBorder(
      color: AppColors.cardBorderColor,
      width: 1.2,
      child: Column(
        children: [
          WindowTitleBarBox(
            child: Container(
              height: 42,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.blackPearlColor,
                    AppColors.backgroundColor,
                  ],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 12),
                  Icon(Icons.sensors, color: AppColors.mediumSeaGreenColor, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    AppText.appName,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.mainTextColor2,
                    ),
                  ),
                  Expanded(child: MoveWindow()),
                  WindowButtonsWidget(),
                ],
              ),
            ),
          ),
          Expanded(child: body),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return CustomCard(
      color: AppColors.blackPearlColor.withOpacity(0.82),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      margin: EdgeInsets.zero,
      expandChild: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppText.appName,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: AppColors.contentColorWhite,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Select connection mode to continue',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.mainTextColor2,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeCard(ConnectionMode mode, IconData icon) {
    return _ModeCard(
      title: ConnectionConfig.modeTitle(mode),
      subtitle: ConnectionConfig.modeSubtitle(mode),
      icon: icon,
      accentColor: _accentForMode(mode),
      selected: _selectedMode == mode,
      onTap: () => setState(() => _selectedMode = mode),
    );
  }

  Widget _buildContinueButton() {
    final buttonColor = _selectedMode == null
        ? AppColors.squidInkColor
        : _accentForMode(_selectedMode!);
    return SizedBox(
      height: 46,
      child: ElevatedButton(
        onPressed: _selectedMode == null ? null : _continueToAppFlow,
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 8),
          backgroundColor: buttonColor,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.squidInkColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: const Text(
          'Continue',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  void _continueToAppFlow() {
    final mode = _selectedMode;
    if (mode == null) return;

    ConnectionConfig.selectMode(mode);
    ViewModel().connectWithSelectedMode();
    final isDesktop = !kIsWeb &&
        {
          TargetPlatform.windows,
          TargetPlatform.macOS,
          TargetPlatform.linux,
        }.contains(defaultTargetPlatform);
    Navigator.of(context).pushReplacementNamed(
      isDesktop ? RouteName.titleBar : RouteName.homeScreen,
    );
  }
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color accentColor;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: selected
                ? AppColors.blackPearlColor.withOpacity(0.95)
                : AppColors.itemsBackground.withOpacity(0.72),
            border: Border.all(
              color: selected ? accentColor : AppColors.borderColor,
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: selected
                      ? accentColor.withOpacity(0.18)
                      : AppColors.squidInkColor.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  size: 24,
                  color: selected ? accentColor : AppColors.mainTextColor2,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: selected ? accentColor : AppColors.mainTextColor1,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: selected
                                ? accentColor.withOpacity(0.82)
                                : AppColors.mainTextColor2,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
