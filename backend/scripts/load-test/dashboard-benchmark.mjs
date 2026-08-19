import { cpus } from 'node:os';
import { writeFile } from 'node:fs/promises';
import http from 'node:http';
import https from 'node:https';
import {
  Worker,
  isMainThread,
  parentPort,
  workerData,
} from 'node:worker_threads';
import { performance } from 'node:perf_hooks';

const LOCAL_HOSTS = new Set(['localhost', '127.0.0.1', '::1', '[::1]']);

function requireLocalBaseUrl(value) {
  const url = new URL(value);
  if (!LOCAL_HOSTS.has(url.hostname) || !['http:', 'https:'].includes(url.protocol)) {
    throw new Error('Benchmark chỉ được phép chạy với localhost/127.0.0.1/::1.');
  }
  return url;
}

function positiveInteger(value, fallback, name) {
  const parsed = Number.parseInt(value ?? '', 10);
  if (Number.isInteger(parsed) && parsed > 0) return parsed;
  if (fallback !== undefined) return fallback;
  throw new Error(`${name} phải là số nguyên dương.`);
}

function positiveNumber(value, fallback, name) {
  const parsed = Number.parseFloat(value ?? '');
  if (Number.isFinite(parsed) && parsed > 0) return parsed;
  if (fallback !== undefined) return fallback;
  throw new Error(`${name} phải là số dương.`);
}

function parseStages(value) {
  const stages = (value || '1x10s,5x20s,10x20s,20x30s')
    .split(',')
    .map((item) => item.trim())
    .filter(Boolean)
    .map((item) => {
      const match = /^(\d+)x(\d+)(s|m)?$/i.exec(item);
      if (!match) {
        throw new Error(`Stage không hợp lệ: ${item}. Ví dụ: 10x30s.`);
      }
      const virtualUsers = positiveInteger(match[1], undefined, 'virtualUsers');
      const duration = positiveInteger(match[2], undefined, 'duration');
      return {
        virtualUsers,
        durationSeconds: match[3]?.toLowerCase() === 'm' ? duration * 60 : duration,
      };
    });
  if (stages.length === 0) throw new Error('Phải có ít nhất một stage.');
  return stages;
}

function percentile(sorted, percentileValue) {
  if (sorted.length === 0) return 0;
  const index = Math.min(
    sorted.length - 1,
    Math.max(0, Math.ceil((percentileValue / 100) * sorted.length) - 1),
  );
  return sorted[index];
}

function round(value, digits = 2) {
  const factor = 10 ** digits;
  return Math.round(value * factor) / factor;
}

function vietnamDayRange(now = new Date()) {
  const parts = Object.fromEntries(
    new Intl.DateTimeFormat('en-CA', {
      timeZone: 'Asia/Ho_Chi_Minh',
      year: 'numeric',
      month: '2-digit',
      day: '2-digit',
    })
      .formatToParts(now)
      .filter((part) => part.type !== 'literal')
      .map((part) => [part.type, part.value]),
  );
  const current = new Date(`${parts.year}-${parts.month}-${parts.day}T00:00:00+07:00`);
  const next = new Date(current.getTime() + 24 * 60 * 60 * 1000);
  const format = (date) => {
    const shifted = new Date(date.getTime() + 7 * 60 * 60 * 1000);
    return `${shifted.toISOString().slice(0, 19)}+07:00`;
  };
  return { from: format(current), to: format(next) };
}

function requestOnce({
  baseUrl,
  path,
  method = 'GET',
  token,
  body,
  timeoutMs,
  agent,
  captureBody = true,
}) {
  const base = requireLocalBaseUrl(baseUrl);
  const transport = base.protocol === 'https:' ? https : http;
  const payload = body === undefined ? undefined : JSON.stringify(body);
  const startedAt = performance.now();

  return new Promise((resolve) => {
    const request = transport.request(
      {
        protocol: base.protocol,
        hostname: base.hostname,
        port: base.port || (base.protocol === 'https:' ? 443 : 80),
        method,
        path,
        agent,
        headers: {
          accept: 'application/json',
          ...(token ? { authorization: `Bearer ${token}` } : {}),
          ...(payload
            ? {
                'content-type': 'application/json',
                'content-length': Buffer.byteLength(payload),
              }
            : {}),
        },
      },
      (response) => {
        const chunks = [];
        response.on('data', (chunk) => {
          if (captureBody) chunks.push(chunk);
        });
        response.on('end', () => {
          resolve({
            statusCode: response.statusCode ?? 0,
            latencyMs: performance.now() - startedAt,
            body: captureBody ? Buffer.concat(chunks).toString('utf8') : '',
            error: null,
          });
        });
      },
    );

    request.setTimeout(timeoutMs, () => request.destroy(new Error('timeout')));
    request.on('error', (error) => {
      resolve({
        statusCode: 0,
        latencyMs: performance.now() - startedAt,
        body: '',
        error: error.message,
      });
    });
    if (payload) request.write(payload);
    request.end();
  });
}

async function requestJson(options) {
  const result = await requestOnce(options);
  if (result.statusCode < 200 || result.statusCode >= 300) {
    throw new Error(`${options.method ?? 'GET'} ${options.path} trả HTTP ${result.statusCode}.`);
  }
  try {
    return JSON.parse(result.body);
  } catch {
    throw new Error(`${options.path} không trả JSON hợp lệ.`);
  }
}

async function resolveToken(baseUrl, timeoutMs) {
  const suppliedToken = process.env.LOAD_TEST_TOKEN?.trim();
  if (suppliedToken) return suppliedToken;

  const userName = process.env.LOAD_TEST_USERNAME?.trim();
  const password = process.env.LOAD_TEST_PASSWORD;
  if (!userName || !password) {
    throw new Error(
      'Thiếu LOAD_TEST_TOKEN hoặc cặp LOAD_TEST_USERNAME/LOAD_TEST_PASSWORD.',
    );
  }

  const response = await requestJson({
    baseUrl,
    path: '/api/auth/login',
    method: 'POST',
    body: { userName, password },
    timeoutMs,
  });
  if (typeof response.accessToken !== 'string' || response.accessToken.length === 0) {
    throw new Error('Login thành công nhưng response không có accessToken.');
  }
  return response.accessToken;
}

async function resolveDashboardPath(baseUrl, token, timeoutMs) {
  const explicitPath = process.env.BENCH_PATH?.trim();
  if (explicitPath) {
    if (!explicitPath.startsWith('/') || explicitPath.startsWith('//')) {
      throw new Error('BENCH_PATH phải là đường dẫn tương đối bắt đầu bằng /.');
    }
    return { path: explicitPath, branchId: null, companyId: null };
  }

  const scopes = await requestJson({
    baseUrl,
    path: '/api/dashboard/scopes',
    token,
    timeoutMs,
  });
  if (!Array.isArray(scopes)) throw new Error('/api/dashboard/scopes phải trả một mảng.');

  const requestedCompanyId = process.env.BENCH_COMPANY_ID
    ? positiveInteger(process.env.BENCH_COMPANY_ID, undefined, 'BENCH_COMPANY_ID')
    : null;
  const requestedBranchId = process.env.BENCH_BRANCH_ID
    ? positiveInteger(process.env.BENCH_BRANCH_ID, undefined, 'BENCH_BRANCH_ID')
    : null;
  const stations = scopes.filter(
    (scope) =>
      scope?.type === 'station' &&
      Number.isInteger(scope.companyId) &&
      Number.isInteger(scope.branchId) &&
      (requestedCompanyId === null || scope.companyId === requestedCompanyId) &&
      (requestedBranchId === null || scope.branchId === requestedBranchId),
  );
  const station = stations[0];
  if (!station) {
    throw new Error('Không tìm thấy trạm được cấp quyền phù hợp BENCH_COMPANY_ID/BENCH_BRANCH_ID.');
  }

  const { from, to } = vietnamDayRange();
  const query = new URLSearchParams({
    companyId: String(station.companyId),
    branchId: String(station.branchId),
    from,
    to,
    interval: 'hour',
  });
  return {
    path: `/api/dashboard?${query}`,
    branchId: station.branchId,
    companyId: station.companyId,
  };
}

function mergeWorkerResults(results, durationSeconds, elapsedSeconds, virtualUsers) {
  const latencies = results.flatMap((result) => result.latencies).sort((a, b) => a - b);
  const statuses = {};
  const errors = {};
  for (const result of results) {
    for (const [key, value] of Object.entries(result.statuses)) {
      statuses[key] = (statuses[key] ?? 0) + value;
    }
    for (const [key, value] of Object.entries(result.errors)) {
      errors[key] = (errors[key] ?? 0) + value;
    }
  }
  const total = latencies.length;
  const failed = results.reduce((sum, result) => sum + result.failed, 0);
  return {
    virtualUsers,
    durationSeconds,
    elapsedSeconds: round(elapsedSeconds),
    requests: total,
    requestsPerSecond: round(total / elapsedSeconds),
    failed,
    errorRate: total === 0 ? 1 : round(failed / total, 5),
    latencyMs: {
      min: round(latencies[0] ?? 0),
      average: round(total === 0 ? 0 : latencies.reduce((sum, value) => sum + value, 0) / total),
      p50: round(percentile(latencies, 50)),
      p90: round(percentile(latencies, 90)),
      p95: round(percentile(latencies, 95)),
      p99: round(percentile(latencies, 99)),
      max: round(latencies[latencies.length - 1] ?? 0),
    },
    statuses,
    errors,
  };
}

async function runStage(config, stage) {
  const startedAt = performance.now();
  const workerCount = Math.min(config.maxWorkers, stage.virtualUsers);
  const baseVus = Math.floor(stage.virtualUsers / workerCount);
  const remainder = stage.virtualUsers % workerCount;
  const workers = Array.from({ length: workerCount }, (_, index) => {
    const virtualUsers = baseVus + (index < remainder ? 1 : 0);
    return new Promise((resolve, reject) => {
      const worker = new Worker(new URL(import.meta.url), {
        workerData: {
          ...config,
          virtualUsers,
          durationSeconds: stage.durationSeconds,
        },
      });
      worker.once('message', resolve);
      worker.once('error', reject);
      worker.once('exit', (code) => {
        if (code !== 0) reject(new Error(`Worker dừng với exit code ${code}.`));
      });
    });
  });
  const results = await Promise.all(workers);
  return mergeWorkerResults(
    results,
    stage.durationSeconds,
    (performance.now() - startedAt) / 1_000,
    stage.virtualUsers,
  );
}

function printResult(result, warmup = false) {
  const prefix = warmup ? 'WARM-UP' : `${result.virtualUsers} VU`;
  console.log(
    `${prefix.padEnd(10)} | ${String(result.requests).padStart(6)} req | ` +
      `${String(result.requestsPerSecond).padStart(7)} req/s | ` +
      `p50 ${String(result.latencyMs.p50).padStart(8)} ms | ` +
      `p95 ${String(result.latencyMs.p95).padStart(8)} ms | ` +
      `p99 ${String(result.latencyMs.p99).padStart(8)} ms | ` +
      `error ${(result.errorRate * 100).toFixed(2)}%`,
  );
  if (result.failed > 0) {
    console.log(`           statuses ${JSON.stringify(result.statuses)}`);
    if (Object.keys(result.errors).length > 0) {
      console.log(`           errors   ${JSON.stringify(result.errors)}`);
    }
  }
}

async function main() {
  const baseUrl = requireLocalBaseUrl(
    process.env.BENCH_BASE_URL?.trim() || 'http://localhost:5052',
  ).origin;
  const timeoutMs = positiveInteger(process.env.BENCH_TIMEOUT_MS, 30_000, 'BENCH_TIMEOUT_MS');
  const maxWorkers = Math.min(
    positiveInteger(process.env.BENCH_WORKERS, Math.max(1, Math.floor(cpus().length / 2)), 'BENCH_WORKERS'),
    cpus().length,
  );
  const stages = parseStages(process.env.BENCH_STAGES);
  const warmupSeconds = positiveInteger(
    process.env.BENCH_WARMUP_SECONDS,
    5,
    'BENCH_WARMUP_SECONDS',
  );
  const maxP95Ms = positiveNumber(process.env.BENCH_MAX_P95_MS, 5_000, 'BENCH_MAX_P95_MS');
  const maxErrorRate = positiveNumber(
    process.env.BENCH_MAX_ERROR_RATE,
    0.01,
    'BENCH_MAX_ERROR_RATE',
  );

  const token = await resolveToken(baseUrl, timeoutMs);
  const target = await resolveDashboardPath(baseUrl, token, timeoutMs);
  const config = {
    baseUrl,
    path: target.path,
    token,
    timeoutMs,
    maxWorkers,
  };

  const benchmarkName = process.env.BENCH_NAME?.trim() || 'Dashboard';
  console.log(`TTSmart local benchmark: ${benchmarkName}`);
  console.log(`Base URL : ${baseUrl}`);
  console.log(
    process.env.BENCH_PATH?.trim()
      ? `Target   : ${target.path}`
      : `Target   : dashboard một trạm (companyId=${target.companyId}, branchId=${target.branchId})`,
  );
  console.log(`Workers  : tối đa ${maxWorkers}/${cpus().length} CPU logic`);
  console.log(`Stages   : ${stages.map((stage) => `${stage.virtualUsers}x${stage.durationSeconds}s`).join(', ')}`);
  console.log('');

  const warmup = await runStage(config, { virtualUsers: 1, durationSeconds: warmupSeconds });
  printResult(warmup, true);

  const results = [];
  for (const stage of stages) {
    const result = await runStage(config, stage);
    results.push(result);
    printResult(result);
  }

  const report = {
    generatedAt: new Date().toISOString(),
    baseUrl,
    target: {
      scenario: benchmarkName,
      companyId: target.companyId,
      branchId: target.branchId,
    },
    configuration: { maxWorkers, timeoutMs, warmupSeconds, stages },
    thresholds: { maxP95Ms, maxErrorRate },
    results,
  };
  const output = process.env.BENCH_OUTPUT?.trim();
  if (output) {
    await writeFile(output, `${JSON.stringify(report, null, 2)}\n`, 'utf8');
    console.log(`\nĐã ghi báo cáo: ${output}`);
  }

  const failedThreshold = results.some(
    (result) => result.latencyMs.p95 > maxP95Ms || result.errorRate > maxErrorRate,
  );
  if (failedThreshold) {
    console.error('\nFAIL: Có stage vượt ngưỡng p95 hoặc error rate.');
    process.exitCode = 2;
  } else {
    console.log('\nPASS: Tất cả stage nằm trong ngưỡng cấu hình.');
  }
}

async function runWorker() {
  const base = requireLocalBaseUrl(workerData.baseUrl);
  const Agent = base.protocol === 'https:' ? https.Agent : http.Agent;
  const agent = new Agent({
    keepAlive: true,
    keepAliveMsecs: 1_000,
    maxSockets: workerData.virtualUsers,
    maxFreeSockets: workerData.virtualUsers,
    scheduling: 'lifo',
  });
  const deadline = performance.now() + workerData.durationSeconds * 1_000;
  const latencies = [];
  const statuses = {};
  const errors = {};
  let failed = 0;

  async function virtualUserLoop() {
    while (performance.now() < deadline) {
      const result = await requestOnce({
        baseUrl: workerData.baseUrl,
        path: workerData.path,
        token: workerData.token,
        timeoutMs: workerData.timeoutMs,
        agent,
        captureBody: false,
      });
      latencies.push(result.latencyMs);
      const statusKey = String(result.statusCode);
      statuses[statusKey] = (statuses[statusKey] ?? 0) + 1;
      if (result.error || result.statusCode < 200 || result.statusCode >= 400) {
        failed += 1;
        const errorKey = result.error || `HTTP ${result.statusCode}`;
        errors[errorKey] = (errors[errorKey] ?? 0) + 1;
      }
    }
  }

  await Promise.all(
    Array.from({ length: workerData.virtualUsers }, () => virtualUserLoop()),
  );
  agent.destroy();
  parentPort.postMessage({ latencies, statuses, errors, failed });
}

if (isMainThread) {
  main().catch((error) => {
    console.error(`Benchmark không chạy được: ${error.message}`);
    process.exitCode = 1;
  });
} else {
  runWorker().catch((error) => {
    parentPort.postMessage({
      latencies: [],
      statuses: {},
      errors: { [error.message]: 1 },
      failed: 1,
    });
  });
}
