/// 纯 dart:io 的落盘兜底：不依赖任何插件，也不经过 platform channel。
///
/// 为什么不直接用 path_provider：如果插件通道本身出问题，它一样会失败。
/// Android 上 `Directory.systemTemp` 是 `/data/user/0/<pkg>/cache`，
/// 它的父目录就是应用私有目录，往 `files/` 写是稳定可用的。
library;

import 'dart:io';

const _dirName = 'dailyq';
const _fileName = 'dailyq-state.json';

/// 改名前的路径，仅用于一次性迁移读取。
const _legacyDirName = 'fastlog';
const _legacyFileName = 'fastlog-state.json';

/// 应用私有目录（Android 上为 `/data/user/0/<pkg>`，其余平台为临时目录的父级）。
Directory? _baseDir() {
  try {
    final tempPath = Directory.systemTemp.path;
    final isAndroidCache =
        tempPath.endsWith('/cache') || tempPath.endsWith(r'\cache');
    return isAndroidCache ? Directory(tempPath).parent : Directory(tempPath);
  } catch (_) {
    return null;
  }
}

File? _fileIn(String dirName, String fileName) {
  final base = _baseDir();
  if (base == null) return null;
  return File(
    '${base.path}${Platform.pathSeparator}$dirName${Platform.pathSeparator}$fileName',
  );
}

File? _stateFile() => _fileIn(_dirName, _fileName);

File? _legacyStateFile() => _fileIn(_legacyDirName, _legacyFileName);

Future<String?> _readFile(File? file) async {
  try {
    if (file == null || !file.existsSync()) return null;
    final text = await file.readAsString();
    return text.isEmpty ? null : text;
  } catch (_) {
    return null;
  }
}

Future<String?> readStateRaw() => _readFile(_stateFile());

/// 读改名前的文件，命中后调用方会立即按新名字重写一份。
Future<String?> readLegacyStateRaw() => _readFile(_legacyStateFile());

Future<bool> writeStateRaw(String data) async {
  try {
    final file = _stateFile();
    if (file == null) return false;
    file.parent.createSync(recursive: true);
    // 先写临时文件再改名，避免写到一半被系统杀掉留下残缺 JSON
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsString(data, flush: true);
    await tmp.rename(file.path);
    return true;
  } catch (_) {
    return false;
  }
}

String get backendName => 'files';
