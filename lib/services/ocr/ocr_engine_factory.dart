import 'ocr_engine.dart';
import 'ocr_engine_web.dart'
    if (dart.library.io) 'ocr_engine_mobile.dart';

OcrEngine getOcrEngine() => OcrEngineImpl();
