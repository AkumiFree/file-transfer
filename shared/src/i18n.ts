import type { AppLanguage } from './protocol.js';
import { languages } from './protocol.js';

const DEFAULT_LANGUAGE = 'en' as const;

export const messages = {
  en: {
    appName: 'FileTransfer',
    tagline: 'Move files. Stay close.',
    home: 'Home',
    files: 'Files',
    transfers: 'Transfers',
    chat: 'Chat',
    friends: 'Friends',
    settings: 'Settings',
    serverUrl: 'Server URL',
    testConnection: 'Test Connection',
    login: 'Login',
    register: 'Register',
    logout: 'Logout',
    sendFiles: 'Send Files',
    receiveFiles: 'Receive Files',
    online: 'Online',
    offline: 'Offline',
    saveToFiles: 'Save to Files',
    saveAndDelete: 'Save to Folder & Delete',
    welcome: 'Welcome back',
    chooseLanguage: 'Language',
  },
  vi: {
    appName: 'FileTransfer',
    tagline: 'Gửi file, giữ kết nối.',
    home: 'Trang chủ',
    files: 'Tệp',
    transfers: 'Truyền',
    chat: 'Trò chuyện',
    friends: 'Bạn bè',
    settings: 'Cài đặt',
    serverUrl: 'URL máy chủ',
    testConnection: 'Kiểm tra kết nối',
    login: 'Đăng nhập',
    register: 'Đăng ký',
    logout: 'Đăng xuất',
    sendFiles: 'Gửi tệp',
    receiveFiles: 'Nhận tệp',
    online: 'Trực tuyến',
    offline: 'Ngoại tuyến',
    saveToFiles: 'Lưu vào Files',
    saveAndDelete: 'Lưu vào thư mục & Xóa',
    welcome: 'Chào mừng trở lại',
    chooseLanguage: 'Ngôn ngữ',
  },
  'zh-Hans': {
    appName: 'FileTransfer',
    tagline: '传输文件，保持联系。',
    home: '首页',
    files: '文件',
    transfers: '传输',
    chat: '聊天',
    friends: '朋友',
    settings: '设置',
    serverUrl: '服务器地址',
    testConnection: '测试连接',
    login: '登录',
    register: '注册',
    logout: '退出登录',
    sendFiles: '发送文件',
    receiveFiles: '接收文件',
    online: '在线',
    offline: '离线',
    saveToFiles: '存储到文件',
    saveAndDelete: '存储到文件夹并删除',
    welcome: '欢迎回来',
    chooseLanguage: '语言',
  },
  'zh-Hant': {
    appName: 'FileTransfer',
    tagline: '傳輸檔案，保持聯繫。',
    home: '首頁',
    files: '檔案',
    transfers: '傳輸',
    chat: '聊天',
    friends: '朋友',
    settings: '設定',
    serverUrl: '伺服器網址',
    testConnection: '測試連線',
    login: '登入',
    register: '註冊',
    logout: '登出',
    sendFiles: '傳送檔案',
    receiveFiles: '接收檔案',
    online: '線上',
    offline: '離線',
    saveToFiles: '儲存到檔案',
    saveAndDelete: '儲存到資料夾並刪除',
    welcome: '歡迎回來',
    chooseLanguage: '語言',
  },
  ja: {
    appName: 'FileTransfer',
    tagline: 'ファイルを送り、つながる。',
    home: 'ホーム',
    files: 'ファイル',
    transfers: '転送',
    chat: 'チャット',
    friends: 'フレンド',
    settings: '設定',
    serverUrl: 'サーバーURL',
    testConnection: '接続をテスト',
    login: 'ログイン',
    register: '登録',
    logout: 'ログアウト',
    sendFiles: 'ファイルを送信',
    receiveFiles: 'ファイルを受信',
    online: 'オンライン',
    offline: 'オフライン',
    saveToFiles: 'ファイルに保存',
    saveAndDelete: 'フォルダに保存して削除',
    welcome: 'おかえりなさい',
    chooseLanguage: '言語',
  },
} as const;

export type MessageKey = keyof (typeof messages)[typeof DEFAULT_LANGUAGE];
export type TranslationCatalog = Record<MessageKey, string>;

export function isAppLanguage(value: string): value is AppLanguage {
  return languages.some((language) => language.code === value);
}

export function getCatalog(language: AppLanguage): TranslationCatalog {
  return messages[language] ?? messages[DEFAULT_LANGUAGE];
}

export function getLanguageLabel(language: AppLanguage): string {
  return languages.find((item) => item.code === language)?.nativeLabel ?? 'English';
}
