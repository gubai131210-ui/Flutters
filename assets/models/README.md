Senti expects the following offline sentiment assets here:

- `feeling_model.tflite` - exported Chinese sentiment classifier
- `sentiment_vocab.txt` - BERT / RoBERTa Chinese vocab
- `sentiment_model_config.json` - label list and feeling projection
- `tokenizer_config.json` - tokenizer settings reference
- `special_tokens_map.json` - special token reference

Current default integration target:
- Hugging Face model: `techthiyanes/chinese_sentiment`
- Typical export command:
  `optimum-cli export tflite --model techthiyanes/chinese_sentiment --task text-classification --sequence_length 128 assets/models/_export_tmp`

After export, rename or copy:
- `assets/models/_export_tmp/model.tflite` -> `assets/models/feeling_model.tflite`

Until `feeling_model.tflite` is present, Senti falls back to dictionary rules and manual confirmation.
