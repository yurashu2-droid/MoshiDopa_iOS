import { useCallback, useState } from 'react';
import { Pressable, ScrollView, StyleSheet, Text, View } from 'react-native';
import { router, useFocusEffect, useLocalSearchParams } from 'expo-router';
import { useSQLiteContext } from 'expo-sqlite';
import { listSessions, sessionAmount, type Session } from '../../src/db';

const yen = new Intl.NumberFormat('ja-JP');

export default function SessionDetailScreen() {
  const db = useSQLiteContext();
  const {id} = useLocalSearchParams<{id: string}>();
  const [session, setSession] = useState<Session | null>(null);
  useFocusEffect(useCallback(() => { void listSessions(db).then((items) => setSession(items.find((item) => item.id === id) ?? null)); }, [db, id]));
  if (!session) return <View style={styles.page}><Pressable onPress={() => router.back()}><Text style={styles.back}>‹ 戻る</Text></Pressable><Text style={styles.empty}>明細を読み込めませんでした。</Text></View>;
  const amount = sessionAmount(session);
  const date = new Date(session.endedAt ?? session.startedAt).toLocaleString('ja-JP', {dateStyle: 'medium', timeStyle: 'short'});
  return <ScrollView style={styles.page} contentContainerStyle={styles.content}>
    <Pressable onPress={() => router.back()}><Text style={styles.back}>‹ 閉じる</Text></Pressable>
    <View style={styles.paper}>
      <Text style={styles.brand}>もしドパ ～もしもドパガキが働いたら？～</Text>
      <Text style={styles.activity}>{session.displayName}</Text>
      <Text style={styles.ifWorked}>働いていたら</Text>
      <Text style={styles.amount}>{amount == null ? '---' : `¥${yen.format(amount)}`}</Text>
      {session.mode === 'SPEND' && <><View style={styles.strike} /><Text style={styles.noTransfer}>なお、振込はありません</Text></>}
      <Text style={styles.duration}>経過時間　{formatDuration(session.elapsedMs)}</Text>
      <Text style={styles.rate}>設定時給　{session.hourlyWage == null ? '未設定' : `¥${yen.format(session.hourlyWage)}`}</Text>
      <Text style={styles.date}>{date}</Text>
      <Text style={styles.disclaimer}>この金額は開始・終了イベント間の時間を時給で換算した仮定額です。実際の未払い賃金や金銭的損失を示すものではありません。</Text>
    </View>
  </ScrollView>;
}

function formatDuration(ms: number) { const s = Math.floor(Math.max(ms, 0) / 1000); return `${String(Math.floor(s / 3600)).padStart(2, '0')}:${String(Math.floor((s % 3600) / 60)).padStart(2, '0')}:${String(s % 60).padStart(2, '0')}`; }

const styles: any = StyleSheet.create({page: {backgroundColor: '#e9e5dc', flex: 1}, content: {padding: 24, paddingTop: 64, paddingBottom: 50}, back: {color: '#8c3731', fontSize: 15, fontWeight: '700', marginBottom: 20}, paper: {backgroundColor: '#fbf8ef', borderColor: '#ded4c4', borderWidth: 1, minHeight: 560, padding: 26, shadowColor: '#51483e', shadowOpacity: 0.13, shadowRadius: 14, shadowOffset: {width: 0, height: 8}}, brand: {color: '#958d82', fontSize: 11, lineHeight: 17}, activity: {color: '#272421', fontSize: 28, fontWeight: '800', marginTop: 58}, ifWorked: {color: '#756e64', fontSize: 16, marginTop: 34}, amount: {color: '#b13e36', fontSize: 56, fontWeight: '800', letterSpacing: -2, marginTop: 4}, strike: {backgroundColor: '#b13e36', height: 1, marginTop: -27, transform: [{rotate: '-3deg'}], width: '94%'}, noTransfer: {color: '#b13e36', fontSize: 13, marginTop: 17}, duration: {borderTopColor: '#e1d9ca', borderTopWidth: 1, color: '#4d4841', fontSize: 15, marginTop: 34, paddingTop: 18}, rate: {color: '#756e64', fontSize: 13, marginTop: 10}, date: {color: '#958d82', fontSize: 12, marginTop: 34}, disclaimer: {color: '#958d82', fontSize: 11, lineHeight: 17, marginTop: 42}, empty: {color: '#625d55', fontSize: 17, marginTop: 40}});
