# Matrice des jeux et états — lot3

Sources : fixtures versionnées, journaux de captures et 88 scénarios de cycle de vie. Chaque ligne distingue ID ET mécanique : certains IDs historiques ont été réaffectés. Les jeux historiques ne sont pas réintroduits au catalogue.

« Rendu réussi » signifie absence de débordement et d’erreur JavaScript, pas validation de tous les coups. Les petites cibles détectées de N2-035 ont été corrigées et retestées strictement. Les contrôles partagés loading/reconnect/quit ne prouvent pas une synchronisation réelle. Les tests et packs sont listés comme hors lot, sans prétendre leur couverture.

## actuel

| Jeu / mécanique | Salon | Jeu | Révélation | Résultats | Erreur / réseau / quitter |
|---|---|---|---|---|---|
| N2-076 · 4 rendus réussis (`tic_tac_toe`) | 6 rendus réussis | 4 rendus réussis | 4 rendus réussis | 8 rendus réussis | Cycle commun réussi ; coups non exhaustifs |
| N2-079 · 4 rendus réussis (`dots_boxes`) | 6 rendus réussis | 4 rendus réussis | NON TESTÉ dans ces journaux | 4 rendus réussis | Cycle commun réussi ; coups non exhaustifs |
| N2-083 · 4 rendus réussis (`rps`) | 6 rendus réussis | 4 rendus réussis | 13 rendus réussis | 4 rendus réussis | Cycle commun réussi ; coups non exhaustifs |
| nd-de-chanceux · 4 rendus réussis (`nd_pig`) | 6 rendus réussis | 4 rendus réussis | NON TESTÉ dans ces journaux | 4 rendus réussis | Cycle commun réussi ; coups non exhaustifs |
| N2-078 · 12 rendus réussis (`battleship`) | 6 rendus réussis | 12 rendus réussis | NON TESTÉ dans ces journaux | 4 rendus réussis | Cycle commun réussi ; coups non exhaustifs |
| N2-003 · 2 rendus réussis (`nd_never`) | NON TESTÉ dans ces journaux | 2 rendus réussis | 2 rendus réussis | NON TESTÉ dans ces journaux | Cycle commun réussi ; coups non exhaustifs |
| N2-002 · 2 rendus réussis (`nd_dilemma`) | 8 rendus réussis | 2 rendus réussis | NON TESTÉ dans ces journaux | NON TESTÉ dans ces journaux | Cycle commun réussi ; coups non exhaustifs |
| nd-qui-de-nous-deux · NON TESTÉ dans ces journaux (`nd_duo_target`) | NON TESTÉ dans ces journaux | NON TESTÉ dans ces journaux | 2 rendus réussis | NON TESTÉ dans ces journaux | Cycle commun réussi ; coups non exhaustifs |
| N2-004 · NON TESTÉ dans ces journaux (`nd_predict`) | NON TESTÉ dans ces journaux | NON TESTÉ dans ces journaux | 2 rendus réussis | NON TESTÉ dans ces journaux | Cycle commun réussi ; coups non exhaustifs |
| nd-complete-phrase · 2 rendus réussis (`nd_sentence`) | NON TESTÉ dans ces journaux | 2 rendus réussis | NON TESTÉ dans ces journaux | NON TESTÉ dans ces journaux | Cycle commun réussi ; coups non exhaustifs |
| nd-accord-desaccord · 2 rendus réussis (`nd_opinion`) | NON TESTÉ dans ces journaux | 2 rendus réussis | NON TESTÉ dans ces journaux | NON TESTÉ dans ces journaux | Cycle commun réussi ; coups non exhaustifs |
| nd-action-verite · 4 rendus réussis (`nd_truth_dare`) | NON TESTÉ dans ces journaux | 4 rendus réussis | NON TESTÉ dans ces journaux | NON TESTÉ dans ces journaux | Cycle commun réussi ; coups non exhaustifs |
| nd-deux-verites-mensonge · 8 rendus réussis (`nd_two_truths`) | NON TESTÉ dans ces journaux | 8 rendus réussis | 4 rendus réussis | NON TESTÉ dans ces journaux | Cycle commun réussi ; coups non exhaustifs |
| N2-023 · 12 rendus réussis (`nd_hangman`) | 6 rendus réussis | 12 rendus réussis | 4 rendus réussis | NON TESTÉ dans ces journaux | Cycle commun réussi ; coups non exhaustifs |
| N2-018 · 10 rendus réussis (`nd_categories_stop`) | 6 rendus réussis | 10 rendus réussis | 5 rendus réussis | NON TESTÉ dans ces journaux | Cycle commun réussi ; coups non exhaustifs |
| nd-cite-trois · 8 rendus réussis (`nd_name_three_call`) | 6 rendus réussis | 8 rendus réussis | 4 rendus réussis | NON TESTÉ dans ces journaux | Cycle commun réussi ; coups non exhaustifs |
## historique

| Jeu / mécanique | Salon | Jeu | Révélation | Résultats | Erreur / réseau / quitter |
|---|---|---|---|---|---|
| N2-001 · 2 rendus réussis (`conversation`) | NON TESTÉ dans ces journaux | 2 rendus réussis | 2 rendus réussis | NON TESTÉ dans ces journaux | Cycle commun réussi ; coups non exhaustifs |
| N2-002 · 2 rendus réussis (`dilemma`) | NON TESTÉ dans ces journaux | 2 rendus réussis | 2 rendus réussis | NON TESTÉ dans ces journaux | Cycle commun réussi ; coups non exhaustifs |
| N2-003 · 2 rendus réussis (`experience`) | NON TESTÉ dans ces journaux | 2 rendus réussis | 2 rendus réussis | NON TESTÉ dans ces journaux | Cycle commun réussi ; coups non exhaustifs |
| N2-004 · 2 rendus réussis (`prediction`) | NON TESTÉ dans ces journaux | 2 rendus réussis | 2 rendus réussis | NON TESTÉ dans ces journaux | Cycle commun réussi ; coups non exhaustifs |
| N2-005 · 2 rendus réussis (`select_words`) | NON TESTÉ dans ces journaux | 2 rendus réussis | NON TESTÉ dans ces journaux | 2 rendus réussis | Cycle commun réussi ; coups non exhaustifs |
| N2-006 · 2 rendus réussis (`object_portrait`) | NON TESTÉ dans ces journaux | 2 rendus réussis | NON TESTÉ dans ces journaux | 2 rendus réussis | Cycle commun réussi ; coups non exhaustifs |
| N2-007 · 2 rendus réussis (`mood`) | NON TESTÉ dans ces journaux | 2 rendus réussis | NON TESTÉ dans ces journaux | 2 rendus réussis | Cycle commun réussi ; coups non exhaustifs |
| N2-008 · 2 rendus réussis (`rank`) | NON TESTÉ dans ces journaux | 2 rendus réussis | NON TESTÉ dans ces journaux | 2 rendus réussis | Cycle commun réussi ; coups non exhaustifs |
| N2-009 · 2 rendus réussis (`appreciation`) | NON TESTÉ dans ces journaux | 2 rendus réussis | NON TESTÉ dans ces journaux | 2 rendus réussis | Cycle commun réussi ; coups non exhaustifs |
| N2-010 · 2 rendus réussis (`listening`) | NON TESTÉ dans ces journaux | 2 rendus réussis | 2 rendus réussis | NON TESTÉ dans ces journaux | Cycle commun réussi ; coups non exhaustifs |
| N2-011 · 2 rendus réussis (`timeline_personal`) | NON TESTÉ dans ces journaux | 2 rendus réussis | NON TESTÉ dans ces journaux | 2 rendus réussis | Cycle commun réussi ; coups non exhaustifs |
| N2-012 · 2 rendus réussis (`capsule`) | NON TESTÉ dans ces journaux | 2 rendus réussis | NON TESTÉ dans ces journaux | 2 rendus réussis | Cycle commun réussi ; coups non exhaustifs |
| N2-013 · 2 rendus réussis (`budget`) | NON TESTÉ dans ces journaux | 2 rendus réussis | NON TESTÉ dans ces journaux | 2 rendus réussis | Cycle commun réussi ; coups non exhaustifs |
| N2-014 · 2 rendus réussis (`scene_builder`) | NON TESTÉ dans ces journaux | 2 rendus réussis | NON TESTÉ dans ces journaux | 2 rendus réussis | Cycle commun réussi ; coups non exhaustifs |
| N2-015 · 2 rendus réussis (`attention`) | NON TESTÉ dans ces journaux | 2 rendus réussis | NON TESTÉ dans ces journaux | 2 rendus réussis | Cycle commun réussi ; coups non exhaustifs |
| N2-121 · 2 rendus réussis (`taste_map`) | NON TESTÉ dans ces journaux | 2 rendus réussis | NON TESTÉ dans ces journaux | 2 rendus réussis | Cycle commun réussi ; coups non exhaustifs |
| N2-122 · 2 rendus réussis (`gift_box`) | NON TESTÉ dans ces journaux | 2 rendus réussis | NON TESTÉ dans ces journaux | 2 rendus réussis | Cycle commun réussi ; coups non exhaustifs |
| N2-123 · 2 rendus réussis (`zine`) | NON TESTÉ dans ces journaux | 2 rendus réussis | NON TESTÉ dans ces journaux | 2 rendus réussis | Cycle commun réussi ; coups non exhaustifs |
| N2-016 · 4 rendus réussis (`taboo`) | NON TESTÉ dans ces journaux | 4 rendus réussis | 2 rendus réussis | 2 rendus réussis | Cycle commun réussi ; coups non exhaustifs |
| N2-017 · 2 rendus réussis (`anagram`) | NON TESTÉ dans ces journaux | 2 rendus réussis | 4 rendus réussis | 2 rendus réussis | Cycle commun réussi ; coups non exhaustifs |
| N2-018 · 2 rendus réussis (`categories`) | NON TESTÉ dans ces journaux | 2 rendus réussis | 4 rendus réussis | 2 rendus réussis | Cycle commun réussi ; coups non exhaustifs |
| N2-019 · 4 rendus réussis (`word_chain`) | NON TESTÉ dans ces journaux | 4 rendus réussis | NON TESTÉ dans ces journaux | 4 rendus réussis | Cycle commun réussi ; coups non exhaustifs |
| N2-020 · 2 rendus réussis (`convergence`) | NON TESTÉ dans ces journaux | 2 rendus réussis | 4 rendus réussis | 2 rendus réussis | Cycle commun réussi ; coups non exhaustifs |
| N2-021 · 2 rendus réussis (`word_ladder`) | NON TESTÉ dans ces journaux | 2 rendus réussis | 4 rendus réussis | 2 rendus réussis | Cycle commun réussi ; coups non exhaustifs |
| N2-022 · 4 rendus réussis (`word_search`) | NON TESTÉ dans ces journaux | 4 rendus réussis | 2 rendus réussis | 2 rendus réussis | Cycle commun réussi ; coups non exhaustifs |
| N2-023 · 4 rendus réussis (`masked_word`) | NON TESTÉ dans ces journaux | 4 rendus réussis | 2 rendus réussis | 2 rendus réussis | Cycle commun réussi ; coups non exhaustifs |
| N2-024 · 2 rendus réussis (`syllables`) | NON TESTÉ dans ces journaux | 2 rendus réussis | 4 rendus réussis | 2 rendus réussis | Cycle commun réussi ; coups non exhaustifs |
| N2-025 · 4 rendus réussis (`letter_market`) | NON TESTÉ dans ces journaux | 4 rendus réussis | 2 rendus réussis | 2 rendus réussis | Cycle commun réussi ; coups non exhaustifs |
| N2-026 · 2 rendus réussis (`semantic_intruder`) | NON TESTÉ dans ces journaux | 2 rendus réussis | 4 rendus réussis | 2 rendus réussis | Cycle commun réussi ; coups non exhaustifs |
| N2-027 · 4 rendus réussis (`telegram`) | NON TESTÉ dans ces journaux | 4 rendus réussis | 2 rendus réussis | 2 rendus réussis | Cycle commun réussi ; coups non exhaustifs |
| N2-028 · 4 rendus réussis (`rhymes`) | NON TESTÉ dans ces journaux | 4 rendus réussis | 2 rendus réussis | 2 rendus réussis | Cycle commun réussi ; coups non exhaustifs |
| N2-029 · 2 rendus réussis (`clue_grid`) | NON TESTÉ dans ces journaux | 2 rendus réussis | 4 rendus réussis | 2 rendus réussis | Cycle commun réussi ; coups non exhaustifs |
| N2-030 · 4 rendus réussis (`sentence_order`) | NON TESTÉ dans ces journaux | 4 rendus réussis | 2 rendus réussis | 2 rendus réussis | Cycle commun réussi ; coups non exhaustifs |
| N2-124 · 2 rendus réussis (`word_growth`) | NON TESTÉ dans ces journaux | 2 rendus réussis | 4 rendus réussis | 2 rendus réussis | Cycle commun réussi ; coups non exhaustifs |
| N2-125 · 2 rendus réussis (`cross_letters`) | NON TESTÉ dans ces journaux | 2 rendus réussis | 4 rendus réussis | 2 rendus réussis | Cycle commun réussi ; coups non exhaustifs |
| N2-126 · 2 rendus réussis (`rebus`) | NON TESTÉ dans ces journaux | 2 rendus réussis | 4 rendus réussis | 2 rendus réussis | Cycle commun réussi ; coups non exhaustifs |
| N2-031 · 4 rendus réussis (`draw_guess`) | NON TESTÉ dans ces journaux | 4 rendus réussis | 2 rendus réussis | 2 rendus réussis | Cycle commun réussi ; coups non exhaustifs |
| N2-032 · 4 rendus réussis (`complete_doodle`) | NON TESTÉ dans ces journaux | 4 rendus réussis | 2 rendus réussis | 2 rendus réussis | Cycle commun réussi ; coups non exhaustifs |
| N2-033 · 2 rendus réussis (`draw_dictation`) | NON TESTÉ dans ces journaux | 2 rendus réussis | 4 rendus réussis | 2 rendus réussis | Cycle commun réussi ; coups non exhaustifs |
| N2-034 · 4 rendus réussis (`exquisite_drawing`) | NON TESTÉ dans ces journaux | 4 rendus réussis | NON TESTÉ dans ces journaux | 4 rendus réussis | Cycle commun réussi ; coups non exhaustifs |
| N2-035 · 11 rendus réussis (`pixel_art`) | NON TESTÉ dans ces journaux | 11 rendus réussis | NON TESTÉ dans ces journaux | 10 rendus réussis | Cycle commun réussi ; coups non exhaustifs |
| N2-036 · 4 rendus réussis (`tangram`) | NON TESTÉ dans ces journaux | 4 rendus réussis | NON TESTÉ dans ces journaux | 4 rendus réussis | Cycle commun réussi ; coups non exhaustifs |
| N2-037 · 4 rendus réussis (`jigsaw`) | NON TESTÉ dans ces journaux | 4 rendus réussis | 2 rendus réussis | 2 rendus réussis | Cycle commun réussi ; coups non exhaustifs |
| N2-038 · 2 rendus réussis (`sticker_portrait`) | NON TESTÉ dans ces journaux | 2 rendus réussis | NON TESTÉ dans ces journaux | 6 rendus réussis | Cycle commun réussi ; coups non exhaustifs |
| N2-039 · 4 rendus réussis (`emblem`) | NON TESTÉ dans ces journaux | 4 rendus réussis | NON TESTÉ dans ces journaux | 4 rendus réussis | Cycle commun réussi ; coups non exhaustifs |
| N2-040 · 4 rendus réussis (`stroke_budget`) | NON TESTÉ dans ces journaux | 4 rendus réussis | 2 rendus réussis | 2 rendus réussis | Cycle commun réussi ; coups non exhaustifs |
| N2-041 · 4 rendus réussis (`mirror_draw`) | NON TESTÉ dans ces journaux | 4 rendus réussis | NON TESTÉ dans ces journaux | 4 rendus réussis | Cycle commun réussi ; coups non exhaustifs |
| N2-042 · 4 rendus réussis (`palette`) | NON TESTÉ dans ces journaux | 4 rendus réussis | NON TESTÉ dans ces journaux | 4 rendus réussis | Cycle commun réussi ; coups non exhaustifs |
| N2-043 · 4 rendus réussis (`poster`) | NON TESTÉ dans ces journaux | 4 rendus réussis | NON TESTÉ dans ces journaux | 4 rendus réussis | Cycle commun réussi ; coups non exhaustifs |
| N2-044 · 4 rendus réussis (`silent_comic`) | NON TESTÉ dans ces journaux | 4 rendus réussis | NON TESTÉ dans ces journaux | 4 rendus réussis | Cycle commun réussi ; coups non exhaustifs |
| N2-045 · 4 rendus réussis (`tile_scene`) | NON TESTÉ dans ces journaux | 4 rendus réussis | NON TESTÉ dans ces journaux | 4 rendus réussis | Cycle commun réussi ; coups non exhaustifs |
| N2-127 · 4 rendus réussis (`constellation`) | NON TESTÉ dans ces journaux | 4 rendus réussis | NON TESTÉ dans ces journaux | 4 rendus réussis | Cycle commun réussi ; coups non exhaustifs |
| N2-128 · 4 rendus réussis (`flipbook`) | NON TESTÉ dans ces journaux | 4 rendus réussis | NON TESTÉ dans ces journaux | 4 rendus réussis | Cycle commun réussi ; coups non exhaustifs |
| N2-129 · 4 rendus réussis (`weaving`) | NON TESTÉ dans ces journaux | 4 rendus réussis | NON TESTÉ dans ces journaux | 4 rendus réussis | Cycle commun réussi ; coups non exhaustifs |
| N2-046 · 6 rendus réussis (`memory_pairs`) | NON TESTÉ dans ces journaux | 6 rendus réussis | NON TESTÉ dans ces journaux | 2 rendus réussis | Cycle commun réussi ; coups non exhaustifs |
| N2-047 · 4 rendus réussis (`change_detection`) | NON TESTÉ dans ces journaux | 4 rendus réussis | 2 rendus réussis | 2 rendus réussis | Cycle commun réussi ; coups non exhaustifs |
| N2-048 · 4 rendus réussis (`differences`) | NON TESTÉ dans ces journaux | 4 rendus réussis | 2 rendus réussis | 2 rendus réussis | Cycle commun réussi ; coups non exhaustifs |
| N2-049 · 2 rendus réussis (`zoom_recognition`) | NON TESTÉ dans ces journaux | 2 rendus réussis | 4 rendus réussis | 2 rendus réussis | Cycle commun réussi ; coups non exhaustifs |
| N2-050 · 2 rendus réussis (`visual_search`) | NON TESTÉ dans ces journaux | 2 rendus réussis | 4 rendus réussis | 2 rendus réussis | Cycle commun réussi ; coups non exhaustifs |
| N2-051 · 4 rendus réussis (`recall_set`) | NON TESTÉ dans ces journaux | 4 rendus réussis | 2 rendus réussis | 2 rendus réussis | Cycle commun réussi ; coups non exhaustifs |
| N2-052 · 9 rendus réussis (`simon`) | NON TESTÉ dans ces journaux | 9 rendus réussis | NON TESTÉ dans ces journaux | 8 rendus réussis | Cycle commun réussi ; coups non exhaustifs |
| N2-053 · 9 rendus réussis (`rhythm`) | NON TESTÉ dans ces journaux | 9 rendus réussis | 4 rendus réussis | 4 rendus réussis | Cycle commun réussi ; coups non exhaustifs |
| N2-054 · 4 rendus réussis (`ordered_recall`) | NON TESTÉ dans ces journaux | 4 rendus réussis | 2 rendus réussis | 2 rendus réussis | Cycle commun réussi ; coups non exhaustifs |
| N2-055 · 4 rendus réussis (`spatial_recall`) | NON TESTÉ dans ces journaux | 4 rendus réussis | 2 rendus réussis | 2 rendus réussis | Cycle commun réussi ; coups non exhaustifs |
| N2-056 · 4 rendus réussis (`pixel_recall`) | NON TESTÉ dans ces journaux | 4 rendus réussis | 2 rendus réussis | 2 rendus réussis | Cycle commun réussi ; coups non exhaustifs |
| N2-057 · 2 rendus réussis (`sorting`) | NON TESTÉ dans ces journaux | 2 rendus réussis | 4 rendus réussis | 2 rendus réussis | Cycle commun réussi ; coups non exhaustifs |
| N2-058 · 2 rendus réussis (`go_nogo`) | NON TESTÉ dans ces journaux | 2 rendus réussis | 4 rendus réussis | 2 rendus réussis | Cycle commun réussi ; coups non exhaustifs |
| N2-059 · 4 rendus réussis (`precision`) | NON TESTÉ dans ces journaux | 4 rendus réussis | 2 rendus réussis | 2 rendus réussis | Cycle commun réussi ; coups non exhaustifs |
| N2-060 · 4 rendus réussis (`split_memory`) | NON TESTÉ dans ces journaux | 4 rendus réussis | 2 rendus réussis | 2 rendus réussis | Cycle commun réussi ; coups non exhaustifs |
| N2-130 · 2 rendus réussis (`silhouette`) | NON TESTÉ dans ces journaux | 2 rendus réussis | 4 rendus réussis | 2 rendus réussis | Cycle commun réussi ; coups non exhaustifs |
| N2-131 · 2 rendus réussis (`layers`) | NON TESTÉ dans ces journaux | 2 rendus réussis | 4 rendus réussis | 2 rendus réussis | Cycle commun réussi ; coups non exhaustifs |
| N2-132 · 2 rendus réussis (`rotation`) | NON TESTÉ dans ces journaux | 2 rendus réussis | 4 rendus réussis | 2 rendus réussis | Cycle commun réussi ; coups non exhaustifs |
## catalogue — hors lot jeux

| Jeu / mécanique | Salon | Jeu | Révélation | Résultats | Erreur / réseau / quitter |
|---|---|---|---|---|---|
| ND-Q-011 · NON TESTÉ dans ces journaux (`test_form`) | NON TESTÉ dans ces journaux | NON TESTÉ dans ces journaux | NON TESTÉ dans ces journaux | NON TESTÉ dans ces journaux | Non testé dans ce lot |
| ND-Q-012 · NON TESTÉ dans ces journaux (`test_form`) | NON TESTÉ dans ces journaux | NON TESTÉ dans ces journaux | NON TESTÉ dans ces journaux | NON TESTÉ dans ces journaux | Non testé dans ce lot |
| ND-Q-021 · NON TESTÉ dans ces journaux (`test_form`) | NON TESTÉ dans ces journaux | NON TESTÉ dans ces journaux | NON TESTÉ dans ces journaux | NON TESTÉ dans ces journaux | Non testé dans ce lot |
| ND-Q-022 · NON TESTÉ dans ces journaux (`test_form`) | NON TESTÉ dans ces journaux | NON TESTÉ dans ces journaux | NON TESTÉ dans ces journaux | NON TESTÉ dans ces journaux | Non testé dans ce lot |
| ND-Q-024 · NON TESTÉ dans ces journaux (`test_form`) | NON TESTÉ dans ces journaux | NON TESTÉ dans ces journaux | NON TESTÉ dans ces journaux | NON TESTÉ dans ces journaux | Non testé dans ce lot |
| ND-Q-025 · NON TESTÉ dans ces journaux (`test_form`) | NON TESTÉ dans ces journaux | NON TESTÉ dans ces journaux | NON TESTÉ dans ces journaux | NON TESTÉ dans ces journaux | Non testé dans ce lot |
| ND-Q-027 · NON TESTÉ dans ces journaux (`test_form`) | NON TESTÉ dans ces journaux | NON TESTÉ dans ces journaux | NON TESTÉ dans ces journaux | NON TESTÉ dans ces journaux | Non testé dans ce lot |
| ND-Q-H01 · NON TESTÉ dans ces journaux (`pack_conversation`) | NON TESTÉ dans ces journaux | NON TESTÉ dans ces journaux | NON TESTÉ dans ces journaux | NON TESTÉ dans ces journaux | Non testé dans ce lot |
| ND-Q-H02 · NON TESTÉ dans ces journaux (`pack_conversation`) | NON TESTÉ dans ces journaux | NON TESTÉ dans ces journaux | NON TESTÉ dans ces journaux | NON TESTÉ dans ces journaux | Non testé dans ce lot |
| ND-Q-H03 · NON TESTÉ dans ces journaux (`pack_conversation`) | NON TESTÉ dans ces journaux | NON TESTÉ dans ces journaux | NON TESTÉ dans ces journaux | NON TESTÉ dans ces journaux | Non testé dans ce lot |
| ND-Q-H04 · NON TESTÉ dans ces journaux (`pack_conversation`) | NON TESTÉ dans ces journaux | NON TESTÉ dans ces journaux | NON TESTÉ dans ces journaux | NON TESTÉ dans ces journaux | Non testé dans ce lot |
| ND-Q-H05 · NON TESTÉ dans ces journaux (`pack_conversation`) | NON TESTÉ dans ces journaux | NON TESTÉ dans ces journaux | NON TESTÉ dans ces journaux | NON TESTÉ dans ces journaux | Non testé dans ce lot |
| ND-Q-H06 · NON TESTÉ dans ces journaux (`pack_conversation`) | NON TESTÉ dans ces journaux | NON TESTÉ dans ces journaux | NON TESTÉ dans ces journaux | NON TESTÉ dans ces journaux | Non testé dans ce lot |
| ND-Q-H07 · NON TESTÉ dans ces journaux (`pack_conversation`) | NON TESTÉ dans ces journaux | NON TESTÉ dans ces journaux | NON TESTÉ dans ces journaux | NON TESTÉ dans ces journaux | Non testé dans ce lot |
| ND-Q-H08 · NON TESTÉ dans ces journaux (`pack_conversation`) | NON TESTÉ dans ces journaux | NON TESTÉ dans ces journaux | NON TESTÉ dans ces journaux | NON TESTÉ dans ces journaux | Non testé dans ce lot |
| ND-Q-P01 · NON TESTÉ dans ces journaux (`pack_conversation`) | NON TESTÉ dans ces journaux | NON TESTÉ dans ces journaux | NON TESTÉ dans ces journaux | NON TESTÉ dans ces journaux | Non testé dans ce lot |
| ND-Q-P03 · NON TESTÉ dans ces journaux (`pack_conversation`) | NON TESTÉ dans ces journaux | NON TESTÉ dans ces journaux | NON TESTÉ dans ces journaux | NON TESTÉ dans ces journaux | Non testé dans ce lot |
| ND-Q-P11 · NON TESTÉ dans ces journaux (`pack_conversation`) | NON TESTÉ dans ces journaux | NON TESTÉ dans ces journaux | NON TESTÉ dans ces journaux | NON TESTÉ dans ces journaux | Non testé dans ce lot |
| ND-Q-P12 · NON TESTÉ dans ces journaux (`pack_conversation`) | NON TESTÉ dans ces journaux | NON TESTÉ dans ces journaux | NON TESTÉ dans ces journaux | NON TESTÉ dans ces journaux | Non testé dans ce lot |
| ND-Q-P13 · NON TESTÉ dans ces journaux (`pack_conversation`) | NON TESTÉ dans ces journaux | NON TESTÉ dans ces journaux | NON TESTÉ dans ces journaux | NON TESTÉ dans ces journaux | Non testé dans ce lot |
| ND-Q-P14 · NON TESTÉ dans ces journaux (`pack_conversation`) | NON TESTÉ dans ces journaux | NON TESTÉ dans ces journaux | NON TESTÉ dans ces journaux | NON TESTÉ dans ces journaux | Non testé dans ce lot |
| ND-Q-P15 · NON TESTÉ dans ces journaux (`pack_conversation`) | NON TESTÉ dans ces journaux | NON TESTÉ dans ces journaux | NON TESTÉ dans ces journaux | NON TESTÉ dans ces journaux | Non testé dans ce lot |
| ND-Q-P20 · NON TESTÉ dans ces journaux (`pack_conversation`) | NON TESTÉ dans ces journaux | NON TESTÉ dans ces journaux | NON TESTÉ dans ces journaux | NON TESTÉ dans ces journaux | Non testé dans ce lot |
| ND-Q-P21 · NON TESTÉ dans ces journaux (`pack_conversation`) | NON TESTÉ dans ces journaux | NON TESTÉ dans ces journaux | NON TESTÉ dans ces journaux | NON TESTÉ dans ces journaux | Non testé dans ce lot |
| ND-Q-P22 · NON TESTÉ dans ces journaux (`pack_conversation`) | NON TESTÉ dans ces journaux | NON TESTÉ dans ces journaux | NON TESTÉ dans ces journaux | NON TESTÉ dans ces journaux | Non testé dans ce lot |
| ND-Q-P23 · NON TESTÉ dans ces journaux (`pack_conversation`) | NON TESTÉ dans ces journaux | NON TESTÉ dans ces journaux | NON TESTÉ dans ces journaux | NON TESTÉ dans ces journaux | Non testé dans ce lot |
| ND-Q-P24 · NON TESTÉ dans ces journaux (`pack_conversation`) | NON TESTÉ dans ces journaux | NON TESTÉ dans ces journaux | NON TESTÉ dans ces journaux | NON TESTÉ dans ces journaux | Non testé dans ce lot |
| ND-Q-RND1 · NON TESTÉ dans ces journaux (`pack_conversation`) | NON TESTÉ dans ces journaux | NON TESTÉ dans ces journaux | NON TESTÉ dans ces journaux | NON TESTÉ dans ces journaux | Non testé dans ce lot |
| ND-Q-RND2 · NON TESTÉ dans ces journaux (`pack_conversation`) | NON TESTÉ dans ces journaux | NON TESTÉ dans ces journaux | NON TESTÉ dans ces journaux | NON TESTÉ dans ces journaux | Non testé dans ce lot |

Le CSV fournit les fichiers source et limites par ligne. La couverture du lot précédent reste dans LOT2_CERISE_AUTH_SALON.md. Aucun ordre/scoring de test standardisé modifié.
