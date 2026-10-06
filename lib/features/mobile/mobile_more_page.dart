import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../core/locale/locale_cubit.dart';
import '../../core/router/app_router.dart';
import '../../l10n/app_localizations.dart';
import '../auth/auth_cubit.dart';
import '../auth/biometric_login.dart';
import '../shell/shell_nav.dart';
import 'mobile_ui.dart';

/// "More" tab on native mobile: every section the user can open as a grid of
/// icon cards, followed by account actions (fingerprint, language, sign out).
class MobileMorePage extends StatefulWidget {
  const MobileMorePage({
    super.key,
    required this.items,
    required this.location,
    required this.onOpen,
  });

  final List<NavItem> items;
  final String location;
  final ValueChanged<String> onOpen;

  @override
  State<MobileMorePage> createState() => _MobileMorePageState();
}

class _MobileMorePageState extends State<MobileMorePage> {
  bool _bioAvailable = false;
  bool _bioEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadBio();
  }

  Future<void> _loadBio() async {
    final available = await BiometricLogin.isAvailable();
    final enabled = available && await BiometricLogin.isEnabled();
    if (!mounted) return;
    setState(() {
      _bioAvailable = available;
      _bioEnabled = enabled;
    });
  }

  Future<void> _toggleBio(bool on) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    if (!on) {
      await BiometricLogin.disable();
      if (!mounted) return;
      setState(() => _bioEnabled = false);
      messenger.showSnackBar(SnackBar(content: Text(l10n.t('m.bioDisabled'))));
      return;
    }
    final creds = BiometricLogin.last;
    if (creds == null) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.t('m.bioNeedPassword'))));
      return;
    }
    if (!await BiometricLogin.authenticate(l10n.t('m.bioReason'))) return;
    await BiometricLogin.enable(
      company: creds.company,
      login: creds.login,
      password: creds.password,
    );
    if (!mounted) return;
    setState(() => _bioEnabled = true);
    messenger.showSnackBar(SnackBar(content: Text(l10n.t('m.bioEnabled'))));
  }

  Future<void> _signOut() async {
    await context.read<AuthCubit>().signOut();
    if (mounted) context.go(AppRoutes.signIn);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    var i = 0;
    Widget enter(Widget child) => child
        .animate(delay: Duration(milliseconds: 35 * i++))
        .fadeIn(duration: 300.ms)
        .scaleXY(begin: 0.94, end: 1, duration: 300.ms, curve: Curves.easeOutBack);

    return ColoredBox(
      color: MobileUi.background,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 110),
        children: [
          Text(l10n.t('m.moreTitle'), style: MobileUi.text(20, weight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(
            l10n.t('m.moreSub'),
            style: MobileUi.text(13, weight: FontWeight.w500, color: MobileUi.muted),
          ),
          const SizedBox(height: 16),
          LayoutBuilder(builder: (context, c) {
            const gap = 12.0;
            final w = (c.maxWidth - gap * 2) / 3;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                for (final item in widget.items)
                  SizedBox(
                    width: w,
                    child: enter(_SectionCard(
                      item: item,
                      selected: widget.location.startsWith(item.route),
                      onTap: () => widget.onOpen(item.route),
                    )),
                  ),
              ],
            );
          }),
          const SizedBox(height: 26),
          Text(l10n.t('m.account'), style: MobileUi.sectionTitle),
          const SizedBox(height: 12),
          Container(
            decoration: MobileUi.card(r: 20),
            child: Column(
              children: [
                if (_bioAvailable) ...[
                  _AccountRow(
                    icon: Icons.fingerprint_rounded,
                    color: MobileUi.primary,
                    title: l10n.t('m.bioLogin'),
                    trailing: Switch.adaptive(
                      value: _bioEnabled,
                      onChanged: _toggleBio,
                    ),
                    onTap: () => _toggleBio(!_bioEnabled),
                  ),
                  const _RowDivider(),
                ],
                _AccountRow(
                  icon: Icons.translate_rounded,
                  color: MobileTone.violet,
                  title: l10n.t('m.language'),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: MobileUi.primarySoft,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      l10n.isAr ? 'العربية' : 'English',
                      style: MobileUi.text(12.5, weight: FontWeight.w700, color: MobileUi.primary),
                    ),
                  ),
                  onTap: () => context
                      .read<LocaleCubit>()
                      .setLocale(Locale(l10n.isAr ? 'en' : 'ar')),
                ),
                const _RowDivider(),
                _AccountRow(
                  icon: Icons.logout_rounded,
                  color: MobileTone.danger,
                  title: l10n.logout,
                  titleColor: MobileTone.danger,
                  onTap: _signOut,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Filled icon and accent color for each menu section.
(IconData, Color) mobileSectionLook(IconData icon) => switch (icon) {
      Icons.schedule_outlined => (Icons.schedule_rounded, const Color(0xFF2F6BFF)),
      Icons.calendar_month_outlined => (Icons.calendar_month_rounded, const Color(0xFF0EA5E9)),
      Icons.assignment_outlined => (Icons.assignment_rounded, const Color(0xFFF59E0B)),
      Icons.assignment_ind_outlined => (Icons.badge_rounded, const Color(0xFF8B5CF6)),
      Icons.payments_outlined => (Icons.payments_rounded, const Color(0xFF10B981)),
      Icons.card_giftcard_outlined => (Icons.redeem_rounded, const Color(0xFFEC4899)),
      Icons.people_outline => (Icons.groups_rounded, const Color(0xFF2F6BFF)),
      Icons.access_time_outlined => (Icons.more_time_rounded, const Color(0xFF6366F1)),
      Icons.event_repeat_outlined => (Icons.event_repeat_rounded, const Color(0xFF14B8A6)),
      Icons.grid_on_outlined => (Icons.calendar_view_week_rounded, const Color(0xFF0891B2)),
      Icons.fact_check_outlined => (Icons.fact_check_rounded, const Color(0xFF22C55E)),
      Icons.remove_circle_outline => (Icons.money_off_rounded, const Color(0xFFEF4444)),
      Icons.account_balance_wallet_outlined =>
        (Icons.account_balance_wallet_rounded, const Color(0xFFF97316)),
      Icons.assessment_outlined => (Icons.insights_rounded, const Color(0xFF7C3AED)),
      Icons.settings_outlined => (Icons.settings_rounded, const Color(0xFF64748B)),
      Icons.account_tree_outlined => (Icons.account_tree_rounded, const Color(0xFF0D9488)),
      Icons.request_quote_outlined => (Icons.request_quote_rounded, const Color(0xFFEA580C)),
      Icons.my_location_outlined => (Icons.fingerprint_rounded, const Color(0xFF2F6BFF)),
      _ => (Icons.dashboard_rounded, MobileUi.primary),
    };

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final NavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = mobileSectionLook(item.icon);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          height: 124,
          padding: const EdgeInsets.fromLTRB(8, 16, 8, 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: selected ? color.withValues(alpha: 0.55) : const Color(0xFFEDF1F7),
              width: selected ? 1.6 : 1,
            ),
            boxShadow: MobileUi.softShadow,
          ),
          child: Column(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color.lerp(color, Colors.white, 0.18)!, color],
                  ),
                  borderRadius: BorderRadius.circular(17),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.32),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Icon(icon, color: Colors.white, size: 27),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: Center(
                  child: Text(
                    item.label,
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: MobileUi.text(12.5, weight: FontWeight.w700, height: 1.25),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AccountRow extends StatelessWidget {
  const _AccountRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.onTap,
    this.trailing,
    this.titleColor,
  });

  final IconData icon;
  final Color color;
  final String title;
  final VoidCallback onTap;
  final Widget? trailing;
  final Color? titleColor;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            MobileIconBadge(icon: icon, color: color, size: 40),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: MobileUi.text(14.5, weight: FontWeight.w700, color: titleColor ?? MobileUi.ink),
              ),
            ),
            trailing ??
                Icon(
                  Directionality.of(context) == TextDirection.rtl
                      ? Icons.chevron_left_rounded
                      : Icons.chevron_right_rounded,
                  color: MobileUi.muted,
                ),
          ],
        ),
      ),
    );
  }
}

class _RowDivider extends StatelessWidget {
  const _RowDivider();

  @override
  Widget build(BuildContext context) => const Divider(
        height: 1,
        indent: 66,
        endIndent: 14,
        color: Color(0xFFEDF1F7),
      );
}
