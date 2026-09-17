import 'package:flutter/material.dart';
import 'package:pretty_qr_code/pretty_qr_code.dart';
import 'package:src/theme/app_theme_colors.dart';
import 'package:src/utils/desktop_interaction.dart';
import 'package:url_launcher/url_launcher.dart';

const _officeNumber = '+92 42 35880007';
const _mobileNumber = '+92 335 437 0587';
const _website =
    'https://sites.google.com/view/space4all/space-camp/space-camp-2026';
const _email = 'kamran.saleem@ucp.edu.pk';

/// Opens the center details without moving the user away from their current
/// workflow. Phones use a bottom sheet; wider layouts use a compact dialog.
Future<void> showCenterInfo(
  BuildContext context, {
  Color? accentColor,
}) async {
  final colors = context.colors;
  final accent = accentColor ?? colors.positive;
  final isCompact = MediaQuery.sizeOf(context).width < 700;

  if (isCompact) {
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: colors.surfaceElevated,
      barrierColor: colors.scrim,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: accent.withValues(alpha: 0.28)),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) => ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.86,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
          child: CenterInfoContent(accentColor: accent),
        ),
      ),
    );
    return;
  }

  await showDialog<void>(
    context: context,
    barrierColor: colors.scrim,
    builder: (dialogContext) => Dialog(
      backgroundColor: dialogContext.colors.surfaceElevated,
      insetPadding: const EdgeInsets.all(32),
      shape: RoundedRectangleBorder(
        side: BorderSide(color: accent.withValues(alpha: 0.28)),
        borderRadius: BorderRadius.circular(28),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 680,
          maxHeight: MediaQuery.sizeOf(dialogContext).height * 0.88,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: CenterInfoContent(
            accentColor: accent,
            onClose: () => Navigator.of(dialogContext).pop(),
          ),
        ),
      ),
    ),
  );
}

/// Reusable institutional and contact content for both the full info page and
/// the protocol-selection quick view.
class CenterInfoContent extends StatelessWidget {
  const CenterInfoContent({
    super.key,
    this.accentColor,
    this.onClose,
  });

  final Color? accentColor;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final accent = accentColor ?? colors.positive;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(17),
                border: Border.all(
                  color: accent.withValues(alpha: 0.28),
                ),
              ),
              child: Icon(
                Icons.rocket_launch_outlined,
                color: accent,
                size: 29,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Space Research Center',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: colors.textStrong,
                          fontWeight: FontWeight.w700,
                          height: 1.15,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Electrical Engineering Department',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colors.textSecondary,
                          height: 1.35,
                        ),
                  ),
                ],
              ),
            ),
            if (onClose != null) ...[
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Close',
                onPressed: onClose,
                icon: const Icon(Icons.close),
                color: colors.textSecondary,
              ),
            ],
          ],
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.fromLTRB(18, 12, 12, 12),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: colors.isDark ? 0.08 : 0.06),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: accent.withValues(alpha: 0.22),
            ),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final details = Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.account_balance_outlined,
                    color: accent,
                    size: 24,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Faculty of Engineering',
                          style: TextStyle(
                            color: colors.textStrong,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          'University of Central Punjab',
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontSize: 14,
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Icon(
                              Icons.location_on_outlined,
                              color: colors.textTertiary,
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                'Lahore, Pakistan',
                                style: TextStyle(
                                  color: colors.textSecondary,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              );
              final qrCode = _WebsiteQrCode(accentColor: accent);

              if (constraints.maxWidth >= 350) {
                return Row(
                  children: [
                    Expanded(child: details),
                    const SizedBox(width: 18),
                    qrCode,
                  ],
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  details,
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.center,
                    child: qrCode,
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Contact',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: colors.textStrong,
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            const gap = 12.0;
            final twoColumns = constraints.maxWidth >= 540;
            final tileWidth = twoColumns
                ? (constraints.maxWidth - gap) / 2
                : constraints.maxWidth;

            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                SizedBox(
                  width: tileWidth,
                  child: _ContactTile(
                    icon: Icons.phone_outlined,
                    label: 'Office',
                    value: '$_officeNumber, Ext. 441',
                    uri: Uri.parse('tel:+924235880007'),
                    accentColor: accent,
                  ),
                ),
                SizedBox(
                  width: tileWidth,
                  child: _ContactTile(
                    icon: Icons.smartphone_outlined,
                    label: 'Mobile',
                    value: _mobileNumber,
                    uri: Uri.parse('tel:+923354370587'),
                    accentColor: accent,
                  ),
                ),
                SizedBox(
                  width: tileWidth,
                  child: _ContactTile(
                    icon: Icons.language_outlined,
                    label: 'Website',
                    value: _website,
                    uri: Uri.parse(_website),
                    accentColor: accent,
                  ),
                ),
                SizedBox(
                  width: tileWidth,
                  child: _ContactTile(
                    icon: Icons.mail_outline_rounded,
                    label: 'Email',
                    value: _email,
                    uri: Uri(
                      scheme: 'mailto',
                      path: _email,
                    ),
                    accentColor: accent,
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _WebsiteQrCode extends StatelessWidget {
  const _WebsiteQrCode({required this.accentColor});

  final Color accentColor;

  Future<void> _openWebsite() async {
    try {
      await launchUrl(
        Uri.parse(_website),
        mode: LaunchMode.externalApplication,
      );
    } on Exception {
      // The website remains available in the contact tile if launch fails.
    }
  }

  @override
  Widget build(BuildContext context) {
    final opaqueAccent = accentColor.withValues(alpha: 1);
    final qrBackground = Color.alphaBlend(
      opaqueAccent.withValues(alpha: 0.11),
      Colors.white,
    );
    // Bright accents need darker ink against the pale tile to remain reliably
    // scannable. Blending with black preserves the active accent's hue.
    final qrForeground = Color.alphaBlend(
      Colors.black.withValues(alpha: 0.55),
      opaqueAccent,
    );

    return Semantics(
      label: 'QR code for the Space Research Center website. '
          'Scan or tap to open.',
      button: true,
      child: Tooltip(
        message: 'Scan or tap to open website',
        child: SizedBox.square(
          dimension: 92,
          child: Material(
            color: qrBackground,
            elevation: 2,
            shadowColor: accentColor.withValues(alpha: 0.28),
            surfaceTintColor: Colors.transparent,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
              side: BorderSide(
                color: accentColor.withValues(alpha: 0.34),
              ),
            ),
            child: InkWell(
              key: const Key('center-info-website-qr'),
              mouseCursor: clickCursor,
              onTap: _openWebsite,
              child: Padding(
                padding: const EdgeInsets.all(3),
                child: PrettyQrView.data(
                  data: _website,
                  errorCorrectLevel: QrErrorCorrectLevel.M,
                  decoration: PrettyQrDecoration(
                    background: qrBackground,
                    quietZone: PrettyQrQuietZone.standard,
                    shape: PrettyQrSmoothSymbol(
                      color: qrForeground,
                      roundFactor: 0.65,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ContactTile extends StatelessWidget {
  const _ContactTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.uri,
    required this.accentColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Uri uri;
  final Color accentColor;

  Future<void> _open() async {
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } on Exception {
      // The details remain visible if the platform has no matching app.
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Material(
      color: colors.surfaceMuted.withValues(alpha: 0.62),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        mouseCursor: clickCursor,
        onTap: _open,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  icon,
                  color: accentColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label.toUpperCase(),
                      style: TextStyle(
                        color: colors.textTertiary,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      value,
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                Icons.north_east_rounded,
                color: colors.textTertiary,
                size: 15,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
