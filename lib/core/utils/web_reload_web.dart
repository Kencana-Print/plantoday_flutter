import 'dart:js_interop';

@JS('forceHardReload')
external void _forceHardReload();

@JS('window.location.replace')
external void _locationReplace(JSString url);

@JS('window.location.reload')
external void _locationReload();

@JS('window.addEventListener')
external void _addWindowEventListener(JSString type, JSFunction listener);

@JS('document.addEventListener')
external void _addDocumentEventListener(JSString type, JSFunction listener);

@JS('document.hidden')
external bool get _isDocumentHidden;

void reloadWebPage() {
  try {
    _forceHardReload();
  } catch (_) {
    try {
      final base = Uri.base;
      final newQuery = Map<String, String>.from(base.queryParameters);
      newQuery['_v'] = DateTime.now().millisecondsSinceEpoch.toString();
      final targetUri = base.replace(queryParameters: newQuery);
      _locationReplace(targetUri.toString().toJS);
    } catch (_) {
      _locationReload();
    }
  }
}

void registerWebFocusListener(void Function() onFocus) {
  try {
    final focusCallback = (() {
      onFocus();
    }).toJS;

    final pageShowCallback = (() {
      onFocus();
    }).toJS;

    final visibilityCallback = (() {
      try {
        if (!_isDocumentHidden) {
          onFocus();
        }
      } catch (_) {
        onFocus();
      }
    }).toJS;

    _addWindowEventListener('focus'.toJS, focusCallback);
    _addWindowEventListener('pageshow'.toJS, pageShowCallback);
    _addDocumentEventListener('visibilitychange'.toJS, visibilityCallback);
  } catch (_) {}
}
