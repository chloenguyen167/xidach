import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../app.dart';
import '../../core/layout/breakpoints.dart';
import '../../core/widgets/common.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Giới thiệu')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          MaxWidth(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 24),
                Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Image.asset(
                      'assets/images/app_icon.png',
                      width: 96,
                      height: 96,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  appName,
                  textAlign: TextAlign.center,
                  style: t.textTheme.titleLarge,
                ),
                Text(
                  'Phiên bản $appVersion',
                  textAlign: TextAlign.center,
                  style: t.textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    'Ghi điểm xì dách nhanh, gọn, chạy hoàn toàn offline. '
                    'Không cần đăng nhập, không quảng cáo.',
                    textAlign: TextAlign.center,
                  ),
                ),
                const SectionHeader('Quyền riêng tư'),
                const ListTile(
                  leading: FaIcon(FontAwesomeIcons.shieldHalved, size: 18),
                  title: Text('Không thu thập dữ liệu'),
                  subtitle: Text(
                    'Mọi dữ liệu (lần chơi, người chơi, bộ luật) chỉ lưu trên máy của bạn '
                    'và không được gửi đi đâu. Gỡ app hoặc dùng "Xóa dữ liệu" trong Cài đặt '
                    'để xóa toàn bộ.',
                  ),
                ),
                const ListTile(
                  leading: FaIcon(
                    FontAwesomeIcons.triangleExclamation,
                    size: 18,
                  ),
                  title: Text('Lưu ý'),
                  subtitle: Text(
                    'App chỉ dùng để ghi chép điểm, không tổ chức hay hỗ trợ cá cược bằng tiền thật.',
                  ),
                ),
                const SectionHeader('Thư viện mã nguồn mở'),
                ListTile(
                  leading: const FaIcon(FontAwesomeIcons.fileLines, size: 18),
                  title: const Text('Giấy phép'),
                  subtitle: const Text('Font Awesome Free, Flutter, Riverpod…'),
                  onTap: () => showLicensePage(
                    context: context,
                    applicationName: appName,
                    applicationVersion: appVersion,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
