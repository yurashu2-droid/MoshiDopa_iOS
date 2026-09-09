import { requireNativeModule } from 'expo-modules-core';

export type NativeSession = {
  id: string;
  activityId: string;
  displayName: string;
  mode: 'SPEND' | 'INVEST';
  startedAt: number;
  endedAt: number | null;
  elapsedMs: number | null;
  hourlyWage: number | null;
  state: 'running' | 'needsWage' | 'finished';
  diagnostics: string[];
};

export type NativeEvent = {
  eventId: string;
  kind: 'start' | 'end' | 'diagnostic';
  createdAt: number;
  diagnostic?: string;
  session?: NativeSession;
};

type NativeModule = {
  setHourlyWage(wage: number): number;
  getConfiguredHourlyWage(): number | null;
  getPendingEvents(): Promise<NativeEvent[]>;
  acknowledgeEvents(eventIds: string[]): Promise<void>;
  consumeOpenLastSessionRequest(): boolean;
  getDiagnosticSnapshot(): {
    configuredHourlyWage: number | null;
    pendingEventCount: number;
    activeSessions: string[];
    fileURL: string;
  };
};

export type NativeAvailability = {
  available: boolean;
  error: string | null;
};

export class NativeModuleUnavailableError extends Error {
  constructor(operation: string, cause?: unknown) {
    super(`MoshidopaIntents is unavailable while running ${operation}. Build a development client with the local iOS module; Expo Go and Web do not include it.`);
    this.name = 'NativeModuleUnavailableError';
    if (cause instanceof Error) this.cause = cause;
  }
}

let cachedModule: NativeModule | null | undefined;
let nativeLoadError: unknown;
let unavailableWarningShown = false;

function isDevelopmentBuild() {
  return typeof __DEV__ !== 'undefined' && __DEV__;
}

function describeError(error: unknown) {
  return error instanceof Error ? error.message : String(error);
}

function reportUnavailable(operation: string): void {
  const error = new NativeModuleUnavailableError(operation, nativeLoadError);
  if (isDevelopmentBuild()) throw error;
  if (!unavailableWarningShown) {
    unavailableWarningShown = true;
    console.warn(error.message);
  }
}

function getNativeModule() {
  if (cachedModule !== undefined) return cachedModule;
  try {
    cachedModule = requireNativeModule<NativeModule>('MoshidopaIntents');
  } catch (error) {
    nativeLoadError = error;
    // Keep the unavailable state explicit. In development, every operation
    // fails loudly so a missing autolinked module cannot look successful.
    cachedModule = null;
  }
  return cachedModule;
}

export const nativeIntents = {
  isAvailable: () => Boolean(getNativeModule()),
  getAvailability: (): NativeAvailability => {
    const available = Boolean(getNativeModule());
    return { available, error: available ? null : describeError(nativeLoadError) };
  },
  setHourlyWage: (wage: number): number | null => {
    const module = getNativeModule();
    if (!module) { reportUnavailable('setHourlyWage'); return null; }
    return module.setHourlyWage(wage);
  },
  getConfiguredHourlyWage: (): number | null => {
    const module = getNativeModule();
    if (!module) { reportUnavailable('getConfiguredHourlyWage'); return null; }
    return module.getConfiguredHourlyWage();
  },
  getPendingEvents: async (): Promise<NativeEvent[]> => {
    const module = getNativeModule();
    if (!module) { reportUnavailable('getPendingEvents'); return []; }
    return module.getPendingEvents();
  },
  acknowledgeEvents: async (eventIds: string[]): Promise<void> => {
    const module = getNativeModule();
    if (!module) { reportUnavailable('acknowledgeEvents'); return; }
    await module.acknowledgeEvents(eventIds);
  },
  consumeOpenLastSessionRequest: (): boolean => {
    const module = getNativeModule();
    if (!module) { reportUnavailable('consumeOpenLastSessionRequest'); return false; }
    return module.consumeOpenLastSessionRequest();
  },
  getDiagnosticSnapshot: () => {
    const module = getNativeModule();
    if (!module) {
      reportUnavailable('getDiagnosticSnapshot');
      return {
        available: false,
        error: describeError(nativeLoadError),
        configuredHourlyWage: null,
        pendingEventCount: 0,
        activeSessions: [],
        fileURL: 'ネイティブモジュール未接続（Expo Go / Web）',
      };
    }
    return { available: true, error: null, ...module.getDiagnosticSnapshot() };
  },
};
