import 'package:flutter/material.dart';
import 'package:src/theme/app_theme_colors.dart';
import 'package:src/utils/desktop_interaction.dart';
import 'package:url_launcher/url_launcher.dart';

const _officeNumber = '+92 42 35880007';
const _mobileNumber = '+92 335 437 0587';
const _website = 'www.ucp.edu.pk';
const _email = 'kamran.saleem@ucp.edu.pk';

/// Opens the center details without moving the user away from their current
/// workflow. Phones use a bottom sheet; wider layouts use a compact dialog.
Future<void> showCenterInfo(BuildContext context) async {
  final colors = context.colors;
  final isCompact = MediaQuery.sizeOf(context).width < 700;

  if (isCompact) {
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: colors.surfaceElevated,
      barrierColor: colors.scrim,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) => ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.86,
        ),
        child: const SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(20, 0, 20, 28),
          child: CenterInfoContent(),
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
        side: BorderSide(color: dialogContext.colors.cardBorder),
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
  const CenterInfoContent({super.key, this.onClose});

  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final accent = colors.positive;

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
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: colors.isDark ? 0.08 : 0.06),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: accent.withValues(alpha: 0.22),
            ),
          ),
          child: Row(
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
                  ),
                ),
                SizedBox(
                  width: tileWidth,
                  child: _ContactTile(
                    icon: Icons.smartphone_outlined,
                    label: 'Mobile',
                    value: _mobileNumber,
                    uri: Uri.parse('tel:+923354370587'),
                  ),
                ),
                SizedBox(
                  width: tileWidth,
                  child: _ContactTile(
                    icon: Icons.language_outlined,
                    label: 'Website',
                    value: _website,
                    uri: Uri.parse('https://$_website'),
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

class _ContactTile extends StatelessWidget {
  const _ContactTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.uri,
  });

  final IconData icon;
  final String label;
  final String value;
  final Uri uri;

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
                  color: colors.positive.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  icon,
                  color: colors.positive,
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
