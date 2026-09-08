import { ScrollView, StyleSheet, Text, View, Pressable } from 'react-native';
import { router } from 'expo-router';

export default function GuideScreen() {
  return <ScrollView style={styles.page} contentContainerStyle={styles.content}>
    <Pressable onPress={() => router.back()}><Text style={styles.back}>‹ 戻る</Text></Pressable>
    <Text style={styles.eyebrow}>SHORTCUTS</Text><Text style={styles.title}>連携ガイド</Text>
    <Text style={styles.lead}>最初はYouTube用の個人オートメーションを、ユーザー自身で二つ作ります。</Text>
    <Step n="1" title="開始オートメーション"><Text>ショートカットの「オートメーション」→「アプリ」→ YouTube →「開いている」→「すぐに実行」を選びます。アクションに「もしドパ：計測開始」を追加し、活動識別子は <Text style={styles.code}>youtube</Text> にします。</Text></Step>
    <Step n="2" title="終了オートメーション"><Text>同じくYouTubeの「閉じている」を選び、「もしドパ：計測終了」を追加します。終了アクションは記録だけを保存し、もしドパを前面には出しません。</Text></Step>
    <Step n="3" title="明細を自動表示（任意）"><Text>アプリの設定でONにした場合だけ、終了アクションの後ろに「もしドパ：最新の明細を開く」を追加します。OFFならこのアクションを追加しないため、終了時に画面は切り替わりません。</Text></Step>
    <View style={styles.note}><Text style={styles.noteTitle}>大切な制約</Text><Text style={styles.noteBody}>これはユーザーが作成した開始・終了イベント間の時間です。Screen Timeの使用時間と同じではありません。アプリから個人用オートメーションを無断で作成することはできません。</Text></View>
    <Pressable style={styles.button} onPress={() => router.push('/diagnostics')}><Text style={styles.buttonText}>イベント診断を見る</Text></Pressable>
  </ScrollView>;
}

function Step({n, title, children}: {n: string; title: string; children: React.ReactNode}) { return <View style={styles.step}><Text style={styles.number}>{n}</Text><View style={styles.stepCopy}><Text style={styles.stepTitle}>{title}</Text><Text style={styles.stepBody}>{children}</Text></View></View>; }

const styles: any = StyleSheet.create({page: {backgroundColor: '#f3f0e9', flex: 1}, content: {padding: 24, paddingTop: 64, paddingBottom: 50}, back: {color: '#b13e36', fontSize: 15, fontWeight: '700', marginBottom: 36}, eyebrow: {color: '#b13e36', fontSize: 12, fontWeight: '800', letterSpacing: 2}, title: {color: '#272421', fontSize: 34, fontWeight: '800', marginTop: 6}, lead: {color: '#625d55', fontSize: 16, lineHeight: 24, marginTop: 13}, step: {borderBottomColor: '#e1d9ca', borderBottomWidth: 1, flexDirection: 'row', paddingVertical: 20}, number: {alignItems: 'center', backgroundColor: '#b13e36', borderRadius: 18, color: '#fffaf2', fontSize: 16, fontWeight: '800', height: 36, lineHeight: 36, marginRight: 14, textAlign: 'center', width: 36}, stepCopy: {flex: 1}, stepTitle: {color: '#272421', fontSize: 17, fontWeight: '800'}, stepBody: {color: '#625d55', fontSize: 14, lineHeight: 22, marginTop: 7}, code: {backgroundColor: '#e7e0d4', color: '#6e352f', fontWeight: '700', paddingHorizontal: 3}, note: {backgroundColor: '#fff0da', borderRadius: 14, marginTop: 22, padding: 16}, noteTitle: {color: '#8c4e21', fontSize: 14, fontWeight: '800'}, noteBody: {color: '#8c4e21', fontSize: 13, lineHeight: 20, marginTop: 6}, button: {alignItems: 'center', backgroundColor: '#b13e36', borderRadius: 12, marginTop: 24, padding: 15}, buttonText: {color: '#fffaf2', fontSize: 15, fontWeight: '700'}});
