import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// OTP input 6 ô số.
/// - Tự focus ô kế tiếp khi nhập
/// - Backspace ở ô trống → focus ô trước
/// - Hỗ trợ paste/auto-fill SMS (textContentType oneTimeCode trên iOS,
///   autofillHints sms-otp trên Android)
/// - Khi đầy 6 chữ số → emit chuỗi qua [onCompleted]
class OtpInput extends StatefulWidget {
  final int length;
  final ValueChanged<String> onChanged;
  final ValueChanged<String>? onCompleted;
  final bool obscureText;
  final bool enabled;

  const OtpInput({
    super.key,
    this.length = 6,
    required this.onChanged,
    this.onCompleted,
    this.obscureText = true,
    this.enabled = true,
  });

  @override
  State<OtpInput> createState() => _OtpInputState();
}

class _OtpInputState extends State<OtpInput> {
  late final List<TextEditingController> _ctrls;
  late final List<FocusNode> _focuses;

  @override
  void initState() {
    super.initState();
    _ctrls = List.generate(widget.length, (_) => TextEditingController());
    _focuses = List.generate(widget.length, (_) => FocusNode());
  }

  @override
  void dispose() {
    for (final c in _ctrls) {
      c.dispose();
    }
    for (final f in _focuses) {
      f.dispose();
    }
    super.dispose();
  }

  String get _value => _ctrls.map((c) => c.text).join();

  void _handleChanged(int index, String raw) {
    // Hỗ trợ paste / autofill: nếu user dán chuỗi nhiều ký tự
    if (raw.length > 1) {
      _distributeFromIndex(index, raw);
      return;
    }
    if (raw.isNotEmpty && index < widget.length - 1) {
      _focuses[index + 1].requestFocus();
    }
    final v = _value;
    widget.onChanged(v);
    if (v.length == widget.length) {
      _focuses[index].unfocus();
      widget.onCompleted?.call(v);
    }
  }

  void _distributeFromIndex(int startIndex, String raw) {
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    int i = startIndex;
    for (final ch in digits.characters) {
      if (i >= widget.length) break;
      _ctrls[i].text = ch;
      i++;
    }
    if (i < widget.length) {
      _focuses[i].requestFocus();
    } else {
      _focuses[widget.length - 1].unfocus();
    }
    final v = _value;
    widget.onChanged(v);
    if (v.length == widget.length) {
      widget.onCompleted?.call(v);
    }
  }

  KeyEventResult _onKey(int index, FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.backspace &&
        _ctrls[index].text.isEmpty &&
        index > 0) {
      _ctrls[index - 1].clear();
      _focuses[index - 1].requestFocus();
      widget.onChanged(_value);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(widget.length, (i) {
        final isFilled = _ctrls[i].text.isNotEmpty;
        return SizedBox(
          width: 44,
          height: 52,
          child: Focus(
            onKeyEvent: (node, event) => _onKey(i, node, event),
            child: TextField(
              controller: _ctrls[i],
              focusNode: _focuses[i],
              enabled: widget.enabled,
              autofocus: i == 0,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              maxLength: 1,
              obscureText: widget.obscureText,
              autofillHints: i == 0 ? const [AutofillHints.oneTimeCode] : null,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
              ],
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: Color(0xff1E1E1E),
              ),
              decoration: InputDecoration(
                counterText: '',
                filled: true,
                fillColor: isFilled
                    ? const Color(0xff006e1c).withOpacity(0.06)
                    : Colors.grey.shade50,
                contentPadding: EdgeInsets.zero,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(
                    color: isFilled
                        ? const Color(0xff006e1c).withOpacity(0.5)
                        : Colors.grey.shade300,
                    width: isFilled ? 1.4 : 1,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide:
                      const BorderSide(color: Color(0xff006e1c), width: 1.6),
                ),
              ),
              onChanged: (v) => _handleChanged(i, v),
            ),
          ),
        );
      }),
    );
  }
}
