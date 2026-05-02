#!/usr/bin/env node

import { readFile, writeFile } from 'node:fs/promises';

const DEFAULTS = {
  providerKey: 'windsurf',
  providerName: 'Windsurf',
  baseUrl: 'http://localhost:50731/v1',
  apiKey: 'Penci1',
  npm: '@ai-sdk/openai-compatible',
  modelsDevUrl: 'https://models.dev/api.json',
  configPath: new URL('../chezmoi/dot_config/opencode/opencode.json', import.meta.url),
};

const args = parseArgs(process.argv.slice(2));
const config = {
  providerKey: args['provider-key'] ?? DEFAULTS.providerKey,
  providerName: args['provider-name'] ?? DEFAULTS.providerName,
  baseUrl: stripTrailingSlash(args['base-url'] ?? DEFAULTS.baseUrl),
  apiKey: args['api-key'] ?? DEFAULTS.apiKey,
  npm: args.npm ?? DEFAULTS.npm,
  configPath: args['config-path'] ?? DEFAULTS.configPath,
  output: args.output,
  modelsDevUrl: args['models-dev-url'] ?? DEFAULTS.modelsDevUrl,
  headers: parseHeaderArgs(args.header),
};

const [remoteModels, modelsDev] = await Promise.all([
  fetchProviderModels(config),
  fetchJson(config.modelsDevUrl),
]);

const modelIndex = buildModelIndex(modelsDev);
const missing = [];
const models = {};

for (const remoteModel of remoteModels) {
  const resolved = resolveModel(remoteModel.id, modelIndex);
  const modelConfig = {};

  if (typeof remoteModel.name === 'string' && remoteModel.name.length > 0) {
    modelConfig.name = remoteModel.name;
  } else {
    const generatedName = generateModelName(remoteModel.id, resolved);
    if (generatedName) modelConfig.name = generatedName;
  }

  const context = remoteModel.id.includes('-1m') ? 1_000_000 : resolved?.model?.limit?.context;
  const output = resolved?.model?.limit?.output;

  if (Number.isFinite(context) && Number.isFinite(output)) {
    modelConfig.limit = { context, output };
  } else {
    missing.push(remoteModel.id);
  }

  models[remoteModel.id] = modelConfig;
}

const providerConfig = {
  npm: config.npm,
  name: config.providerName,
  options: {
    baseURL: config.baseUrl,
    apiKey: config.apiKey,
    ...(Object.keys(config.headers).length > 0 ? { headers: config.headers } : {}),
  },
  models,
};

const opencodeConfig = await readOpencodeConfig(config.configPath);
opencodeConfig.provider ??= {};
opencodeConfig.provider[config.providerKey] = providerConfig;

const outputText = `${JSON.stringify(opencodeConfig, null, 2)}\n`;
const outputPath = config.output ?? config.configPath;

await writeFile(outputPath, outputText, 'utf8');
process.stdout.write(`updated ${displayPath(outputPath)}\n`);

if (missing.length > 0) {
  process.stderr.write(
    `warn: missing models.dev limits for ${missing.length} model(s): ${missing.join(', ')}\n`,
  );
}

function parseArgs(argv) {
  const parsed = {};

  for (let i = 0; i < argv.length; i += 1) {
    const token = argv[i];
    if (!token.startsWith('--')) continue;

    const eqIndex = token.indexOf('=');
    if (eqIndex >= 0) {
      const key = token.slice(2, eqIndex);
      const value = token.slice(eqIndex + 1);
      pushArg(parsed, key, value);
      continue;
    }

    const key = token.slice(2);
    const next = argv[i + 1];
    if (!next || next.startsWith('--')) {
      pushArg(parsed, key, true);
      continue;
    }

    pushArg(parsed, key, next);
    i += 1;
  }

  return parsed;
}

function pushArg(parsed, key, value) {
  if (key === 'header') {
    const current = parsed[key] ?? [];
    current.push(value);
    parsed[key] = current;
    return;
  }

  parsed[key] = value;
}

function parseHeaderArgs(headerArgs = []) {
  const headers = {};

  for (const item of headerArgs) {
    const separator = item.includes('=') ? '=' : ':';
    const index = item.indexOf(separator);
    if (index <= 0) {
      throw new Error(`Invalid --header value: ${item}. Use 'Name=Value'.`);
    }

    const key = item.slice(0, index).trim();
    const value = item.slice(index + 1).trim();
    headers[key] = value;
  }

  return headers;
}

async function fetchProviderModels({ baseUrl, apiKey, headers }) {
  const requestHeaders = {
    accept: 'application/json',
    ...headers,
  };

  if (apiKey && !hasHeader(requestHeaders, 'authorization')) {
    requestHeaders.Authorization = `Bearer ${apiKey}`;
  }

  const response = await fetch(`${baseUrl}/models`, { headers: requestHeaders });
  if (!response.ok) {
    throw new Error(`Provider models fetch failed: ${response.status} ${response.statusText}`);
  }

  const payload = await response.json();
  if (!Array.isArray(payload?.data)) {
    throw new Error('Provider models response missing data array.');
  }

  return payload.data;
}

async function fetchJson(url) {
  const response = await fetch(url);
  if (!response.ok) {
    throw new Error(`Fetch failed for ${url}: ${response.status} ${response.statusText}`);
  }

  return response.json();
}

async function readOpencodeConfig(filePath) {
  const content = await readFile(filePath, 'utf8');
  return JSON.parse(content);
}

function hasHeader(headers, targetKey) {
  return Object.keys(headers).some((key) => key.toLowerCase() === targetKey.toLowerCase());
}

function buildModelIndex(modelsDev) {
  const exact = new Map();
  const normalized = new Map();

  for (const [providerKey, provider] of Object.entries(modelsDev)) {
    if (!provider?.models) continue;

    for (const [id, model] of Object.entries(provider.models)) {
      const entry = { providerKey, id, model };
      const exactBucket = exact.get(id) ?? [];
      exactBucket.push(entry);
      exact.set(id, exactBucket);

      const key = normalizeModelId(id);
      const bucket = normalized.get(key) ?? [];
      bucket.push(entry);
      normalized.set(key, bucket);
    }
  }

  return { exact, normalized };
}

function resolveModel(id, modelIndex) {
  for (const candidate of buildCandidates(id)) {
    const exactMatches = modelIndex.exact.get(candidate);
    if (exactMatches?.length) {
      return pickBestMatch(exactMatches, id);
    }

    const normalizedMatches = modelIndex.normalized.get(normalizeModelId(candidate));
    if (normalizedMatches?.length) {
      return pickBestMatch(normalizedMatches, id);
    }
  }

  return null;
}

function pickBestMatch(matches, requestedId) {
  return [...matches].sort((left, right) => scoreMatch(right, requestedId) - scoreMatch(left, requestedId))[0];
}

function scoreMatch(entry, requestedId) {
  let score = 0;

  const preferredProviders = getPreferredProviders(requestedId);
  const providerRank = preferredProviders.indexOf(entry.providerKey);
  if (providerRank >= 0) score += 1000 - providerRank * 25;

  const context = entry.model?.limit?.context ?? 0;
  const output = entry.model?.limit?.output ?? 0;
  score += context / 1000;
  score += output / 1000;

  if (Number.isFinite(entry.model?.limit?.context)) score += 4;
  if (Number.isFinite(entry.model?.limit?.output)) score += 4;
  if (!entry.id.includes('/')) score += 2;
  if (!entry.id.includes(':')) score += 1;
  score -= entry.id.length / 1000;
  return score;
}

function buildCandidates(id) {
  const ordered = [
    ...buildClaudeCandidates(id),
    ...buildGenericCandidates(id),
    id,
  ];

  const seen = new Set();
  return ordered.filter((candidate) => {
    if (!candidate || seen.has(candidate)) return false;
    seen.add(candidate);
    return true;
  });
}

function buildClaudeCandidates(id) {
  const parsed = parseClaudeAlias(id);
  if (!parsed) return [];

  const { family, versionRaw, tailRaw } = parsed;
  const versionDot = versionRaw.replace(/-/gu, '.');
  const versionDash = versionRaw.replace(/\.0$/u, '').replace(/\./gu, '-');

  let tail = tailRaw;
  if (/^-(low|medium|high|xhigh|max)(-thinking)?$/u.test(tail)) {
    tail = tail.includes('-thinking') ? '-thinking' : '';
  }
  tail = tail.replace(/-1m/gu, '');
  if (tail === '-thinking-fast') tail = '-thinking';

  const candidates = [
    `anthropic/claude-${family}-${versionDot}${tail.replace('-thinking', ':thinking')}`,
    `anthropic/claude-${family}-${versionDash}${tail.replace('-thinking', ':thinking')}`,
    `claude-${family}-${versionDash}${tail}`,
  ];

  if (tail === '-thinking' || tail === '-fast') {
    candidates.push(`anthropic/claude-${family}-${versionDot}`);
    candidates.push(`anthropic/claude-${family}-${versionDash}`);
    candidates.push(`claude-${family}-${versionDash}`);
  }

  return candidates;
}

function parseClaudeAlias(id) {
  const leadingVersion = id.match(/^claude-(\d(?:\.\d+)?)-(sonnet|opus|haiku)(.*)$/);
  if (leadingVersion) {
    return {
      family: leadingVersion[2],
      versionRaw: leadingVersion[1],
      tailRaw: leadingVersion[3] ?? '',
    };
  }

  const familyFirst = id.match(/^claude-(sonnet|opus|haiku)-(.+)$/);
  if (!familyFirst) return null;

  const family = familyFirst[1];
  const parts = familyFirst[2].split('-');
  const suffixes = new Set(['thinking', 'low', 'medium', 'high', 'xhigh', 'max', 'fast', '1m']);
  const versionParts = [];
  const tailParts = [];
  let tailStarted = false;

  for (const part of parts) {
    if (!tailStarted && !suffixes.has(part)) {
      versionParts.push(part);
      continue;
    }

    tailStarted = true;
    tailParts.push(part);
  }

  if (versionParts.length === 0) return null;

  return {
    family,
    versionRaw: versionParts.join('-'),
    tailRaw: tailParts.length > 0 ? `-${tailParts.join('-')}` : '',
  };
}

function buildGenericCandidates(id) {
  const candidates = new Set();
  const strippedVariants = stripKnownSuffixes(id);

  for (const variant of [...strippedVariants]) {
    if (/^gpt-\d-\d/u.test(variant)) {
      candidates.add(variant.replace(/^gpt-(\d)-(\d)/u, 'gpt-$1.$2'));
    }

    if (/^gemini-3\.0-/u.test(variant)) {
      candidates.add(variant.replace(/^gemini-3\.0-/u, 'gemini-3-'));
    }

    candidates.add(variant);
  }

  if (id === 'grok-3-mini-thinking') candidates.add('grok-3-mini');
  if (id === 'o3-high') candidates.add('o3');
  if (id === 'glm-4.7-fast') {
    candidates.add('glm-4.7-flash');
    candidates.add('glm-4.7');
  }

  return [...candidates];
}

function stripKnownSuffixes(id) {
  const variants = new Set([id]);
  const suffixPattern = /-(none|low|medium|high|xhigh|max|minimal|priority|fast|1m)(?=-|$)/gu;

  let changed = true;
  while (changed) {
    changed = false;

    for (const variant of [...variants]) {
      const next = variant.replace(suffixPattern, '');
      if (next !== variant && !variants.has(next)) {
        variants.add(next);
        changed = true;
      }

      const noThinking = next.replace(/-thinking$/u, '');
      if (noThinking !== next && !variants.has(noThinking)) {
        variants.add(noThinking);
        changed = true;
      }
    }
  }

  return [...variants];
}

function normalizeModelId(id) {
  return id
    .toLowerCase()
    .replace(/^.*\//u, '')
    .replace(/_/gu, '-')
    .replace(/:/gu, '-')
    .replace(/\.{2,}/gu, '.')
    .replace(/\.0(?=-|$)/gu, '')
    .replace(/-+/gu, '-');
}

function getPreferredProviders(id) {
  if (/^claude-/u.test(id)) return ['anthropic', 'opencode', 'github-copilot'];
  if (/^(gpt-|o\d|gpt-oss)/u.test(id)) return ['openai', 'opencode', 'azure-cognitive-services', 'azure'];
  if (/^gemini-/u.test(id)) return ['google', 'opencode'];
  if (/^grok-/u.test(id)) return ['xai', 'x-ai', 'opencode'];
  if (/^kimi-/u.test(id)) return ['opencode', 'moonshotai', 'qiniu-ai', 'iflowcn'];
  if (/^glm-/u.test(id)) return ['z-ai', 'zai', 'opencode'];
  if (/^minimax-/u.test(id)) return ['opencode', 'minimax', 'minimax-cn'];
  return ['opencode'];
}

function generateModelName(remoteId, resolved) {
  const baseName = resolved?.model?.name;
  if (!baseName) return undefined;

  const suffixes = getAdditionalNameSuffixes(remoteId, resolved.id);
  if (suffixes.length === 0) return baseName;

  return `${baseName} ${suffixes.join(' ')}`;
}

function getAdditionalNameSuffixes(remoteId, resolvedId) {
  const suffixOrder = ['none', 'low', 'medium', 'high', 'xhigh', 'fast', 'priority', 'minimal', 'max', 'thinking', '1m'];
  const remoteCounts = countSuffixTokens(remoteId, suffixOrder);
  const resolvedCounts = countSuffixTokens(resolvedId, suffixOrder);
  const suffixes = [];

  for (const token of suffixOrder) {
    const extraCount = Math.max(0, (remoteCounts.get(token) ?? 0) - (resolvedCounts.get(token) ?? 0));
    for (let i = 0; i < extraCount; i += 1) {
      suffixes.push(formatSuffixToken(token));
    }
  }

  return suffixes;
}

function countSuffixTokens(id, suffixOrder) {
  const counts = new Map();
  if (!id) return counts;

  const suffixSet = new Set(suffixOrder);
  const tokens = normalizeModelId(id).split(/[-.]/u).filter(Boolean);

  for (const token of tokens) {
    if (!suffixSet.has(token)) continue;
    counts.set(token, (counts.get(token) ?? 0) + 1);
  }

  return counts;
}

function formatSuffixToken(token) {
  if (token === '1m') return '1M';
  if (token === 'xhigh') return 'XHigh';
  return token.charAt(0).toUpperCase() + token.slice(1);
}

function displayPath(filePath) {
  return filePath instanceof URL ? filePath.pathname : filePath;
}

function stripTrailingSlash(value) {
  return value.replace(/\/+$/u, '');
}
