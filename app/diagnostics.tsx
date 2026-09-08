import { useCallback, useState } from 'react';
import { Pressable, ScrollView, StyleSheet, Text, View } from 'react-native';
import { router, useFocusEffect } from 'expo-router';
import { useSQLiteContext } from 'expo-sqlite';
import { getDiagnostics, type Diagnostic } from '../src/db';
import { nativeIntents } from '../src/native';

export default function DiagnosticsScreen() {
  const db = useSQLiteContext();
  const [native, setNative] = useState(nativeIntents.getDiagnosticSnapshot());
  const [items, setItems] = useState<Diagnostic[]>([]);
  useFocusEffect(useCallback(() => { setNative(nativeIntents.getDiagnosticSnapshot()); void getDiagnostics(db).then(setItems); }, [db]));
  return <ScrollView style={styles.page} contentContainerStyle={styles.content}>
    <Pressable onPress={() => router.back()}><Text style={styles.back}>‹ 戻る</Text></Pressable>
    <Text style={styles.eyebrow}>DEVELOPMENT</Text><Text style={styles.title}>イベント診断</Text>
    <Text style={styles.body}>App IntentsがReact Nativeを起動せずに保存したキューと、取り込み済みの診断情報です。</Text>
    <View style={styles.card}><Row label="ネイティブ連携" value={native.fileURL.includes('未接続') ? '未接続（Expo Go / Web）' : '接続済み'} /><Row label="未取り込みイベント" value={String(native.pendingEventCount)} /><Row label="ネイティブ設定時給" value={native.configuredHourlyWage == null ? '未設定' : `¥${native.configuredHourlyWage}`} /><Row label="計測中セッション" value={native.activeSessions.length ? native.activeSessions.join(', ') : 'なし'} /></View>
    <Text style={styles.section}>診断ログ</Text>
    {items.length === 0 ? <Text style={styles.empty}>診断ログはありません。</Text> : items.map((item) => <View style={styles.log} key={item.id}><Text style={styles.logKind}>{item.kind}</Text><Text style={styles.logMessage}>{item.message}</Text><Text style={styles.logDate}>{new Date(item.createdAt).toLocaleString('ja-JP')}</Text></View>)}
    <Text style={styles.note}>開始の重複、終了対象なし、時計の巻き戻しなどは記録されます。終了イベントが届かない場合は、ホーム画面から手動終了できます。</Text>
  </ScrollView>;
}

function Row({label, value}: {label: string; value: string}) { return <View style={styles.row}><Text style={styles.rowLabel}>{label}</Text><Text style={styles.rowValue}>{value}</Text></View>; }

const styles: any = StyleSheet.create({page: {backgroundColor: '#f3f0e9', flex: 1}, content: {padding: 24, paddingTop: 64, paddingBottom: 50}, back: {color: '#b13e36', fontSize: 15, fontWeight: '700', marginBottom: 36}, eyebrow: {color: '#b13e36', fontSize: 12, fontWeight: '800', letterSpacing: 2}, title: {color: '#272421', fontSize: 34, fontWeight: '800', marginTop: 6}, body: {color: '#625d55', fontSize: 15, lineHeight: 23, marginTop: 12}, card: {backgroundColor: '#fbf8f1', borderColor: '#e1d9ca', borderRadius: 14, borderWidth: 1, marginTop: 24, paddingHorizontal: 16}, row: {borderBottomColor: '#e1d9ca', borderBottomWidth: 1, flexDirection: 'row', paddingVertical: 15}, rowLabel: {color: '#756e64', flex: 1, fontSize: 13}, rowValue: {color: '#272421', flex: 1, fontSize: 13, fontWeight: '700', textAlign: 'right'}, section: {color: '#756e64', fontSize: 13, fontWeight: '800', letterSpacing: 1.1, marginTop: 28}, empty: {color: '#958d82', fontSize: 13, marginTop: 12}, log: {backgroundColor: '#fbf8f1', borderColor: '#e1d9ca', borderRadius: 10, borderWidth: 1, marginTop: 8, padding: 12}, logKind: {color: '#b13e36', fontSize: 11, fontWeight: '800'}, logMessage: {color: '#4d4841', fontSize: 14, marginTop: 4}, logDate: {color: '#958d82', fontSize: 11, marginTop: 6}, note: {color: '#958d82', fontSize: 11, lineHeight: 17, marginTop: 26}});
