import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:busgo_mobile/features/auth/presentation/providers/auth_provider.dart';
import 'package:busgo_mobile/features/profile/presentation/utils/profile_validators.dart';
import 'package:busgo_mobile/features/profile/presentation/widgets/otp_input.dart';

enum ContactField { email, phone }

/// Modal đổi email/số điện thoại theo flow 3 bước:
///   1. Verify OTP của giá trị HIỆN TẠI (skip nếu giá trị hiện tại null/rỗng).
///   2. Nhập giá trị MỚI + gửi OTP đến giá trị mới.
///   3. Xác nhận OTP của giá trị mới + cập nhật.
Future<bool?> showUpdateContactModal(
  BuildContext context, {
  required ContactField field,
  required String? currentValue,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => UpdateContactModal(
      field: field,
      currentValue: currentValue,
    ),
  );
}

class UpdateContactModal extends StatefulWidget {
  final ContactField field;
  final String? currentValue;
  const UpdateContactModal({
    super.key,
    required this.field,
    required this.currentValue,
  });

  @override
  State<UpdateContactModal> createState() => _UpdateContactModalState();
}

enum _Step { verifyCurrent, sendNew, confirmUpdate }

class _UpdateContactModalState extends State<UpdateContactModal> {
  static const Color _primary = Color(0xff006e1c);
  static const Color _primaryLight = Color(0xff4caf50);
  static const LinearGradient _primaryGradient = LinearGradient(
    colors: [_primary, _primaryLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  late _Step _step;
  bool _loading = false;
  String? _error;

  String _otpCurrent = '';
  String _otpNew = '';
  final TextEditingController _newValueCtrl = TextEditingController();
  bool _otpCurrentSent = false;

  String get _fieldKey => widget.field == ContactField.email ? 'email' : 'phone';
  String get _fieldLabel =>
      widget.field == ContactField.email ? 'email' : 'số điện thoại';
  String get _fieldLabelCap => widget.field == ContactField.email
      ? 'Email'
      : 'Số điện thoại';

  @override
  void initState() {
    super.initState();
    final hasCurrent =
        widget.currentValue != null && widget.currentValue!.trim().isNotEmpty;
    _step = hasCurrent ? _Step.verifyCurrent : _Step.sendNew;

    // Tự gửi OTP đến giá trị HIỆN TẠI khi mở modal (chỉ khi có)
    if (hasCurrent) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _sendOtpCurrent();
      });
    }
  }

  @override
  void dispose() {
    _newValueCtrl.dispose();
    super.dispose();
  }

  // ---------- API calls ----------

  Future<void> _sendOtpCurrent() async {
    if (_otpCurrentSent) return;
    setState(() => _otpCurrentSent = true);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    try {
      await auth.sendOtp(field: _fieldKey, value: widget.currentValue!);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = _resolveErr(e, fallback: 'Không gửi được OTP. Thử lại.');
        });
      }
    }
  }

  Future<void> _verifyCurrent() async {
    if (!ProfileValidators.isValidOtp(_otpCurrent)) {
      setState(() => _error = 'Mã OTP không hợp lệ (4-8 chữ số).');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final ok = await auth.verifyContact(
        field: _fieldKey,
        value: widget.currentValue!,
        otp: _otpCurrent,
      );
      if (!mounted) return;
      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Xác thực liên hệ hiện tại thành công'),
            backgroundColor: _primary,
          ),
        );
        setState(() {
          _step = _Step.sendNew;
          _error = null;
        });
      } else {
        setState(() => _error = auth.errorMessage ?? 'Xác thực thất bại.');
      }
    } catch (e) {
      if (mounted) setState(() => _error = _resolveErr(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _sendOtpNew() async {
    final newVal = _newValueCtrl.text.trim();
    final isEmail = widget.field == ContactField.email;
    if (isEmail && !ProfileValidators.isValidEmail(newVal)) {
      setState(() => _error = 'Email mới không hợp lệ.');
      return;
    }
    if (!isEmail && !ProfileValidators.isValidPhone(newVal)) {
      setState(() => _error =
          'Số điện thoại mới không hợp lệ (định dạng +84xxxxxxxxx hoặc 0xxxxxxxxxx).');
      return;
    }
    if (widget.currentValue != null &&
        widget.currentValue!.trim() == newVal) {
      setState(() => _error = '$_fieldLabelCap mới phải khác giá trị hiện tại.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      await auth.sendOtp(field: _fieldKey, value: newVal);
      if (!mounted) return;
      setState(() => _step = _Step.confirmUpdate);
    } catch (e) {
      if (mounted) setState(() => _error = _resolveErr(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _confirmUpdate() async {
    if (!ProfileValidators.isValidOtp(_otpNew)) {
      setState(() => _error = 'Mã OTP không hợp lệ (4-8 chữ số).');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final ok = await auth.updateContact(
        field: _fieldKey,
        value: _newValueCtrl.text.trim(),
        otp: _otpNew,
      );
      if (!mounted) return;
      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cập nhật $_fieldLabel thành công'),
            backgroundColor: _primary,
          ),
        );
        Navigator.pop(context, true);
      } else {
        setState(() => _error = auth.errorMessage ?? 'Cập nhật thất bại.');
      }
    } catch (e) {
      if (mounted) setState(() => _error = _resolveErr(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _resolveErr(Object e, {String fallback = 'Đã có lỗi xảy ra. Thử lại.'}) {
    if (e is DioException) {
      final data = e.response?.data;
      if (data is Map) {
        final m = data['message'] ?? data['error'];
        if (m != null && m.toString().isNotEmpty) return m.toString();
      }
      if (e.error != null && e.error.toString().isNotEmpty) {
        return e.error.toString();
      }
    }
    return fallback;
  }

  // ---------- Build helpers ----------

  String _submitLabel() {
    final isPhoneNull = widget.currentValue == null ||
        widget.currentValue!.trim().isEmpty;
    switch (_step) {
      case _Step.verifyCurrent:
        return _loading ? 'Đang xác thực...' : 'Xác thực OTP hiện tại';
      case _Step.sendNew:
        if (_loading) return 'Đang gửi OTP...';
        return isPhoneNull ? 'Gửi OTP' : 'Gửi OTP liên hệ mới';
      case _Step.confirmUpdate:
        return _loading ? 'Đang cập nhật...' : 'Xác nhận cập nhật';
    }
  }

  VoidCallback? _onSubmit() {
    if (_loading) return null;
    switch (_step) {
      case _Step.verifyCurrent:
        return _verifyCurrent;
      case _Step.sendNew:
        return _sendOtpNew;
      case _Step.confirmUpdate:
        return _confirmUpdate;
    }
  }

  int _stepIndex() {
    final hasCurrent = widget.currentValue != null &&
        widget.currentValue!.trim().isNotEmpty;
    switch (_step) {
      case _Step.verifyCurrent:
        return 1;
      case _Step.sendNew:
        return hasCurrent ? 2 : 1;
      case _Step.confirmUpdate:
        return hasCurrent ? 3 : 2;
    }
  }

  int _totalSteps() {
    final hasCurrent = widget.currentValue != null &&
        widget.currentValue!.trim().isNotEmpty;
    return hasCurrent ? 3 : 2;
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return AnimatedPadding(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 14),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  // Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          gradient: _primaryGradient,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          widget.field == ContactField.email
                              ? Icons.mail_outline_rounded
                              : Icons.phone_iphone_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'BƯỚC ${_stepIndex()}/${_totalSteps()}',
                              style: const TextStyle(
                                color: _primary,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.4,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              widget.field == ContactField.email
                                  ? 'Cập nhật email'
                                  : 'Cập nhật số điện thoại',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF1E1E1E),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Semantics(
                        label: 'Đóng',
                        child: IconButton(
                          icon: Icon(Icons.close_rounded,
                              color: Colors.grey.shade600),
                          onPressed: () => Navigator.pop(context, false),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _buildStepBody(),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    _buildErrorBox(_error!),
                  ],
                  const SizedBox(height: 16),
                  _buildSubmitButton(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStepBody() {
    switch (_step) {
      case _Step.verifyCurrent:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHintBox(
              icon: Icons.shield_outlined,
              title: 'Xác thực liên hệ hiện tại',
              body:
                  'Chúng tôi đã gửi mã OTP đến $_fieldLabel hiện tại của bạn:\n${widget.currentValue}',
            ),
            const SizedBox(height: 14),
            const Text(
              'Nhập mã OTP',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1E1E1E),
              ),
            ),
            const SizedBox(height: 8),
            OtpInput(
              onChanged: (v) {
                setState(() {
                  _otpCurrent = v;
                  if (_error != null) _error = null;
                });
              },
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _loading
                  ? null
                  : () {
                      setState(() => _otpCurrentSent = false);
                      _sendOtpCurrent();
                    },
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Gửi lại OTP'),
              style: TextButton.styleFrom(
                foregroundColor: _primary,
                padding: EdgeInsets.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
        );

      case _Step.sendNew:
        final isEmail = widget.field == ContactField.email;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHintBox(
              icon: Icons.edit_outlined,
              title: 'Nhập $_fieldLabel mới',
              body:
                  'Chúng tôi sẽ gửi mã OTP đến $_fieldLabel mới để xác thực.',
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _newValueCtrl,
              autofocus: true,
              keyboardType: isEmail
                  ? TextInputType.emailAddress
                  : TextInputType.phone,
              autofillHints:
                  isEmail ? const [AutofillHints.email] : const [AutofillHints.telephoneNumber],
              decoration: InputDecoration(
                labelText: '$_fieldLabelCap mới',
                hintText: isEmail ? 'name@example.com' : '0901234567',
                prefixIcon: Icon(isEmail
                    ? Icons.alternate_email_rounded
                    : Icons.phone_rounded),
                filled: true,
                fillColor: Colors.grey.shade50,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: _primary, width: 1.5),
                ),
              ),
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
            ),
          ],
        );

      case _Step.confirmUpdate:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHintBox(
              icon: Icons.mark_email_read_outlined,
              title: 'Nhập OTP đã gửi đến $_fieldLabel mới',
              body: _newValueCtrl.text.trim(),
            ),
            const SizedBox(height: 14),
            const Text(
              'Nhập mã OTP',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1E1E1E),
              ),
            ),
            const SizedBox(height: 8),
            OtpInput(
              onChanged: (v) {
                setState(() {
                  _otpNew = v;
                  if (_error != null) _error = null;
                });
              },
            ),
          ],
        );
    }
  }

  Widget _buildHintBox({
    required IconData icon,
    required String title,
    required String body,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _primary.withOpacity(0.06),
            _primaryLight.withOpacity(0.06),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _primary.withOpacity(0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: _primary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    color: _primary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: Colors.grey.shade800,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBox(String msg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, size: 16, color: Colors.red.shade600),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              msg,
              style: TextStyle(
                color: Colors.red.shade700,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    final onTap = _onSubmit();
    final disabled = onTap == null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        height: 50,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: disabled ? null : _primaryGradient,
          color: disabled ? Colors.grey.shade300 : null,
          borderRadius: BorderRadius.circular(14),
          boxShadow: disabled
              ? null
              : [
                  BoxShadow(
                    color: _primary.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: _loading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.4,
                ),
              )
            : Text(
                _submitLabel(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.3,
                ),
              ),
      ),
    );
  }
}
