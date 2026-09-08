import { useEffect, useState } from 'react';
import { Alert, Pressable, StyleSheet, Switch, Text, TextInput, View } from 'react-native';
import { router } from 'expo-router';
import { useSQLiteContext } from 'expo-sqlite';
import { getSetting, setSetting } from '../src/db';
import { nativeIntents } from '../src/native';

export default function SettingsScreen() {
  const db = useSQLiteContext();
  const [wage, setWage] = useState('1800');
  const [autoDisplay, setAutoDisplay] = useState(true);
  const [saving, setSaving] = useState(false);

  useEffect(() => {
    void (async () => {
      const [storedWage, storedAuto] = await Promise.all([getSetting(db, 'hourlyWage'), getSetting(db, 'autoDisplay')]);
      if (storedWage) setWage(storedWage);
      if (storedAuto != null) setAutoDisplay(storedAuto === 'true');
    })();
  }, [db]);

  const save = async () => {
    const value = Number(wage);
    if (!Number.isFinite(value) || value <= 0) { Alert.alert('時給を確認してください', '0より大きい数字を入力してください。'); return; }
    setSaving(true);
    try {
      await setSetting(db, 'hourlyWage', String(value));
      await setSetting(db, 'autoDisplay', String(autoDisplay));
      nativeIntents.setHourlyWage(value);
      Alert.alert('保存しました', '次回の計測開始からこの時給が固定されます。', [{text: 'OK', onPress: () => router.back()}]);
    } finally { setSaving(false); }
  };

  return <View style={styles.page}>
    <Pressable onPress={() => router.back()}><Text style={styles.back}>‹ 戻る</Text></Pressable>
    <Text style={styles.eyebrow}>SETTINGS</Text><Text style={styles.title}>時給設定</Text>
    <Text style={styles.body}>セッション開始時の時給を、そのセッションの換算額に固定します。過去の明細は変更されません。</Text>
    <Text style={styles.label}>時給（円 / 時間）</Text>
    <TextInput value={wage} onChangeText={setWage} keyboardType="decimal-pad" style={styles.input} placeholder="1800" />
    <View style={styles.row}><View style={styles.rowCopy}><Text style={styles.label}>計測終了時に明細を自動表示</Text><Text style={styles.hint}>ショートカットに「最新の明細を開く」を追加した場合に使います。</Text></View><Switch value={autoDisplay} onValueChange={setAutoDisplay} trackColor={{false: '#d6d0c4', true: '#d88a80'}} thumbColor={autoDisplay ? '#b13e36' : '#f5f2eb'} /></View>
    <Pressable style={styles.button} onPress={save} disabled={saving}><Text style={styles.buttonText}>{saving ? '保存中…' : '保存する'}</Text></Pressable>
    <Text style={styles.note}>初期表示は1,800円です。最低賃金を意味する表示ではありません。</Text>
  </View>;
}

const styles: any = StyleSheet.create({page: {backgroundColor: '#f3f0e9', flex: 1, padding: 24, paddingTop: 64}, back: {color: '#b13e36', fontSize: 15, fontWeight: '700', marginBottom: 36}, eyebrow: {color: '#b13e36', fontSize: 12, fontWeight: '800', letterSpacing: 2}, title: {color: '#272421', fontSize: 34, fontWeight: '800', marginTop: 6}, body: {color: '#625d55', fontSize: 15, lineHeight: 23, marginTop: 12}, label: {color: '#4d4841', fontSize: 14, fontWeight: '700', marginBottom: 8}, input: {backgroundColor: '#fbf8f1', borderColor: '#d9d0c0', borderRadius: 12, borderWidth: 1, color: '#272421', fontSize: 26, marginBottom: 28, padding: 15}, row: {alignItems: 'center', borderColor: '#e1d9ca', borderRadius: 14, borderWidth: 1, flexDirection: 'row', padding: 15}, rowCopy: {flex: 1, paddingRight: 10}, hint: {color: '#958d82', fontSize: 12, lineHeight: 18, marginTop: 4}, button: {alignItems: 'center', backgroundColor: '#b13e36', borderRadius: 12, marginTop: 28, padding: 16}, buttonText: {color: '#fffaf2', fontSize: 16, fontWeight: '700'}, note: {color: '#958d82', fontSize: 12, lineHeight: 18, marginTop: 20}});
