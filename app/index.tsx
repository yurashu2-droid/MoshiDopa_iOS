import { useCallback, useEffect, useState } from 'react';
import { Pressable, RefreshControl, ScrollView, StyleSheet, Text, View } from 'react-native';
import { router, useFocusEffect } from 'expo-router';
import { useSQLiteContext } from 'expo-sqlite';
import { getSetting, listSessions, manuallyCloseSession, sessionAmount, syncNativeEvents, type Session } from '../src/db';

const yen = new Intl.NumberFormat('ja-JP');

function formatDuration(ms: number) {
  const totalSeconds = Math.floor(Math.max(0, ms) / 1000);
  const hours = Math.floor(totalSeconds / 3600);
  const minutes = Math.floor((totalSeconds % 3600) / 60);
  const seconds = totalSeconds % 60;
  return `${String(hours).padStart(2, '0')}:${String(minutes).padStart(2, '0')}:${String(seconds).padStart(2, '0')}`;
}

export default function HomeScreen() {
  const db = useSQLiteContext();
  const [sessions, setSessions] = useState<Session[]>([]);
  const [now, setNow] = useState(Date.now());
  const [refreshing, setRefreshing] = useState(false);
  const [hourlyWage, setHourlyWage] = useState<number | null>(null);

  const refresh = useCallback(async () => {
    const shouldOpenLastSession = await syncNativeEvents(db);
    const [nextSessions, wage] = await Promise.all([listSessions(db), getSetting(db, 'hourlyWage')]);
    setSessions(nextSessions);
    setHourlyWage(wage ? Number(wage) : null);
    if (shouldOpenLastSession) {
      const latestFinished = nextSessions.find((session) => session.state === 'finished' || session.state === 'manuallyClosed');
      if (latestFinished) router.replace(`/session/${latestFinished.id}`);
    }
  }, [db]);

  useFocusEffect(useCallback(() => {
    void refresh();
  }, [refresh]));

  useEffect(() => {
    const timer = setInterval(() => setNow(Date.now()), 100);
    return () => clearInterval(timer);
  }, []);

  const active = sessions.find((session) => session.state === 'running' || session.state === 'needsWage');
  const activeElapsedMs = active ? (active.state === 'running' ? now - active.startedAt : active.elapsedMs) : 0;
  const activeAmount = active ? sessionAmount({elapsedMs: activeElapsedMs, hourlyWage: active.hourlyWage}) : null;

  const onRefresh = async () => {
    setRefreshing(true);
    await refresh();
    setRefreshing(false);
  };

  const closeManually = async () => {
    if (!active) return;
    await manuallyCloseSession(db, active, Date.now());
    await refresh();
  };

  return (
    <ScrollView style={styles.page} contentContainerStyle={styles.content} refreshControl={<RefreshControl refreshing={refreshing} onRefresh={onRefresh} />}>
      <View style={styles.header}>
        <View>
          <Text style={styles.eyebrow}>MOSHIDOPA</Text>
          <Text style={styles.title}>もしドパ</Text>
          <Text style={styles.subtitle}>もしもドパガキが働いたら？</Text>
        </View>
        <Text style={styles.statusDot}>●</Text>
      </View>

      {active ? (
        <View style={styles.card}>
          <Text style={styles.cardLabel}>計測中</Text>
          <Text style={styles.activity}>{active.displayName}</Text>
          <Text style={styles.runningAmount}>{activeAmount == null ? '---' : `¥${yen.format(activeAmount)}`}</Text>
          <Text style={styles.caption}>働いていたら（仮の換算額）</Text>
          <View style={styles.metaRow}>
            <Text style={styles.meta}>経過 {formatDuration(activeElapsedMs)}</Text>
            <Text style={styles.meta}>{active.hourlyWage == null ? '時給未設定' : `時給 ¥${yen.format(active.hourlyWage)}`}</Text>
          </View>
          {active.state === 'needsWage' && <Text style={styles.warning}>開始時に時給が未設定でした。勝手な金額では確定していません。</Text>}
          <Pressable style={styles.manualButton} onPress={closeManually}><Text style={styles.manualButtonText}>届かない場合：手動で終了</Text></Pressable>
          <Pressable style={styles.secondaryButton} onPress={() => router.push('/settings')}><Text style={styles.secondaryButtonText}>時給を設定</Text></Pressable>
        </View>
      ) : (
        <View style={styles.card}>
          <Text style={styles.cardLabel}>待機中</Text>
          <Text style={styles.emptyTitle}>ショートカットから計測できます</Text>
          <Text style={styles.body}>YouTubeを開いたときに開始、離れたときに終了。開始イベントではこの画面を開きません。</Text>
          <Pressable style={styles.primaryButton} onPress={() => router.push('/guide')}><Text style={styles.primaryButtonText}>連携ガイドを見る</Text></Pressable>
        </View>
      )}

      <View style={styles.settingStrip}>
        <Text style={styles.stripLabel}>設定時給</Text>
        <Text style={styles.stripValue}>{hourlyWage ? `¥${yen.format(hourlyWage)} / 時` : '未設定'}</Text>
        <Pressable onPress={() => router.push('/settings')}><Text style={styles.link}>変更</Text></Pressable>
      </View>

      <Text style={styles.sectionTitle}>メニュー</Text>
      <View style={styles.menuGrid}>
        <MenuButton label="時給設定" hint="換算単価" onPress={() => router.push('/settings')} />
        <MenuButton label="連携ガイド" hint="ショートカット" onPress={() => router.push('/guide')} />
        <MenuButton label="最近の明細" hint={`${sessions.length} 件`} onPress={() => active ? router.push(`/session/${active.id}`) : sessions[0] ? router.push(`/session/${sessions[0].id}`) : undefined} />
        <MenuButton label="イベント診断" hint="開発用" onPress={() => router.push('/diagnostics')} />
      </View>

      <Text style={styles.disclaimer}>表示額は「働いていたら」の仮定による換算額です。実際の給与・損失・売上ではありません。</Text>
    </ScrollView>
  );
}

function MenuButton({label, hint, onPress}: {label: string; hint: string; onPress: () => void}) {
  return <Pressable style={styles.menuButton} onPress={onPress}><Text style={styles.menuLabel}>{label}</Text><Text style={styles.menuHint}>{hint}</Text></Pressable>;
}

const styles: any = StyleSheet.create({
  page: {flex: 1, backgroundColor: '#f3f0e9'},
  content: {padding: 22, paddingTop: 64, paddingBottom: 50, gap: 18},
  header: {flexDirection: 'row', justifyContent: 'space-between', alignItems: 'flex-start'},
  eyebrow: {color: '#b13e36', fontSize: 12, letterSpacing: 2, fontWeight: '800'},
  title: {color: '#272421', fontSize: 36, fontWeight: '800', marginTop: 4},
  subtitle: {color: '#756e64', fontSize: 13, marginTop: 4},
  statusDot: {color: '#b13e36', fontSize: 18},
  card: {backgroundColor: '#fbf8f1', borderColor: '#e1d9ca', borderRadius: 20, borderWidth: 1, padding: 24, shadowColor: '#4e463d', shadowOpacity: 0.08, shadowRadius: 16, shadowOffset: {width: 0, height: 7}},
  cardLabel: {color: '#b13e36', fontSize: 12, fontWeight: '800', letterSpacing: 1.5, textTransform: 'uppercase'},
  activity: {color: '#272421', fontSize: 25, fontWeight: '700', marginTop: 10},
  runningAmount: {color: '#b13e36', fontSize: 54, fontWeight: '800', letterSpacing: -2, marginTop: 18},
  caption: {color: '#756e64', fontSize: 13, marginTop: 2},
  emptyTitle: {color: '#272421', fontSize: 22, fontWeight: '700', marginTop: 12},
  body: {color: '#625d55', fontSize: 15, lineHeight: 23, marginTop: 10},
  metaRow: {borderTopColor: '#e1d9ca', borderTopWidth: 1, flexDirection: 'row', justifyContent: 'space-between', marginTop: 22, paddingTop: 13},
  meta: {color: '#625d55', fontSize: 13},
  warning: {backgroundColor: '#fff0da', color: '#8c4e21', fontSize: 13, lineHeight: 19, marginTop: 16, padding: 10},
  primaryButton: {alignItems: 'center', backgroundColor: '#b13e36', borderRadius: 12, marginTop: 20, padding: 15},
  primaryButtonText: {color: '#fffaf2', fontSize: 15, fontWeight: '700'},
  secondaryButton: {alignItems: 'center', backgroundColor: '#efe9dc', borderRadius: 10, marginTop: 20, padding: 12},
  secondaryButtonText: {color: '#6e352f', fontSize: 14, fontWeight: '700'},
  manualButton: {alignItems: 'center', borderColor: '#d6cfc2', borderRadius: 10, borderWidth: 1, marginTop: 12, padding: 11},
  manualButtonText: {color: '#756e64', fontSize: 13, fontWeight: '700'},
  settingStrip: {alignItems: 'center', backgroundColor: '#e7e0d4', borderRadius: 12, flexDirection: 'row', padding: 15},
  stripLabel: {color: '#756e64', fontSize: 13},
  stripValue: {color: '#272421', flex: 1, fontSize: 15, fontWeight: '700', marginLeft: 12},
  link: {color: '#b13e36', fontSize: 14, fontWeight: '700'},
  sectionTitle: {color: '#756e64', fontSize: 13, fontWeight: '800', letterSpacing: 1.2, marginTop: 5},
  menuGrid: {flexDirection: 'row', flexWrap: 'wrap', gap: 10},
  menuButton: {backgroundColor: '#fbf8f1', borderColor: '#e1d9ca', borderRadius: 14, borderWidth: 1, minWidth: '47%', padding: 16},
  menuLabel: {color: '#272421', fontSize: 15, fontWeight: '700'},
  menuHint: {color: '#958d82', fontSize: 12, marginTop: 5},
  disclaimer: {color: '#958d82', fontSize: 11, lineHeight: 17, marginTop: 10},
});
