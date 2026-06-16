import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/language_provider.dart';
import '../providers/user_provider.dart';
import '../constants/app_theme.dart';
import '../utils/responsive.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    final up = Provider.of<UserProvider>(context, listen: false);
    _nameController = TextEditingController(text: up.userName);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _save() {
    final up = Provider.of<UserProvider>(context, listen: false);
    up.updateProfile(name: _nameController.text.trim());
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    R.init(context);
    final lp = Provider.of<LanguageProvider>(context);

    return Scaffold(
      backgroundColor: AppColors.bgDark,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(lp.getText('edit_profile').toUpperCase(),
            style: AppText.manrope(
                fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 1.5)),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _save,
            child: Text(lp.getText('save').toUpperCase(),
                style: AppText.manrope(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                    letterSpacing: 1.2)),
          ),
        ],
      ),
      body: Container(
        height: double.infinity,
        decoration: AppDeco.radialBg(center: Alignment.topLeft),
        child: SingleChildScrollView(
          padding:
              EdgeInsets.symmetric(horizontal: R.px(24), vertical: R.px(20)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildLabel(lp.getText('username').toUpperCase()),
              _buildTextField(_nameController),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: EdgeInsets.only(bottom: R.px(12)),
      child: Text(text,
          style: AppText.label(color: AppColors.primary.withOpacity(0.8))),
    );
  }

  Widget _buildTextField(TextEditingController controller) {
    return TextField(
      controller: controller,
      style: AppText.manrope(fontSize: 16, color: Colors.white),
      decoration: InputDecoration(
        enabledBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: AppColors.primary.withOpacity(0.3)),
        ),
        focusedBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: AppColors.primary),
        ),
        isDense: true,
        contentPadding: EdgeInsets.only(bottom: R.px(12)),
      ),
    );
  }
}
