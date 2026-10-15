import 'package:flutter/material.dart';
import '../../../l10n/l10n_extension.dart';

import '../../../core/theme/app_colors.dart';
import 'departments_settings_section.dart';
import 'devices_settings_section.dart';
import 'locations_settings_section.dart';
import 'insurance_companies_settings_section.dart';
import 'insurance_establishments_settings_section.dart';
import 'custody_types_settings_section.dart';
import 'job_titles_settings_section.dart';
import 'archive_reasons_settings_section.dart';

class AppSettingsSection extends StatefulWidget {
  const AppSettingsSection({
    super.key,
    this.embedded = false,
    this.showInsuranceEstablishments = true,
  });

  final bool embedded;
  /// Tab «منشآت التأمين» — only when `insurance_forms` entitlement is on.
  final bool showInsuranceEstablishments;

  @override
  State<AppSettingsSection> createState() => _AppSettingsSectionState();
}

class _AppSettingsSectionState extends State<AppSettingsSection>
    with SingleTickerProviderStateMixin {
  TabController? _tabs;

  @override
  void initState() {
    super.initState();
    _initTabs();
  }

  @override
  void didUpdateWidget(covariant AppSettingsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.showInsuranceEstablishments != widget.showInsuranceEstablishments) {
      _tabs?.dispose();
      _initTabs();
    }
  }

  void _initTabs() {
    _tabs = TabController(length: widget.showInsuranceEstablishments ? 8 : 7, vsync: this);
  }

  @override
  void dispose() {
    _tabs?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tabs = _tabs!;
    final tabWidgets = <Widget>[
      Tab(text: context.t('set.branchesAndLocations')),
      Tab(text: context.t('set.insurance')),
      if (widget.showInsuranceEstablishments) Tab(text: context.t('set.est')),
      Tab(text: context.t('set.departments')),
      Tab(text: context.t('set.devices')),
      Tab(text: context.t('set.custody')),
      Tab(text: context.t('set.jobTitles')),
      Tab(text: context.t('set.archiveReasons')),
    ];
    final viewWidgets = <Widget>[
      const SingleChildScrollView(child: LocationsSettingsSection(embedded: true)),
      const SingleChildScrollView(child: InsuranceCompaniesSettingsSection(embedded: true)),
      if (widget.showInsuranceEstablishments)
        const SingleChildScrollView(
          child: InsuranceEstablishmentsSettingsSection(embedded: true),
        ),
      const SingleChildScrollView(child: DepartmentsSettingsSection(embedded: true)),
      const SingleChildScrollView(child: DevicesSettingsSection(embedded: true)),
      const SingleChildScrollView(child: CustodyTypesSettingsSection(embedded: true)),
      const SingleChildScrollView(child: JobTitlesSettingsSection(embedded: true)),
      const SingleChildScrollView(child: ArchiveReasonsSettingsSection(embedded: true)),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!widget.embedded) ...[
          Text(context.t('set.title'), style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
        ],
        TabBar(
          controller: tabs,
          isScrollable: true,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          tabs: tabWidgets,
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 460,
          child: TabBarView(
            controller: tabs,
            children: viewWidgets,
          ),
        ),
      ],
    );
  }
}
