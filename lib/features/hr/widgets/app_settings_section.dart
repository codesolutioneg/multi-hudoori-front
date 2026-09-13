import 'package:flutter/material.dart';
import '../../../l10n/l10n_extension.dart';

import '../../../core/theme/app_colors.dart';
import 'departments_settings_section.dart';
import 'devices_settings_section.dart';
import 'locations_settings_section.dart';
import 'insurance_companies_settings_section.dart';
import 'custody_types_settings_section.dart';
import 'job_titles_settings_section.dart';
import 'archive_reasons_settings_section.dart';

class AppSettingsSection extends StatefulWidget {
  const AppSettingsSection({super.key, this.embedded = false});

  final bool embedded;

  @override
  State<AppSettingsSection> createState() => _AppSettingsSectionState();
}

class _AppSettingsSectionState extends State<AppSettingsSection> with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 7, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!widget.embedded) ...[
          Text(context.t('set.title'), style: TextStyle(fontWeight: FontWeight.w700)),
          SizedBox(height: 12),
        ],
        TabBar(
          controller: _tabs,
          isScrollable: true,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          tabs: [
            Tab(text: context.t('set.branchesAndLocations')),
            Tab(text: context.t('set.insurance')),
            Tab(text: context.t('set.departments')),
            Tab(text: context.t('set.devices')),
            Tab(text: context.t('set.custody')),
            Tab(text: context.t('set.jobTitles')),
            Tab(text: context.t('set.archiveReasons')),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 460,
          child: TabBarView(
            controller: _tabs,
            children: const [
              SingleChildScrollView(child: LocationsSettingsSection(embedded: true)),
              SingleChildScrollView(child: InsuranceCompaniesSettingsSection(embedded: true)),
              SingleChildScrollView(child: DepartmentsSettingsSection(embedded: true)),
              SingleChildScrollView(child: DevicesSettingsSection(embedded: true)),
              SingleChildScrollView(child: CustodyTypesSettingsSection(embedded: true)),
              SingleChildScrollView(child: JobTitlesSettingsSection(embedded: true)),
              SingleChildScrollView(child: ArchiveReasonsSettingsSection(embedded: true)),
            ],
          ),
        ),
      ],
    );
  }
}
