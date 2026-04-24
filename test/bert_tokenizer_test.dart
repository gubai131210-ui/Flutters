import 'package:flutter_test/flutter_test.dart';

import 'package:senti/core/services/bert_tokenizer.dart';

void main() {
  test('BERT tokenizer adds special tokens and padding', () {
    final tokenizer = BertTokenizer(
      vocab: <String>[
        '[PAD]',
        '[UNK]',
        '[CLS]',
        '[SEP]',
        '[MASK]',
        '今',
        '天',
        '心',
        '情',
        '很',
        '好',
      ],
      maxSequenceLength: 9,
    );

    final encoded = tokenizer.encode('今天心情很好');

    expect(encoded.tokens.first, '[CLS]');
    expect(encoded.tokens[1], '今');
    expect(encoded.tokens[2], '天');
    expect(encoded.tokens[7], '[SEP]');
    expect(encoded.inputIds.length, 9);
    expect(encoded.attentionMask, <int>[1, 1, 1, 1, 1, 1, 1, 1, 0]);
    expect(encoded.tokenTypeIds, List<int>.filled(9, 0));
  });
}
