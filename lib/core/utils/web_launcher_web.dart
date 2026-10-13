import 'dart:js' as js;

bool openBrowserWindow(String url) {
  try {
    js.context.callMethod('open', [url, '_blank']);
    return true;
  } catch (e) {
    return false;
  }
}
