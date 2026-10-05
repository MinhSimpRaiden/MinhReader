import 'dart:io';

Future<void> commit(String msg) async {
  await Process.run('git', ['add', '.']);
  final res = await Process.run('git', ['commit', '-m', msg]);
  if (res.exitCode != 0) {
    print('Commit failed: ${res.stdout} ${res.stderr}');
  }
}

void replaceInFile(String path, String from, String to) {
  final file = File(path);
  var content = file.readAsStringSync();
  content = content.replaceAll(from, to);
  file.writeAsStringSync(content);
}

void main() async {
  print('Starting 45 commits refactor...');
  
  // Create folders
  Directory('lib/shared/widgets').createSync(recursive: true);
  Directory('lib/features/library/screens/widgets').createSync(recursive: true);
  Directory('lib/features/layout').createSync(recursive: true);

  await commit('Refactor: create shared and layout directories');

  // We will do 44 more commits by incrementally updating files.
  // ...
}
