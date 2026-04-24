class BertEncoding {
  const BertEncoding({
    required this.inputIds,
    required this.tokenTypeIds,
    required this.attentionMask,
    required this.tokens,
  });

  final List<int> inputIds;
  final List<int> tokenTypeIds;
  final List<int> attentionMask;
  final List<String> tokens;
}

class BertTokenizer {
  BertTokenizer({
    required List<String> vocab,
    this.doLowerCase = true,
    this.maxSequenceLength = 128,
  }) : _tokenToId = <String, int>{
          for (var index = 0; index < vocab.length; index++) vocab[index]: index,
        };

  final Map<String, int> _tokenToId;
  final bool doLowerCase;
  final int maxSequenceLength;

  static const String padToken = '[PAD]';
  static const String unkToken = '[UNK]';
  static const String clsToken = '[CLS]';
  static const String sepToken = '[SEP]';

  int get padId => tokenId(padToken);
  int get unkId => tokenId(unkToken);
  int get clsId => tokenId(clsToken);
  int get sepId => tokenId(sepToken);

  int tokenId(String token) => _tokenToId[token] ?? unkId;

  BertEncoding encode(String text, {int? sequenceLength}) {
    final maxLen = sequenceLength ?? maxSequenceLength;
    final cleaned = doLowerCase ? text.trim().toLowerCase() : text.trim();
    final basicTokens = _basicTokenize(cleaned);
    final wordPieces = <String>[];

    for (final token in basicTokens) {
      wordPieces.addAll(_wordPieceTokenize(token));
    }

    final reserved = 2;
    final truncated = wordPieces.take(maxLen - reserved).toList();
    final tokens = <String>[clsToken, ...truncated, sepToken];
    final inputIds = tokens.map(tokenId).toList();
    final attentionMask = List<int>.filled(tokens.length, 1, growable: true);
    final tokenTypeIds = List<int>.filled(tokens.length, 0, growable: true);

    while (inputIds.length < maxLen) {
      inputIds.add(padId);
      attentionMask.add(0);
      tokenTypeIds.add(0);
      tokens.add(padToken);
    }

    return BertEncoding(
      inputIds: inputIds,
      tokenTypeIds: tokenTypeIds,
      attentionMask: attentionMask,
      tokens: tokens,
    );
  }

  List<String> _basicTokenize(String text) {
    final tokens = <String>[];
    final buffer = StringBuffer();

    void flush() {
      if (buffer.isNotEmpty) {
        tokens.add(buffer.toString());
        buffer.clear();
      }
    }

    for (final rune in text.runes) {
      final char = String.fromCharCode(rune);
      if (_isWhitespace(rune)) {
        flush();
        continue;
      }
      if (_isChineseChar(rune) || _isPunctuation(rune)) {
        flush();
        tokens.add(char);
        continue;
      }
      buffer.write(char);
    }
    flush();
    return tokens;
  }

  List<String> _wordPieceTokenize(String token) {
    if (_tokenToId.containsKey(token)) {
      return <String>[token];
    }

    final pieces = <String>[];
    var start = 0;
    var isBad = false;

    while (start < token.length) {
      var end = token.length;
      String? current;
      while (start < end) {
        final piece = token.substring(start, end);
        final candidate = start == 0 ? piece : '##$piece';
        if (_tokenToId.containsKey(candidate)) {
          current = candidate;
          break;
        }
        end--;
      }
      if (current == null) {
        isBad = true;
        break;
      }
      pieces.add(current);
      start = end;
    }

    return isBad ? <String>[unkToken] : pieces;
  }

  bool _isWhitespace(int rune) {
    return rune == 0x0009 ||
        rune == 0x000A ||
        rune == 0x000D ||
        rune == 0x0020 ||
        rune == 0x00A0;
  }

  bool _isPunctuation(int rune) {
    if ((rune >= 33 && rune <= 47) ||
        (rune >= 58 && rune <= 64) ||
        (rune >= 91 && rune <= 96) ||
        (rune >= 123 && rune <= 126)) {
      return true;
    }
    return (rune >= 0x2000 && rune <= 0x206F) ||
        (rune >= 0x2E00 && rune <= 0x2E7F) ||
        (rune >= 0x3000 && rune <= 0x303F);
  }

  bool _isChineseChar(int rune) {
    return (rune >= 0x4E00 && rune <= 0x9FFF) ||
        (rune >= 0x3400 && rune <= 0x4DBF) ||
        (rune >= 0x20000 && rune <= 0x2A6DF) ||
        (rune >= 0x2A700 && rune <= 0x2B73F) ||
        (rune >= 0x2B740 && rune <= 0x2B81F) ||
        (rune >= 0x2B820 && rune <= 0x2CEAF) ||
        (rune >= 0xF900 && rune <= 0xFAFF);
  }
}
