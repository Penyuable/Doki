import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';

import '../../core/i18n/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/ui/widgets.dart';
import '../../domain/models/card_model.dart';
import '../settings/settings_cubit.dart';

enum _ViewerStatus { loading, ready, failed }

class CardViewer3DPage extends StatefulWidget {
  const CardViewer3DPage({super.key, required this.card});

  final CardModel card;

  @override
  State<CardViewer3DPage> createState() => _CardViewer3DPageState();
}

class _CardViewer3DPageState extends State<CardViewer3DPage> {
  static const Duration _loadTimeout = Duration(seconds: 5);

  _ViewerStatus _status = _ViewerStatus.loading;
  Timer? _timeout;

  @override
  void initState() {
    super.initState();
    if (widget.card.model3dUrl == null || widget.card.model3dUrl!.isEmpty) {
      _status = _ViewerStatus.failed;
      return;
    }
    _timeout = Timer(_loadTimeout, () {
      if (!mounted || _status != _ViewerStatus.loading) return;
      setState(() => _status = _ViewerStatus.failed);
    });
  }

  @override
  void dispose() {
    _timeout?.cancel();
    super.dispose();
  }

  void _markReady() {
    _timeout?.cancel();
    if (!mounted || _status == _ViewerStatus.ready) return;
    setState(() => _status = _ViewerStatus.ready);
  }

  void _markFailed() {
    _timeout?.cancel();
    if (!mounted || _status == _ViewerStatus.failed) return;
    setState(() => _status = _ViewerStatus.failed);
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final batterySaver = context.watch<SettingsCubit>().state.batterySaver;
    final modelUrl = widget.card.model3dUrl;

    return Scaffold(
      appBar: AppBar(
        title: Text(strings.t('card.view3dTitle')),
        leading: IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
      ),
      body: AppBackground(
        child: SafeArea(
          top: false,
          child: Column(
            children: <Widget>[
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    if (modelUrl != null && _status != _ViewerStatus.failed)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: ModelViewer(
                          src: modelUrl,
                          alt: widget.card.name,
                          backgroundColor: Colors.transparent,
                          autoRotate: !batterySaver,
                          cameraControls: true,
                          disableZoom: false,
                          interactionPrompt: InteractionPrompt.none,
                          debugLogging: false,
                          javascriptChannels: <JavascriptChannel>{
                            JavascriptChannel(
                              'DokimonModel',
                              onMessageReceived: (message) {
                                if (message.message == 'loaded') {
                                  _markReady();
                                } else if (message.message == 'error') {
                                  _markFailed();
                                }
                              },
                            ),
                          },
                          relatedJs: _relatedJs,
                        ),
                      )
                    else
                      _Fallback(card: widget.card, message: strings.t('card.3dError')),
                    if (_status == _ViewerStatus.loading &&
                        modelUrl != null)
                      Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            const CircularProgressIndicator(),
                            const SizedBox(height: 12),
                            Text(strings.t('card.3dLoading')),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                child: Column(
                  children: <Widget>[
                    Text(
                      widget.card.name,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    ElementChip(
                      element: widget.card.element,
                      label: strings.t(widget.card.element.i18nKey),
                    ),
                    if (_status == _ViewerStatus.failed &&
                        modelUrl != null) ...<Widget>[
                      const SizedBox(height: 8),
                      Text(
                        strings.t('card.3dError'),
                        style: Theme.of(context).textTheme.bodySmall,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static const String _relatedJs = '''
    (function check() {
      try {
        var viewer = document.querySelector('model-viewer');
        if (!viewer) {
          setTimeout(check, 100);
          return;
        }
        viewer.addEventListener('load', function () {
          window.DokimonModel.postMessage('loaded');
        });
        viewer.addEventListener('error', function () {
          window.DokimonModel.postMessage('error');
        });
      } catch (e) {
        window.DokimonModel.postMessage('error');
      }
    })();
  ''';
}

class _Fallback extends StatelessWidget {
  const _Fallback({required this.card, required this.message});

  final CardModel card;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 240),
              child: AspectRatio(
                aspectRatio: 2 / 3,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: AppTheme.rarityColor(
                        card.rarity,
                      ).withValues(alpha: 0.6),
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(17),
                    child: CardArtwork(card: card),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
