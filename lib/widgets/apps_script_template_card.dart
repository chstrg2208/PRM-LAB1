import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../widgets/birdle_components.dart';

/// Trạng thái tải mã nguồn Google Apps Script
enum ScriptLoadState { loading, loaded, error }

/// Widget hiển thị và sao chép mã nguồn Google Apps Script (Code.gs) từ asset bundle
class AppsScriptTemplateCard extends StatefulWidget {
  final AssetBundle? bundle;
  final String assetPath;

  const AppsScriptTemplateCard({
    super.key,
    this.bundle,
    this.assetPath = 'google-apps-script/Code.gs',
  });

  @override
  State<AppsScriptTemplateCard> createState() => _AppsScriptTemplateCardState();
}

class _AppsScriptTemplateCardState extends State<AppsScriptTemplateCard> {
  ScriptLoadState _state = ScriptLoadState.loading;
  String _scriptContent = '';
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadScript();
  }

  @override
  void didUpdateWidget(covariant AppsScriptTemplateCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.assetPath != widget.assetPath || oldWidget.bundle != widget.bundle) {
      _loadScript();
    }
  }

  Future<void> _loadScript() async {
    setState(() {
      _state = ScriptLoadState.loading;
      _scriptContent = '';
      _errorMessage = '';
    });

    try {
      String content = '';
      if (widget.bundle != null) {
        content = await widget.bundle!.loadString(widget.assetPath);
      } else {
        // Trên môi trường Desktop Windows, ưu tiên đọc file trực tiếp từ source để luôn có bản mới nhất
        try {
          final file = File(widget.assetPath);
          if (file.existsSync()) {
            content = await file.readAsString();
          }
        } catch (_) {}

        if (content.isEmpty) {
          content = await rootBundle.loadString(widget.assetPath);
        }
      }

      if (!mounted) return;
      setState(() {
        _state = ScriptLoadState.loaded;
        _scriptContent = content;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _state = ScriptLoadState.error;
        _errorMessage = 'Không thể tải mã nguồn Google Apps Script từ asset: $e';
      });
    }
  }

  Future<void> _copyScript() async {
    if (_state != ScriptLoadState.loaded || _scriptContent.isEmpty) return;

    await Clipboard.setData(ClipboardData(text: _scriptContent));
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✓ Đã sao chép toàn bộ mã nguồn Google Apps Script!'),
        backgroundColor: BirdleColors.brand,
        duration: Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BirdleCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Mã Nguồn Backend Google Apps Script (Code.gs)',
                  style: BirdleTypography.cardTitle,
                ),
              ),
              const SizedBox(width: 12),
              if (_state == ScriptLoadState.loading)
                const BirdleSecondaryButton(
                  icon: Icons.copy,
                  label: 'Đang tải...',
                  isLoading: true,
                  onPressed: null,
                )
              else if (_state == ScriptLoadState.error)
                BirdleSecondaryButton(
                  icon: Icons.refresh,
                  label: 'Thử lại',
                  onPressed: _loadScript,
                )
              else
                BirdleSecondaryButton(
                  icon: Icons.copy,
                  label: 'Sao chép mã',
                  onPressed: _copyScript,
                ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            height: 180,
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: BirdleColors.surfaceSecondary,
              borderRadius: BirdleRadius.smBorder,
              border: Border.all(color: BirdleColors.border),
            ),
            child: _buildBody(),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    switch (_state) {
      case ScriptLoadState.loading:
        return const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2, color: BirdleColors.textSecondary),
              ),
              SizedBox(height: 8),
              Text(
                'Đang tải mã nguồn Google Apps Script...',
                style: TextStyle(fontSize: 12, color: BirdleColors.textMuted),
              ),
            ],
          ),
        );
      case ScriptLoadState.error:
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: BirdleColors.danger, size: 28),
              const SizedBox(height: 8),
              const Text(
                'Không thể tải mã nguồn Google Apps Script',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: BirdleColors.danger),
              ),
              if (_errorMessage.isNotEmpty) ...[
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    _errorMessage,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11.5, color: BirdleColors.textMuted),
                  ),
                ),
              ],
            ],
          ),
        );
      case ScriptLoadState.loaded:
        return SingleChildScrollView(
          child: SelectableText(
            _scriptContent,
            style: const TextStyle(
              fontSize: 11.5,
              fontFamily: 'Consolas, monospace',
              color: BirdleColors.textPrimary,
              height: 1.4,
            ),
          ),
        );
    }
  }
}
