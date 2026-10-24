export type WordForm = "f" | "m" | "n";

export interface Profile {
  id: string;
  display_name: string;
  word_form: WordForm;
  intimate_opt_in: boolean;
  reduced_motion: boolean;
  avatar_path: string | null;
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
  avatar_path?: string | null;
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
    result?: Record<string, unknown>;
  };
  my_seat: number | null;
  game: { title: string; mechanic: string; rules: GameRules; config: GameConfig };
  players: Player[];
  rounds: Round[];
}

export type GameStyle = "echange" | "duel" | "cooperation" | "creation";

export interface Game {
  id: string;
  category_id: string;
  mechanic: string;
  title: string;
  promise: string;
  hook: string;
  style: GameStyle;
  duration_min: number;
  duration_max: number;
  content_level: "standard" | "intime";
  current_version: number | null;
  sort: number;
  is_demo: boolean;
  /** playable : jouable ; coming_soon : visible grisé « Bientôt », non lançable. */
  implementation: "playable" | "coming_soon";
  adult_available: boolean;
  mute_ok: boolean;
  difficulties: string[];
  thumbnail: string | null;
  /** Métadonnées éditoriales (nombre d'items, code de référence, statut des droits…). */
  meta: { items?: number; code?: string; instrument?: string; reference_code?: string; rights_status?: string; duration_is_estimate?: boolean } | null;
}

export interface Category {
  id: string;
  title: string;
  promise: string;
  sort: number;
  is_demo: boolean;
  family_no: number | null;
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
