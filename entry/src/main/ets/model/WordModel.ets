// entry/src/main/ets/model/WordModel.ets

export interface WordEntry {
  wordRank: number;
  headWord: string;
  bookId: string;
  content: WordContentWrapper;
}

export interface WordContentWrapper {
  word: WordDetail;
}

export interface WordDetail {
  wordHead: string;
  wordId: string;
  content: WordDeepContent;
}

export interface WordDeepContent {
  usphone?: string;
  ukphone?: string;
  usspeech?: string;
  ukspeech?: string;
  trans?: TransItem[];
  sentence?: SentenceWrapper;
  phrase?: PhraseWrapper;
  syno?: SynoWrapper;
  exam?: ExamItem[];         // 修复：使用明确定义的 ExamItem 数组替换 any[]
  relWord?: RelWordWrapper;  // 修复：使用明确定义的 RelWordWrapper 替换 any
}

// ---------------- 翻译 ----------------
export interface TransItem {
  tranCn: string;
  pos: string;
  tranOther?: string;
  descCn?: string;
  descOther?: string;
}

// ---------------- 例句 ----------------
export interface SentenceWrapper {
  sentences: SentenceItem[];
  desc: string;
}

export interface SentenceItem {
  sContent: string;
  sCn: string;
}

// ---------------- 短语 ----------------
export interface PhraseWrapper {
  phrases: PhraseItem[];
  desc: string;
}

export interface PhraseItem {
  pContent: string;
  pCn: string;
}

// ---------------- 同近义词 ----------------
export interface SynoWrapper {
  synos: SynoItem[];
  desc: string;
}

export interface SynoItem {
  pos: string;
  tran: string;
  hwds: HwdItem[]; // 修复：使用独立的 HwdItem 类型替换了字面量 { w: string }
}

export interface HwdItem {
  w: string;
}

// ---------------- 考试真题 (新增) ----------------
export interface ExamItem {
  question: string;
  answer: ExamAnswer;
  examType: number;
  choices: ExamChoice[];
}

export interface ExamAnswer {
  explain: string;
  rightIndex: number;
}

export interface ExamChoice {
  choiceIndex: number;
  choice: string;
}

// ---------------- 同根词 (新增) ----------------
export interface RelWordWrapper {
  rels: RelItem[];
  desc: string;
}

export interface RelItem {
  pos: string;
  words: RelWordDetail[];
}

export interface RelWordDetail {
  hwd: string;
  tran: string;
}