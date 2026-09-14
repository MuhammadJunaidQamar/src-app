import 'package:flutter/material.dart';
import 'package:src/model/team_member_model.dart';
import 'package:src/theme/app_theme_colors.dart';
import 'package:src/utils/desktop_interaction.dart';
import 'package:url_launcher/url_launcher.dart';

/// Comfortable on-screen card width (portrait photos stay ~2:3).
const double kTeamCardWidth = 220;
const double kTeamCardAspect = 682 / 1024;
const double kCutCorner = 24;
const double kBorderWidth = 5.5;
const double kBorderWidthHover = 7.0;
const double kBorderGap = 10.0;

/// Portrait card with cut-corner green border outside the image.
/// Color at top fades to grayscale at bottom; name / role / LinkedIn
/// sit on the grayscale area.
class TeamMemberCard extends StatefulWidget {
  final TeamMember member;

  const TeamMemberCard({super.key, required this.member});

  @override
  State<TeamMemberCard> createState() => _TeamMemberCardState();
}

class _TeamMemberCardState extends State<TeamMemberCard> {
  bool _hovered = false;

  Future<void> _openLinkedIn() async {
    final url = widget.member.linkedInUrl;
    if (url == null || url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final borderColor = _hovered ? colors.info : colors.positive;
    final stroke = _hovered ? kBorderWidthHover : kBorderWidth;
    // The photo fades to grayscale at the bottom and a wash is laid over it so
    // the caption reads. It has to flip with the theme: a black wash under
    // light text on a dark canvas, a white wash under dark text on a light one.
    final wash =
        colors.isDark ? const Color(0xFF000000) : const Color(0xFFFFFFFF);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: kTeamCardWidth,
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: borderColor.withValues(alpha: _hovered ? 0.45 : 0.18),
              blurRadius: _hovered ? 18 : 8,
              spreadRadius: _hovered ? 1 : 0,
            ),
          ],
        ),
        child: AspectRatio(
          aspectRatio: kTeamCardAspect,
          child: CustomPaint(
            painter: _CutCornerPainter(
              color: borderColor,
              strokeWidth: stroke,
              cut: kCutCorner,
            ),
            child: Padding(
              // Gap between outer border stroke and clipped photo
              padding: EdgeInsets.all(stroke / 2 + kBorderGap),
              child: ClipPath(
                clipper: const _CutCornerClipper(cut: kCutCorner - 6),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.asset(
                      widget.member.imagePath,
                      fit: BoxFit.cover,
                    ),
                    ShaderMask(
                      blendMode: BlendMode.dstIn,
                      shaderCallback: (bounds) {
                        return const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Color(0x00FFFFFF),
                            Color(0x00FFFFFF),
                            Color(0x66FFFFFF),
                            Color(0xFFFFFFFF),
                          ],
                          stops: [0.0, 0.35, 0.55, 0.78],
                        ).createShader(bounds);
                      },
                      child: ColorFiltered(
                        colorFilter: const ColorFilter.matrix([
                          0.2126,
                          0.7152,
                          0.0722,
                          0,
                          0,
                          0.2126,
                          0.7152,
                          0.0722,
                          0,
                          0,
                          0.2126,
                          0.7152,
                          0.0722,
                          0,
                          0,
                          0,
                          0,
                          0,
                          1,
                          0,
                        ]),
                        child: Image.asset(
                          widget.member.imagePath,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            wash.withValues(alpha: 0.0),
                            wash.withValues(alpha: 0.0),
                            wash.withValues(alpha: 0.6),
                            wash.withValues(alpha: 0.8),
                          ],
                          stops: const [0.0, 0.45, 0.72, 1.0],
                        ),
                      ),
                    ),
                    Positioned(
                      left: 12,
                      right: 12,
                      bottom: 12,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.member.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: colors.textStrong,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              height: 1.15,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            widget.member.role,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: colors.textPrimary,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (widget.member.linkedInUrl != null) ...[
                            const SizedBox(height: 6),
                            withClickCursor(
                              GestureDetector(
                                onTap: _openLinkedIn,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 18,
                                      height: 18,
                                      decoration: BoxDecoration(
                                        color: colors.info,
                                        borderRadius: BorderRadius.circular(3),
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        'in',
                                        // `surface` inverts against `info` in
                                        // both modes: near-black on bright
                                        // cyan, white on deep teal.
                                        style: TextStyle(
                                          color: colors.surface,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800,
                                          height: 1,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      'LinkedIn',
                                      style: TextStyle(
                                        color: colors.info
                                            .withValues(alpha: 0.95),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CutCornerPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double cut;

  const _CutCornerPainter({
    required this.color,
    required this.strokeWidth,
    required this.cut,
  });

  Path _path(Size size, double inset) {
    final c = cut;
    final w = size.width - inset;
    final h = size.height - inset;
    final o = inset;
    return Path()
      ..moveTo(o + c, o)
      ..lineTo(w, o)
      ..lineTo(w, h - c)
      ..lineTo(w - c, h)
      ..lineTo(o, h)
      ..lineTo(o, o + c)
      ..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    // Inset by half the stroke so the full width stays inside the widget
    // and doesn't get clipped by parents.
    final inset = strokeWidth / 2;
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.miter
      ..isAntiAlias = true;

    canvas.drawPath(_path(size, inset), paint);
  }

  @override
  bool shouldRepaint(covariant _CutCornerPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.cut != cut;
  }
}

class _CutCornerClipper extends CustomClipper<Path> {
  final double cut;

  const _CutCornerClipper({required this.cut});

  @override
  Path getClip(Size size) {
    return Path()
      ..moveTo(cut, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height - cut)
      ..lineTo(size.width - cut, size.height)
      ..lineTo(0, size.height)
      ..lineTo(0, cut)
      ..close();
  }

  @override
  bool shouldReclip(covariant _CutCornerClipper oldClipper) =>
      oldClipper.cut != cut;
}
