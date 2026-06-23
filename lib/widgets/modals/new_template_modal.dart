import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/template_model.dart';
import '../../services/auth_service.dart';
import '../../services/template_service.dart';
import '../../theme/app_colors.dart';

class NewTemplateModal extends StatefulWidget {
  const NewTemplateModal({super.key});

  @override
  State<NewTemplateModal> createState() => _NewTemplateModalState();
}

class _NewTemplateModalState extends State<NewTemplateModal> {
  final _nameCtrl = TextEditingController();
  String _docType = 'label';
  String _sizeKey = '4x6';
  double _customW = 100;
  double _customH = 100;
  bool _creating = false;

  List<CanvasSize> get _filteredSizes {
    return kCanvasSizes.where((s) =>
        s.category == _docType || s.category == 'both').toList();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (_nameCtrl.text.trim().isEmpty) return;
    setState(() => _creating = true);
    final user = context.read<AuthService>().user;
    if (user == null) return;

    double wMm, hMm;
    if (_sizeKey == 'custom') {
      wMm = _customW;
      hMm = _customH;
    } else {
      final size = kCanvasSizes.firstWhere((s) => s.key == _sizeKey);
      wMm = size.widthMm;
      hMm = size.heightMm;
    }

    final template = await TemplateService.create(
      name: _nameCtrl.text.trim(),
      docType: _docType,
      canvasSize: _sizeKey,
      widthMm: wMm,
      heightMm: hMm,
      ownerId: user.id,
    );
    if (!mounted) return;
    Navigator.of(context).pop(template);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: GestureDetector(
        onTap: () {},
        child: Container(
          width: 512,
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(16),
            boxShadow: AppColors.shadowXL,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.9,
            ),
            child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(32, 32, 32, 24),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('New Template',
                              style: Theme.of(context).textTheme.headlineMedium),
                          const SizedBox(height: 4),
                          const Text(
                            'Choose a type and size to get started.',
                            style: TextStyle(
                                fontSize: 14,
                                color: AppColors.mutedForeground),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: AppColors.border),
              // Content
              Flexible(
               child: SingleChildScrollView(
                child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionLabel('TEMPLATE NAME'),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _nameCtrl,
                      autofocus: true,
                      onSubmitted: (_) => _create(),
                      decoration: InputDecoration(
                        hintText: 'e.g. Shipping Label, Invoice…',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 24),
                    _sectionLabel('DOCUMENT TYPE'),
                    const SizedBox(height: 8),
                    Row(children: [
                      Expanded(child: _TypeOption(
                        icon: Icons.label_outline,
                        title: 'Label / Sticker',
                        desc: 'Free-position canvas for labels and stickers',
                        selected: _docType == 'label',
                        onTap: () => setState(() {
                          _docType = 'label';
                          _sizeKey = '4x6';
                        }),
                      )),
                      const SizedBox(width: 12),
                      Expanded(child: _TypeOption(
                        icon: Icons.description_outlined,
                        title: 'Formal Document',
                        desc: 'Letter, invoice, certificate, or report',
                        selected: _docType == 'document',
                        onTap: () => setState(() {
                          _docType = 'document';
                          _sizeKey = 'A4';
                        }),
                      )),
                    ]),
                    const SizedBox(height: 24),
                    _sectionLabel('CANVAS SIZE'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _filteredSizes.map((size) {
                        final active = _sizeKey == size.key;
                        return GestureDetector(
                          onTap: () => setState(() => _sizeKey = size.key),
                          child: Container(
                            width: 120,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: active ? AppColors.accent : Colors.transparent,
                              border: Border.all(
                                color: active ? AppColors.accent : AppColors.border,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(children: [
                              Text(
                                size.label,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: active
                                        ? AppColors.accentForeground
                                        : AppColors.foreground),
                              ),
                              if (size.key != 'custom') ...[
                                const SizedBox(height: 2),
                                Text(
                                  '${size.widthMm.toStringAsFixed(0)}×${size.heightMm.toStringAsFixed(0)}mm',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      fontSize: 9,
                                      color: active
                                          ? AppColors.accentForeground
                                              .withValues(alpha: 0.7)
                                          : AppColors.mutedForeground),
                                ),
                              ],
                            ]),
                          ),
                        );
                      }).toList(),
                    ),
                    if (_sizeKey == 'custom') ...[
                      const SizedBox(height: 12),
                      Row(children: [
                        Expanded(child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Width (mm)',
                                style: TextStyle(fontSize: 10, color: AppColors.mutedForeground)),
                            const SizedBox(height: 4),
                            TextField(
                              keyboardType: TextInputType.number,
                              onChanged: (v) => setState(() => _customW = double.tryParse(v) ?? _customW),
                              decoration: InputDecoration(
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                hintText: '100',
                              ),
                            ),
                          ],
                        )),
                        const Padding(
                            padding: EdgeInsets.fromLTRB(12, 20, 12, 0),
                            child: Text('×', style: TextStyle(color: AppColors.mutedForeground))),
                        Expanded(child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Height (mm)',
                                style: TextStyle(fontSize: 10, color: AppColors.mutedForeground)),
                            const SizedBox(height: 4),
                            TextField(
                              keyboardType: TextInputType.number,
                              onChanged: (v) => setState(() => _customH = double.tryParse(v) ?? _customH),
                              decoration: InputDecoration(
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                hintText: '100',
                              ),
                            ),
                          ],
                        )),
                      ]),
                    ],
                  ],
                ),
              ), // Padding
              )), // SingleChildScrollView + Flexible
              // Footer
              Padding(
                padding: const EdgeInsets.fromLTRB(32, 0, 32, 32),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 10),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 12),
                    ValueListenableBuilder(
                      valueListenable: _nameCtrl,
                      builder: (_, __, ___) => FilledButton(
                        onPressed: (_nameCtrl.text.trim().isEmpty || _creating)
                            ? null
                            : _create,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.accent,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 10),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: _creating
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : const Text('Create Template',
                                style: TextStyle(fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ), // Column
          ), // ConstrainedBox
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) => Text(
        text,
        style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.05,
            color: AppColors.mutedForeground),
      );
}

class _TypeOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String desc;
  final bool selected;
  final VoidCallback onTap;

  const _TypeOption({
    required this.icon,
    required this.title,
    required this.desc,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? withAlpha(AppColors.accent, 0.05) : Colors.transparent,
          border: Border.all(
            color: selected ? AppColors.accent : AppColors.border,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon,
              size: 20,
              color: selected ? AppColors.accent : AppColors.mutedForeground),
          const SizedBox(height: 8),
          Text(title,
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(desc,
              style: const TextStyle(
                  fontSize: 11, color: AppColors.mutedForeground)),
        ]),
      ),
    );
  }
}
