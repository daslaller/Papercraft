import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../state/editor_state.dart';
import '../../theme/app_colors.dart';
import 'layers_tree.dart';
import 'page_settings_panel.dart';
import 'properties_panel.dart';
import 'sidebar_utils.dart';

class RightSidebar extends StatefulWidget {
  const RightSidebar({super.key});

  @override
  State<RightSidebar> createState() => _RightSidebarState();
}

class _RightSidebarState extends State<RightSidebar> {
  bool _open = true;
  double _width = 248;
  String _tab = 'properties'; // 'properties' | 'layers' | 'page'

  @override
  Widget build(BuildContext context) {
    final state = context.watch<EditorState>();
    final el = state.selectedElement;

    if (!_open) {
      return SidebarPill(
        label: 'PROPS',
        side: 'right',
        onTap: () => setState(() => _open = true),
      );
    }

    // Auto-switch to Properties tab when an element is selected
    if (el != null && _tab == 'layers') {
      // Don't auto-switch — let user stay on the tab they chose
    }

    return ResizableSidebar(
      width: _width,
      side: 'left',
      onWidthChanged: (w) => setState(() => _width = w),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.panelBg,
          border: Border(left: BorderSide(color: AppColors.border)),
        ),
        child: Column(children: [
          _buildTabBar(el),
          Expanded(child: _buildTabContent()),
        ]),
      ),
    );
  }

  Widget _buildTabBar(dynamic el) {
    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(children: [
        _Tab(label: 'Properties', active: _tab == 'properties', onTap: () => setState(() => _tab = 'properties')),
        _Tab(label: 'Layers', active: _tab == 'layers', onTap: () => setState(() => _tab = 'layers')),
        _Tab(label: 'Page', active: _tab == 'page', onTap: () => setState(() => _tab = 'page')),
        const SizedBox(width: 4),
        GestureDetector(
          onTap: () => setState(() => _open = false),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: const Icon(Icons.close, size: 13, color: AppColors.mutedForeground),
          ),
        ),
      ]),
    );
  }

  Widget _buildTabContent() {
    return switch (_tab) {
      'layers' => const _LayersTab(),
      'page' => const SingleChildScrollView(child: PageSettingsPanel()),
      _ => const PropertiesPanel(),
    };
  }
}

class _Tab extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _Tab({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: active ? AppColors.accent : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              fontWeight: active ? FontWeight.w600 : FontWeight.w400,
              color: active ? AppColors.accent : AppColors.mutedForeground,
            ),
          ),
        ),
      ),
    );
  }
}

// Layers tab wraps the full layers tree in an Expanded scroll
class _LayersTab extends StatelessWidget {
  const _LayersTab();

  @override
  Widget build(BuildContext context) {
    return const Column(children: [
      Expanded(child: LayersTree()),
    ]);
  }
}
