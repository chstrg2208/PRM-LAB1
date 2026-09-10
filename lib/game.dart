/// Game logic and supporting types for Birdle,
/// a five-letter word-guessing game similar to Wordle.
///
/// Defines the [Game] state machine and the
/// [Word], [Letter], and [HitType] data model used to
/// represent guesses and their evaluation against a hidden word.
library;

import 'dart:collection';
import 'dart:math';

/// The result of evaluating a [Letter] of a guess against the hidden word.
enum HitType {
  /// The letter hasn't yet been evaluated.
  none,

  /// The letter matches the hidden word's letter at the same position.
  hit,

  /// The letter is in the hidden word, but at a different position.
  partial,

  /// The letter doesn't appear in the hidden word.
  miss,
}

/// A single character paired with its [HitType] against the hidden word.
typedef Letter = ({String char, HitType type});

/// Words that can be chosen as the hidden word.
const List<String> legalWords = [
  'aback',
  'abase',
  'abate',
  'abbey',
  'abbot',
  'apple',
  'beach',
  'birdy',
  'blade',
  'brain',
  'brave',
  'bread',
  'break',
  'brick',
  'cairn',
  'camel',
  'candy',
  'chair',
  'chalk',
  'charm',
  'chart',
  'chase',
  'clean',
  'climb',
  'cloud',
  'coral',
  'crane',
  'dance',
  'dream',
  'eagle',
  'earth',
  'flame',
  'flash',
  'float',
  'flute',
  'frost',
  'fruit',
  'giant',
  'glass',
  'grape',
  'grass',
  'green',
  'heart',
  'honey',
  'house',
  'laser',
  'lemon',
  'light',
  'lucky',
  'magic',
  'mango',
  'melon',
  'money',
  'music',
  'night',
  'ocean',
  'paint',
  'paper',
  'party',
  'peace',
  'peach',
  'pearl',
  'piano',
  'pilot',
  'pizza',
  'plane',
  'plant',
  'queen',
  'quiet',
  'river',
  'robot',
  'shine',
  'smart',
  'smile',
  'solar',
  'space',
  'spark',
  'spice',
  'spoon',
  'stand',
  'star',
  'steam',
  'storm',
  'sugar',
  'sweet',
  'table',
  'tiger',
  'toast',
  'tower',
  'track',
  'train',
  'tulip',
  'water',
  'whale',
  'white',
  'world',
  'zebra',
];

/// Additional words accepted as guesses beyond those in [legalWords].
const List<String> legalGuesses = [
  'abhor',
  'abide',
  'abled',
  'abode',
  'abort',
  'about',
  'above',
  'abuse',
  'actor',
  'acute',
  'admit',
  'adopt',
  'adult',
  'after',
  'again',
  'agent',
  'agree',
  'ahead',
  'alarm',
  'album',
  'alert',
  'alien',
  'align',
  'alike',
  'alive',
  'allow',
  'alone',
  'along',
  'alter',
  'amber',
  'amend',
  'ample',
  'acute',
  'admit',
  'adopt',
  'adult',
  'after',
  'again',
  'agent',
  'agree',
  'ahead',
  'alarm',
  'album',
  'alert',
  'alien',
  'align',
  'alike',
  'alive',
  'allow',
  'alone',
  'along',
  'alter',
  'amber',
  'amend',
  'angel',
  'anger',
  'angle',
  'angry',
  'apart',
  'apply',
  'arena',
  'argue',
  'arise',
  'armor',
  'arrow',
  'asset',
  'audio',
  'audit',
  'avoid',
  'award',
  'aware',
  'baker',
  'basic',
  'basin',
  'basis',
  'batch',
  'begin',
  'belly',
  'below',
  'bench',
  'birth',
  'black',
  'blame',
  'blank',
  'blast',
  'blend',
  'bless',
  'blind',
  'block',
  'blood',
  'board',
  'boast',
  'bonus',
  'boost',
  'bound',
  'breed',
  'brief',
  'bring',
  'broad',
  'brown',
  'build',
  'buyer',
  'cable',
  'cabin',
  'candy',
  'cargo',
  'carry',
  'catch',
  'cause',
  'chain',
  'chaos',
  'charm',
  'cheap',
  'check',
  'cheer',
  'chess',
  'chest',
  'chief',
  'child',
  'chill',
  'china',
  'civil',
  'claim',
  'clash',
  'class',
  'clear',
  'clerk',
  'click',
  'cliff',
  'clock',
  'close',
  'coach',
  'coast',
  'count',
  'court',
  'cover',
  'craft',
  'crash',
  'cream',
  'creed',
  'creek',
  'crest',
  'crowd',
  'crown',
  'cycle',
  'daily',
  'draft',
  'drama',
  'dress',
  'drift',
  'drink',
  'drive',
  'early',
  'elder',
  'elect',
  'elite',
  'empty',
  'enemy',
  'enjoy',
  'enter',
  'entry',
  'equal',
  'error',
  'essay',
  'event',
  'every',
  'exact',
  'extra',
  'faith',
  'false',
  'fault',
  'favor',
  'feast',
  'fiber',
  'field',
  'fifth',
  'fifty',
  'fight',
  'final',
  'first',
  'fixed',
  'flock',
  'flood',
  'floor',
  'flour',
  'focus',
  'force',
  'forge',
  'forth',
  'forty',
  'forum',
  'found',
  'frame',
  'fresh',
  'front',
  'gamer',
  'ghost',
  'glide',
  'globe',
  'glory',
  'grace',
  'grade',
  'grain',
  'grand',
  'grant',
  'graph',
  'grasp',
  'grave',
  'great',
  'grief',
  'grind',
  'group',
  'guard',
  'guess',
  'guest',
  'guide',
  'guild',
  'happy',
  'harsh',
  'haste',
  'haven',
  'heavy',
  'honor',
  'horse',
  'hotel',
  'human',
  'ideal',
  'image',
  'index',
  'inner',
  'input',
  'irony',
  'issue',
  'joint',
  'judge',
  'juice',
  'knife',
  'labor',
  'large',
  'layer',
  'learn',
  'lease',
  'least',
  'leave',
  'legal',
  'level',
  'lever',
  'limit',
  'liver',
  'logic',
  'loose',
  'lover',
  'loyal',
  'major',
  'maker',
  'march',
  'match',
  'mayor',
  'metal',
  'meter',
  'micro',
  'minor',
  'model',
  'money',
  'month',
  'moral',
  'motor',
  'mount',
  'mouse',
  'mouth',
  'movie',
  'nerve',
  'noble',
  'noise',
  'north',
  'novel',
  'nurse',
  'occur',
  'olive',
  'onion',
  'order',
  'organ',
  'other',
  'outer',
  'owner',
  'panel',
  'panic',
  'patch',
  'pause',
  'phase',
  'phone',
  'photo',
  'piece',
  'pixel',
  'place',
  'plain',
  'plate',
  'plaza',
  'point',
  'polar',
  'pound',
  'power',
  'press',
  'price',
  'pride',
  'prime',
  'print',
  'prior',
  'prize',
  'proof',
  'proud',
  'prove',
  'pulse',
  'punch',
  'pupil',
  'purse',
  'quest',
  'quick',
  'quota',
  'quote',
  'radar',
  'radio',
  'raise',
  'rally',
  'ranch',
  'range',
  'rapid',
  'ratio',
  'reach',
  'react',
  'ready',
  'realm',
  'rebel',
  'refer',
  'reign',
  'relax',
  'reply',
  'reset',
  'ridge',
  'rifle',
  'right',
  'rival',
  'round',
  'route',
  'royal',
  'ruler',
  'rural',
  'saint',
  'salad',
  'sauce',
  'scale',
  'scene',
  'scent',
  'scope',
  'score',
  'scout',
  'sense',
  'serve',
  'seven',
  'shade',
  'shaft',
  'shake',
  'shame',
  'shape',
  'share',
  'sharp',
  'sheep',
  'sheet',
  'shelf',
  'shell',
  'shift',
  'shirt',
  'shock',
  'shoot',
  'shore',
  'short',
  'shout',
  'sight',
  'sigma',
  'since',
  'sixth',
  'sixty',
  'skill',
  'skirt',
  'skull',
  'slate',
  'slave',
  'sleep',
  'slice',
  'slide',
  'slope',
  'smoke',
  'solid',
  'solve',
  'sound',
  'south',
  'spare',
  'speak',
  'speed',
  'spell',
  'spend',
  'spite',
  'split',
  'spoke',
  'sport',
  'squad',
  'staff',
  'stage',
  'stair',
  'stake',
  'stare',
  'start',
  'state',
  'steak',
  'steel',
  'steep',
  'steer',
  'stick',
  'stiff',
  'still',
  'stock',
  'stone',
  'stool',
  'store',
  'story',
  'strip',
  'stuck',
  'study',
  'stuff',
  'style',
  'super',
  'surge',
  'swear',
  'sweep',
  'swift',
  'swing',
  'sword',
  'taste',
  'teach',
  'tempo',
  'tenth',
  'theme',
  'there',
  'thick',
  'thief',
  'thing',
  'think',
  'third',
  'thorn',
  'those',
  'three',
  'throw',
  'thumb',
  'tight',
  'title',
  'today',
  'token',
  'topic',
  'total',
  'touch',
  'tough',
  'trace',
  'trail',
  'trait',
  'trash',
  'treat',
  'trend',
  'trial',
  'tribe',
  'trick',
  'troop',
  'truck',
  'truly',
  'trunk',
  'trust',
  'truth',
  'tumor',
  'twist',
  'uncle',
  'under',
  'union',
  'unite',
  'unity',
  'until',
  'upper',
  'upset',
  'urban',
  'usage',
  'usual',
  'valid',
  'value',
  'valve',
  'vault',
  'verse',
  'video',
  'vigor',
  'viral',
  'virus',
  'visit',
  'vital',
  'vocal',
  'voice',
  'voter',
  'wagon',
  'waste',
  'watch',
  'weave',
  'weigh',
  'wheat',
  'wheel',
  'where',
  'which',
  'while',
  'whole',
  'whose',
  'widen',
  'width',
  'woman',
  'wound',
  'wreck',
  'wrist',
  'write',
  'wrong',
  'yield',
  'young',
  'youth',
];

/// Every word that can be legally entered as a guess.
const List<String> allLegalGuesses = [...legalWords, ...legalGuesses];

/// Game state of a single round of Birdle,
/// a five-letter word-guessing game similar to Wordle.
class Game {
  /// The default maximum number of guesses allowed in a [Game].
  static const int defaultMaxGuesses = 5;

  /// Creates a new game with [maxGuesses] guesses allowed.
  Game({this.maxGuesses = defaultMaxGuesses, this.seed})
      : _wordToGuess = _generateInitialWord(seed),
        _guesses = List<Word>.filled(maxGuesses, Word.empty());

  /// The maximum number of guesses allowed in this game.
  final int maxGuesses;

  /// The seed used to choose the hidden word,
  /// or `null` if it was selected at random.
  final int? seed;

  /// The current hidden word, exposed publicly through [hiddenWord].
  Word _wordToGuess;

  /// Backing storage for [guesses].
  List<Word> _guesses;

  /// The word the player is trying to guess.
  Word get hiddenWord => _wordToGuess;

  /// An unmodifiable view of every guess slot, including those still empty.
  UnmodifiableListView<Word> get guesses => UnmodifiableListView(_guesses);

  /// The most recently submitted guess,
  /// or an empty [Word] if no guesses have been made.
  Word get previousGuess {
    final index = _guesses.lastIndexWhere((word) => word.isNotEmpty);
    return index == -1 ? Word.empty() : _guesses[index];
  }

  /// The index of the next empty guess slot, or `-1` if every slot is full.
  int get activeIndex => _guesses.indexWhere((word) => word.isEmpty);

  /// The number of guesses still available to the player.
  int get guessesRemaining {
    if (activeIndex == -1) return 0;
    return maxGuesses - activeIndex;
  }

  /// Whether the most recent guess matches the hidden word.
  bool get didWin {
    if (_guesses.first.isEmpty) return false;

    for (final letter in previousGuess) {
      if (letter.type != HitType.hit) return false;
    }

    return true;
  }

  /// Whether all allowed guesses have been used without winning.
  bool get didLose => guessesRemaining == 0 && !didWin;

  /// Picks a new hidden word and clears every submitted guess.
  void resetGame() {
    _wordToGuess = _generateInitialWord(seed);
    _guesses = List<Word>.filled(maxGuesses, Word.empty());
  }

  /// Evaluates [guess] against the hidden word,
  /// records the result in [guesses], and returns it.
  Word guess(String guess) {
    final result = matchGuessOnly(guess);
    addGuessToList(result);
    return result;
  }

  /// Whether [guess] is a legal word to guess.
  bool isLegalGuess(String guess) =>
      guess.length == 5 && Word.fromString(guess).isLegalGuess;

  /// Evaluates [guess] against the hidden word without advancing the game.
  Word matchGuessOnly(String guess) =>
      Word.fromString(guess).evaluateGuess(_wordToGuess);

  /// Stores [guess] in the next empty slot of [guesses].
  void addGuessToList(Word guess) {
    final guessIndex = activeIndex;
    if (guessIndex == -1) {
      throw StateError('No guesses remaining.');
    }

    _guesses[guessIndex] = guess;
  }

  /// Returns the starting hidden word for a new round.
  static Word _generateInitialWord(int? seed) =>
      seed == null ? Word.random() : Word.fromSeed(seed);
}

/// A five-letter word made up of [Letter]s, each tracking its [HitType].
class Word with IterableMixin<Letter> {
  /// Creates a word backed by the specified list of [Letter]s.
  Word(this._letters);

  /// Creates a word with five blank letters of [HitType.none].
  factory Word.empty() =>
      Word(List<Letter>.filled(5, (char: '', type: HitType.none)));

  /// Creates a [Word] from [guess].
  factory Word.fromString(String guess) {
    if (guess.length != 5) {
      throw ArgumentError.value(
        guess,
        'guess',
        'Must be exactly 5 characters long.',
      );
    }

    final letters = guess
        .toLowerCase()
        .split('')
        .map((char) => (char: char, type: HitType.none))
        .toList();
    return Word(letters);
  }

  /// Creates a word chosen at random from [legalWords].
  factory Word.random() {
    final random = Random();
    final nextWord = legalWords[random.nextInt(legalWords.length)];
    return Word.fromString(nextWord);
  }

  /// Creates a word chosen from [legalWords] using [seed] as an index.
  factory Word.fromSeed(int seed) =>
      Word.fromString(legalWords[seed % legalWords.length]);

  final List<Letter> _letters;

  @override
  Iterator<Letter> get iterator => _letters.iterator;

  @override
  bool get isEmpty => every((letter) => letter.char.isEmpty);

  @override
  int get length => _letters.length;

  Letter operator [](int i) => _letters[i];

  @override
  String toString() => _letters.map((letter) => letter.char).join().trim();

  String toStringVerbose() => _letters
      .map((letter) => '${letter.char} - ${letter.type.name}')
      .join('\n');
}

/// Validation and guess-evaluation logic on [Word].
extension WordUtils on Word {
  /// Whether this word appears in [allLegalGuesses].
  bool get isLegalGuess => allLegalGuesses.contains(toString());

  /// Compares this [Word] against the specified [hiddenWord]
  Word evaluateGuess(Word hiddenWord) {
    assert(isLegalGuess);

    final result = List<Letter>.filled(length, (char: '', type: HitType.none));
    final unmatchedHiddenLetterCounts = <String, int>{};

    // 1. Exact matches (Hit)
    for (var i = 0; i < length; i++) {
      final guessChar = this[i].char;
      final hiddenChar = hiddenWord[i].char;

      if (guessChar == hiddenChar) {
        result[i] = (char: guessChar, type: HitType.hit);
      } else {
        final unmatchedCount = unmatchedHiddenLetterCounts[hiddenChar] ?? 0;
        unmatchedHiddenLetterCounts[hiddenChar] = unmatchedCount + 1;
      }
    }

    // 2. Partial matches (Yellow) or Misses (Grey)
    for (var i = 0; i < length; i++) {
      if (result[i].type == HitType.hit) continue;

      final guessChar = this[i].char;
      final unmatchedCount = unmatchedHiddenLetterCounts[guessChar] ?? 0;
      final isPartial = unmatchedCount > 0;
      if (isPartial) {
        unmatchedHiddenLetterCounts[guessChar] = unmatchedCount - 1;
      }

      result[i] = (
        char: guessChar,
        type: isPartial ? HitType.partial : HitType.miss,
      );
    }

    return Word(result);
  }
}
