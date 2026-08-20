/// The publisher behind a model, so the loader can say who made the thing it is
/// about to download instead of just "the language model".
///
/// The rule table is a hand-kept copy of the same table in iOS
/// (`ModelOrgCatalog`), Android (`ModelTaxonomy`), Web and Electron
/// (`model-org.ts`). Five copies is a known cost; the alternative is a field on
/// the catalog row, which is a commons change. Keep them in step when a family
/// is added.
library;

class ModelOrg {
  const ModelOrg(this.key, this.name);

  /// Stable key, e.g. `nvidia`.
  final String key;

  /// Consumer-facing name, e.g. `NVIDIA`.
  final String name;
}

class _OrgRule {
  const _OrgRule(this.org, this.pattern);

  final ModelOrg org;
  final RegExp pattern;
}

/// Ordered rules against the lowercased "id + name" haystack. First match wins,
/// so a specific publisher precedes the family it would otherwise be swallowed
/// by: NVIDIA before Meta so Nemotron stays NVIDIA, DeepSeek before Alibaba so
/// the R1 Qwen distills stay DeepSeek.
final List<_OrgRule> _rules = <_OrgRule>[
  _OrgRule(
    const ModelOrg('nvidia', 'NVIDIA'),
    RegExp(r'nemotron|nemoguard|cosmos|canary|parakeet|nv[_-]embed|nv_rerank|nvidia|sortformer'),
  ),
  _OrgRule(const ModelOrg('deepseek', 'DeepSeek'), RegExp(r'deepseek')),
  _OrgRule(const ModelOrg('prism', 'Prism'), RegExp(r'bonsai|prismml|prism-?ml')),
  _OrgRule(const ModelOrg('deepgrove', 'Deepgrove'), RegExp(r'maple')),
  _OrgRule(const ModelOrg('ibm', 'IBM'), RegExp(r'granite')),
  // `fara` rides with Microsoft's `phi`: Fara1.5 ships mirrored under our own HF
  // org, so the catalog row names no upstream publisher. Filing it by its own
  // name beats guessing one into a UI label.
  _OrgRule(const ModelOrg('microsoft', 'Microsoft'), RegExp(r'\bphi\b|fara')),
  _OrgRule(const ModelOrg('google', 'Google'), RegExp(r'gemma|embeddinggemma|siglip')),
  // Muse Glimmer is Meta's, per the catalog row's own name.
  _OrgRule(const ModelOrg('meta', 'Meta'), RegExp(r'llama|muse-glimmer|muse_glimmer')),
  _OrgRule(const ModelOrg('alibaba', 'Alibaba'), RegExp(r'qwen')),
  _OrgRule(const ModelOrg('liquid', 'Liquid AI'), RegExp(r'lfm2')),
  _OrgRule(const ModelOrg('mistral', 'Mistral AI'), RegExp(r'mistral|ministral')),
  _OrgRule(const ModelOrg('hugging-face', 'Hugging Face'), RegExp(r'smollm|smolvlm')),
  _OrgRule(const ModelOrg('openai', 'OpenAI'), RegExp(r'whisper')),
  _OrgRule(const ModelOrg('zhipu', 'Zhipu AI'), RegExp(r'\bglm\b|glm-')),
  _OrgRule(
    const ModelOrg('open-source', 'Open source'),
    RegExp(r'internvl|moonshine|melo|kokoro|kitten|piper|vits|silero|vad|minilm|supertonic|segformer'),
  ),
];

const ModelOrg _fallbackOrg = ModelOrg('open-source', 'Open source');

/// The publisher for one model. Never throws; an unrecognised name reads as
/// community rather than guessing a company.
ModelOrg modelOrg({required String id, required String name}) {
  final String haystack = '$id $name'.toLowerCase();
  for (final _OrgRule rule in _rules) {
    if (rule.pattern.hasMatch(haystack)) return rule.org;
  }
  return _fallbackOrg;
}

/// "Qwen3.5 0.8B Q4_K_M · Alibaba" — what the loader shows so a reader knows
/// what is about to land on their device and who made it.
String modelCredit({required String id, required String name}) =>
    '$name · ${modelOrg(id: id, name: name).name}';
