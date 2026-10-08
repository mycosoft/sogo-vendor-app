import 'dart:io';
import 'dart:math';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../../../core/app_services.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/sogo_widgets.dart';
import 'otp_verification_screen.dart';

/// Vendor onboarding - mirrors the web /register form in 6 steps:
///   1. Account    - name, phone, email, password
///   2. Business   - name, type, description, experience, rate, radius
///   3. Services   - multi-select service categories (min 1)
///   4. Location   - district -> city (gazetteer), street address, socials
///   5. KYC        - ID/TIN/license + document uploads + cover + logo
///   6. Review     - summary, terms & privacy, submit
class VendorRegisterScreen extends StatefulWidget {
  const VendorRegisterScreen({super.key});

  @override
  State<VendorRegisterScreen> createState() => _VendorRegisterScreenState();
}

class _DocRow {
  String type;
  String? path;
  String? name;

  _DocRow({this.type = 'national_id', this.path, this.name});
}

class _VendorRegisterScreenState extends State<VendorRegisterScreen> {
  static const _stepCount = 6;
  int _step = 0;
  bool _loading = false;
  bool _obscure = true;
  bool _terms = false;

  final _forms = List.generate(_stepCount, (_) => GlobalKey<FormState>());

  // Step 1 - account
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  // Step 2 - business
  final _businessName = TextEditingController();
  final _description = TextEditingController();
  final _experience = TextEditingController();
  final _hourlyRate = TextEditingController();
  double _radius = 15;
  String _providerType = 'mechanic';

  static const _providerTypes = [
    ('mechanic', 'Mechanic', Icons.build_rounded),
    ('shop', 'Parts Shop', Icons.storefront_outlined),
    ('tow', 'Towing', Icons.local_shipping_outlined),
    ('washer', 'Car Wash', Icons.local_car_wash_outlined),
    ('parts', 'Parts Dealer', Icons.settings_outlined),
    ('lubricant', 'Lubricants', Icons.oil_barrel_outlined),
    ('other', 'Other', Icons.handyman_outlined),
  ];

  // Step 3 - services
  final List<int> _selectedServices = [];
  List<Map<String, dynamic>> _categories = [];
  bool _loadingCategories = false;

  // Step 4 - location + socials
  List<String> _districts = [];
  String? _district;
  List<Map<String, dynamic>> _cities = [];
  int? _locationId;
  String? _cityName;
  bool _loadingLocation = false;
  bool _locating = false;
  double? _gpsLat;
  double? _gpsLng;
  final _address = TextEditingController();
  final _website = TextEditingController();
  final _facebook = TextEditingController();
  final _instagram = TextEditingController();

  // Step 5 - KYC
  final _idNumber = TextEditingController();
  final _tinNumber = TextEditingController();
  final _license = TextEditingController();
  final List<_DocRow> _docs = [_DocRow()];
  XFile? _coverImage;
  XFile? _logoImage;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  @override
  void dispose() {
    for (final c in [
      _name,
      _phone,
      _email,
      _password,
      _confirm,
      _businessName,
      _description,
      _experience,
      _hourlyRate,
      _address,
      _website,
      _facebook,
      _instagram,
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

  Future<void> _loadCategories() async {
    setState(() => _loadingCategories = true);
    try {
      final cats = await serviceApi.categories();
      if (!mounted) return;
      setState(() {
        _categories = List<Map<String, dynamic>>.from(cats);
        _loadingCategories = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingCategories = false);
    }
  }

  Future<void> _loadDistricts() async {
    setState(() => _loadingLocation = true);
    try {
      final d = await locationsApi.districts();
      if (!mounted) return;
      setState(() {
        _districts = d;
        _loadingLocation = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingLocation = false);
    }
  }

  Future<void> _onDistrictChanged(String? district) async {
    setState(() {
      _district = district;
      _cities = [];
      _locationId = null;
      _cityName = null;
    });
    if (district == null || district.isEmpty) return;
    try {
      final cities = await locationsApi.cities(district);
      if (!mounted) return;
      setState(() => _cities = cities);
      _autoPickNearestCity();
    } catch (_) {}
  }

  /// Auto-select the gazetteer city nearest to the captured GPS position.
  void _autoPickNearestCity() {
    if (_gpsLat == null || _gpsLng == null || _cities.isEmpty) return;
    double dist(Map<String, dynamic> c) {
      final dLat = _deg2rad((c['lat'] as num).toDouble() - _gpsLat!);
      final dLng = _deg2rad((c['lng'] as num).toDouble() - _gpsLng!);
      final a = sin(dLat / 2) * sin(dLat / 2) +
          cos(_deg2rad(_gpsLat!)) *
              cos(_deg2rad((c['lat'] as num).toDouble())) *
              sin(dLng / 2) *
              sin(dLng / 2);
      return 2 * 6371 * asin(min(1, sqrt(a)));
    }

    Map<String, dynamic>? nearest;
    var best = double.infinity;
    for (final c in _cities) {
      if (c['lat'] == null || c['lng'] == null) continue;
      final d = dist(c);
      if (d < best) {
        best = d;
        nearest = c;
      }
    }
    if (nearest != null) {
      setState(() {
        _locationId = nearest!['id'] as int;
        _cityName = nearest['city'] as String?;
      });
    }
  }

  double _deg2rad(double deg) => deg * pi / 180;

  /// Capture the device GPS position. Used for accurate matching from day
  /// one, and to auto-select the nearest gazetteer city.
  Future<void> _captureGps() async {
    setState(() => _locating = true);
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Location permission is required to use GPS')));
        }
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      if (!mounted) return;
      setState(() {
        _gpsLat = pos.latitude;
        _gpsLng = pos.longitude;
      });
      _autoPickNearestCity();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                'GPS captured: ${pos.latitude.toStringAsFixed(5)}, ${pos.longitude.toStringAsFixed(5)}'),
            backgroundColor: SogoColors.primary));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _pickCover() async {
    final x = await ImagePicker().pickImage(
        source: ImageSource.gallery, maxWidth: 1600, imageQuality: 85);
    if (x != null) setState(() => _coverImage = x);
  }

  Future<void> _pickLogo() async {
    final x = await ImagePicker().pickImage(
        source: ImageSource.gallery, maxWidth: 800, imageQuality: 85);
    if (x != null) setState(() => _logoImage = x);
  }

  Future<void> _pickDoc(int index) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
    );
    if (result == null || result.files.isEmpty) return;
    final f = result.files.first;
    if (f.path == null) return;
    setState(() {
      _docs[index].path = f.path;
      _docs[index].name = f.name;
    });
  }

  bool _validateCurrent() {
    // Step 3 needs at least one service; all other steps validate their forms.
    if (_step == 2 && _selectedServices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Select at least one service to continue')));
      return false;
    }
    if (_step == 3 && (_locationId == null)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content:
              Text('Select your district and city so customers can find you')));
      return false;
    }
    return _forms[_step].currentState?.validate() ?? true;
  }

  Future<void> _next() async {
    if (!_validateCurrent()) return;

    if (_step < _stepCount - 1) {
      final nextStep = _step + 1;
      if (nextStep == 2 && _categories.isEmpty && !_loadingCategories) {
        await _loadCategories();
      }
      if (nextStep == 3 && _districts.isEmpty) {
        await _loadDistricts();
      }
      setState(() => _step = nextStep);
      return;
    }
    await _submit();
  }

  void _back() {
    if (_step > 0) setState(() => _step--);
  }

  Future<void> _submit() async {
    if (!_terms) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please accept the terms to continue')));
      return;
    }

    setState(() => _loading = true);

    try {
      // 1) Register the user account.
      final reg = await authApi.register(
        name: _name.text.trim(),
        phone: _phone.text.trim(),
        email: _email.text.trim(),
        password: _password.text,
      );
      if (reg['success'] != true) {
        throw Exception(reg['message'] ?? 'Registration failed');
      }

      // 2) Register the provider profile - multipart so we can carry
      //    KYC documents, cover image and logo.
      final fields = <String, String>{
        'business_name': _t(_businessName),
        'provider_type': _providerType,
        'service_radius_km': _radius.round().toString(),
        if (_t(_description).isNotEmpty) 'description': _t(_description),
        if (int.tryParse(_t(_experience)) != null)
          'experience_years': _t(_experience),
        if (double.tryParse(_t(_hourlyRate)) != null)
          'hourly_rate': _t(_hourlyRate),
        if (_t(_idNumber).isNotEmpty) 'id_number': _t(_idNumber),
        if (_t(_tinNumber).isNotEmpty) 'tin_number': _t(_tinNumber),
        if (_t(_license).isNotEmpty) 'business_license': _t(_license),
        if (_district != null) 'district': _district!,
        if (_cityName != null) 'city': _cityName!,
        if (_locationId != null) 'location_id': '$_locationId',
        if (_gpsLat != null) 'current_lat': _gpsLat.toString(),
        if (_gpsLng != null) 'current_lng': _gpsLng.toString(),
        if (_t(_address).isNotEmpty) 'address': _t(_address),
        if (_url(_website).isNotEmpty) 'website': _url(_website),
        if (_url(_facebook).isNotEmpty) 'facebook_url': _url(_facebook),
        if (_url(_instagram).isNotEmpty) 'instagram_url': _url(_instagram),
      };
      // Array fields need UNIQUE keys in a Map - "services[]" repeated
      // would overwrite itself. Laravel parses services[0], services[1]...
      for (var i = 0; i < _selectedServices.length; i++) {
        fields['services[$i]'] = '${_selectedServices[i]}';
      }
      var docIndex = 0;
      for (final d in _docs.where((d) => d.path != null)) {
        fields['doc_types[$docIndex]'] = d.type;
        docIndex++;
      }

      final files = <http.MultipartFile>[];
      if (_coverImage != null) {
        files.add(await http.MultipartFile.fromPath(
            'cover_image', _coverImage!.path));
      }
      if (_logoImage != null) {
        files.add(await http.MultipartFile.fromPath('logo', _logoImage!.path));
      }
      for (final d in _docs.where((d) => d.path != null)) {
        files.add(await http.MultipartFile.fromPath('documents[]', d.path!,
            filename: d.name));
      }

      final prov = await providerApi.registerProviderMultipart(fields, files);
      if (prov['success'] != true) {
        throw Exception(prov['message'] ?? 'Could not create vendor profile');
      }

      if (!mounted) return;
      // First verify the phone (OTP screen), then the pending-approval
      // screen unlocks the dashboard once an admin approves.
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
            builder: (_) => OtpVerificationScreen(phone: _phone.text.trim())),
        (_) => false,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 6),
          backgroundColor: SogoColors.danger,
          content: Text('Registration failed: ${e.toString()}'),
        ),
      );
    }
  }

  String _url(TextEditingController c) {
    final v = _t(c);
    if (v.isEmpty) return '';
    if (v.toLowerCase().startsWith('http://') ||
        v.toLowerCase().startsWith('https://')) {
      return v;
    }
    return 'https://$v';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SogoColors.surfaceMuted,
      appBar: AppBar(
        backgroundColor: SogoColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        title: Text(_stepTitle(),
            style: SogoText.headlineMd.copyWith(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        leading: _step > 0
            ? IconButton(
                tooltip: 'Back',
                icon: const Icon(Icons.arrow_back_rounded,
                    color: Colors.white, size: 26),
                onPressed: _back)
            : null,
      ),
      body: GestureDetector(
        // Tap anywhere outside a field to close the keyboard.
        onTap: () => FocusScope.of(context).unfocus(),
        child: Column(
          children: [
            _progressHeader(),
            Expanded(
              child: Form(
                key: _forms[_step],
                child: SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(SogoSpacing.lg,
                      SogoSpacing.lg, SogoSpacing.lg, SogoSpacing.xl),
                  child: _stepBody(),
                ),
              ),
            ),
            _bottomBar(),
          ],
        ),
      ),
    );
  }

  String _stepTitle() {
    switch (_step) {
      case 0:
        return 'Create vendor account';
      case 1:
        return 'Business details';
      case 2:
        return 'Your services';
      case 3:
        return 'Location';
      case 4:
        return 'Verification (KYC)';
      default:
        return 'Review & submit';
    }
  }

  Widget _progressHeader() {
    return Container(
      color: SogoColors.primary,
      padding: const EdgeInsets.fromLTRB(
          SogoSpacing.lg, SogoSpacing.sm, SogoSpacing.lg, SogoSpacing.md),
      child: Row(
        children: [
          for (int i = 0; i < _stepCount; i++) ...[
            Expanded(
              child: Row(
                children: [
                  Container(
                    width: 26,
                    height: 26,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: i <= _step
                          ? Colors.white
                          : Colors.white.withOpacity(0.15),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withOpacity(i <= _step ? 1 : 0.4),
                        width: 1.5,
                      ),
                    ),
                    child: Text(
                      '${i + 1}',
                      style: SogoText.labelMd.copyWith(
                        color:
                            i <= _step ? SogoColors.primaryDark : Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (i < _stepCount - 1)
                    Expanded(
                      child: Container(
                        height: 2,
                        color: i < _step
                            ? Colors.white
                            : Colors.white.withOpacity(0.35),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _stepBody() {
    switch (_step) {
      case 0:
        return _accountStep();
      case 1:
        return _businessStep();
      case 2:
        return _servicesStep();
      case 3:
        return _locationStep();
      case 4:
        return _kycStep();
      default:
        return _reviewStep();
    }
  }

  Widget _accountStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Account details', style: SogoText.headlineMd),
        const SizedBox(height: 4),
        Text('This is your login. Use a phone and email you can access.',
            style: SogoText.bodySm.copyWith(color: SogoColors.textSecondary)),
        const SizedBox(height: SogoSpacing.lg),
        SogoTextField(
            label: 'Full name',
            hint: 'Your name',
            controller: _name,
            prefixIcon: Icons.person_outline,
            validator: (v) =>
                v == null || v.trim().isEmpty ? 'Required' : null),
        const SizedBox(height: SogoSpacing.lg),
        SogoTextField(
            label: 'Phone',
            hint: '0750 000 000',
            controller: _phone,
            keyboardType: TextInputType.phone,
            prefixIcon: Icons.phone_outlined,
            validator: (v) => v == null || v.trim().length < 9
                ? 'Enter a valid phone'
                : null),
        const SizedBox(height: SogoSpacing.lg),
        SogoTextField(
            label: 'Email',
            hint: 'you@example.com',
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            prefixIcon: Icons.alternate_email,
            validator: (v) =>
                v == null || !v.contains('@') ? 'Invalid email' : null),
        const SizedBox(height: SogoSpacing.lg),
        SogoTextField(
            label: 'Password',
            hint: 'At least 8 characters',
            controller: _password,
            obscureText: _obscure,
            prefixIcon: Icons.lock_outline,
            suffixIcon: IconButton(
                icon: Icon(
                    _obscure
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    color: SogoColors.textMuted),
                onPressed: () => setState(() => _obscure = !_obscure)),
            validator: (v) =>
                v == null || v.length < 8 ? 'Min 8 characters' : null),
        const SizedBox(height: SogoSpacing.lg),
        SogoTextField(
            label: 'Confirm password',
            hint: 'Re-enter password',
            controller: _confirm,
            obscureText: true,
            prefixIcon: Icons.lock_outline,
            validator: (v) =>
                v != _password.text ? 'Passwords do not match' : null),
      ],
    );
  }

  Widget _businessStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Tell us about your business', style: SogoText.headlineMd),
        const SizedBox(height: 4),
        Text('Customers see this on your profile.',
            style: SogoText.bodySm.copyWith(color: SogoColors.textSecondary)),
        const SizedBox(height: SogoSpacing.lg),
        SogoTextField(
            label: 'Business name',
            hint: 'e.g. Kampala Auto Care',
            controller: _businessName,
            prefixIcon: Icons.storefront_outlined,
            validator: (v) =>
                v == null || v.trim().isEmpty ? 'Required' : null),
        const SizedBox(height: SogoSpacing.lg),
        Text('Business type',
            style: SogoText.bodyMd.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: SogoSpacing.sm),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: SogoSpacing.sm,
          crossAxisSpacing: SogoSpacing.sm,
          childAspectRatio: 2.6,
          children: _providerTypes.map((t) {
            final selected = _providerType == t.$1;
            return GestureDetector(
              onTap: () => setState(() => _providerType = t.$1),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: SogoSpacing.md),
                decoration: BoxDecoration(
                  color:
                      selected ? SogoColors.primaryLight : SogoColors.surface,
                  borderRadius: BorderRadius.circular(SogoRadius.md),
                  border: Border.all(
                      color: selected
                          ? SogoColors.primary
                          : SogoColors.surfaceBorder,
                      width: selected ? 2 : 1),
                ),
                child: Row(
                  children: [
                    Icon(t.$3,
                        size: 18,
                        color: selected
                            ? SogoColors.primary
                            : SogoColors.textMuted),
                    const SizedBox(width: SogoSpacing.sm),
                    Expanded(
                        child: Text(t.$2,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: SogoText.bodySm.copyWith(
                                fontWeight: FontWeight.w700,
                                color: selected
                                    ? SogoColors.primaryDark
                                    : SogoColors.textPrimary))),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: SogoSpacing.lg),
        SogoTextField(
            label: 'Description',
            hint: 'What makes your business stand out?',
            controller: _description,
            maxLines: 3),
        const SizedBox(height: SogoSpacing.lg),
        Row(
          children: [
            Expanded(
                child: SogoTextField(
                    label: 'Experience (years)',
                    hint: '5',
                    controller: _experience,
                    keyboardType: TextInputType.number)),
            const SizedBox(width: SogoSpacing.md),
            Expanded(
                child: SogoTextField(
                    label: 'Hourly rate (UGX)',
                    hint: '20000',
                    controller: _hourlyRate,
                    keyboardType: TextInputType.number)),
          ],
        ),
        const SizedBox(height: SogoSpacing.lg),
        Text('Service radius: ${_radius.round()} km',
            style: SogoText.bodyMd.copyWith(fontWeight: FontWeight.w600)),
        Slider(
          value: _radius,
          min: 1,
          max: 100,
          divisions: 99,
          activeColor: SogoColors.primary,
          label: '${_radius.round()} km',
          onChanged: (v) => setState(() => _radius = v),
        ),
        Text('How far you are willing to travel for jobs.',
            style: SogoText.bodySm.copyWith(color: SogoColors.textSecondary)),
      ],
    );
  }

  Widget _servicesStep() {
    if (_loadingCategories) {
      return const Center(child: CircularProgressIndicator());
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('What services do you offer?', style: SogoText.headlineMd),
        const SizedBox(height: 4),
        Text('Pick at least one. Customers find you through these.',
            style: SogoText.bodySm.copyWith(color: SogoColors.textSecondary)),
        const SizedBox(height: SogoSpacing.lg),
        if (_categories.isEmpty)
          SogoCard(
              child: Column(
            children: [
              Text('Could not load services.',
                  style: SogoText.bodySm.copyWith(color: SogoColors.danger)),
              const SizedBox(height: SogoSpacing.md),
              SogoButton(
                  label: 'Retry',
                  fullWidth: false,
                  onPressed: () async {
                    await _loadCategories();
                    if (mounted) setState(() {});
                  }),
            ],
          ))
        else
          ..._categories.map((c) {
            final selected = _selectedServices.contains(c['id']);
            final price = num.tryParse('${c['base_price'] ?? ''}');
            return Padding(
              padding: const EdgeInsets.only(bottom: SogoSpacing.sm),
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    selected
                        ? _selectedServices.remove(c['id'])
                        : _selectedServices.add(c['id'] as int);
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: SogoSpacing.md, vertical: SogoSpacing.md),
                  decoration: BoxDecoration(
                    color:
                        selected ? SogoColors.primaryLight : SogoColors.surface,
                    borderRadius: BorderRadius.circular(SogoRadius.md),
                    border: Border.all(
                        color: selected
                            ? SogoColors.primary
                            : SogoColors.surfaceBorder,
                        width: selected ? 2 : 1),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        selected
                            ? Icons.check_circle_rounded
                            : Icons.radio_button_unchecked,
                        color: selected
                            ? SogoColors.primary
                            : SogoColors.textMuted,
                        size: 20,
                      ),
                      const SizedBox(width: SogoSpacing.md),
                      Expanded(
                          child: Text('${c['name']}',
                              style: SogoText.bodyLg
                                  .copyWith(fontWeight: FontWeight.w600))),
                      if (price != null && price > 0)
                        Text('from UGX ${price.toStringAsFixed(0)}',
                            style: SogoText.bodySm
                                .copyWith(color: SogoColors.textSecondary)),
                    ],
                  ),
                ),
              ),
            );
          }),
      ],
    );
  }

  Widget _locationStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Where are you based?', style: SogoText.headlineMd),
        const SizedBox(height: 4),
        Text('Customers search by location - pick your area.',
            style: SogoText.bodySm.copyWith(color: SogoColors.textSecondary)),
        const SizedBox(height: SogoSpacing.lg),

        // GPS - one tap for accurate coordinates + nearest-city autoselect
        Container(
          padding: const EdgeInsets.all(SogoSpacing.md),
          decoration: BoxDecoration(
            color:
                _gpsLat != null ? SogoColors.primaryLight : SogoColors.surface,
            borderRadius: BorderRadius.circular(SogoRadius.md),
            border: Border.all(
                color: _gpsLat != null
                    ? SogoColors.primary.withOpacity(0.4)
                    : SogoColors.surfaceBorder),
          ),
          child: Column(
            children: [
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _locating ? null : _captureGps,
                  icon: _locating
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : Icon(
                          _gpsLat != null
                              ? Icons.check_circle_rounded
                              : Icons.gps_fixed_rounded,
                          size: 18,
                          color: _gpsLat != null
                              ? SogoColors.success
                              : SogoColors.primary,
                        ),
                  label: Text(
                    _gpsLat != null
                        ? 'GPS captured - ${_gpsLat!.toStringAsFixed(4)}, ${_gpsLng!.toStringAsFixed(4)}'
                        : 'Use my current location (GPS)',
                    style: SogoText.bodySm.copyWith(
                        fontWeight: FontWeight.w700,
                        color: _gpsLat != null
                            ? SogoColors.success
                            : SogoColors.primary),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: SogoColors.primary,
                    side: BorderSide(
                        color: _gpsLat != null
                            ? SogoColors.success
                            : SogoColors.primary,
                        width: 1.2),
                    padding:
                        const EdgeInsets.symmetric(vertical: SogoSpacing.md),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(SogoRadius.md)),
                  ),
                ),
              ),
              if (_gpsLat != null) ...[
                const SizedBox(height: SogoSpacing.sm),
                Text(
                  'Your exact position will be used for job matching. '
                  'You can still adjust the district/city below.',
                  style: SogoText.bodySm
                      .copyWith(color: SogoColors.textSecondary, fontSize: 11),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: SogoSpacing.lg),
        DropdownButtonFormField<String>(
          value: _district,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: 'District',
            prefixIcon: const Icon(Icons.map_outlined),
            filled: true,
            fillColor: SogoColors.surface,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(SogoRadius.md)),
          ),
          items: _districts
              .map((d) => DropdownMenuItem(value: d, child: Text(d)))
              .toList(),
          onChanged: (v) => _onDistrictChanged(v),
          validator: (v) =>
              v == null || v.isEmpty ? 'Select your district' : null,
        ),
        const SizedBox(height: SogoSpacing.lg),
        DropdownButtonFormField<int>(
          value: _locationId,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: 'City / Town',
            prefixIcon: const Icon(Icons.location_city_outlined),
            filled: true,
            fillColor: SogoColors.surface,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(SogoRadius.md)),
          ),
          items: _cities
              .map((c) => DropdownMenuItem(
                  value: c['id'] as int, child: Text('${c['city']}')))
              .toList(),
          onChanged: (v) {
            final c = _cities.firstWhere((c) => c['id'] == v);
            setState(() {
              _locationId = v;
              _cityName = c['city'];
            });
          },
          validator: (v) => v == null ? 'Select your city' : null,
        ),
        const SizedBox(height: SogoSpacing.lg),
        SogoTextField(
            label: 'Street address',
            hint: 'Plot 12, Acacia Avenue (optional)',
            controller: _address,
            prefixIcon: Icons.location_on_outlined),
        const SizedBox(height: SogoSpacing.xl),
        const SogoSectionTitle('Online presence (optional)'),
        const SizedBox(height: SogoSpacing.md),
        SogoTextField(
            label: 'Website',
            hint: 'yourbusiness.com',
            controller: _website,
            prefixIcon: Icons.language_outlined),
        const SizedBox(height: SogoSpacing.md),
        SogoTextField(
            label: 'Facebook',
            hint: 'facebook.com/yourpage',
            controller: _facebook,
            prefixIcon: Icons.facebook_outlined),
        const SizedBox(height: SogoSpacing.md),
        SogoTextField(
            label: 'Instagram',
            hint: 'instagram.com/yourhandle',
            controller: _instagram,
            prefixIcon: Icons.camera_alt_outlined),
      ],
    );
  }

  Widget _kycStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Verification documents', style: SogoText.headlineMd),
        const SizedBox(height: 4),
        Text(
            'Optional but recommended - admins approve verified vendors faster.',
            style: SogoText.bodySm.copyWith(color: SogoColors.textSecondary)),
        const SizedBox(height: SogoSpacing.lg),
        SogoTextField(
            label: 'National ID number',
            hint: 'CM00000000',
            controller: _idNumber,
            prefixIcon: Icons.badge_outlined),
        const SizedBox(height: SogoSpacing.md),
        SogoTextField(
            label: 'TIN number',
            hint: '1000000000',
            controller: _tinNumber,
            prefixIcon: Icons.receipt_outlined),
        const SizedBox(height: SogoSpacing.md),
        SogoTextField(
            label: 'Business license',
            hint: 'BL-000000',
            controller: _license,
            prefixIcon: Icons.workspace_premium_outlined),
        const SizedBox(height: SogoSpacing.xl),
        const SogoSectionTitle('Upload documents'),
        const SizedBox(height: SogoSpacing.sm),
        ..._docs.asMap().entries.map((entry) {
          final i = entry.key;
          final doc = entry.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: SogoSpacing.md),
            child: Container(
              padding: const EdgeInsets.all(SogoSpacing.md),
              decoration: BoxDecoration(
                color: SogoColors.surfaceMuted,
                borderRadius: BorderRadius.circular(SogoRadius.md),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: doc.type,
                          isExpanded: true,
                          decoration: const InputDecoration(
                              labelText: 'Document type',
                              border: OutlineInputBorder()),
                          items: const [
                            DropdownMenuItem(
                                value: 'national_id',
                                child: Text('National ID')),
                            DropdownMenuItem(
                                value: 'tin_certificate',
                                child: Text('TIN Certificate')),
                            DropdownMenuItem(
                                value: 'business_license_doc',
                                child: Text('Business License')),
                            DropdownMenuItem(
                                value: 'insurance', child: Text('Insurance')),
                            DropdownMenuItem(
                                value: 'other', child: Text('Other')),
                          ],
                          onChanged: (v) =>
                              setState(() => _docs[i].type = v ?? 'other'),
                        ),
                      ),
                      IconButton(
                          onPressed: _docs.length <= 1
                              ? null
                              : () => setState(() => _docs.removeAt(i)),
                          icon: const Icon(Icons.close_rounded,
                              color: SogoColors.textMuted)),
                    ],
                  ),
                  const SizedBox(height: SogoSpacing.sm),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _pickDoc(i),
                      icon: Icon(
                          doc.path != null
                              ? Icons.check_circle_rounded
                              : Icons.upload_file_rounded,
                          size: 18,
                          color: doc.path != null
                              ? SogoColors.success
                              : SogoColors.primary),
                      label: Text(doc.path != null
                          ? (doc.name ?? 'Attached')
                          : 'Choose file (image or PDF)'),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
        TextButton.icon(
          onPressed: _docs.length >= 5
              ? null
              : () => setState(() => _docs.add(_DocRow())),
          icon: const Icon(Icons.add_rounded, size: 18),
          label: const Text('Add another document'),
        ),
        const SizedBox(height: SogoSpacing.lg),
        const SogoSectionTitle('Business photos'),
        const SizedBox(height: SogoSpacing.sm),
        Row(
          children: [
            Expanded(
                child: _imagePickTile('Cover image', _coverImage, _pickCover)),
            const SizedBox(width: SogoSpacing.md),
            Expanded(child: _imagePickTile('Logo', _logoImage, _pickLogo)),
          ],
        ),
      ],
    );
  }

  Widget _imagePickTile(
      String label, XFile? file, Future<void> Function() onPick) {
    return GestureDetector(
      onTap: onPick,
      child: Container(
        height: 110,
        decoration: BoxDecoration(
          color: SogoColors.surface,
          borderRadius: BorderRadius.circular(SogoRadius.md),
          border: Border.all(color: SogoColors.surfaceBorder),
        ),
        child: file != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(SogoRadius.md),
                child: Image.file(File(file.path),
                    fit: BoxFit.cover, width: double.infinity))
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.add_photo_alternate_outlined,
                      color: SogoColors.textMuted),
                  const SizedBox(height: 4),
                  Text(label,
                      style: SogoText.bodySm
                          .copyWith(color: SogoColors.textSecondary)),
                ],
              ),
      ),
    );
  }

  String _serviceName(Object? id) {
    for (final c in _categories) {
      if ('${c['id']}' == '$id') return '${c['name']}';
    }
    return 'Service #$id';
  }

  Widget _reviewSection(String title, List<Widget> rows) {
    if (rows.isEmpty) return const SizedBox.shrink();
    return SogoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: SogoText.labelMd.copyWith(
                  color: SogoColors.primary,
                  fontWeight: FontWeight.w800,
                  fontSize: 11)),
          const SizedBox(height: SogoSpacing.sm),
          ...rows,
        ],
      ),
    );
  }

  Widget _reviewStep() {
    final services = _selectedServices.map((id) => _serviceName(id)).toList();
    final docs = _docs.where((d) => d.path != null).toList();
    final gps = _gpsLat != null
        ? '${_gpsLat!.toStringAsFixed(5)}, ${_gpsLng!.toStringAsFixed(5)}'
        : '';
    final exp = int.tryParse(_t(_experience));
    final rate = double.tryParse(_t(_hourlyRate));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Review your details', style: SogoText.headlineMd),
        const SizedBox(height: 4),
        Text('Check everything below before you submit.',
            style: SogoText.bodySm.copyWith(color: SogoColors.textSecondary)),
        const SizedBox(height: SogoSpacing.lg),
        _reviewSection('ACCOUNT', [
          _reviewRow('Name', _t(_name)),
          _reviewRow('Phone', _t(_phone)),
          _reviewRow('Email', _t(_email)),
        ]),
        const SizedBox(height: SogoSpacing.md),
        _reviewSection('BUSINESS', [
          _reviewRow('Business name', _t(_businessName)),
          _reviewRow('Type', _providerType),
          if (_t(_description).isNotEmpty)
            _reviewRow('Description', _t(_description)),
          if (exp != null) _reviewRow('Experience', '$exp years'),
          if (rate != null)
            _reviewRow('Hourly rate', 'UGX ${rate.toStringAsFixed(0)}'),
        ]),
        const SizedBox(height: SogoSpacing.md),
        _reviewSection('SERVICES (${services.length})', [
          Wrap(
            spacing: SogoSpacing.sm,
            runSpacing: SogoSpacing.sm,
            children: services
                .map((s) => Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: SogoColors.primaryLight,
                        borderRadius: BorderRadius.circular(SogoRadius.pill),
                      ),
                      child: Text(s,
                          style: SogoText.bodySm.copyWith(
                              color: SogoColors.primary,
                              fontWeight: FontWeight.w600)),
                    ))
                .toList(),
          ),
        ]),
        const SizedBox(height: SogoSpacing.md),
        _reviewSection('LOCATION', [
          if (gps.isNotEmpty) _reviewRow('GPS', gps),
          _reviewRow('District', _district ?? ''),
          _reviewRow('City / Town', _cityName ?? ''),
          if (_t(_address).isNotEmpty) _reviewRow('Address', _t(_address)),
          _reviewRow('Service radius', '${_radius.round()} km'),
        ]),
        const SizedBox(height: SogoSpacing.md),
        _reviewSection('CONTACT & SOCIAL', [
          if (_url(_website).isNotEmpty) _reviewRow('Website', _url(_website)),
          if (_url(_facebook).isNotEmpty)
            _reviewRow('Facebook', _url(_facebook)),
          if (_url(_instagram).isNotEmpty)
            _reviewRow('Instagram', _url(_instagram)),
        ]),
        const SizedBox(height: SogoSpacing.md),
        _reviewSection('KYC DOCUMENTS (${docs.length})', [
          ...docs.map((d) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(children: [
                  const Icon(Icons.description_rounded,
                      size: 16, color: SogoColors.success),
                  const SizedBox(width: SogoSpacing.sm),
                  Expanded(
                      child: Text(d.name ?? 'Document',
                          style: SogoText.bodySm,
                          overflow: TextOverflow.ellipsis)),
                  Text(d.type.replaceAll('_', ' '),
                      style: SogoText.bodySm
                          .copyWith(color: SogoColors.textSecondary)),
                ]),
              )),
          if (_coverImage != null) _reviewRow('Cover photo', _coverImage!.name),
          if (_logoImage != null) _reviewRow('Logo', _logoImage!.name),
        ]),
        const SizedBox(height: SogoSpacing.lg),
        Row(
          children: [
            Checkbox(
                value: _terms,
                onChanged: (v) => setState(() => _terms = v ?? false),
                activeColor: SogoColors.primary),
            Expanded(
                child: Text.rich(TextSpan(
                    text: 'I agree to the ',
                    style: SogoText.bodySm
                        .copyWith(color: SogoColors.textSecondary),
                    children: [
                  WidgetSpan(
                      child: GestureDetector(
                          onTap: _showTerms,
                          child: Text('Terms',
                              style: SogoText.bodySm.copyWith(
                                  color: SogoColors.primary,
                                  fontWeight: FontWeight.w700)))),
                  const TextSpan(text: ' & '),
                  WidgetSpan(
                      child: GestureDetector(
                          onTap: _showPrivacy,
                          child: Text('Privacy Policy',
                              style: SogoText.bodySm.copyWith(
                                  color: SogoColors.primary,
                                  fontWeight: FontWeight.w700)))),
                ]))),
          ],
        ),
      ],
    );
  }

  void _showTerms() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(SogoRadius.xl))),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        builder: (ctx, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.all(SogoSpacing.xl),
          children: [
            Text('Terms & Conditions', style: SogoText.headlineLg),
            const SizedBox(height: SogoSpacing.md),
            Text(
              '1. Services\n'
              'SOGO connects vehicle owners with independent service providers. '
              'Providers are responsible for the quality and safety of the work performed.\n\n'
              '2. Provider obligations\n'
              'You agree to provide accurate business information, honour accepted jobs, '
              'and maintain professional conduct with customers.\n\n'
              '3. Payments\n'
              'Service fees are collected through SOGO. A platform commission is deducted '
              'from each completed job before provider earnings are credited.\n\n'
              '4. Verification\n'
              'SOGO may request identity or business documents. Providing false '
              'information may lead to suspension.\n\n'
              '5. Account suspension\n'
              'Accounts may be suspended for fraud, repeated cancellations, or customer '
              'safety violations.\n\n'
              '6. Changes\n'
              'These terms may be updated. Continued use of SOGO constitutes acceptance.',
              style: SogoText.bodyMd
                  .copyWith(color: SogoColors.textSecondary, height: 1.6),
            ),
            const SizedBox(height: SogoSpacing.xl),
          ],
        ),
      ),
    );
  }

  void _showPrivacy() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(SogoRadius.xl))),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        builder: (ctx, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.all(SogoSpacing.xl),
          children: [
            Text('Privacy Policy', style: SogoText.headlineLg),
            const SizedBox(height: SogoSpacing.md),
            Text(
              '1. Data we collect\n'
              'Your name, contact details, business information, location data '
              '(while online), documents you upload, and transaction records.\n\n'
              '2. How we use it\n'
              'To match customers with providers, process payments, verify '
              'identities, and provide support.\n\n'
              '3. Location data\n'
              'Provider locations are used only for job matching and live tracking '
              'during active jobs.\n\n'
              '4. Sharing\n'
              'Your business name, rating, and service area are visible to '
              'customers. We never sell personal data.\n\n'
              '5. Your rights\n'
              'You may request a copy or deletion of your data at any time via '
              'support.',
              style: SogoText.bodyMd
                  .copyWith(color: SogoColors.textSecondary, height: 1.6),
            ),
            const SizedBox(height: SogoSpacing.xl),
          ],
        ),
      ),
    );
  }

  Widget _reviewRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: SogoSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
              width: 100,
              child: Text(label,
                  style: SogoText.bodySm
                      .copyWith(color: SogoColors.textSecondary))),
          Expanded(
              child: Text(value.isEmpty ? '-' : value,
                  style:
                      SogoText.bodySm.copyWith(fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }

  Widget _bottomBar() {
    final isLast = _step == _stepCount - 1;
    return Container(
      color: SogoColors.surface,
      padding: const EdgeInsets.symmetric(
          horizontal: SogoSpacing.lg, vertical: SogoSpacing.md),
      child: SafeArea(
        top: false,
        child: SogoButton(
          label: isLast ? 'Create vendor account' : 'Continue',
          onPressed: _next,
          loading: _loading,
          icon: isLast ? Icons.check_rounded : Icons.arrow_forward_rounded,
        ),
      ),
    );
  }
}
