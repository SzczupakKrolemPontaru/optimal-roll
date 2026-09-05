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

  await Directory(options.outputDirectory).create(recursive: true);
  final optimizer = const AdvisorWeightOptimizer();
  final runner = const SimulationRunner();
  final exploratoryResults = <WeightOptimizationResult>[];

  print(
    'Running ${options.starts} exploratory starts; target mean: '
    '${options.targetMean.toStringAsFixed(0)}.',
  );
  for (var start = 0; start < options.starts; start++) {
    final profileName = '${options.profilePrefix}-start-${start + 1}';
    final seed = options.seed + start * options.seedStride;
    final optimizerSeed = options.optimizerSeed + start;
    print('');
    print(
      'Start ${start + 1}/${options.starts}: seed=$seed, '
      'optimizerSeed=$optimizerSeed',
    );
    final result = await optimizer.optimize(
      profileName: profileName,
      options: WeightOptimizerOptions(
        populationSize: options.population,
        generations: options.generations,
        minimumTrainingGames: options.minimumTrainingGames,
        trainingGames: options.trainingGames,
        validationCandidateCount: options.finalists,
        validationGames: options.validationGames,
        testGames: options.exploratoryTestGames,
        firstTrainingSeed: seed,
        firstValidationSeed: seed + 1000000,
        firstTestSeed: seed + 2000000,
        workers: options.workers,
        optimizerSeed: optimizerSeed,
        searchSpace: options.searchSpace,
      ),
      fastTraining: options.fastExploration,
      onProgress: (progress) {
        if (progress.candidateIndex != progress.populationSize) return;
        print(
          '  generation ${progress.generation}: '
          '${progress.meanScore.toStringAsFixed(2)} '
          '(${progress.trainingGames} games)',
        );
      },
    );
    exploratoryResults.add(result);
    final path = '${options.outputDirectory}/$profileName.json';
    await File(path).writeAsString(
      '${const JsonEncoder.withIndent('  ').convert(result.toJson())}\n',
    );
    print(
      '  validation diff: '
      '${_signed(result.validationComparison.scoreDifference.mean)} +/- '
      '${result.validationComparison.confidence95HalfWidth.toStringAsFixed(2)}',
    );
    print(
      '  quick-test diff: '
      '${_signed(result.testComparison.scoreDifference.mean)} +/- '
      '${result.testComparison.confidence95HalfWidth.toStringAsFixed(2)}',
    );
  }

  exploratoryResults.sort((left, right) {
    final validation = right.validationComparison.scoreDifference.mean
        .compareTo(left.validationComparison.scoreDifference.mean);
    if (validation != 0) return validation;
    return right.testComparison.scoreDifference.mean.compareTo(
      left.testComparison.scoreDifference.mean,
    );
  });
  final finalists = exploratoryResults.take(options.holdoutFinalists).toList();
  final holdoutBaseline = await runner.runParallel(
    strategy: const AdvisorGameStrategy(name: 'default-holdout-baseline'),
    gameCount: options.holdoutGames,
    firstSeed: options.holdoutSeed,
    workers: options.workers,
  );

  final holdout = <Map<String, Object>>[];
  for (var index = 0; index < finalists.length; index++) {
    final result = finalists[index];
    final report = await runner.runParallel(
      strategy: AdvisorGameStrategy.withWeights(
        name: '${result.profileName}-holdout',
        weights: result.bestCandidate.weights,
      ),
      gameCount: options.holdoutGames,
      firstSeed: options.holdoutSeed,
      workers: options.workers,
    );
    final comparison = StrategyComparison(
      candidate: report,
      baseline: holdoutBaseline,
    );
    holdout.add({
      'profileName': result.profileName,
      'weights': result.bestCandidate.toJson(),
      'report': report.toJson(),
      'comparison': comparison.toJson(),
      'searchSpaceBoundaryHits': options.searchSpace.boundaryHits(
        result.bestCandidate,
      ),
    });
    print('');
    print(
      'Holdout ${index + 1}/${finalists.length} ${result.profileName}: '
      'mean=${report.totalScore.mean.toStringAsFixed(2)}, '
      'diff=${_signed(comparison.scoreDifference.mean)} +/- '
      '${comparison.confidence95HalfWidth.toStringAsFixed(2)}',
    );
  }

  holdout.sort((left, right) {
    final leftComparison = left['comparison']! as Map<String, Object>;
    final rightComparison = right['comparison']! as Map<String, Object>;
    final leftDiff =
        ((leftComparison['scoreDifference']! as Map<String, Object>)['mean']!
                as num)
            .toDouble();
    final rightDiff =
        ((rightComparison['scoreDifference']! as Map<String, Object>)['mean']!
                as num)
            .toDouble();
    return rightDiff.compareTo(leftDiff);
  });

  final summary = {
    'profileVersion': 1,
    'profileName': options.profilePrefix,
    'targetMean': options.targetMean,
    'searchSpace': options.searchSpace.toJson(),
    'exploratoryStarts': exploratoryResults
        .map(
          (result) => {
            'profileName': result.profileName,
            'validationComparison': result.validationComparison.toJson(),
            'quickTestComparison': result.testComparison.toJson(),
            'weights': result.bestCandidate.toJson(),
          },
        )
        .toList(),
    'holdoutBaseline': holdoutBaseline.toJson(),
    'holdout': holdout,
  };
  final summaryPath =
      '${options.outputDirectory}/${options.profilePrefix}.json';
  await File(
    summaryPath,
  ).writeAsString('${const JsonEncoder.withIndent('  ').convert(summary)}\n');
  print('');
  print('Saved tuning summary to $summaryPath');
}

String _signed(double value) =>
    '${value >= 0 ? '+' : ''}${value.toStringAsFixed(2)}';

void _printHelp() {
  print('''
Run several short Advisor weight searches and compare their winners on one
shared holdout. This is faster for exploration than one large optimizer run.

Usage:
  dart run tool/tune_advisor_weights.dart [options]

Options:
  --starts <count>             Independent searches (default: 4)
  --population <count>         Candidates per search (default: 10)
  --generations <count>        Generations per search (default: 5)
  --min-training-games <n>     Games in first generation (default: 10)
  --training-games <count>     Games in final generation (default: 100)
  --finalists <count>          Finalists per search validation (default: 3)
  --validation-games <count>   Validation games per search (default: 200)
  --exploratory-test-games <n> Cheap test games per search (default: 30)
  --holdout-finalists <count>  Winners tested on shared holdout (default: 3)
  --holdout-games <count>      Shared holdout games (default: 1000)
  --seed <value>               First training seed (default: 14000000)
  --seed-stride <value>        Seed range spacing (default: 3000000)
  --holdout-seed <value>       Shared holdout seed (default: 50000000)
  --optimizer-seed <value>     First optimizer seed (default: 20260908)
  --workers <count>            Parallel game isolates (default: 8)
  --search-space <name>        standard or wide bounds (default: wide)
  --fast-exploration           Use the lightweight strategy during training
                               only; validation and holdout stay exact.
  --target-mean <score>        Reporting target (default: 1800)
  --profile-prefix <name>      Output profile prefix (default: advisor-tune)
  --output-dir <path>          Output directory (default: tool/results/tuning)
  --help                       Show this help
''');
}

class _Options {
  final int starts;
  final int population;
  final int generations;
  final int minimumTrainingGames;
  final int trainingGames;
  final int finalists;
  final int validationGames;
  final int exploratoryTestGames;
  final int holdoutFinalists;
  final int holdoutGames;
  final int seed;
  final int seedStride;
  final int holdoutSeed;
  final int optimizerSeed;
  final int workers;
  final AdvisorWeightSearchSpace searchSpace;
  final double targetMean;
  final String profilePrefix;
  final String outputDirectory;
  final bool showHelp;
  final bool fastExploration;

  const _Options({
    required this.starts,
    required this.population,
    required this.generations,
    required this.minimumTrainingGames,
    required this.trainingGames,
    required this.finalists,
    required this.validationGames,
    required this.exploratoryTestGames,
    required this.holdoutFinalists,
    required this.holdoutGames,
    required this.seed,
    required this.seedStride,
    required this.holdoutSeed,
    required this.optimizerSeed,
    required this.workers,
    required this.searchSpace,
    required this.targetMean,
    required this.profilePrefix,
    required this.outputDirectory,
    required this.showHelp,
    required this.fastExploration,
  });

  factory _Options.parse(List<String> arguments) {
    var starts = 4;
    var population = 10;
    var generations = 5;
    var minimumTrainingGames = 10;
    var trainingGames = 100;
    var finalists = 3;
    var validationGames = 200;
    var exploratoryTestGames = 30;
    var holdoutFinalists = 3;
    var holdoutGames = 1000;
    var seed = 14000000;
    var seedStride = 3000000;
    var holdoutSeed = 50000000;
    var optimizerSeed = 20260908;
    var workers = 8;
    var searchSpaceName = 'wide';
    var targetMean = 1800.0;
    var profilePrefix = 'advisor-tune';
    var outputDirectory = 'tool/results/tuning';
    var showHelp = false;
    var fastExploration = false;

    for (var index = 0; index < arguments.length; index++) {
      final argument = arguments[index];
      switch (argument) {
        case '--starts':
          starts = int.parse(_nextValue(arguments, ++index, argument));
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
        case '--exploratory-test-games':
          exploratoryTestGames = int.parse(
            _nextValue(arguments, ++index, argument),
          );
        case '--holdout-finalists':
          holdoutFinalists = int.parse(
            _nextValue(arguments, ++index, argument),
          );
        case '--holdout-games':
          holdoutGames = int.parse(_nextValue(arguments, ++index, argument));
        case '--seed':
          seed = int.parse(_nextValue(arguments, ++index, argument));
        case '--seed-stride':
          seedStride = int.parse(_nextValue(arguments, ++index, argument));
        case '--holdout-seed':
          holdoutSeed = int.parse(_nextValue(arguments, ++index, argument));
        case '--optimizer-seed':
          optimizerSeed = int.parse(_nextValue(arguments, ++index, argument));
        case '--workers':
          workers = int.parse(_nextValue(arguments, ++index, argument));
        case '--search-space':
          searchSpaceName = _nextValue(arguments, ++index, argument);
        case '--target-mean':
          targetMean = double.parse(_nextValue(arguments, ++index, argument));
        case '--profile-prefix':
          profilePrefix = _nextValue(arguments, ++index, argument);
        case '--output-dir':
          outputDirectory = _nextValue(arguments, ++index, argument);
        case '--help' || '-h':
          showHelp = true;
        case '--fast-exploration':
          fastExploration = true;
        default:
          throw FormatException('Unknown argument: $argument');
      }
    }
    if (starts <= 0 ||
        population < 2 ||
        generations <= 0 ||
        minimumTrainingGames <= 0 ||
        trainingGames < minimumTrainingGames ||
        finalists <= 0 ||
        finalists > population ||
        validationGames <= 0 ||
        exploratoryTestGames <= 0 ||
        holdoutFinalists <= 0 ||
        holdoutFinalists > starts ||
        holdoutGames <= 0 ||
        seedStride <= 0 ||
        workers <= 0) {
      throw const FormatException('Counts must be positive and consistent.');
    }
    return _Options(
      starts: starts,
      population: population,
      generations: generations,
      minimumTrainingGames: minimumTrainingGames,
      trainingGames: trainingGames,
      finalists: finalists,
      validationGames: validationGames,
      exploratoryTestGames: exploratoryTestGames,
      holdoutFinalists: holdoutFinalists,
      holdoutGames: holdoutGames,
      seed: seed,
      seedStride: seedStride,
      holdoutSeed: holdoutSeed,
      optimizerSeed: optimizerSeed,
      workers: workers,
      searchSpace: switch (searchSpaceName) {
        'standard' => AdvisorWeightSearchSpace.standard,
        'wide' => AdvisorWeightSearchSpace.wide,
        _ => throw FormatException(
          'Unknown search space: $searchSpaceName. Expected standard or wide.',
        ),
      },
      targetMean: targetMean,
      profilePrefix: profilePrefix,
      outputDirectory: outputDirectory,
      showHelp: showHelp,
      fastExploration: fastExploration,
    );
  }
}

String _nextValue(List<String> arguments, int index, String option) {
  if (index >= arguments.length) {
    throw FormatException('$option requires a value.');
  }
  return arguments[index];
}
