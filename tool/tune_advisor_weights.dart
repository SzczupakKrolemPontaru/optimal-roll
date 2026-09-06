// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';

import 'package:optimal_roll/domain/game_engine.dart';
import 'package:optimal_roll/simulation/simulation.dart';

Future<void> main(List<String> arguments) async {
  final options = _Options.parse(arguments);
  if (options.showHelp) {
    _printHelp();
    return;
  }

  if (options.sensitivitySweep) {
    await _runSensitivitySweep(options);
    return;
  }
  if (options.pairwiseSweep) {
    await _runPairwiseSweep(options);
    return;
  }

  await Directory(options.outputDirectory).create(recursive: true);
  final optimizer = const AdvisorWeightOptimizer();
  final runner = const SimulationRunner();
  final resumeCandidates = options.resumePath == null
      ? const <AdvisorWeightCandidate>[]
      : await _loadResumeCandidates(options.resumePath!);
  if (resumeCandidates.isNotEmpty) {
    print(
      'Loaded ${resumeCandidates.length} candidates from ${options.resumePath}.',
    );
  }
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
      initialCandidates: resumeCandidates,
      onProgress: (progress) {
        if (progress.candidateIndex != progress.populationSize) return;
        print(
          '  generation ${progress.generation}: '
          '${progress.meanScore.toStringAsFixed(2)} '
          '(${progress.trainingGames} games)',
        );
      },
    );
    final selectedResult = options.fastExploration
        ? await _exactlyRerankFastFinalists(
            result: result,
            runner: runner,
            games: options.exactTrainingGames,
            firstSeed: seed + 3000000,
            workers: options.workers,
          )
        : result;
    exploratoryResults.add(selectedResult);
    final path = '${options.outputDirectory}/$profileName.json';
    await File(path).writeAsString(
      '${const JsonEncoder.withIndent('  ').convert(selectedResult.toJson())}\n',
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

Future<List<AdvisorWeightCandidate>> _loadResumeCandidates(String path) async {
  final decoded = jsonDecode(await File(path).readAsString());
  final candidates = <AdvisorWeightCandidate>[];

  void visit(Object? node) {
    if (node is Map) {
      final weights = node['weights'];
      if (weights is Map && weights.containsKey('openingColumnValue')) {
        candidates.add(
          AdvisorWeightCandidate.fromJson(Map<String, dynamic>.from(weights)),
        );
      }
      for (final value in node.values) {
        visit(value);
      }
    } else if (node is List) {
      for (final value in node) {
        visit(value);
      }
    }
  }

  visit(decoded);
  final seen = <String>{};
  return [
    for (final candidate in candidates)
      if (seen.add(candidate.cacheKey)) candidate,
  ];
}

Future<WeightOptimizationResult> _exactlyRerankFastFinalists({
  required WeightOptimizationResult result,
  required SimulationRunner runner,
  required int games,
  required int firstSeed,
  required int workers,
}) async {
  final exactReports = <AdvisorWeightCandidate, SimulationReport>{};
  for (final finalist in result.validatedCandidates) {
    exactReports[finalist.candidate] = await runner.runParallel(
      strategy: AdvisorGameStrategy.withWeights(
        name: '${result.profileName}-exact-training',
        weights: finalist.candidate.weights,
      ),
      gameCount: games,
      firstSeed: firstSeed,
      workers: workers,
    );
  }
  final baseline = AdvisorWeightCandidate.defaults();
  if (!exactReports.containsKey(baseline)) {
    exactReports[baseline] = await runner.runParallel(
      strategy: const AdvisorGameStrategy(name: 'exact-training-baseline'),
      gameCount: games,
      firstSeed: firstSeed,
      workers: workers,
    );
  }
  if (exactReports.isEmpty) return result;
  final selected = exactReports.entries.reduce(
    (left, right) => left.value.totalScore.mean >= right.value.totalScore.mean
        ? left
        : right,
  );
  print(
    '  exact finalist rerank: '
    '${selected.value.totalScore.mean.toStringAsFixed(2)}',
  );
  final validation = await runner.runParallel(
    strategy: AdvisorGameStrategy.withWeights(
      name: '${result.profileName}-exact-validation',
      weights: selected.key.weights,
    ),
    gameCount: result.options.validationGames,
    firstSeed: result.options.firstValidationSeed,
    workers: workers,
  );
  final test = await runner.runParallel(
    strategy: AdvisorGameStrategy.withWeights(
      name: '${result.profileName}-exact-test',
      weights: selected.key.weights,
    ),
    gameCount: result.options.testGames,
    firstSeed: result.options.firstTestSeed,
    workers: workers,
  );
  return result.copyWithExactReports(
    candidate: selected.key,
    training: selected.value,
    validation: validation,
    test: test,
  );
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
  --exact-training-games <n>   Exact games for finalists after fast filter
                               (default: 300)
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
  --sensitivity-sweep          Sweep selected weights one at a time on shared seeds
  --pairwise-sweep             Sweep interactions between selected weight pairs
  --pairwise-games <count>     Games per pairwise candidate (default: 100)
  --pairwise-seed <value>      First seed for pairwise sweep (default: 101000000)
  --pairwise-output <path>     Pairwise output path
  --sweep-games <count>        Games per sensitivity candidate (default: 100)
  --sweep-seed <value>         First seed for sensitivity sweep (default: 95000000)
  --sweep-output <path>        Sensitivity output path
  --target-mean <score>        Reporting target (default: 1800)
  --profile-prefix <name>      Output profile prefix (default: advisor-tune)
  --output-dir <path>          Output directory (default: tool/results/tuning)
  --resume <path>               Seed the next run from a previous JSON result
  --help                       Show this help
''');
}

class _Options {
  final int starts;
  final int population;
  final int generations;
  final int minimumTrainingGames;
  final int trainingGames;
  final int exactTrainingGames;
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
  final String? resumePath;
  final bool showHelp;
  final bool fastExploration;
  final bool sensitivitySweep;
  final int sweepGames;
  final int sweepSeed;
  final String sweepOutput;
  final bool pairwiseSweep;
  final int pairwiseGames;
  final int pairwiseSeed;
  final String pairwiseOutput;

  const _Options({
    required this.starts,
    required this.population,
    required this.generations,
    required this.minimumTrainingGames,
    required this.trainingGames,
    required this.exactTrainingGames,
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
    required this.resumePath,
    required this.showHelp,
    required this.fastExploration,
    required this.sensitivitySweep,
    required this.sweepGames,
    required this.sweepSeed,
    required this.sweepOutput,
    required this.pairwiseSweep,
    required this.pairwiseGames,
    required this.pairwiseSeed,
    required this.pairwiseOutput,
  });

  factory _Options.parse(List<String> arguments) {
    var starts = 4;
    var population = 10;
    var generations = 5;
    var minimumTrainingGames = 10;
    var trainingGames = 100;
    var exactTrainingGames = 300;
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
    String? resumePath;
    var showHelp = false;
    var fastExploration = false;
    var sensitivitySweep = false;
    var sweepGames = 100;
    var sweepSeed = 95000000;
    var sweepOutput = 'tool/results/sensitivity-sweep.json';
    var pairwiseSweep = false;
    var pairwiseGames = 100;
    var pairwiseSeed = 101000000;
    var pairwiseOutput = 'tool/results/pairwise-sweep.json';

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
        case '--exact-training-games':
          exactTrainingGames = int.parse(
            _nextValue(arguments, ++index, argument),
          );
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
        case '--resume':
          resumePath = _nextValue(arguments, ++index, argument);
        case '--help' || '-h':
          showHelp = true;
        case '--fast-exploration':
          fastExploration = true;
        case '--sensitivity-sweep':
          sensitivitySweep = true;
        case '--sweep-games':
          sweepGames = int.parse(_nextValue(arguments, ++index, argument));
        case '--sweep-seed':
          sweepSeed = int.parse(_nextValue(arguments, ++index, argument));
        case '--sweep-output':
          sweepOutput = _nextValue(arguments, ++index, argument);
        case '--pairwise-sweep':
          pairwiseSweep = true;
        case '--pairwise-games':
          pairwiseGames = int.parse(_nextValue(arguments, ++index, argument));
        case '--pairwise-seed':
          pairwiseSeed = int.parse(_nextValue(arguments, ++index, argument));
        case '--pairwise-output':
          pairwiseOutput = _nextValue(arguments, ++index, argument);
        default:
          throw FormatException('Unknown argument: $argument');
      }
    }
    if (starts <= 0 ||
        population < 2 ||
        generations <= 0 ||
        minimumTrainingGames <= 0 ||
        trainingGames < minimumTrainingGames ||
        exactTrainingGames <= 0 ||
        finalists <= 0 ||
        finalists > population ||
        validationGames <= 0 ||
        exploratoryTestGames <= 0 ||
        holdoutFinalists <= 0 ||
        holdoutFinalists > starts ||
        holdoutGames <= 0 ||
        sweepGames <= 0 ||
        pairwiseGames <= 0 ||
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
      exactTrainingGames: exactTrainingGames,
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
      resumePath: resumePath,
      showHelp: showHelp,
      fastExploration: fastExploration,
      sensitivitySweep: sensitivitySweep,
      sweepGames: sweepGames,
      sweepSeed: sweepSeed,
      sweepOutput: sweepOutput,
      pairwiseSweep: pairwiseSweep,
      pairwiseGames: pairwiseGames,
      pairwiseSeed: pairwiseSeed,
      pairwiseOutput: pairwiseOutput,
    );
  }
}

Future<void> _runPairwiseSweep(_Options options) async {
  final runner = const SimulationRunner();
  final baseline = AdvisorWeightCandidate.defaults();
  final baselineReport = await runner.runParallel(
    strategy: AdvisorGameStrategy.withWeights(
      name: 'pairwise-baseline',
      weights: baseline.weights,
    ),
    gameCount: options.pairwiseGames,
    firstSeed: options.pairwiseSeed,
    workers: options.workers,
  );
  final figureRelativeValues = [.75, 1.0, 1.25];
  final schoolValues = [0.0, 2.0, 5.0, 10.0];
  final pairs = [
    (Figure.PAIR, Figure.GREAT_STRAIGHT),
    (Figure.PAIR, Figure.CHANCE),
    (Figure.MARSHAL, Figure.GREAT_STRAIGHT),
  ];
  final results = <Map<String, Object>>[];
  for (final pair in pairs) {
    final leftBase =
        baseline.figureOpportunityCosts[_pijolGroupForFigure(pair.$1)] ?? 0;
    final rightBase =
        baseline.figureOpportunityCosts[_pijolGroupForFigure(pair.$2)] ?? 0;
    for (final leftMultiplier in figureRelativeValues) {
      for (final rightMultiplier in figureRelativeValues) {
        final candidate = _copyCandidate(
          baseline,
          figureSpecificOpportunityCosts: {
            pair.$1: leftBase * leftMultiplier,
            pair.$2: rightBase * rightMultiplier,
          },
        );
        final report = await runner.runParallel(
          strategy: AdvisorGameStrategy.withWeights(
            name: 'pairwise-${pair.$1.name}-${pair.$2.name}',
            weights: candidate.weights,
          ),
          gameCount: options.pairwiseGames,
          firstSeed: options.pairwiseSeed,
          workers: options.workers,
        );
        final comparison = StrategyComparison(
          candidate: report,
          baseline: baselineReport,
        );
        results.add({
          'parameters': '${pair.$1.name} x ${pair.$2.name}',
          'values': {
            pair.$1.name: leftBase * leftMultiplier,
            pair.$2.name: rightBase * rightMultiplier,
          },
          'comparison': comparison.toJson(),
          'weights': candidate.toJson(),
        });
      }
    }
  }
  for (final figureMultiplier in figureRelativeValues) {
    for (final schoolValue in schoolValues) {
      final candidate = _copyCandidate(
        baseline,
        figureSpecificOpportunityCosts: {
          Figure.PAIR:
              (baseline.figureOpportunityCosts[PijolFigureGroup.basic] ?? 0) *
              figureMultiplier,
        },
        schoolFaceOpportunityCosts: {6: schoolValue},
      );
      final report = await runner.runParallel(
        strategy: AdvisorGameStrategy.withWeights(
          name: 'pairwise-pair-school6',
          weights: candidate.weights,
        ),
        gameCount: options.pairwiseGames,
        firstSeed: options.pairwiseSeed,
        workers: options.workers,
      );
      final comparison = StrategyComparison(
        candidate: report,
        baseline: baselineReport,
      );
      results.add({
        'parameters': 'PAIR x school[6]',
        'values': {
          'PAIR':
              (baseline.figureOpportunityCosts[PijolFigureGroup.basic] ?? 0) *
              figureMultiplier,
          'school[6]': schoolValue,
        },
        'comparison': comparison.toJson(),
        'weights': candidate.toJson(),
      });
    }
  }
  // The school target term changes the trade-off between school bonus and
  // figure score. Test it together with the existing progress term; sweeping
  // either scalar in isolation misses this interaction.
  for (final targetWeight in [0.0, 2.0, 5.0, 10.0, 20.0]) {
    for (final progressWeight in [0.0, 2.0, 4.0, 8.0]) {
      final candidate = _copyCandidate(
        baseline,
        scalarOverrides: {
          'schoolBonusTargetWeight': targetWeight,
          'schoolBonusProgressWeight': progressWeight,
        },
      );
      final report = await runner.runParallel(
        strategy: AdvisorGameStrategy.withWeights(
          name: 'pairwise-school-target-progress',
          weights: candidate.weights,
        ),
        gameCount: options.pairwiseGames,
        firstSeed: options.pairwiseSeed,
        workers: options.workers,
      );
      final comparison = StrategyComparison(
        candidate: report,
        baseline: baselineReport,
      );
      results.add({
        'parameters': 'schoolBonusTargetWeight x schoolBonusProgressWeight',
        'values': {
          'schoolBonusTargetWeight': targetWeight,
          'schoolBonusProgressWeight': progressWeight,
        },
        'comparison': comparison.toJson(),
        'weights': candidate.toJson(),
      });
    }
  }
  results.sort((left, right) {
    final leftDiff =
        (((left['comparison']! as Map)['scoreDifference'] as Map)['mean']
                as num)
            .toDouble();
    final rightDiff =
        (((right['comparison']! as Map)['scoreDifference'] as Map)['mean']
                as num)
            .toDouble();
    return rightDiff.compareTo(leftDiff);
  });
  final file = File(options.pairwiseOutput);
  await file.parent.create(recursive: true);
  await file.writeAsString(
    '${const JsonEncoder.withIndent('  ').convert({'baseline': baselineReport.toJson(), 'games': options.pairwiseGames, 'seed': options.pairwiseSeed, 'results': results})}\n',
  );
  print('Saved pairwise sweep to ${options.pairwiseOutput}');
  for (final result in results.take(10)) {
    final comparison = result['comparison']! as Map;
    print(
      '${result['parameters']} ${result['values']}: diff=${(comparison['scoreDifference'] as Map)['mean']}',
    );
  }
}

Future<void> _runSensitivitySweep(_Options options) async {
  final runner = const SimulationRunner();
  final baseline = AdvisorWeightCandidate.defaults();
  final baselineReport = await runner.runParallel(
    strategy: AdvisorGameStrategy.withWeights(
      name: 'sensitivity-baseline',
      weights: baseline.weights,
    ),
    gameCount: options.sweepGames,
    firstSeed: options.sweepSeed,
    workers: options.workers,
  );
  final relativeValues = [0.5, 0.75, 1.0, 1.25, 1.5];
  final schoolValues = [0.0, 2.0, 5.0, 10.0, 20.0];
  final figures = [
    Figure.PAIR,
    Figure.MARSHAL,
    Figure.GREAT_STRAIGHT,
    Figure.CHANCE,
    Figure.SMALL,
  ];
  final candidates = <Map<String, Object>>[];
  for (final figure in figures) {
    final baseValue =
        baseline.figureOpportunityCosts[_pijolGroupForFigure(figure)] ?? 0;
    for (final multiplier in relativeValues) {
      final value = baseValue * multiplier;
      final candidate = _copyCandidate(
        baseline,
        figureSpecificOpportunityCosts: {figure: value},
      );
      final report = await runner.runParallel(
        strategy: AdvisorGameStrategy.withWeights(
          name: 'sweep-${figure.name}-$value',
          weights: candidate.weights,
        ),
        gameCount: options.sweepGames,
        firstSeed: options.sweepSeed,
        workers: options.workers,
      );
      final comparison = StrategyComparison(
        candidate: report,
        baseline: baselineReport,
      );
      candidates.add({
        'parameter': 'figureSpecificOpportunityCosts.${figure.name}',
        'value': value,
        'relativeToProduction': multiplier,
        'report': report.toJson(),
        'comparison': comparison.toJson(),
        'weights': candidate.toJson(),
      });
    }
  }
  for (final face in [MIN_DIE_VALUE, MAX_DIE_VALUE]) {
    for (final value in schoolValues) {
      final candidate = _copyCandidate(
        baseline,
        schoolFaceOpportunityCosts: {face: value},
      );
      final report = await runner.runParallel(
        strategy: AdvisorGameStrategy.withWeights(
          name: 'sweep-school-$face-$value',
          weights: candidate.weights,
        ),
        gameCount: options.sweepGames,
        firstSeed: options.sweepSeed,
        workers: options.workers,
      );
      final comparison = StrategyComparison(
        candidate: report,
        baseline: baselineReport,
      );
      candidates.add({
        'parameter': 'schoolFaceOpportunityCosts.$face',
        'value': value,
        'report': report.toJson(),
        'comparison': comparison.toJson(),
        'weights': candidate.toJson(),
      });
    }
  }
  final scalarSweeps = <String, List<double>>{
    'pijolBaseCost': [0, 5, 15, 30, 50],
    'perfectColumnRiskCost': [30, 60, 90, 120, 150],
    'perfectColumnProgressWeight': [0, 5, 10, 20, 30],
    'schoolBonusProgressWeight': [2, 4, 8, 12, 16],
    'futureFieldValueWeight': [.01, .03, .05, .1, .2],
    'schoolPointWeight': [.05, .1, .2, .4, .8],
    'schoolNegativePenaltyWeight': [.25, .5, 1, 2, 4],
    'figureCompletionValueWeight': [2, 5, 10, 20, 40],
    'rareFigureChaseWeight': [2, 5, 10, 20, 40],
    'straightChaseWeight': [2, 5, 10, 20, 40],
    'schoolBonusTargetWeight': [1, 2, 5, 10, 20],
    'rerollValueWeight': [0, .1, .25, .5, 1, 2],
    'rerollLowScoreWeight': [0, .5, 1, 2, 5, 10],
    'openingColumnValue': [20, 36.64490059669705, 50, 70],
    'chanceCostEarly': [20, 32.385866293107256, 50, 70],
    'chanceCostLate': [10, 27.4009005750395, 40, 55],
  };
  for (final entry in scalarSweeps.entries) {
    for (final value in entry.value) {
      final candidate = _copyCandidate(
        baseline,
        scalarOverrides: {entry.key: value},
      );
      final report = await runner.runParallel(
        strategy: AdvisorGameStrategy.withWeights(
          name: 'sweep-${entry.key}-$value',
          weights: candidate.weights,
        ),
        gameCount: options.sweepGames,
        firstSeed: options.sweepSeed,
        workers: options.workers,
      );
      final comparison = StrategyComparison(
        candidate: report,
        baseline: baselineReport,
      );
      candidates.add({
        'parameter': entry.key,
        'value': value,
        'report': report.toJson(),
        'comparison': comparison.toJson(),
        'weights': candidate.toJson(),
      });
    }
  }
  candidates.sort((left, right) {
    final leftDiff =
        (((left['comparison']! as Map)['scoreDifference'] as Map)['mean']
                as num)
            .toDouble();
    final rightDiff =
        (((right['comparison']! as Map)['scoreDifference'] as Map)['mean']
                as num)
            .toDouble();
    return rightDiff.compareTo(leftDiff);
  });
  final file = File(options.sweepOutput);
  await file.parent.create(recursive: true);
  await file.writeAsString(
    '${const JsonEncoder.withIndent('  ').convert({'baseline': baselineReport.toJson(), 'games': options.sweepGames, 'seed': options.sweepSeed, 'candidates': candidates})}\n',
  );
  print('Saved sensitivity sweep to ${options.sweepOutput}');
  for (final candidate in candidates.take(10)) {
    final comparison = candidate['comparison']! as Map;
    final difference = (comparison['scoreDifference'] as Map)['mean'];
    print('${candidate['parameter']}=${candidate['value']}: diff=$difference');
  }
}

PijolFigureGroup _pijolGroupForFigure(Figure figure) => switch (figure) {
  Figure.PAIR ||
  Figure.TWO_PAIRS ||
  Figure.THREE_OF_A_KIND ||
  Figure.FOUR_OF_A_KIND => PijolFigureGroup.basic,
  Figure.GENERAL || Figure.MARSHAL => PijolFigureGroup.rare,
  Figure.THREE_PAIRS ||
  Figure.TWO_TRIPLES ||
  Figure.FOUR_PLUS_TWO ||
  Figure.FULL_HOUSE => PijolFigureGroup.compound,
  Figure.SMALL_STRAIGHT ||
  Figure.BIG_STRAIGHT ||
  Figure.GREAT_STRAIGHT => PijolFigureGroup.straight,
  Figure.EVEN || Figure.ODD => PijolFigureGroup.parity,
  Figure.SMALL => PijolFigureGroup.small,
  Figure.CHANCE => PijolFigureGroup.chance,
};

AdvisorWeightCandidate _copyCandidate(
  AdvisorWeightCandidate source, {
  Map<Figure, double>? figureSpecificOpportunityCosts,
  Map<int, double>? schoolFaceOpportunityCosts,
  Map<String, double>? scalarOverrides,
}) => AdvisorWeightCandidate(
  openingColumnValue:
      scalarOverrides?['openingColumnValue'] ?? source.openingColumnValue,
  chanceCostEarly:
      scalarOverrides?['chanceCostEarly'] ?? source.chanceCostEarly,
  chanceCostLate: scalarOverrides?['chanceCostLate'] ?? source.chanceCostLate,
  rerollValueWeight:
      scalarOverrides?['rerollValueWeight'] ?? source.rerollValueWeight,
  rerollLowScoreWeight:
      scalarOverrides?['rerollLowScoreWeight'] ?? source.rerollLowScoreWeight,
  pijolBaseCost: scalarOverrides?['pijolBaseCost'] ?? source.pijolBaseCost,
  perfectColumnRiskCost:
      scalarOverrides?['perfectColumnRiskCost'] ?? source.perfectColumnRiskCost,
  perfectColumnProgressWeight:
      scalarOverrides?['perfectColumnProgressWeight'] ??
      source.perfectColumnProgressWeight,
  schoolBonusProgressWeight:
      scalarOverrides?['schoolBonusProgressWeight'] ??
      source.schoolBonusProgressWeight,
  schoolCompletionValue:
      scalarOverrides?['schoolCompletionValue'] ?? source.schoolCompletionValue,
  futureFieldValueWeight:
      scalarOverrides?['futureFieldValueWeight'] ??
      source.futureFieldValueWeight,
  schoolPointWeight:
      scalarOverrides?['schoolPointWeight'] ?? source.schoolPointWeight,
  schoolNegativePenaltyWeight:
      scalarOverrides?['schoolNegativePenaltyWeight'] ??
      source.schoolNegativePenaltyWeight,
  figureCompletionValueWeight:
      scalarOverrides?['figureCompletionValueWeight'] ??
      source.figureCompletionValueWeight,
  rareFigureChaseWeight:
      scalarOverrides?['rareFigureChaseWeight'] ?? source.rareFigureChaseWeight,
  straightChaseWeight:
      scalarOverrides?['straightChaseWeight'] ?? source.straightChaseWeight,
  schoolBonusTargetWeight:
      scalarOverrides?['schoolBonusTargetWeight'] ??
      source.schoolBonusTargetWeight,
  earlyGameRiskMultiplier: source.earlyGameRiskMultiplier,
  middleGameRiskMultiplier: source.middleGameRiskMultiplier,
  lateGameRiskMultiplier: source.lateGameRiskMultiplier,
  pijolScarcityWeight: source.pijolScarcityWeight,
  figureOpportunityCosts: source.figureOpportunityCosts,
  figureSpecificOpportunityCosts:
      figureSpecificOpportunityCosts ?? source.figureSpecificOpportunityCosts,
  schoolFaceOpportunityCosts:
      schoolFaceOpportunityCosts ?? source.schoolFaceOpportunityCosts,
  schoolOpeningFaceCosts: source.schoolOpeningFaceCosts,
  pijolGroupCosts: source.pijolGroupCosts,
);

String _nextValue(List<String> arguments, int index, String option) {
  if (index >= arguments.length) {
    throw FormatException('$option requires a value.');
  }
  return arguments[index];
}
