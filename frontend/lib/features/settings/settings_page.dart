import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/config/env.dart';
import '../../core/i18n/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/ui/widgets.dart';
import '../auth/auth_cubit.dart';
import 'settings_cubit.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(strings.t('settings.title')),
        leading: IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
      ),
      body: AppBackground(
        child: SafeArea(
          top: false,
          child: BlocBuilder<SettingsCubit, AppSettings>(
            builder: (context, settings) {
              final cubit = context.read<SettingsCubit>();
              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
                children: <Widget>[
                  SectionHeader(title: strings.t('settings.language')),
                  Panel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        SegmentedButton<String>(
                          segments: const <ButtonSegment<String>>[
                            ButtonSegment<String>(
                              value: 'id',
                              label: Text('Bahasa Indonesia'),
                            ),
                            ButtonSegment<String>(
                              value: 'en',
                              label: Text('English'),
                            ),
                          ],
                          selected: <String>{settings.localeCode},
                          onSelectionChanged: (selection) {
                            if (selection.isEmpty) return;
                            cubit.setLocale(selection.first);
                          },
                        ),
                        const SizedBox(height: 8),
                        Text(
                          strings.t('settings.languageHint'),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  SectionHeader(title: strings.t('settings.title')),
                  Panel(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: <Widget>[
                        SwitchListTile(
                          value: settings.reduceMotion,
                          onChanged: cubit.setReduceMotion,
                          secondary: const Icon(
                            Icons.motion_photos_off_rounded,
                            color: AppTheme.primary,
                          ),
                          title: Text(strings.t('settings.reduceMotion')),
                          subtitle: Text(
                            strings.t('settings.reduceMotionHint'),
                          ),
                        ),
                        const Divider(height: 1),
                        SwitchListTile(
                          value: settings.haptics,
                          onChanged: cubit.setHaptics,
                          secondary: const Icon(
                            Icons.vibration_rounded,
                            color: AppTheme.accent,
                          ),
                          title: Text(strings.t('settings.haptics')),
                          subtitle: Text(strings.t('settings.hapticsHint')),
                        ),
                        const Divider(height: 1),
                        SwitchListTile(
                          value: settings.batterySaver,
                          onChanged: cubit.setBatterySaver,
                          secondary: const Icon(
                            Icons.battery_saver_rounded,
                            color: AppTheme.success,
                          ),
                          title: Text(strings.t('settings.batterySaver')),
                          subtitle: Text(
                            strings.t('settings.batterySaverHint'),
                          ),
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(
                            Icons.volume_off_rounded,
                            color: AppTheme.inkSoft,
                          ),
                          title: Text(strings.t('settings.audio')),
                          subtitle: Text(strings.t('settings.audioPending')),
                          trailing: Text(
                            strings.t('settings.audioHint'),
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppTheme.inkFaint,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  SectionHeader(title: strings.t('settings.about')),
                  Panel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            const Clay(
                              width: 42,
                              height: 42,
                              radius: 16,
                              color: AppTheme.primary,
                              depth: 0.7,
                              alignment: Alignment.center,
                              child: Icon(
                                Icons.auto_awesome_mosaic_rounded,
                                color: Colors.white,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    strings.t('app.name'),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 15,
                                    ),
                                  ),
                                  Text(
                                    strings.t('app.tagline'),
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          strings.t('profile.version', <String, String>{
                            'version': Env.appVersion,
                          }),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  if (!Env.offlineMode) ...<Widget>[
                    const SizedBox(height: 18),
                    SectionHeader(title: strings.t('settings.session')),
                    Panel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          Text(
                            strings.t('settings.sessionHint'),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: () => _logout(context),
                            icon: const Icon(Icons.logout_rounded, size: 18),
                            label: Text(strings.t('profile.logout')),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.danger,
                              side: BorderSide(
                                color: const Color(
                                  0xFFF87171,
                                ).withValues(alpha: 0.4),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _logout(BuildContext context) async {
    final strings = AppStrings.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(strings.t('auth.logout')),
        content: Text(strings.t('auth.logoutConfirm')),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(strings.t('common.cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(strings.t('auth.logout')),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    await context.read<AuthCubit>().logout();
    if (context.mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }
}
