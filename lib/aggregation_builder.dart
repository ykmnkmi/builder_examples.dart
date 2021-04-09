library aggregation_builder;

import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:builder_examples/aggregation.dart';
import 'package:glob/glob.dart';
import 'package:path/path.dart' as path;
import 'package:source_gen/source_gen.dart';

Builder aggregationBuilder(BuilderOptions options) {
  return AggregationBuilder(options.config['filename'] ?? 'export');
}

class AggregationBuilder implements Builder {
  AggregationBuilder(this.outFileName) : outputPath = path.join('lib', '$outFileName.dart');

  final String outFileName;

  final String outputPath;

  @override
  Map<String, List<String>> get buildExtensions {
    return <String, List<String>>{
      r'$lib$': ['$outFileName.dart'],
    };
  }

  AssetId allFileOutput(BuildStep buildStep) {
    return AssetId(buildStep.inputId.package, outputPath);
  }

  @override
  Future<void> build(BuildStep buildStep) async {
    final checker = TypeChecker.fromRuntime(Aggregate);
    final functions = <Uri, List<Element>>{};

    await for (final input in buildStep.findAssets(Glob('lib/**.dart'))) {
      final library = await buildStep.resolver.libraryFor(input);
      final annotatedElements = LibraryReader(library).annotatedWith(checker);
      final elements = annotatedElements
          .where((annotatedElement) => annotatedElement.element.isPublic)
          .map((annotatedElement) => annotatedElement.element);

      for (final element in elements) {
        final source = element.source;

        if (source != null) {
          if (!functions.containsKey(source.uri)) {
            functions[source.uri] = <Element>[];
          }

          functions[source.uri]!.add(element);
        }
      }
    }

    final buffer = StringBuffer();

    for (final uri in functions.keys) {
      buffer.write('export \'$uri\' show ');
      functions[uri]!.sort((a, b) => a.name!.compareTo(b.name!));
      buffer.writeAll(functions[uri]!.map((function) => function.name), ', ');
      buffer.writeln(';');
    }

    await buildStep.writeAsString(allFileOutput(buildStep), buffer.toString());
  }
}
