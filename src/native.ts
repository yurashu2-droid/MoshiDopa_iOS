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

let cachedModule: NativeModule | null | undefined;

function getNativeModule() {
  if (cachedModule !== undefined) return cachedModule;
  try {
    cachedModule = requireNativeModule<NativeModule>('MoshidopaIntents');
  } catch {
    // Web and Expo Go intentionally have no native App Intents module.
    cachedModule = null;
  }
  return cachedModule;
}

export const nativeIntents = {
  isAvailable: () => Boolean(getNativeModule()),
  setHourlyWage: (wage: number) => getNativeModule()?.setHourlyWage(wage) ?? wage,
  getConfiguredHourlyWage: () => getNativeModule()?.getConfiguredHourlyWage() ?? null,
  getPendingEvents: async () => (await getNativeModule()?.getPendingEvents()) ?? [],
  acknowledgeEvents: async (eventIds: string[]) => { await getNativeModule()?.acknowledgeEvents(eventIds); },
  consumeOpenLastSessionRequest: () => getNativeModule()?.consumeOpenLastSessionRequest() ?? false,
  getDiagnosticSnapshot: () => getNativeModule()?.getDiagnosticSnapshot() ?? {
    configuredHourlyWage: null,
    pendingEventCount: 0,
    activeSessions: [],
    fileURL: 'ネイティブモジュール未接続（Expo Go / Web）',
  },
};
