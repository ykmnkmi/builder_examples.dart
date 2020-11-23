import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:abet/abet.dart';
import 'package:glob/glob.dart';
import 'package:path/path.dart' as path;
import 'package:source_gen/source_gen.dart';

Builder abetBuilder(BuilderOptions options) {
  return ABETBuilder(options.config['filename'] ?? 'export');
}

class ABETBuilder implements Builder {
  static final allFilesInLib = Glob('lib/**.dart');

  const ABETBuilder(this.outFileName);

  final String outFileName;

  @override
  Map<String, List<String>> get buildExtensions {
    return <String, List<String>>{
      r'$lib$': ['$outFileName.dart'],
    };
  }

  AssetId allFileOutput(BuildStep buildStep) {
    return AssetId(buildStep.inputId.package, path.join('lib', '$outFileName.dart'));
  }

  @override
  Future<void> build(BuildStep buildStep) async {
    final checker = TypeChecker.fromRuntime(Export);
    final functions = <Uri, List<Element>>{};

    await for (final input in buildStep.findAssets(Glob('lib/**.dart'))) {
      final library = await buildStep.resolver.libraryFor(input);
      final annotatedElements = LibraryReader(library).annotatedWith(checker);
      final elements = annotatedElements
          .where((annotatedElement) => annotatedElement.element.isPublic)
          .map((annotatedElement) => annotatedElement.element);

      for (final element in elements) {
        if (!functions.containsKey(element.source.uri)) {
          functions[element.source.uri] = <Element>[];
        }

        functions[element.source.uri].add(element);
      }
    }

    final buffer = StringBuffer();

    for (final uri in functions.keys) {
      buffer.write('export \'$uri\' show ');
      functions[uri].sort((a, b) => a.name.compareTo(b.name));
      buffer.writeAll(functions[uri].map((function) => function.name), ', ');
      buffer.writeln(';');
    }

    await buildStep.writeAsString(allFileOutput(buildStep), buffer.toString());
  }
}
