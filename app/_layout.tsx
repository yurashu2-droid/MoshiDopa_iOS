import { Stack } from 'expo-router';
import { SQLiteProvider } from 'expo-sqlite';
import { initDatabase } from '../src/db';

export default function RootLayout() {
  return (
    <SQLiteProvider databaseName="moshidopa.db" onInit={initDatabase} useSuspense>
      <Stack screenOptions={{headerShown: false, animation: 'fade'}} />
    </SQLiteProvider>
  );
}
