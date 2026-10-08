import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/app_services.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/sogo_widgets.dart';

/// Editable vendor profile - mirrors the web settings page:
/// personal account data (name/phone/email) + business profile fields.
class VendorEditProfileScreen extends StatefulWidget {
  const VendorEditProfileScreen({super.key, required this.provider});

  final Map<String, dynamic> provider;

  @override
  State<VendorEditProfileScreen> createState() =>
      _VendorEditProfileScreenState();
}

class _VendorEditProfileScreenState extends State<VendorEditProfileScreen> {
  final _personalForm = GlobalKey<FormState>();
  final _businessForm = GlobalKey<FormState>();

  late final Map<String, dynamic> _user =
      (widget.provider['user'] as Map<String, dynamic>?) ?? const {};

  late final _name = TextEditingController(text: '${_user['name'] ?? ''}');
  late final _phone = TextEditingController(text: '${_user['phone'] ?? ''}');
  late final _email = TextEditingController(text: '${_user['email'] ?? ''}');

  late final _businessName =
      TextEditingController(text: '${widget.provider['business_name'] ?? ''}');
  late final _description =
      TextEditingController(text: '${widget.provider['description'] ?? ''}');
  late final _address =
      TextEditingController(text: '${widget.provider['address'] ?? ''}');
  late final _city =
      TextEditingController(text: '${widget.provider['city'] ?? ''}');
  late final _region =
      TextEditingController(text: '${widget.provider['region'] ?? ''}');
  late final _website =
      TextEditingController(text: '${widget.provider['website'] ?? ''}');
  late final _facebook =
      TextEditingController(text: '${widget.provider['facebook_url'] ?? ''}');
  late final _instagram =
      TextEditingController(text: '${widget.provider['instagram_url'] ?? ''}');
  late final _experience = TextEditingController(
      text: '${widget.provider['experience_years'] ?? ''}');
  late final _hourlyRate =
      TextEditingController(text: '${widget.provider['hourly_rate'] ?? ''}');
  late final _radius = TextEditingController(
      text: '${widget.provider['service_radius_km'] ?? 10}');
  late final _idNumber =
      TextEditingController(text: '${widget.provider['id_number'] ?? ''}');
  late final _tinNumber =
      TextEditingController(text: '${widget.provider['tin_number'] ?? ''}');
  late final _license = TextEditingController(
      text: '${widget.provider['business_license'] ?? ''}');

  bool _saving = false;
  String? _avatarPath;
  String? _coverPath;
  String? _logoPath;
  String? _businessCoverPath;

  /// Working hours as day -> {open, close} (HH:mm). Initialized from the
  /// saved profile so untouched days are preserved on save.
  late Map<String, Map<String, String>> _hours =
      _parseHours(widget.provider['operating_hours']);

  static Map<String, Map<String, String>> _parseHours(dynamic raw) {
    final out = <String, Map<String, String>>{};
    if (raw is Map) {
      for (final e in raw.entries) {
        final day = '${e.key}'
            .toLowerCase()
            .substring(0, '${e.key}'.length >= 3 ? 3 : '${e.key}'.length);
        final v = e.value;
        if (v is Map) {
          final open = '${v['open'] ?? ''}';
          final close = '${v['close'] ?? ''}';
          if (open.isNotEmpty && close.isNotEmpty) {
            out[day] = {'open': open, 'close': close};
          }
        } else if ('$v'.isNotEmpty && '$v'.contains('-')) {
          // Tolerate the "08:00-18:00" string shape too.
          final parts = '$v'.split('-');
          if (parts.length == 2) {
            out[day] = {'open': parts[0].trim(), 'close': parts[1].trim()};
          }
        }
      }
    }
    return out;
  }

  /// Personal avatar (true) or personal cover (false).
  Future<void> _pickImage(bool isAvatar) async {
    final picker = ImagePicker();
    final x = await picker.pickImage(
        source: ImageSource.gallery, maxWidth: 1600, imageQuality: 82);
    if (x == null) return;
    setState(() {
      if (isAvatar) {
        _avatarPath = x.path;
      } else {
        _coverPath = x.path;
      }
    });
  }

  /// Effective cover: newly picked business/personal cover first,
  /// then the saved business cover, then the personal cover.
  String _heroCoverUrl() {
    for (final v in [
      widget.provider['cover_image_url'],
      _user['cover_image_url'],
    ]) {
      if ('$v'.isNotEmpty && '$v' != 'null') return '$v';
    }
    return '';
  }

  String? get _heroCoverFile => _businessCoverPath ?? _coverPath;

  Future<void> _pickCoverChoice() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(SogoRadius.lg))),
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.storefront_outlined,
                color: SogoColors.primary),
            title: const Text('Business cover'),
            subtitle: const Text('Shown as your profile banner'),
            onTap: () => Navigator.pop(ctx, 'business'),
          ),
          ListTile(
            leading:
                const Icon(Icons.person_outline, color: SogoColors.primary),
            title: const Text('Personal cover'),
            subtitle: const Text('Fallback when no business cover'),
            onTap: () => Navigator.pop(ctx, 'personal'),
          ),
        ]),
      ),
    );
    if (choice == 'business') {
      await _pickBusinessImage(false);
    } else if (choice == 'personal') {
      await _pickImage(false);
    }
  }

  /// Business logo (true) or business cover (false).
  Future<void> _pickBusinessImage(bool isLogo) async {
    final picker = ImagePicker();
    final x = await picker.pickImage(
        source: ImageSource.gallery, maxWidth: 1600, imageQuality: 82);
    if (x == null) return;
    setState(() {
      if (isLogo) {
        _logoPath = x.path;
      } else {
        _businessCoverPath = x.path;
      }
    });
  }

  @override
  void dispose() {
    for (final c in [
      _name,
      _phone,
      _email,
      _businessName,
      _description,
      _address,
      _city,
      _region,
      _website,
      _facebook,
      _instagram,
      _experience,
      _hourlyRate,
      _radius,
      _idNumber,
      _tinNumber,
      _license,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  String _t(TextEditingController c) {
    final v = c.text.trim();
    return v.isEmpty || v == 'null' ? '' : v;
  }

  /// URL fields: Laravel requires a scheme, users type bare domains.
  String _url(TextEditingController c) {
    final v = _t(c);
    if (v.isEmpty) return '';
    if (v.toLowerCase().startsWith('http://') ||
        v.toLowerCase().startsWith('https://')) {
      return v;
    }
    return 'https://$v';
  }

  Future<void> _save() async {
    final personalOk = _personalForm.currentState?.validate() ?? false;
    final businessOk = _businessForm.currentState?.validate() ?? false;
    if (!personalOk || !businessOk) return;

    setState(() => _saving = true);
    final errors = <String>[];

    // Business profile (providers table) - only send filled fields.
    try {
      final business = <String, dynamic>{
        'business_name': _t(_businessName),
        if (_t(_description).isNotEmpty) 'description': _t(_description),
        if (_t(_address).isNotEmpty) 'address': _t(_address),
        if (_t(_city).isNotEmpty) 'city': _t(_city),
        if (_t(_region).isNotEmpty) 'region': _t(_region),
        if (_url(_website).isNotEmpty) 'website': _url(_website),
        if (_url(_facebook).isNotEmpty) 'facebook_url': _url(_facebook),
        if (_url(_instagram).isNotEmpty) 'instagram_url': _url(_instagram),
        if (_t(_idNumber).isNotEmpty) 'id_number': _t(_idNumber),
        if (_t(_tinNumber).isNotEmpty) 'tin_number': _t(_tinNumber),
        if (_t(_license).isNotEmpty) 'business_license': _t(_license),
      };
      final experience = int.tryParse(_t(_experience));
      if (experience != null) business['experience_years'] = experience;
      final rate = double.tryParse(_t(_hourlyRate));
      if (rate != null) business['hourly_rate'] = rate;
      final radius = double.tryParse(_t(_radius));
      if (radius != null) business['service_radius_km'] = radius;
      if (_hours.isNotEmpty) business['operating_hours'] = _hours;

      await providerApi.update(business,
          logoPath: _logoPath, coverPath: _businessCoverPath);
    } catch (e) {
      errors.add(e.toString());
    }

    // Personal account data (users table)
    try {
      await authApi.updateProfile({
        'name': _t(_name),
        'phone': _t(_phone),
        'email': _t(_email),
      }, avatarPath: _avatarPath, coverPath: _coverPath);
    } catch (e) {
      errors.add(e.toString());
    }

    if (!mounted) return;

    if (errors.isNotEmpty) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 5),
          content: Text('Could not save: ${errors.join(' - ')}'),
          backgroundColor: SogoColors.danger,
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Profile updated'),
        backgroundColor: SogoColors.primary,
      ),
    );
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SogoColors.surfaceMuted,
      appBar: AppBar(
        title: const Text('Edit profile'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: Text('Save',
                style: SogoText.bodyMd.copyWith(
                    color: SogoColors.primary, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
      body: Form(
        child: Column(
          children: [
            // -- Full-bleed cover hero (taps to change cover) --
            GestureDetector(
              onTap: _pickCoverChoice,
              child: Container(
                height: 170,
                width: double.infinity,
                color: SogoColors.primary,
                foregroundDecoration: BoxDecoration(
                  gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.35),
                      ]),
                ),
                child: Stack(fit: StackFit.expand, children: [
                  if (_heroCoverFile != null)
                    Image.file(File(_heroCoverFile!), fit: BoxFit.cover)
                  else if (_heroCoverUrl().isNotEmpty)
                    Image.network(_heroCoverUrl(),
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const SizedBox.shrink()),
                  Positioned(
                    right: SogoSpacing.md,
                    bottom: SogoSpacing.md,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.55),
                        borderRadius: BorderRadius.circular(SogoRadius.pill),
                      ),
                      child:
                          const Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.camera_alt_rounded,
                            size: 14, color: Colors.white),
                        SizedBox(width: 6),
                        Text('Change cover',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 12)),
                      ]),
                    ),
                  ),
                ]),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(SogoSpacing.lg),
                children: [
                  // -- Personal --
                  const SogoSectionTitle('Personal details'),
                  SogoCard(
                    child: Form(
                      key: _personalForm,
                      child: Column(
                        children: [
                          // Avatar picker (cover lives in the full-bleed hero).
                          Row(children: [
                            GestureDetector(
                              onTap: () => _pickImage(true),
                              child: Stack(children: [
                                CircleAvatar(
                                  radius: 32,
                                  backgroundColor: SogoColors.primaryLight,
                                  backgroundImage: _avatarPath != null
                                      ? FileImage(File(_avatarPath!))
                                      : ('${_user['avatar'] ?? ''}'.isNotEmpty
                                          ? NetworkImage('${_user['avatar']}')
                                              as ImageProvider
                                          : null),
                                  child: _avatarPath == null &&
                                          '${_user['avatar'] ?? ''}'.isEmpty
                                      ? const Icon(Icons.person_outline,
                                          color: SogoColors.primary)
                                      : null,
                                ),
                                Positioned(
                                  right: 0,
                                  bottom: 0,
                                  child: Container(
                                    width: 22,
                                    height: 22,
                                    decoration: const BoxDecoration(
                                      color: SogoColors.primary,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.camera_alt_rounded,
                                        size: 12, color: Colors.white),
                                  ),
                                ),
                              ]),
                            ),
                            const SizedBox(width: SogoSpacing.md),
                            Expanded(
                              child: Text(
                                  'Tap the photo to change your personal avatar. The cover banner at the top changes the profile cover.',
                                  style: SogoText.bodySm.copyWith(
                                      color: SogoColors.textSecondary)),
                            ),
                          ]),
                          const SizedBox(height: SogoSpacing.md),
                          SogoTextField(
                            label: 'Full name',
                            hint: 'Your name',
                            controller: _name,
                            prefixIcon: Icons.person_outline,
                            validator: (v) => v == null || v.trim().isEmpty
                                ? 'Required'
                                : null,
                          ),
                          const SizedBox(height: SogoSpacing.md),
                          SogoTextField(
                            label: 'Phone',
                            hint: '+256 700 000 000',
                            controller: _phone,
                            keyboardType: TextInputType.phone,
                            prefixIcon: Icons.phone_outlined,
                          ),
                          const SizedBox(height: SogoSpacing.md),
                          SogoTextField(
                            label: 'Email',
                            hint: 'you@example.com',
                            controller: _email,
                            keyboardType: TextInputType.emailAddress,
                            prefixIcon: Icons.alternate_email,
                            validator: (v) => v == null || !v.contains('@')
                                ? 'Invalid email'
                                : null,
                          ),
                        ],
                      ),
                    ),
                  ),

                  // -- Business --
                  const SizedBox(height: SogoSpacing.xl),
                  const SogoSectionTitle('Business details'),
                  SogoCard(
                    child: Form(
                      key: _businessForm,
                      child: Column(
                        children: [
                          // Business logo + cover (shown as profile photo + hero).
                          Row(children: [
                            GestureDetector(
                              onTap: () => _pickBusinessImage(true),
                              child: Stack(children: [
                                CircleAvatar(
                                  radius: 32,
                                  backgroundColor: SogoColors.primaryLight,
                                  backgroundImage: _logoPath != null
                                      ? FileImage(File(_logoPath!))
                                      : ('${widget.provider['logo_url'] ?? ''}'
                                              .isNotEmpty
                                          ? NetworkImage(
                                                  '${widget.provider['logo_url']}')
                                              as ImageProvider
                                          : null),
                                  child: _logoPath == null &&
                                          '${widget.provider['logo_url'] ?? ''}'
                                              .isEmpty
                                      ? const Icon(Icons.storefront_outlined,
                                          color: SogoColors.primary)
                                      : null,
                                ),
                                Positioned(
                                  right: 0,
                                  bottom: 0,
                                  child: Container(
                                    width: 22,
                                    height: 22,
                                    decoration: const BoxDecoration(
                                      color: SogoColors.primary,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.camera_alt_rounded,
                                        size: 12, color: Colors.white),
                                  ),
                                ),
                              ]),
                            ),
                            const SizedBox(width: SogoSpacing.md),
                            Expanded(
                              child: GestureDetector(
                                onTap: () => _pickBusinessImage(false),
                                child: Container(
                                  height: 72,
                                  decoration: BoxDecoration(
                                    color: SogoColors.surfaceMuted,
                                    borderRadius:
                                        BorderRadius.circular(SogoRadius.md),
                                    border: Border.all(
                                        color: SogoColors.surfaceBorder),
                                  ),
                                  child: _businessCoverPath != null
                                      ? ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                              SogoRadius.md),
                                          child: Image.file(
                                              File(_businessCoverPath!),
                                              fit: BoxFit.cover),
                                        )
                                      : ('${widget.provider['cover_image_url'] ?? ''}'
                                              .isNotEmpty
                                          ? ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(
                                                      SogoRadius.md),
                                              child: Image.network(
                                                  '${widget.provider['cover_image_url']}',
                                                  fit: BoxFit.cover),
                                            )
                                          : const Column(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Icon(
                                                    Icons
                                                        .add_photo_alternate_outlined,
                                                    color: SogoColors.textMuted,
                                                    size: 20),
                                                Text('Business cover',
                                                    style: SogoText.bodySm),
                                              ],
                                            )),
                                ),
                              ),
                            ),
                          ]),
                          const SizedBox(height: SogoSpacing.md),
                          SogoTextField(
                            label: 'Business name',
                            hint: 'Your business name',
                            controller: _businessName,
                            prefixIcon: Icons.storefront_outlined,
                            validator: (v) => v == null || v.trim().isEmpty
                                ? 'Required'
                                : null,
                          ),
                          const SizedBox(height: SogoSpacing.md),
                          SogoTextField(
                            label: 'Description',
                            hint: 'Tell customers about your business',
                            controller: _description,
                            maxLines: 3,
                          ),
                          const SizedBox(height: SogoSpacing.md),
                          SogoTextField(
                            label: 'Address',
                            hint: 'Street / plot',
                            controller: _address,
                            prefixIcon: Icons.location_on_outlined,
                          ),
                          const SizedBox(height: SogoSpacing.md),
                          Row(
                            children: [
                              Expanded(
                                child: SogoTextField(
                                  label: 'City',
                                  hint: 'Kampala',
                                  controller: _city,
                                ),
                              ),
                              const SizedBox(width: SogoSpacing.md),
                              Expanded(
                                child: SogoTextField(
                                  label: 'Region',
                                  hint: 'Central',
                                  controller: _region,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: SogoSpacing.md),
                          Row(
                            children: [
                              Expanded(
                                child: SogoTextField(
                                  label: 'Experience (years)',
                                  hint: '5',
                                  controller: _experience,
                                  keyboardType: TextInputType.number,
                                ),
                              ),
                              const SizedBox(width: SogoSpacing.md),
                              Expanded(
                                child: SogoTextField(
                                  label: 'Hourly rate (UGX)',
                                  hint: '20000',
                                  controller: _hourlyRate,
                                  keyboardType: TextInputType.number,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: SogoSpacing.md),
                          SogoTextField(
                            label: 'Service radius (km)',
                            hint: 'How far you travel for jobs',
                            controller: _radius,
                            keyboardType: TextInputType.number,
                            prefixIcon: Icons.explore_outlined,
                          ),
                        ],
                      ),
                    ),
                  ),

                  // -- Working hours --
                  const SizedBox(height: SogoSpacing.xl),
                  const SogoSectionTitle('Working hours'),
                  SogoCard(
                    child: Column(
                      children: [
                        Text(
                            'Customers see these hours on your profile. Days left off show as closed.',
                            style: SogoText.bodySm
                                .copyWith(color: SogoColors.textSecondary)),
                        const SizedBox(height: SogoSpacing.md),
                        _WorkingHoursEditor(
                          initial: _hours,
                          onChanged: (v) => setState(() => _hours = v),
                        ),
                      ],
                    ),
                  ),

                  // -- Online presence --
                  const SizedBox(height: SogoSpacing.xl),
                  const SogoSectionTitle('Online presence'),
                  SogoCard(
                    child: Column(
                      children: [
                        SogoTextField(
                          label: 'Website',
                          hint: 'https://yourwebsite.com',
                          controller: _website,
                          prefixIcon: Icons.language_outlined,
                        ),
                        const SizedBox(height: SogoSpacing.md),
                        SogoTextField(
                          label: 'Facebook',
                          hint: 'https://facebook.com/yourpage',
                          controller: _facebook,
                          prefixIcon: Icons.facebook_outlined,
                        ),
                        const SizedBox(height: SogoSpacing.md),
                        SogoTextField(
                          label: 'Instagram',
                          hint: 'https://instagram.com/yourhandle',
                          controller: _instagram,
                          prefixIcon: Icons.camera_alt_outlined,
                        ),
                      ],
                    ),
                  ),

                  // -- Documents --
                  const SizedBox(height: SogoSpacing.xl),
                  const SogoSectionTitle('Verification documents'),
                  SogoCard(
                    child: Column(
                      children: [
                        SogoTextField(
                          label: 'ID number',
                          hint: 'National ID',
                          controller: _idNumber,
                          prefixIcon: Icons.badge_outlined,
                        ),
                        const SizedBox(height: SogoSpacing.md),
                        SogoTextField(
                          label: 'TIN number',
                          hint: 'Tax identification',
                          controller: _tinNumber,
                          prefixIcon: Icons.receipt_outlined,
                        ),
                        const SizedBox(height: SogoSpacing.md),
                        SogoTextField(
                          label: 'Business license',
                          hint: 'License number',
                          controller: _license,
                          prefixIcon: Icons.workspace_premium_outlined,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: SogoSpacing.xl),
                  SogoButton(
                      label: 'Save changes',
                      onPressed: _save,
                      loading: _saving),
                  const SizedBox(height: SogoSpacing.xxl),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WorkingHoursEditor extends StatefulWidget {
  const _WorkingHoursEditor({required this.initial, required this.onChanged});

  final Map<String, Map<String, String>> initial;
  final ValueChanged<Map<String, Map<String, String>>> onChanged;

  @override
  State<_WorkingHoursEditor> createState() => _WorkingHoursEditorState();
}

class _WorkingHoursEditorState extends State<_WorkingHoursEditor> {
  static const _days = [
    ('mon', 'Mon'),
    ('tue', 'Tue'),
    ('wed', 'Wed'),
    ('thu', 'Thu'),
    ('fri', 'Fri'),
    ('sat', 'Sat'),
    ('sun', 'Sun'),
  ];

  late Map<String, Map<String, String>> _hours = Map.fromEntries(widget
      .initial.entries
      .map((e) => MapEntry(e.key, Map<String, String>.from(e.value))));

  void _emit() => widget.onChanged(Map<String, Map<String, String>>.from(
      _hours.map((k, v) => MapEntry(k, Map<String, String>.from(v)))));

  Future<void> _pickTime(String day, bool isOpen) async {
    final current = _hours[day]?[isOpen ? 'open' : 'close'];
    TimeOfDay initial = const TimeOfDay(hour: 8, minute: 0);
    if (!isOpen) initial = const TimeOfDay(hour: 18, minute: 0);
    if (current != null && current.contains(':')) {
      final parts = current.split(':');
      final h = int.tryParse(parts[0]);
      final m = int.tryParse(parts.length > 1 ? parts[1] : '0');
      if (h != null && m != null) initial = TimeOfDay(hour: h, minute: m);
    }
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked == null) return;
    final formatted =
        '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
    setState(() {
      _hours[day] = {
        'open': isOpen ? formatted : (_hours[day]?['open'] ?? '08:00'),
        'close': isOpen ? (_hours[day]?['close'] ?? '18:00') : formatted,
      };
    });
    _emit();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final d in _days)
          Padding(
            padding: const EdgeInsets.only(bottom: SogoSpacing.sm),
            child: Row(children: [
              SizedBox(
                  width: 44,
                  child: Text(d.$2,
                      style: SogoText.bodyMd
                          .copyWith(fontWeight: FontWeight.w700))),
              Switch(
                value: _hours.containsKey(d.$1),
                activeColor: SogoColors.primary,
                onChanged: (v) {
                  setState(() {
                    if (v) {
                      _hours[d.$1] = {'open': '08:00', 'close': '18:00'};
                    } else {
                      _hours.remove(d.$1);
                    }
                  });
                  _emit();
                },
              ),
              Expanded(
                child: _hours.containsKey(d.$1)
                    ? Row(children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => _pickTime(d.$1, true),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 8, horizontal: 10),
                              decoration: BoxDecoration(
                                color: SogoColors.surfaceMuted,
                                borderRadius:
                                    BorderRadius.circular(SogoRadius.sm),
                                border:
                                    Border.all(color: SogoColors.surfaceBorder),
                              ),
                              child: Text(_hours[d.$1]!['open']!,
                                  textAlign: TextAlign.center,
                                  style: SogoText.bodyMd
                                      .copyWith(fontWeight: FontWeight.w600)),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: SogoSpacing.sm),
                          child: Text('-',
                              style: SogoText.bodyMd
                                  .copyWith(color: SogoColors.textSecondary)),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => _pickTime(d.$1, false),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 8, horizontal: 10),
                              decoration: BoxDecoration(
                                color: SogoColors.surfaceMuted,
                                borderRadius:
                                    BorderRadius.circular(SogoRadius.sm),
                                border:
                                    Border.all(color: SogoColors.surfaceBorder),
                              ),
                              child: Text(_hours[d.$1]!['close']!,
                                  textAlign: TextAlign.center,
                                  style: SogoText.bodyMd
                                      .copyWith(fontWeight: FontWeight.w600)),
                            ),
                          ),
                        ),
                      ])
                    : Text('Closed',
                        style: SogoText.bodySm
                            .copyWith(color: SogoColors.textSecondary)),
              ),
            ]),
          ),
      ],
    );
  }
}
