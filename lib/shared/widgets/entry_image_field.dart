import 'dart:io' show Platform;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';

/// 附图选择与预览（PRD 7.1.1 步骤 2 / 7.2.1 步骤 2：文字 + 图片，支持多图）。
///
/// 只负责「选图 → 拿到字节」这一段。加密与落盘在控制器里做，
/// 界面这一层拿不到、也不需要知道图片最终存在哪里。
///
/// 两个刻意的取舍：
/// - **入库前先缩放**：手机原图动辄好几 MB，直接加密存盘会让日记体积失控。
///   交给 `image_picker` 压到长边 1600、质量 85，肉眼几乎无差、体积降到十分之一。
/// - **桌面端不提供「拍照」**：macOS 没有相机采集能力，给一个必然失败的入口
///   不如不给。相册（文件选择）在桌面端照常可用。
class EntryImageField extends StatefulWidget {
  const EntryImageField({
    required this.images,
    required this.onChanged,
    super.key,
    this.maxImages = AppConstants.maxImagesPerEntry,
  });

  /// 当前已选图片的字节。
  final List<Uint8List> images;

  /// 选择结果回调。新增、删除都通过它回传完整列表。
  final ValueChanged<List<Uint8List>> onChanged;

  /// 最多可选张数。
  final int maxImages;

  @override
  State<EntryImageField> createState() => _EntryImageFieldState();
}

class _EntryImageFieldState extends State<EntryImageField> {
  final ImagePicker _picker = ImagePicker();
  bool _busy = false;

  /// 长边缩放到这个尺寸再入库，兼顾观感与体积。
  static const double _maxSide = 1600;

  /// 重编码质量。
  static const int _quality = 85;

  bool get _isFull => widget.images.length >= widget.maxImages;

  Future<void> _pickFromGallery() async {
    final files = await _picker.pickMultiImage(
      maxWidth: _maxSide,
      maxHeight: _maxSide,
      imageQuality: _quality,
    );
    await _append(files);
  }

  Future<void> _pickFromCamera() async {
    final file = await _picker.pickImage(
      source: ImageSource.camera,
      maxWidth: _maxSide,
      maxHeight: _maxSide,
      imageQuality: _quality,
    );
    if (file != null) {
      await _append(<XFile>[file]);
    }
  }

  Future<void> _append(List<XFile> files) async {
    if (files.isEmpty || !mounted) {
      return;
    }

    setState(() => _busy = true);
    try {
      final picked = <Uint8List>[];
      for (final file in files) {
        picked.add(await file.readAsBytes());
      }
      if (!mounted) {
        return;
      }

      final merged = <Uint8List>[...widget.images, ...picked];
      widget.onChanged(merged.take(widget.maxImages).toList(growable: false));

      if (merged.length > widget.maxImages) {
        _toast('最多只能放 ${widget.maxImages} 张，多的没有加进来');
      }
    } catch (error) {
      // 用户取消、权限被拒、读取失败都会走到这里。
      // 不弹技术细节，只说明结果，并保证界面回到可用状态。
      if (mounted) {
        _toast('没能读到这张图片，可以换一张试试');
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  void _removeAt(int index) {
    final next = <Uint8List>[...widget.images]..removeAt(index);
    widget.onChanged(next);
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _showSourceSheet() async {
    if (_isFull || _busy) {
      if (_isFull) {
        _toast('最多只能放 ${widget.maxImages} 张');
      }
      return;
    }

    // 桌面端没有相机采集能力，直接走相册，不摆一个必然失败的选项。
    final canShoot = !Platform.isMacOS && !Platform.isWindows && !Platform.isLinux;

    final choice = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppColors.creamWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppTheme.cardRadius),
        ),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (canShoot)
              ListTile(
                leading: const Text('📷', style: TextStyle(fontSize: 20)),
                title: const Text('拍一张'),
                onTap: () =>
                    Navigator.of(sheetContext).pop(ImageSource.camera),
              ),
            ListTile(
              leading: const Text('🖼️', style: TextStyle(fontSize: 20)),
              title: const Text('从相册选'),
              onTap: () => Navigator.of(sheetContext).pop(ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (choice == null || !mounted) {
      return;
    }
    if (choice == ImageSource.camera) {
      await _pickFromCamera();
    } else {
      await _pickFromGallery();
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (widget.images.isNotEmpty) ...<Widget>[
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: <Widget>[
              for (var i = 0; i < widget.images.length; i++)
                _Thumbnail(
                  bytes: widget.images[i],
                  onRemove: () => _removeAt(i),
                ),
            ],
          ),
          const SizedBox(height: 10),
        ],
        _AddTile(
          busy: _busy,
          enabled: !_isFull,
          remaining: widget.maxImages - widget.images.length,
          onTap: _showSourceSheet,
        ),
        if (_isFull) ...<Widget>[
          const SizedBox(height: 6),
          Text('已经放满 ${widget.maxImages} 张了', style: textTheme.labelSmall),
        ],
      ],
    );
  }
}

/// 一张已选图片的缩略图，右上角带删除。
class _Thumbnail extends StatelessWidget {
  const _Thumbnail({required this.bytes, required this.onRemove});

  final Uint8List bytes;
  final VoidCallback onRemove;

  static const double _size = 78;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _size,
      height: _size,
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          ClipRRect(
            borderRadius: BorderRadius.circular(AppTheme.controlRadius - 4),
            child: Image.memory(
              bytes,
              width: _size,
              height: _size,
              fit: BoxFit.cover,
              // 图片解不开时不留空白块，直接给个占位，别让界面塌掉。
              errorBuilder: (context, error, stackTrace) => Container(
                color: AppColors.creamSoft,
                alignment: Alignment.center,
                child: const Text('🖼️', style: TextStyle(fontSize: 20)),
              ),
            ),
          ),
          Positioned(
            right: -6,
            top: -6,
            child: Semantics(
              button: true,
              label: '移除这张图片',
              child: InkWell(
                onTap: onRemove,
                customBorder: const CircleBorder(),
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(
                    color: AppColors.inkSecondary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close,
                    size: 13,
                    color: AppColors.inkInverse,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 「加张照片」按钮。
class _AddTile extends StatelessWidget {
  const _AddTile({
    required this.busy,
    required this.enabled,
    required this.remaining,
    required this.onTap,
  });

  final bool busy;
  final bool enabled;
  final int remaining;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Semantics(
      button: true,
      enabled: enabled,
      label: '添加图片',
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(AppTheme.controlRadius),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: enabled ? AppColors.creamSoft : AppColors.creamDeep,
            borderRadius: BorderRadius.circular(AppTheme.controlRadius),
            border: Border.all(
              color: enabled
                  ? AppColors.warmApricotSoft
                  : AppColors.creamDeep,
            ),
          ),
          // 用 Wrap 而非 Row：字体放大到 2x 时「加张照片 / 还可放 N 张」
          // 会挤不下，Wrap 让它折到下一行而不是横向溢出
          // （PRD 第 10 章无障碍要求文字大小可调节）。
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: <Widget>[
              Text(
                busy ? '⏳' : '🖼️',
                style: const TextStyle(fontSize: 17),
              ),
              Text(
                busy ? '正在读取…' : '加张照片',
                style: textTheme.labelMedium?.copyWith(
                  color: enabled
                      ? AppColors.warmApricotDeep
                      : AppColors.inkTertiary,
                ),
              ),
              if (enabled)
                Text('还可放 $remaining 张', style: textTheme.labelSmall),
            ],
          ),
        ),
      ),
    );
  }
}
