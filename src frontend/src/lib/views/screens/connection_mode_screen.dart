import 'package:flutter/material.dart';
import 'package:src/theme/app_theme_colors.dart';
import 'package:src/utils/connection/connection_config.dart';
import 'package:src/utils/constants/constants.dart';
import 'package:src/utils/desktop_interaction.dart';
import 'package:src/utils/routing/routes.dart';
import 'package:src/utils/routing/routes_name.dart';
import 'package:src/view_model/view_model.dart';
import 'package:src/widgets/center_info_widget.dart';
import 'package:src/widgets/custom_card_widget.dart';

class ConnectionModeScreen extends StatefulWidget {
  const ConnectionModeScreen({super.key});

  @override
  State<ConnectionModeScreen> createState() => _ConnectionModeScreenState();
}

class _ConnectionModeScreenState extends State<ConnectionModeScreen> {
  ConnectionMode? _selectedMode;
  final _listController = ScrollController();
  final Map<ConnectionMode, GlobalKey> _modeKeys = {
    for (final mode in _modes) mode: GlobalKey(),
  };

  @override
  void initState() {
    super.initState();
    _selectedMode = ConnectionConfig.selectedMode;
  }

  @override
  void dispose() {
    _listController.dispose();
    super.dispose();
  }

  void _selectMode(ConnectionMode mode) {
    setState(() => _selectedMode = mode);
    // After the selection rebuild (border / check icon), scroll just enough
    // so a clipped card becomes fully visible — no-op if already in view.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _modeKeys[mode]?.currentContext;
      if (ctx == null || !ctx.mounted) return;
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    });
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

  /// Brand hue per mode, darkened on light surfaces so it still carries white
  /// text and reads as a label rather than a highlighter stroke.
  Color _accentForMode(BuildContext context, ConnectionMode mode) {
    final raw = switch (mode) {
      ConnectionMode.broadcast => AppColors.spanishSkyBlueColor,
      ConnectionMode.directGroundStation => AppColors.mediumSeaGreenColor,
      ConnectionMode.routerGroundStation => AppColors.contentColorCyan,
      ConnectionMode.bleGroundStation => AppColors.tropicalIndigoColor,
      ConnectionMode.simulation => AppColors.deepSaffronColor,
    };
    return context.colors.tuneAccent(raw);
  }

  IconData _iconForMode(ConnectionMode mode) {
    switch (mode) {
      case ConnectionMode.broadcast:
        return Icons.cloud_outlined;
      case ConnectionMode.directGroundStation:
        return Icons.wifi;
      case ConnectionMode.routerGroundStation:
        return Icons.router_outlined;
      case ConnectionMode.bleGroundStation:
        return Icons.bluetooth;
      case ConnectionMode.simulation:
        return Icons.science_outlined;
    }
  }

  static const _modes = [
    ConnectionMode.bleGroundStation,
    ConnectionMode.directGroundStation,
    ConnectionMode.broadcast,
    ConnectionMode.routerGroundStation,
    ConnectionMode.simulation,
  ];

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 860),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 12,
              ),
              // Header pinned to the top, Continue pinned to the bottom,
              // only the mode list between them scrolls. MainAxisSize.min
              // plus a loose Flexible means the column still shrink-wraps
              // and centres when everything fits — no stretched gap above
              // the button on a tall desktop window.
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildHeader(context),
                  const SizedBox(height: 12),
                  Flexible(
                    fit: FlexFit.loose,
                    child: ScrollConfiguration(
                      behavior: ScrollConfiguration.of(context).copyWith(
                        scrollbars: false,
                      ),
                      child: ListView.separated(
                        controller: _listController,
                        primary: false,
                        shrinkWrap: true,
                        padding: EdgeInsets.zero,
                        itemCount: _modes.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, i) {
                          final mode = _modes[i];
                          return KeyedSubtree(
                            key: _modeKeys[mode],
                            child: _buildModeCard(mode),
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _buildContinueButton(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final colors = context.colors;
    final canOpenInfo = _selectedMode != null;
    final infoAccent = canOpenInfo
        ? _accentForMode(context, _selectedMode!)
        : colors.textTertiary;

    return CustomCard(
      color: colors.isDark
          ? AppColors.blackPearlColor.withValues(alpha: 0.82)
          : colors.surface.withValues(alpha: 0.92),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      margin: EdgeInsets.zero,
      expandChild: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  AppText.appName,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: colors.textStrong,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              const SizedBox(width: 12),
              Tooltip(
                message: canOpenInfo
                    ? 'View center information'
                    : 'Select a connection mode first',
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 180),
                  opacity: canOpenInfo ? 1 : 0.48,
                  child: IconButton(
                    onPressed:
                        canOpenInfo ? () => showCenterInfo(context) : null,
                    style: IconButton.styleFrom(
                      minimumSize: const Size(42, 42),
                      backgroundColor: infoAccent.withValues(
                          alpha: canOpenInfo ? 0.14 : 0.08),
                      disabledBackgroundColor:
                          colors.surfaceStrong.withValues(alpha: 0.35),
                      foregroundColor: infoAccent,
                      disabledForegroundColor: colors.textTertiary,
                      side: BorderSide(
                        color: canOpenInfo
                            ? infoAccent.withValues(alpha: 0.42)
                            : colors.cardBorder,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(13),
                      ),
                    ),
                    icon: const Icon(Icons.info_outline_rounded, size: 22),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Flash GS_ALL_PROTOCOLS.ino once, then choose how the app connects.',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: colors.textSecondary,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeCard(ConnectionMode mode) {
    final supported = ConnectionConfig.isModeSupportedOnPlatform(mode);
    final selected = _selectedMode == mode;
    final accent = _accentForMode(context, mode);

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
      onTap: supported ? () => _selectMode(mode) : null,
    );
  }

  Widget _buildContinueButton() {
    final colors = context.colors;
    final canContinue = _selectedMode != null &&
        ConnectionConfig.isModeSupportedOnPlatform(_selectedMode!);
    final accent = _selectedMode != null
        ? _accentForMode(context, _selectedMode!)
        : colors.disabledSurface;

    return SizedBox(
      height: 46,
      child: ElevatedButton(
        onPressed: canContinue ? _onContinue : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: colors.onAccent,
          disabledBackgroundColor: colors.disabledSurface,
          disabledForegroundColor: colors.textTertiary,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: const Text(
          'Continue',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
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
    final colors = context.colors;

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
                  ? (colors.isDark
                      ? AppColors.blackPearlColor.withValues(alpha: 0.95)
                      : colors.surface)
                  : colors.surfaceMuted.withValues(alpha: 0.72),
              border: Border.all(
                color: selected ? accentColor : colors.cardBorder,
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
                        : colors.surfaceStrong.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    size: 24,
                    color: selected ? accentColor : colors.textSecondary,
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
                              ? colors.textStrong
                              : colors.textSecondary,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: colors.textTertiary,
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
                          style: TextStyle(
                            color: colors.warning,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(
                  Icons.check_circle,
                  color: selected ? accentColor : Colors.transparent,
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
