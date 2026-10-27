/// Web / 非 IO 平台的兜底实现：没有文件系统，直接返回空。
/// 由 `store.dart` 通过条件导入选择真正可用的实现。
library;

Future<String?> readStateRaw() async => null;

/// 无旧文件可读。
Future<String?> readLegacyStateRaw() async => null;

Future<bool> writeStateRaw(String data) async => false;

String get backendName => 'none';
