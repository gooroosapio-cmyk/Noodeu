export type WordForm = "f" | "m" | "n";

export interface Profile {
  id: string;
  display_name: string;
  word_form: WordForm;
  intimate_opt_in: boolean;
  reduced_motion: boolean;
}

export type SessionStatus = "lobby" | "playing" | "paused" | "ended" | "closed" | "abandoned";

export interface Word {
  id: string;
  f: string;
  m: string;
}

export interface StepConfig {
  key: string;
  kind: "pick_words";
  about: "self" | "partner";
}

export interface GameConfig {
  mechanic: "portrait_words";
  rounds: number;
  pick: number;
  steps: StepConfig[];
  settings?: Record<string, { label: string; options: (string | number)[]; default: string | number }>;
}

export interface GameRules {
  objective: string;
  how_to: string[];
  details: string[];
  privacy: string;
  step_texts: Record<string, { title: string; prompt: string; hint: string; confirm: string }>;
}

export interface Answer {
  step: string;
  seat: number;
  skipped: boolean;
  payload: { words: string[] } | null;
}

export interface Round {
  round_no: number;
  card: { words: Word[] };
  revealed: boolean;
  answers: Answer[];
}

export interface Player {
  seat: number;
  user_id: string | null;
  is_me: boolean;
  display_name: string;
  word_form: WordForm;
  ready: boolean;
  keep_memory: boolean;
}

export interface SessionState {
  session: {
    id: string;
    game_id: string;
    status: SessionStatus;
    settings: Record<string, string | number>;
    current_round: number;
    total_rounds: number;
    paused_by: string | null;
    state_version: number;
    read_only: boolean;
    created_at: string;
    ended_at: string | null;
  };
  my_seat: number | null;
  game: { title: string; mechanic: string; rules: GameRules; config: GameConfig };
  players: Player[];
  rounds: Round[];
}

export interface Game {
  id: string;
  category_id: string;
  mechanic: string;
  title: string;
  promise: string;
  style: "echange" | "duel" | "cooperation";
  duration_min: number;
  duration_max: number;
  content_level: "standard" | "intime";
  current_version: number;
  sort: number;
  is_demo: boolean;
}

export interface Category {
  id: string;
  title: string;
  promise: string;
  sort: number;
  is_demo: boolean;
}

export interface ChatMessage {
  id: string;
  user_id: string | null;
  client_id: string;
  body: string;
  created_at: string;
  pending?: boolean;
  failed?: boolean;
}
