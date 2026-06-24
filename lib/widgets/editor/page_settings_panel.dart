import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../state/editor_state.dart';
import '../../theme/app_colors.dart';
import '../common/color_input.dart';

class PageSettingsPanel extends StatefulWidget {
  const PageSettingsPanel({super.key});

  @override
  State<PageSettingsPanel> createState() => _PageSettingsPanelState();
}

class _PageSettingsPanelState extends State<PageSettingsPanel> {
  bool _open = false;
  double? _pendingW;
  double? _pendingH;
  bool _applying = false;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<EditorState>();
    final template = state.template;
    if (template == null) return const SizedBox();

    final currentW = template.canvasWidthMm;
    final currentH = template.canvasHeightMm;
    final pendingW = _pendingW ?? currentW;
    final pendingH = _pendingH ?? currentH;
    final hasChanges = pendingW != currentW || pendingH != currentH;

    return Container(
      decoration: BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.border))),
      child: Column(children: [
        // Toggle header
        GestureDetector(
          onTap: () => setState(() => _open = !_open),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: Colors.transparent,
            child: Row(children: [
              Expanded(
                child: Text(
                  'Page · ${template.canvasSize}',
                  style: const TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ),
              Text(
                '${currentW.toStringAsFixed(0)}×${currentH.toStringAsFixed(0)}',
                style: const TextStyle(
                    fontSize: 10, color: AppColors.mutedForeground),
              ),
            ]),
          ),
        ),

        if (_open) ...[
          Container(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              // Size selector
              const Text('SIZE (MM)',
                  style: TextStyle(
                      fontSize: 10,
                      letterSpacing: 0.05,
                      color: AppColors.mutedForeground)),
              const SizedBox(height: 6),
              Row(children: [
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Width', style: TextStyle(fontSize: 9, color: AppColors.mutedForeground)),
                    TextField(
                      controller: TextEditingController(text: pendingW.toStringAsFixed(0)),
                      keyboardType: TextInputType.number,
                      style: const TextStyle(fontSize: 11),
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(6),
                            borderSide: const BorderSide(color: AppColors.border)),
                      ),
                      onChanged: (v) => setState(() => _pendingW = double.tryParse(v) ?? _pendingW),
                    ),
                  ],
                )),
                const Padding(
                  padding: EdgeInsets.fromLTRB(6, 16, 6, 0),
                  child: Text('×', style: TextStyle(color: AppColors.mutedForeground)),
                ),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Height', style: TextStyle(fontSize: 9, color: AppColors.mutedForeground)),
                    TextField(
                      controller: TextEditingController(text: pendingH.toStringAsFixed(0)),
                      keyboardType: TextInputType.number,
                      style: const TextStyle(fontSize: 11),
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(6),
                            borderSide: const BorderSide(color: AppColors.border)),
                      ),
                      onChanged: (v) => setState(() => _pendingH = double.tryParse(v) ?? _pendingH),
                    ),
                  ],
                )),
              ]),
              const SizedBox(height: 12),

              // Background
              const Text('BACKGROUND',
                  style: TextStyle(
                      fontSize: 10,
                      letterSpacing: 0.05,
                      color: AppColors.mutedForeground)),
              const SizedBox(height: 6),
              ColorInput(
                value: template.backgroundColor,
                onChanged: (v) => state.updateBackgroundColor(v),
              ),
              const SizedBox(height: 4),
              const Text('Applies to the entire document surface.',
                  style: TextStyle(fontSize: 9, color: AppColors.mutedForeground)),

              const SizedBox(height: 12),
              const Text('LAYOUT',
                  style: TextStyle(
                      fontSize: 10,
                      letterSpacing: 0.05,
                      color: AppColors.mutedForeground)),
              const SizedBox(height: 6),
              Row(children: [
                Expanded(
                  child: Text(
                    'Section layout',
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
                Switch(
                  value: state.sectionLayoutEnabled,
                  onChanged: state.setSectionLayoutEnabled,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ]),
              Text(
                state.sectionLayoutEnabled
                    ? 'Rows and columns flow at the top of the page.'
                    : 'Rows and columns can be placed anywhere on the canvas.',
                style: const TextStyle(
                    fontSize: 10, color: AppColors.mutedForeground),
              ),

              // Apply button
              if (hasChanges) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _applying ? null : () => _apply(state),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6)),
                    ),
                    child: Text(
                      _applying ? 'Applying…' : 'Apply & rescale elements',
                      style: const TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ]),
          ),
        ],
      ]),
    );
  }

  Future<void> _apply(EditorState state) async {
    setState(() => _applying = true);
    await state.applyCanvasResize(
        _pendingW ?? state.template!.canvasWidthMm,
        _pendingH ?? state.template!.canvasHeightMm);
    if (mounted) {
      setState(() {
        _pendingW = null;
        _pendingH = null;
        _applying = false;
      });
    }
  }
}

