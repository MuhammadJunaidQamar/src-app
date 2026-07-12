import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:src/utils/connection/connection_config.dart';
import 'package:src/utils/constants/constants.dart';
import 'package:src/utils/desktop_interaction.dart';
import 'package:src/utils/routing/routes.dart';
import 'package:src/utils/routing/routes_name.dart';
import 'package:src/view_model/view_model.dart';
import 'package:src/widgets/custom_card_widget.dart';

class ConnectionModeScreen extends StatefulWidget {
  const ConnectionModeScreen({super.key});

  @override
  State<ConnectionModeScreen> createState() => _ConnectionModeScreenState();
}

class _ConnectionModeScreenState extends State<ConnectionModeScreen> {
  ConnectionMode? _selectedMode;

  @override
  void initState() {
    super.initState();
    _selectedMode = ConnectionConfig.selectedMode;
  }

  void _onContinue() {
    final mode = _selectedMode;
    if (mode == null || !ConnectionConfig.isModeSupportedOnPlatform(mode)) {
      return;
    }

    ConnectionConfig.selectMode(mode);

    // Simulation and broadcast connect immediately — skip the pairing screen
    // so the user does not see two route transitions in a row.
    if (mode == ConnectionMode.broadcast || mode == ConnectionMode.simulation) {
      ViewModel().connectWithSelectedMode();
      Routes.goToMainApp(context);
      return;
    }

    Navigator.of(context).pushNamed(RouteName.groundStationPairingScreen);
  }

  Color _accentForMode(ConnectionMode mode) {
    switch (mode) {
      case ConnectionMode.broadcast:
        return AppColors.spanishSkyBlueColor;
      case ConnectionMode.directGroundStation:
        return AppColors.mediumSeaGreenColor;
      case ConnectionMode.bleGroundStation:
        return AppColors.tropicalIndigoColor;
      case ConnectionMode.simulation:
        return AppColors.deepSaffronColor;
    }
  }

  IconData _iconForMode(ConnectionMode mode) {
    switch (mode) {
      case ConnectionMode.broadcast:
        return Icons.cloud_outlined;
      case ConnectionMode.directGroundStation:
        return Icons.wifi;
      case ConnectionMode.bleGroundStation:
        return Icons.bluetooth;
      case ConnectionMode.simulation:
        return Icons.science_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                    AppColors.blackPearlColor.withValues(alpha: 0.86),
                    AppColors.backgroundColor.withValues(alpha: 0.9),
                    AppColors.backgroundColor,
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight - 24,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 860),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildHeader(context),
                            const SizedBox(height: 12),
                            _buildModeCard(ConnectionMode.bleGroundStation),
                            const SizedBox(height: 10),
                            _buildModeCard(ConnectionMode.directGroundStation),
                            const SizedBox(height: 10),
                            _buildModeCard(ConnectionMode.broadcast),
                            const SizedBox(height: 10),
                            _buildModeCard(ConnectionMode.simulation),
                            const SizedBox(height: 14),
                            _buildContinueButton(),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return CustomCard(
      color: AppColors.blackPearlColor.withValues(alpha: 0.82),
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
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Choose how to connect. Flash the ESP32 with the matching ground-station sketch, then continue.',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.mainTextColor2,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeCard(ConnectionMode mode) {
    final supported = ConnectionConfig.isModeSupportedOnPlatform(mode);
    final selected = _selectedMode == mode;
    final accent = _accentForMode(mode);

    return _ModeCard(
      title: ConnectionConfig.modeTitle(mode),
      subtitle: ConnectionConfig.modeSubtitle(mode),
      firmwareHint: ConnectionConfig.firmwareHint(mode),
      icon: _iconForMode(mode),
      accentColor: accent,
      selected: selected,
      enabled: supported,
      disabledReason:
          supported ? null : 'Bluetooth mode is not available on Web.',
      onTap: supported ? () => setState(() => _selectedMode = mode) : null,
    );
  }

  Widget _buildContinueButton() {
    final canContinue = _selectedMode != null &&
        ConnectionConfig.isModeSupportedOnPlatform(_selectedMode!);
    final accent = _selectedMode != null
        ? _accentForMode(_selectedMode!)
        : AppColors.squidInkColor;

    return SizedBox(
      height: 46,
      child: ElevatedButton(
        onPressed: canContinue ? _onContinue : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.squidInkColor,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: const Text(
          'Continue',
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.title,
    required this.subtitle,
    required this.firmwareHint,
    required this.icon,
    required this.accentColor,
    required this.selected,
    required this.enabled,
    this.disabledReason,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final String firmwareHint;
  final IconData icon;
  final Color accentColor;
  final bool selected;
  final bool enabled;
  final String? disabledReason;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        mouseCursor: onTap != null ? clickCursor : SystemMouseCursors.basic,
        onTap: onTap,
        child: Opacity(
          opacity: enabled ? 1 : 0.45,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: selected
                  ? AppColors.blackPearlColor.withValues(alpha: 0.95)
                  : AppColors.itemsBackground.withValues(alpha: 0.72),
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
                        ? accentColor.withValues(alpha: 0.18)
                        : AppColors.squidInkColor.withValues(alpha: 0.5),
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
                        style: TextStyle(
                          color: selected
                              ? AppColors.contentColorWhite
                              : AppColors.mainTextColor2,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: AppColors.mainTextColor3,
                          fontSize: 12,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        firmwareHint,
                        style: TextStyle(
                          color: accentColor.withValues(alpha: 0.9),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (disabledReason != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          disabledReason!,
                          style: const TextStyle(
                            color: Colors.orangeAccent,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (selected)
                  Icon(Icons.check_circle, color: accentColor, size: 22),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
