// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';

import 'package:optimal_roll/simulation/simulation.dart';

Future<void> main(List<String> arguments) async {
  final options = _Options.parse(arguments);
  if (options.showHelp) {
    _printHelp();
    return;
  }

  print(
    'Optimizing ${options.population} candidates for ${options.generations} '
    'generations on ${options.minimumTrainingGames}..'
    '${options.trainingGames} shared training games.',
  );
  print(
    'Validation: ${options.finalists} finalists x ${options.validationGames} '
    'games; blind test: ${options.testGames} games; workers: ${options.workers}',
  );
  print('Search space: ${options.searchSpaceName}');

  final result = await const AdvisorWeightOptimizer().optimize(
    profileName: options.profileName,
    options: WeightOptimizerOptions(
      populationSize: options.population,
      generations: options.generations,
      minimumTrainingGames: options.minimumTrainingGames,
      trainingGames: options.trainingGames,
      validationCandidateCount: options.finalists,
      validationGames: options.validationGames,
      testGames: options.testGames,
      firstTrainingSeed: options.seed,
      firstValidationSeed: options.seed + 1000000,
      firstTestSeed: options.seed + 2000000,
      workers: options.workers,
      optimizerSeed: options.optimizerSeed,
      searchSpace: options.searchSpace,
    ),
    onProgress: (progress) {
      final cacheLabel = progress.cached ? ', reused prior games' : '';
      print(
        'Generation ${progress.generation}, '
        '${progress.candidateIndex}/${progress.populationSize}: '
        '${progress.meanScore.toStringAsFixed(2)} '
        '(${progress.trainingGames} games)$cacheLabel',
      );
    },
  );

  final json = const JsonEncoder.withIndent('  ').convert(result.toJson());
  print('');
  print(
    'Selected finalist training score: '
    '${result.trainingReport.totalScore.mean.toStringAsFixed(2)}',
  );
  print(
    'Validation score: ${result.validationReport.totalScore.mean.toStringAsFixed(2)}',
  );
  print(
    'Validation difference vs current defaults: '
    '${result.validationComparison.scoreDifference.mean.toStringAsFixed(2)} '
    '+/- ${result.validationComparison.confidence95HalfWidth.toStringAsFixed(2)}',
  );
  print(
    'Blind-test difference vs current defaults: '
    '${result.testComparison.scoreDifference.mean.toStringAsFixed(2)} '
    '+/- ${result.testComparison.confidence95HalfWidth.toStringAsFixed(2)}',
  );
  print('Validated finalist ranking:');
  for (var index = 0; index < result.validatedCandidates.length; index++) {
    final finalist = result.validatedCandidates[index];
    print(
      '  ${index + 1}. '
      '${finalist.validationComparison.scoreDifference.mean.toStringAsFixed(2)} '
      '+/- '
      '${finalist.validationComparison.confidence95HalfWidth.toStringAsFixed(2)}',
    );
  }
  print(
    'Adoption recommendation: '
    '${result.isValidatedImprovement ? 'ACCEPT' : 'REJECT'}',
  );
  print('Weights:');
  print(
    const JsonEncoder.withIndent('  ').convert(result.bestCandidate.toJson()),
  );
  final boundaryHits = options.searchSpace.boundaryHits(result.bestCandidate);
  print(
    'Search-space boundary hits: '
    '${boundaryHits.isEmpty ? 'none' : boundaryHits.join(', ')}',
  );

  if (options.outputPath != null) {
    final file = File(options.outputPath!);
    await file.parent.create(recursive: true);
    await file.writeAsString('$json\n');
    print('Saved result to ${file.path}');
  }
}

void _printHelp() {
  print('''
Search for Advisor weights using deterministic complete-game simulations.

Usage:
  dart run tool/optimize_advisor_weights.dart [options]

Options:
  --population <count>        Candidates per generation (default: 6)
  --generations <count>       Number of generations (default: 2)
  --min-training-games <n>    Games in the first generation (default: 1)
  --training-games <count>    Games in the final generation (default: 1)
  --finalists <count>         Candidates validated after training (default: 2)
  --validation-games <count>  Games used to select a finalist (default: 1)
  --test-games <count>        Blind adoption test games (default: 1)
  --seed <value>              First training seed (default: 1)
  --optimizer-seed <value>    Reproduces candidate mutations (default: 20260903)
  --workers <count>           Parallel game isolates (default: 1)
  --profile-name <name>       Name stored in the result (default: optimized-v2)
  --search-space <name>       standard or wide bounds (default: standard)
  --output <path>             Save the winning profile and reports as JSON
  --help                      Show this help

The defaults are intentionally small. Use more games only after benchmarking
the simulator on the current machine.
''');
}

class _Options {
  final int population;
  final int generations;
  final int minimumTrainingGames;
  final int trainingGames;
  final int finalists;
  final int validationGames;
  final int testGames;
  final int seed;
  final int optimizerSeed;
  final int workers;
  final String profileName;
  final String searchSpaceName;
  final AdvisorWeightSearchSpace searchSpace;
  final String? outputPath;
  final bool showHelp;

  const _Options({
    required this.population,
    required this.generations,
    required this.minimumTrainingGames,
    required this.trainingGames,
    required this.finalists,
    required this.validationGames,
    required this.testGames,
    required this.seed,
    required this.optimizerSeed,
    required this.workers,
    required this.profileName,
    required this.searchSpaceName,
    required this.searchSpace,
    required this.outputPath,
    required this.showHelp,
  });

  factory _Options.parse(List<String> arguments) {
    var population = 6;
    var generations = 2;
    var minimumTrainingGames = 1;
    var trainingGames = 1;
    var finalists = 2;
    var validationGames = 1;
    var testGames = 1;
    var seed = 1;
    var optimizerSeed = 20260903;
    var workers = 1;
    var profileName = 'optimized-v2';
    var searchSpaceName = 'standard';
    String? outputPath;
    var showHelp = false;

    for (var index = 0; index < arguments.length; index++) {
      final argument = arguments[index];
      switch (argument) {
        case '--population':
          population = int.parse(_nextValue(arguments, ++index, argument));
        case '--generations':
          generations = int.parse(_nextValue(arguments, ++index, argument));
        case '--min-training-games':
          minimumTrainingGames = int.parse(
            _nextValue(arguments, ++index, argument),
          );
        case '--training-games':
          trainingGames = int.parse(_nextValue(arguments, ++index, argument));
        case '--finalists':
          finalists = int.parse(_nextValue(arguments, ++index, argument));
        case '--validation-games':
          validationGames = int.parse(_nextValue(arguments, ++index, argument));
        case '--test-games':
          testGames = int.parse(_nextValue(arguments, ++index, argument));
        case '--seed':
          seed = int.parse(_nextValue(arguments, ++index, argument));
        case '--optimizer-seed':
          optimizerSeed = int.parse(_nextValue(arguments, ++index, argument));
        case '--workers':
          workers = int.parse(_nextValue(arguments, ++index, argument));
        case '--profile-name':
          profileName = _nextValue(arguments, ++index, argument);
        case '--search-space':
          searchSpaceName = _nextValue(arguments, ++index, argument);
        case '--output':
          outputPath = _nextValue(arguments, ++index, argument);
        case '--help' || '-h':
          showHelp = true;
        default:
          throw FormatException('Unknown argument: $argument');
      }
    }

    if (population < 2 ||
        generations <= 0 ||
        minimumTrainingGames <= 0 ||
        trainingGames < minimumTrainingGames ||
        finalists <= 0 ||
        finalists > population ||
        validationGames <= 0 ||
        testGames <= 0 ||
        workers <= 0) {
      throw FormatException(
        'Counts are invalid. Final training games must be at least the initial '
        'count, and finalists cannot exceed the population.',
      );
    }
    final searchSpace = _parseSearchSpace(searchSpaceName);
    return _Options(
      population: population,
      generations: generations,
      minimumTrainingGames: minimumTrainingGames,
      trainingGames: trainingGames,
      finalists: finalists,
      validationGames: validationGames,
      testGames: testGames,
      seed: seed,
      optimizerSeed: optimizerSeed,
      workers: workers,
      profileName: profileName,
      searchSpaceName: searchSpaceName,
      searchSpace: searchSpace,
      outputPath: outputPath,
      showHelp: showHelp,
    );
  }
}

AdvisorWeightSearchSpace _parseSearchSpace(String name) => switch (name) {
  'standard' => AdvisorWeightSearchSpace.standard,
  'wide' => AdvisorWeightSearchSpace.wide,
  _ => throw FormatException(
    'Unknown search space: $name. Expected standard or wide.',
  ),
};

String _nextValue(List<String> arguments, int index, String option) {
  if (index >= arguments.length) {
    throw FormatException('$option requires a value.');
  }
  return arguments[index];
}
