import 'dart:math' show max;

import '../domain/game_engine.dart';
import 'advisor_action.dart';

/// Compact feature model for an already-scored game state.
///
/// The coefficients are deliberately kept separate from the advisor weights:
/// they are trained offline from complete games and only evaluated during a
/// decision. A zero model is equivalent to not using state-value guidance.
class StateValueModel {
  final List<double> coefficients;
  final double intercept;

  const StateValueModel({required this.coefficients, this.intercept = 0});

  const StateValueModel.zero()
    : coefficients = const [0, 0, 0, 0, 0, 0],
      intercept = 0;

  /// Coefficients trained by [tool/train_state_value_model.dart] on 500
  /// complete games. Keep the model opt-in until it proves useful on holdout
  /// seeds.
  static const trained = StateValueModel(
    coefficients: [
      272.04692434069887,
      374.7658742964312,
      261.34179042104324,
      507.10197667141887,
      87.6448686946794,
      261.5601404185311,
    ],
    intercept: 636.1076647174679,
  );

  double evaluate(GameState game) {
    final features = stateValueFeatures(game);
    var value = intercept;
    for (var index = 0; index < features.length; index++) {
      value += coefficients[index] * features[index];
    }
    return value;
  }
}

/// Offline action-value model. The label is the final game score obtained
/// after taking a concrete legal option from a concrete state.
class ActionValueModel {
  final List<double> coefficients;
  final double intercept;

  const ActionValueModel({required this.coefficients, this.intercept = 0});

  static const zero = ActionValueModel(
    coefficients: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
  );

  static const trained200 = ActionValueModel(
    coefficients: [
      0,
      0,
      387.99501457356763,
      387.99501457356763,
      0,
      387.99501457356763,
      12.498783845085567,
      0,
      46.31947268585821,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
    ],
    intercept: 387.99501457356763,
  );

  double evaluate(GameState game, ScoringOption option) {
    final features = stateActionFeatures(game, option);
    var value = intercept;
    for (var index = 0; index < features.length; index++) {
      value += coefficients[index] * features[index];
    }
    return value;
  }
}

class RichActionValueModel {
  final List<double> coefficients;
  final double intercept;

  const RichActionValueModel({required this.coefficients, this.intercept = 0});

  double evaluate(GameState game, ScoringOption option) {
    final features = richStateActionFeatures(game, option);
    var value = intercept;
    for (var index = 0; index < features.length; index++) {
      value += coefficients[index] * features[index];
    }
    return value;
  }
}

class PhasedRichActionValueModel {
  final RichActionValueModel early;
  final RichActionValueModel middle;
  final RichActionValueModel late;

  const PhasedRichActionValueModel({
    required this.early,
    required this.middle,
    required this.late,
  });

  RichActionValueModel forState(GameState game) {
    final progress = stateValueFeatures(game)[1];
    if (progress < 1 / 3) return early;
    if (progress < 2 / 3) return middle;
    return late;
  }

  double evaluate(GameState game, ScoringOption option) =>
      forState(game).evaluate(game, option);

  static const trainedRich60 = PhasedRichActionValueModel(
    early: RichActionValueModel(
      coefficients: [
        0, 0, 0, 0, 0, 0, 0, 0, 0, 1901.675300334796, 0, 0, 0,
        .691998560626444, 10.266626261366202, -10.95862482196409, 0, 0, 0,
        0, 18.079045153920216, -32.897680708689556, 79.92067403814274,
        -71.35793583936085, 41.476411794234004, -35.220514438109795, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      ],
    ),
    middle: RichActionValueModel(
      coefficients: [
        0, 0, 0, 0, 0, 0, 0, 0, 0, 158.72980165207224,
        18.525998618773208, -17.533328060311934, -.9926705584639604,
        -45.819598360015675, 20.067872065330878, 25.75172629456954,
        -57.43536452637857, -3.7929258639996797, -.9926705584639767,
        18.525998618770636, 34.05660503117343, -9.30527193463785,
        23.98006220464018, -16.095774152836878, -117.52588963444765,
        103.41626710493497, -4.11653843695594, 36.44249232505145,
        14.620757855590659, -55.97992345529527, 0, 0, -.9926705584640049,
        131.13273289454168, -9.474373362491027, 0, 0, 0, 0,
        -114.86894650423662, -11.496603512630383, 0, -3.792925864004361,
        -2.007823876510731, 0, -99.20528110808613, 42.02887411870953,
        -.25895753699050506,
      ],
    ),
    late: RichActionValueModel(
      coefficients: [
        0, 0, 0, 0, 0, 0, 0, 0, 0, -304.8509057303666,
        20.214075710157843, 75.762488417118, -95.97656412728377,
        42.65029297655801, -24.801043829588625, -17.84924914699081,
        228.43351360849897, -17.193628096082392, -95.97656412728377,
        20.214075710112283, 50.612242316932786, -73.82020459493904, 0,
        43.422037988200174, 0, 0, -89.66972003486632, 0,
        -79.04552832122734, 0, -25.291912482162402, 22.766961601666537,
        -12.439569519492423, 41.65454156392196, 43.87340522668164, 0,
        -14.179816558819583, 0, 0, 0, 62.99601072591539,
        46.31518018425785, -17.19362809607988, 21.35537429572442,
        -14.17981655881957, -92.55856638215481, 42.77116225057709,
        278.2209177400916,
      ],
    ),
  );

  static const trainedRich300 = PhasedRichActionValueModel(
    early: RichActionValueModel(
      coefficients: [
        0, 0, 0, 0, 0, 0, 0, 0, 0, 368.9790150168302, 0, 0, 0,
        -5.290276183919139, 3.1148583112963666, 2.175417873290963, 0, 0,
        0, 0, 11.983157356052674, -28.725968407751868, 10.585286064660904,
        27.459974619908316, 14.787180348096612, -36.08962998133375, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      ],
    ),
    middle: RichActionValueModel(
      coefficients: [
        0, 0, 0, 0, 0, 0, 0, 0, 0, 14.639338301499782,
        6.577107246448408, 21.726903693787037, -28.304010940214155,
        10.196675705510954, 3.051762384012635, -13.248438090050051,
        35.099273686593385, -9.182137662186852, -28.304010940168528,
        6.577107246470553, -1.9172969083743656, -15.233486044407014,
        -12.362082750241465, -15.096945878922137, 3.3970116353709634,
        47.78990719346612, 1.7308327862067068, .9288718753576306,
        11.455212974383999, -20.894964081241895, -17.676245511801756, 0,
        41.354890918214394, 128.70724465182224, -66.23210007289501,
        17.239064615267115, -40.238703983390735, 91.18245427961169,
        -29.921229674643246, -100.14884619474401, -14.881452167250556, 0,
        -9.18213766221882, 13.25336173114672, 68.18281491144636,
        14.585747857696227, 27.897180856489083, -7.383655027877814,
      ],
    ),
    late: RichActionValueModel(
      coefficients: [
        0, 0, 0, 0, 0, 0, 0, 0, 0, 80.06720340768874,
        10.514091132181674, 2.195566397943, -12.709657530759586,
        -11.224018966072391, -3.821850677641571, 15.045869643652711,
        -7.802740686970279, -8.500409819040497, -12.709657530759577,
        10.514091132116171, 13.231295308147164, -2.176625643623179,
        -2.45324018297103, 11.333376986867687, -13.632234777929947,
        4.211519441807586, -5.471401758523922, -10.674782394850219,
        -28.55722277631017, 5.738231219941053, -8.007665212397917,
        11.642044852803288, 23.21538530781622, 36.31452660850317,
        28.870100426526808, -96.02854167398921, 46.462128050459036,
        -19.237636023982148, 0, -26.033227172846974, -16.306452873407398,
        56.060832106973, -8.500409819027267, 4.921228307909687,
        -68.8040496474628, -26.433968027134686, 5.926121091019696,
        12.7051062488128,
      ],
    ),
  );
}

class PhasedActionValueModel {
  final ActionValueModel early;
  final ActionValueModel middle;
  final ActionValueModel late;

  const PhasedActionValueModel({
    required this.early,
    required this.middle,
    required this.late,
  });

  ActionValueModel forState(GameState game) {
    final progress = stateValueFeatures(game)[1];
    if (progress < 1 / 3) return early;
    if (progress < 2 / 3) return middle;
    return late;
  }

  double evaluate(GameState game, ScoringOption option) =>
      forState(game).evaluate(game, option);

  static const trained200 = PhasedActionValueModel(
    early: ActionValueModel.trained200,
    middle: ActionValueModel.trained200,
    late: ActionValueModel.trained200,
  );

  static const trainedPhased500 = PhasedActionValueModel(
    early: ActionValueModel(
      intercept: 321.324497017062,
      coefficients: [
        0,
        0,
        321.324497017062,
        321.324497017062,
        0,
        321.324497017062,
        -2.591292171856874,
        0,
        23.053734811814493,
        0,
        0,
        0,
        321.324497017062,
        73.23127358487851,
        0,
        0,
        0,
      ],
    ),
    middle: ActionValueModel(
      intercept: 465.87151920872356,
      coefficients: [
        186.28657946295425,
        155.29050640290822,
        310.5810128058165,
        465.87151920872356,
        2.0768738949698133,
        308.6293896412724,
        80.78261682159174,
        168.96982946776436,
        42.99385166097847,
        63.03684838655718,
        -34.841863149330685,
        -63.380720563463925,
        64.5511397097302,
        30.148407357684622,
        -11.670473600551587,
        31.917184012601115,
        38.60625512197124,
      ],
    ),
    late: ActionValueModel(
      intercept: 456.232023566676,
      coefficients: [
        374.59686323648424,
        304.1546823777853,
        152.07734118889272,
        488.14089688017674,
        170.85536060664674,
        150.15496424657624,
        96.18603585533513,
        162.62423730853587,
        38.08129518325538,
        152.8028056061646,
        37.663903785109156,
        -82.28258555733699,
        48.70096339226835,
        29.743206763855348,
        2.607044073263298,
        -35.58786722506739,
        -24.833430388758273,
      ],
    ),
  );

  /*
  static const trainedRank50 = PhasedActionValueModel(
    early: ActionValueModel(
      coefficients: [
        0,
        0,
        0,
        0,
        0,
        0,
        .06319394976547729,
        0,
        -.23921460040411566,
        0,
        0,
        0,
        0,
        -.10533929171474296,
        0,
        0,
        0,
      ],
    ),
    middle: ActionValueModel(
      coefficients: [
        0,
        0,
        0,
        0,
        0,
        0,
        .28665919326816425,
        -.09136925144518296,
        .0984023291566554,
        .05345911432729952,
        .532739724378162,
        -.3928647890124259,
        -.21012628612206005,
        -.11523171759092944,
        .42575133174531216,
        -.054396902107439395,
        -.04737632537144432,
      ],
    ),
    late: ActionValueModel(
      coefficients: [
        0,
        0,
        0,
        0,
        0,
        0,
        .2561908560356086,
        -.24066605103024694,
        -.06014137492222702,
        -.02557478928023655,
        .3181819361980482,
        -.6118095394419465,
        -.13047743738145312,
        -.04002875761278923,
        -.054339390134511625,
        -.14183907176970192,
        -.10925316872925832,
      ],
    ),
  );
  */

  static const trainedRankClose50 = PhasedActionValueModel(
    early: ActionValueModel(
      coefficients: [
        0,
        0,
        0,
        0,
        0,
        0,
        .060453544246440824,
        0,
        -.08512219974909294,
        0,
        0,
        0,
        0,
        -.16865314435205275,
        0,
        0,
        0,
      ],
    ),
    middle: ActionValueModel(
      coefficients: [
        0,
        0,
        0,
        0,
        0,
        0,
        .2852777211912171,
        .18719608943425975,
        -.026846325769102876,
        .0011054522537646211,
        -.028945945346261007,
        0,
        -.3743921788685195,
        -.11211781994976179,
        .2999396980479002,
        .12652484875591144,
        .21841020070580824,
      ],
    ),
    late: ActionValueModel(
      coefficients: [
        0,
        0,
        0,
        0,
        0,
        0,
        .25594059326555313,
        -.2532354392361336,
        -.20476011953123155,
        -.034231733864101554,
        .12531439606269254,
        -.6325906195334191,
        -.12611974106115215,
        -.025531294393013947,
        -.050596312527913,
        -.13046947453655966,
        .07804179968686586,
      ],
    ),
  );

  static const trainedRankBalanced60 = PhasedActionValueModel(
    early: ActionValueModel(
      coefficients: [
        0,
        0,
        0,
        0,
        0,
        0,
        .02000501410798467,
        0,
        -.05629051121637521,
        0,
        0,
        0,
        0,
        .05678562041379607,
        0,
        0,
        0,
      ],
    ),
    middle: ActionValueModel(
      coefficients: [
        0,
        0,
        0,
        0,
        0,
        0,
        .15476973288857615,
        .030239067639994954,
        -.016673126253171643,
        .004907679370737538,
        .1919326417448599,
        -.05779644340936751,
        -.11827457868935742,
        .0029050120211142998,
        .17352001994283253,
        .03651669909011112,
        0,
      ],
    ),
    late: ActionValueModel(
      coefficients: [
        0,
        0,
        0,
        0,
        0,
        0,
        .12197183238738082,
        -.19898068302642025,
        -.09705084559585485,
        -.0263638311740043,
        .11537363155326044,
        -.4255863994875271,
        -.027625033434686502,
        -.0031201579756978603,
        -.0022144098923106157,
        -.04105885879869095,
        .03555180332982174,
      ],
    ),
  );

  static const trainedRankBalanced120 = PhasedActionValueModel(
    early: ActionValueModel(
      coefficients: [
        0,
        0,
        0,
        0,
        0,
        0,
        .04611562702090097,
        0,
        -.07411854326664244,
        0,
        0,
        0,
        0,
        .07255517556472788,
        0,
        0,
        0,
      ],
    ),
    middle: ActionValueModel(
      coefficients: [
        0,
        0,
        0,
        0,
        0,
        0,
        .24439134685225491,
        .09321783103099007,
        -.0951995921184482,
        -.030413744171095294,
        -.06602429938625468,
        -.05779644340936751,
        -.24423210547134772,
        -.063139000111529,
        .04729161395705578,
        .07236567247300674,
        .12271918858787681,
      ],
    ),
    late: ActionValueModel(
      coefficients: [
        0,
        0,
        0,
        0,
        0,
        0,
        .22680095617288085,
        -.222688964409439,
        -.2753220898102059,
        -.08725886981163936,
        .283904060333505,
        -.5985433204350903,
        -.15316539161621193,
        -.05837907991716984,
        .09671006099094646,
        -.06407608660844144,
        .0554008585481216,
      ],
    ),
  );

  static const trainedRankBalanced300 = PhasedActionValueModel(
    early: ActionValueModel(
      coefficients: [
        0,
        0,
        0,
        0,
        0,
        0,
        .12415174602463311,
        0,
        -.11450530947515998,
        0,
        0,
        0,
        0,
        -.10969260333784592,
        0,
        0,
        0,
      ],
    ),
    middle: ActionValueModel(
      coefficients: [
        0,
        0,
        0,
        0,
        0,
        0,
        .543803409400674,
        .15222222141043523,
        -.11242992886365621,
        .002757908883313169,
        -.03179041987720404,
        -.12580803817650732,
        -.43025248099737806,
        -.18402940362837955,
        .2949632289274933,
        .207906793181191,
        .3687531910237194,
      ],
    ),
    late: ActionValueModel(
      coefficients: [
        0,
        0,
        0,
        0,
        0,
        0,
        .39125727811139954,
        -.3420535068993981,
        -.32502008894116563,
        -.05312008811036761,
        .29941988827052624,
        -.9333116881401212,
        -.24920467434132512,
        -.16278187575538017,
        .21492179613316423,
        -.13088345709352975,
        .058332963729858515,
      ],
    ),
  );

  static const trainedRidge100 = PhasedActionValueModel(
    early: ActionValueModel(
      coefficients: [
        0, 0, 0, 0, 0, 0, 186.28995316945034, 0, 17.374522553766614, 0,
        0, 0, 0, -27.710050765065493, 0, 0, 0,
      ],
    ),
    middle: ActionValueModel(
      coefficients: [
        0, 0, 0, 0, 0, 0, 49.171355253384604, -2.08306312424623,
        32.93685867416697, -4.1617901692162995, -22.34692743089608,
        30.921774117657172, 35.087900366161165, -129.5189265822503,
        26.166227457073056, -153.9791321685132, 21.345882072102384,
      ],
    ),
    late: ActionValueModel(
      coefficients: [
        0, 0, 0, 0, 0, 0, 99.47724099884073, 6.6307687343201795,
        -105.07616019451373, 328.45521964165425, 12.050829753298023,
        2.137608140747159, -11.123929327937073, 168.66890348704595,
        .8030391603161443, .7416849486030318, -13.125877731321248,
      ],
    ),
  );

  static const trainedRidge300 = PhasedActionValueModel(
    early: ActionValueModel(
      coefficients: [
        0, 0, 0, 0, 0, 0, 861.2199111219036, 0, 3.9563336076366467, 0,
        0, 0, 0, -7.216577883963683, 0, 0, 0,
      ],
    ),
    middle: ActionValueModel(
      coefficients: [
        0, 0, 0, 0, 0, 0, 103.07428272335241, -9.963829987453092,
        7.896054438239987, 26.67139654096107, .4581781382172103,
        30.32734857282152, 50.255008547908226, -66.59683031182199,
        -27.53675317626958, 45.8076304174973, 45.37468277748099,
      ],
    ),
    late: ActionValueModel(
      coefficients: [
        0, 0, 0, 0, 0, 0, 177.50645144860354, 1.6233744610377747,
        73.55977385668376, -88.3877191843577, -43.39658167895494,
        7.156751707827157, 3.9100027861460185, 14.21515395506214,
        11.392441014279285, 12.990501753129603, -88.41605328216403,
      ],
    ),
  );

  static const trainedPolicyRidge100 = PhasedActionValueModel(
    early: ActionValueModel(
      coefficients: [
        0, 0, 0, 0, 0, 0, 1504.754390848954, 0, -3.6269129966258356, 0,
        0, 0, 0, -1.3485066724221983, 0, 0, 0,
      ],
    ),
    middle: ActionValueModel(
      coefficients: [
        0, 0, 0, 0, 0, 0, 213.90101047921615, -10.571458794960051,
        8.64206617587605, 85.54875408125852, 38.02133605639059,
        44.45457658211663, 65.59749417195498, -42.71117965044301,
        -79.05925801489089, 38.89492911154925, 123.12348746619784,
      ],
    ),
    late: ActionValueModel(
      coefficients: [
        0, 0, 0, 0, 0, 0, -266.90516718132375, -34.84711158691272,
        -3.0944004410786565, -56.399296895338836, -56.44954007036786,
        -92.53506844837501, -22.84084527434202, -91.39017739099783,
        133.1676861717479, 30.222235818082527, -18.66469270670481,
      ],
    ),
  );

  static const trainedPolicyRidge300 = PhasedActionValueModel(
    early: ActionValueModel(
      coefficients: [
        0, 0, 0, 0, 0, 0, 759.5718730301348, 0, 9.18858240034585, 0,
        0, 0, 0, -42.83681872565454, 0, 0, 0,
      ],
    ),
    middle: ActionValueModel(
      coefficients: [
        0, 0, 0, 0, 0, 0, -1.7860107785280799, -8.88994156856119,
        -12.750405944169193, 44.98121921191299, -1.5425129884226496,
        -47.91361938640869, -30.13373624948939, 25.205838902187033,
        -20.999992483711033, 71.59403288941712, 46.93677307101436,
      ],
    ),
    late: ActionValueModel(
      coefficients: [
        0, 0, 0, 0, 0, 0, 143.98850076207745, -0.6882421378730927,
        24.51025160361172, 1.9459901530785866, -29.06771707278787,
        24.085713472424747, 25.462197748960428, -1.8971372919116036,
        9.52607482274417, -14.620070458751544, -80.75627613469533,
      ],
    ),
  );
}

class RerollValueModel {
  final List<double> coefficients;
  final double intercept;

  const RerollValueModel({required this.coefficients, this.intercept = 0});

  static const trained500 = RerollValueModel(
    intercept: 287.3793483727316,
    coefficients: [
      -.009023911301966126,
      -.04229188389406198,
      287.42164025662566,
      287.3793483727316,
      0,
      287.3793483727316,
      169.12376572338087,
      118.25558264935056,
      122.88143071306766,
      45.89437026967029,
      287.3793483727316,
      51.03035095116457,
      33.7873093283858,
      32.40697661142153,
    ],
  );

  double evaluate(GameState game, List<int> keptCounts, int rollsLeft) {
    final features = rerollCountFeatures(game, keptCounts, rollsLeft);
    var value = intercept;
    for (var index = 0; index < features.length; index++) {
      value += coefficients[index] * features[index];
    }
    return value;
  }

  double evaluateActionAdvantage(
    GameState game,
    List<int> keptCounts,
    int rollsLeft,
  ) {
    final features = rerollCountFeatures(game, keptCounts, rollsLeft);
    var value = 0.0;
    for (var index = stateValueFeatureCount; index < features.length; index++) {
      value += coefficients[index] * features[index];
    }
    return value;
  }
}

const stateValueFeatureCount = 6;
const actionValueFeatureCount = 17;
const richActionValueFeatureCount = 48;
const rerollValueFeatureCount = 14;

/// Features are normalized to roughly [0, 1] so offline training remains
/// numerically stable and the model can be evaluated without allocations.
List<double> stateValueFeatures(GameState game) {
  var usedFields = 0;
  var totalFields = 0;
  var cleanColumns = 0;
  var nearPerfectColumns = 0;
  var schoolPotential = 0.0;
  var figurePotential = 0.0;

  for (final column in game.columns) {
    final emptyFigures = column.figures.values
        .where((entry) => entry.status == FieldStatus.EMPTY)
        .length;
    final emptySchool = column.school.values
        .where((entry) => entry.status == FieldStatus.EMPTY)
        .length;
    final columnUsed =
        column.school.values
            .where((entry) => entry.status != FieldStatus.EMPTY)
            .length +
        column.figures.values
            .where((entry) => entry.status != FieldStatus.EMPTY)
            .length;
    usedFields += columnUsed;
    totalFields += column.school.length + column.figures.length;
    if (!column.hasPijol) cleanColumns++;
    if (!column.hasPijol && emptyFigures <= 2) nearPerfectColumns++;
    schoolPotential +=
        emptySchool * 3 +
        column.school.entries
            .where((entry) => entry.value.status == FieldStatus.EMPTY)
            .fold<double>(0, (sum, entry) => sum + entry.key / 6);
    figurePotential += emptyFigures * (cleanColumns > 0 ? 1 : .5);
  }

  final progress = totalFields == 0 ? 0.0 : usedFields / totalFields;
  return [
    game.total / 2500,
    progress,
    (1 - progress),
    (cleanColumns / game.columns.length).clamp(0.0, 1.0),
    (nearPerfectColumns / game.columns.length).clamp(0.0, 1.0),
    ((schoolPotential + figurePotential) / 100).clamp(0.0, 1.0),
  ];
}

List<double> stateActionFeatures(GameState game, ScoringOption option) {
  final state = stateValueFeatures(game);
  final column = game.columns[option.columnIndex];
  final usedColumn =
      column.school.values
          .where((entry) => entry.status != FieldStatus.EMPTY)
          .length +
      column.figures.values
          .where((entry) => entry.status != FieldStatus.EMPTY)
          .length;
  final totalColumn = column.school.length + column.figures.length;
  return [
    ...state,
    option.points / 100,
    option.type.index / 2,
    option.columnIndex / 2,
    usedColumn / totalColumn,
    option.figure == Figure.CHANCE ? 1 : 0,
    option.type == ScoringOptionType.pijol ? 1 : 0,
    option.type == ScoringOptionType.school ? 1 : 0,
    (option.schoolFace ?? 0) / 6,
    (option.figure?.index ?? 0) / (Figure.values.length - 1),
    _figurePotential(option.figure) / 160,
    _isStraight(option.figure) ? 1 : 0,
  ];
}

List<double> richStateActionFeatures(GameState game, ScoringOption option) {
  final state = stateValueFeatures(game);
  final progress = state[1];
  final column = game.columns[option.columnIndex];
  final usedColumn =
      column.school.values.where((entry) => entry.status != FieldStatus.EMPTY).length +
      column.figures.values.where((entry) => entry.status != FieldStatus.EMPTY).length;
  final totalColumn = column.school.length + column.figures.length;
  final typeFeatures = [
    option.type == ScoringOptionType.school ? 1.0 : 0.0,
    option.type == ScoringOptionType.figure ? 1.0 : 0.0,
    option.type == ScoringOptionType.pijol ? 1.0 : 0.0,
  ];
  final columnFeatures = [
    for (var index = 0; index < game.columns.length; index++)
      option.columnIndex == index ? 1.0 : 0.0,
  ];
  final figureFeatures = [
    for (final figure in Figure.values)
      option.figure == figure ? 1.0 : 0.0,
  ];
  final schoolFaceFeatures = [
    for (var face = MIN_DIE_VALUE; face <= MAX_DIE_VALUE; face++)
      option.schoolFace == face ? 1.0 : 0.0,
  ];
  return [
    ...state,
    progress < 1 / 3 ? 1.0 : 0.0,
    progress >= 1 / 3 && progress < 2 / 3 ? 1.0 : 0.0,
    progress >= 2 / 3 ? 1.0 : 0.0,
    option.points / 100,
    ...typeFeatures,
    ...columnFeatures,
    usedColumn / totalColumn,
    option.figure == Figure.CHANCE ? 1.0 : 0.0,
    option.type == ScoringOptionType.pijol ? 1.0 : 0.0,
    option.type == ScoringOptionType.school ? 1.0 : 0.0,
    ...schoolFaceFeatures,
    ...figureFeatures,
    _figurePotential(option.figure) / 160,
    _isStraight(option.figure) ? 1.0 : 0.0,
    ...[
      for (final type in typeFeatures) type * (usedColumn / totalColumn),
    ],
  ];
}

double _figurePotential(Figure? figure) => switch (figure) {
  Figure.PAIR => 12,
  Figure.TWO_PAIRS => 30,
  Figure.THREE_OF_A_KIND => 18,
  Figure.FOUR_OF_A_KIND => 24,
  Figure.GENERAL => 80,
  Figure.MARSHAL => 160,
  Figure.THREE_PAIRS => 30,
  Figure.TWO_TRIPLES => 30,
  Figure.FOUR_PLUS_TWO => 30,
  Figure.FULL_HOUSE => 30,
  Figure.SMALL_STRAIGHT => 30,
  Figure.BIG_STRAIGHT => 40,
  Figure.GREAT_STRAIGHT => 70,
  Figure.EVEN => 30,
  Figure.ODD => 30,
  Figure.SMALL => 28,
  Figure.CHANCE => 30,
  null => 0,
};

bool _isStraight(Figure? figure) => switch (figure) {
  Figure.SMALL_STRAIGHT || Figure.BIG_STRAIGHT || Figure.GREAT_STRAIGHT => true,
  _ => false,
};

List<double> rerollValueFeatures(
  GameState game,
  DiceRoll dice,
  RerollAdvisorAction action,
  int rollsLeft,
) {
  final kept = List<int>.filled(MAX_DIE_VALUE, 0);
  for (final index in action.keptDieIndices) {
    kept[dice.values[index] - MIN_DIE_VALUE]++;
  }
  return rerollCountFeatures(game, kept, rollsLeft);
}

List<double> rerollCountFeatures(
  GameState game,
  List<int> kept,
  int rollsLeft,
) {
  final state = stateValueFeatures(game);
  final keptCount = _sumCounts(kept);
  final distinct = kept.where((count) => count > 0).length;
  final largestGroup = kept.fold(0, (max, count) => count > max ? count : max);
  final smallStraight = _facesPresent(kept, 0, 4);
  final bigStraight = _facesPresent(kept, 1, 5);
  return [
    ...state,
    (DICE_COUNT - keptCount) / DICE_COUNT,
    keptCount / DICE_COUNT,
    largestGroup / DICE_COUNT,
    distinct / DICE_COUNT,
    rollsLeft / 2,
    max(smallStraight, bigStraight) / 5,
    _sumCounts(kept) / 21,
    kept.where((count) => count >= 2).length / MAX_DIE_VALUE,
  ];
}

int _facesPresent(List<int> counts, int first, int last) => [
  for (var index = first; index <= last; index++)
    if (counts[index] > 0) index,
].length;

int _sumCounts(List<int> counts) => counts.fold(0, (sum, count) => sum + count);
