#!/usr/bin/env python3
"""Vraies courses PostgreSQL locales, sans dépendance Python tierce.

Usage (après local_shim et migrations jusqu'à 010, posées par le responsable) :
    python3 tests/sql/server_concurrency.py noodeu_server_<suffixe>

Garde-fous : contexte Docker default sur socket Unix, conteneur fixé ci-dessous,
psql par socket Unix uniquement, nom de base contrôlé et commentaire obligatoire
``noodeu:disposable-local-sql-test``. Le script ne crée ni ne détruit de base,
n'applique aucune migration et n'accepte pas d'URL de connexion. Aucun nettoyage
des données : quatre utilisateurs fictifs, leurs deux duos et leurs sessions
restent identifiables par le run_id émis sur stdout, même après un échec.

Chaque course utilise deux processus psql, chacun dans sa propre transaction
authentifiée par GUC de fixture et SET LOCAL ROLE authenticated. Un coordinateur
verrouille la ligne game_sessions, émet un marqueur puis attend que les DEUX RPC
soient observées wait_event_type=Lock. Il conserve ensuite le verrou pendant
pg_sleep(2), puis COMMIT. Deux threads simplement lancés ensemble ne suffisent
donc pas à faire réussir ce test. Les vues de chaque siège sont lues avant le
COMMIT de son worker, pendant que le second reste bloqué.

Le duo C-D garde une session M04 historique comme témoin. Pour libérer le créneau
du duo A-B après G08, seule sa session fictive est marquée abandoned directement,
en conservant ses manches, secrets et coups. Les RPC de clôture, qui purgent,
ne sont jamais appelées. La session M04 suivante est créée par le chemin public
historique, puis sa seule game_version est remplacée par le draft 12x12 AVANT
ready. Ni games.current_version ni game_versions.published_at ne sont changés.

Limites : vérification réelle des transactions/RPC SQL et de leur projection
publique/privée, avec auth locale synthétique. Ce n'est pas un test de JWT signés,
de réseau mobile, de Realtime Supabase, ni de deux téléphones physiques.
"""

from __future__ import annotations

import argparse
import copy
import json
import os
import re
import selectors
import subprocess
import sys
import time
import uuid
from dataclasses import dataclass
from typing import Any


CONTAINER = "noodeu-refonte-test-20261025"
DB_MARKER = "noodeu:disposable-local-sql-test"
DRAFT_VERSION = "noodeu-m04-2.0.0"
Json = dict[str, Any]


class CheckFailure(RuntimeError):
    pass


def check(condition: bool, message: str) -> None:
    if not condition:
        raise CheckFailure(message)


def database_arg(value: str) -> str:
    if not re.fullmatch(r"noodeu_server_[a-zA-Z0-9_]+", value) or len(value) > 63:
        raise argparse.ArgumentTypeError("Base requise : noodeu_server_<suffixe>, 63 caractères maximum ; aucune URL.")
    return value


def literal(value: str) -> str:
    return "'" + value.replace("'", "''") + "'"


def json_sql(value: Any) -> str:
    return literal(json.dumps(value, ensure_ascii=False)) + "::jsonb"


def identity(user_id: str) -> str:
    claims = json.dumps({"sub": user_id, "role": "authenticated"})
    return f"SET LOCAL request.jwt.claims = {literal(claims)};\n"


def json_rows(stdout: str) -> list[Any]:
    rows = []
    for line in stdout.splitlines():
        if line.strip():
            try:
                rows.append(json.loads(line))
            except json.JSONDecodeError as exc:
                raise CheckFailure(f"Sortie psql non JSON inattendue : {line[:240]}") from exc
    return rows


@dataclass(frozen=True)
class Move:
    user: str
    peer: str
    action: str
    kind: str
    payload: Json


class LocalPostgres:
    def __init__(self, database: str):
        self.database = database_arg(database)
        self.env = os.environ.copy()
        # --context default doit être explicite, sans surcharge vers un daemon distant.
        for key in ("DOCKER_HOST", "DOCKER_CONTEXT", "DOCKER_TLS_VERIFY", "DOCKER_CERT_PATH"):
            self.env.pop(key, None)
        self.docker = ["docker", "--context", "default"]
        self.command = self.docker + [
            "exec", "-i", CONTAINER, "psql", "-X", "-q", "-A", "-t", "-w",
            "-v", "ON_ERROR_STOP=1", "-U", "postgres", "-h", "/var/run/postgresql",
            "-d", self.database,
        ]
        self.guard = f"""
SET statement_timeout = '20s';
SET lock_timeout = '12s';
SET standard_conforming_strings = on;
DO $local_test_guard$
BEGIN
  IF current_database() <> {literal(self.database)} OR
     (SELECT shobj_description(oid, 'pg_database') FROM pg_database
      WHERE datname = current_database()) IS DISTINCT FROM {literal(DB_MARKER)} THEN
    RAISE EXCEPTION 'Base jetable locale non attestée : arrêt sans fixture';
  END IF;
END
$local_test_guard$;
"""

    def attest(self) -> Json:
        inspected = subprocess.run(
            self.docker + ["context", "inspect", "default"], capture_output=True,
            text=True, check=True, timeout=10, env=self.env,
        )
        endpoint = json.loads(inspected.stdout)[0]["Endpoints"]["docker"]["Host"]
        check(endpoint.startswith("unix://"), "Le contexte Docker default doit utiliser une socket Unix locale.")
        return self.one("SELECT jsonb_build_object('database', current_database(), 'user', current_user, "
                        "'marker', shobj_description(oid, 'pg_database')) FROM pg_database "
                        "WHERE datname = current_database();")

    def run(self, sql: str, timeout: float = 25) -> list[Any]:
        result = subprocess.run(self.command, input=self.guard + sql, capture_output=True,
                                text=True, timeout=timeout, env=self.env)
        check(result.returncode == 0, f"psql a échoué ({result.returncode}) : {result.stderr.strip()[:2000]}")
        return json_rows(result.stdout)

    def one(self, sql: str) -> Any:
        rows = self.run(sql)
        check(len(rows) == 1, f"Une ligne JSON attendue, reçu {len(rows)}.")
        return rows[0]

    def rpc(self, user: str, expression: str) -> Json:
        return self.one("BEGIN;\nSET LOCAL ROLE authenticated;\n" + identity(user)
                        + f"SELECT {expression};\nCOMMIT;")

    def start(self, sql: str, keep_stdin: bool = False) -> subprocess.Popen[str]:
        process = subprocess.Popen(self.command, stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                                   stderr=subprocess.PIPE, text=True, bufsize=1, env=self.env)
        assert process.stdin is not None
        process.stdin.write(self.guard + sql)
        process.stdin.flush()
        if not keep_stdin:
            process.stdin.close()
            process.stdin = None
        return process


def collect(process: subprocess.Popen[str]) -> str:
    try:
        stdout, stderr = process.communicate(timeout=25)
    except subprocess.TimeoutExpired as exc:
        process.kill()
        process.communicate(timeout=5)
        raise CheckFailure("Processus psql hors délai ; consulter les fixtures tracées, résultat transactionnel incertain.") from exc
    check(process.returncode == 0, f"Worker psql en échec : {stderr.strip()[:2000]}")
    return stdout


def session_snapshot(db: LocalPostgres, session: str) -> Json:
    sid = literal(session) + "::uuid"
    return db.one(f"""
SELECT jsonb_build_object(
 'session', to_jsonb(g),
 'couple', (SELECT to_jsonb(c) FROM public.couples c WHERE c.id=g.couple_id),
 'members', (SELECT jsonb_agg(to_jsonb(m) ORDER BY m.user_id) FROM public.couple_members m WHERE m.couple_id=g.couple_id),
 'players', (SELECT jsonb_agg(to_jsonb(p) ORDER BY p.seat) FROM public.session_players p WHERE p.session_id=g.id),
 'prefs', (SELECT jsonb_agg(to_jsonb(p) ORDER BY p.seat) FROM public.session_prefs p WHERE p.session_id=g.id),
 'rounds', COALESCE((SELECT jsonb_agg(to_jsonb(r) ORDER BY r.round_no) FROM public.session_rounds r WHERE r.session_id=g.id),'[]'),
 'secrets', COALESCE((SELECT jsonb_agg(to_jsonb(s) ORDER BY s.round_no) FROM private.round_secrets s WHERE s.session_id=g.id),'[]'),
 'moves', COALESCE((SELECT jsonb_agg(to_jsonb(m) ORDER BY m.action_id) FROM private.board_moves m WHERE m.session_id=g.id),'[]')
) FROM public.game_sessions g WHERE g.id={sid};
""")


def card(snapshot: Json) -> Json:
    number = snapshot["session"]["current_round"]
    return next(r["card"] for r in snapshot["rounds"] if r["round_no"] == number)


def secret(snapshot: Json) -> Json:
    number = snapshot["session"]["current_round"]
    return next(r["secret"] for r in snapshot["secrets"] if r["round_no"] == number)


def round_view(view: Json) -> Json:
    check(view.get("ok") is True, "Projection get_session_state refusée pour un membre fixture.")
    return next(r for r in view["rounds"] if r["round_no"] == view["session"]["current_round"])


def accepted(result: Json, name: str) -> Json:
    check(result.get("ok") is True, f"{name} refusé : {result}")
    return result


def create_pair(db: LocalPostgres, a: str, b: str) -> str:
    invitation = accepted(db.rpc(a, "public.create_invitation()"), "Invitation fixture")
    accepted(db.rpc(b, f"public.claim_invitation({literal(invitation['code'])})"), "Acceptation fixture")
    accepted(db.rpc(a, f"public.respond_to_claim({literal(invitation['id'])}::uuid, true)"), "Confirmation fixture")
    return db.one(f"SELECT to_jsonb(couple_id) FROM public.couple_members WHERE user_id={literal(a)}::uuid AND left_at IS NULL;")


def create_session(db: LocalPostgres, user: str, game: str) -> str:
    result = accepted(db.rpc(user, f"public.create_session({literal(game)})"), "Création de session fixture")
    check(not result.get("existing"), "La fixture doit créer sa propre session, pas reprendre une session existante.")
    return result["session_id"]


def ready(db: LocalPostgres, session: str, users: list[str]) -> Json:
    for user in users:
        accepted(db.rpc(user, f"public.set_ready({literal(session)}::uuid, true)"), "Ready fixture")
    result = session_snapshot(db, session)
    check(result["session"]["status"] == "playing", "Les deux ready doivent démarrer la session.")
    return result


def move_expression(session: str, move: Move) -> str:
    return (f"public.play_move({literal(session)}::uuid, 1, {literal(move.action)}::uuid, "
            f"{literal(move.kind)}, {json_sql(move.payload)})")


def concurrent(db: LocalPostgres, session: str, moves: list[Move], label: str, report: Json) -> list[Json]:
    """Deux RPC bloquées sur le même verrou, puis deux COMMIT indépendants."""
    check(len(moves) == 2, "Chaque course exige exactement deux workers.")
    tag = f"ndc_{uuid.uuid4().hex[:18]}"
    names = [f"{tag}_w{i}" for i in range(2)]
    marker = f"{tag}_LOCKED:"
    blocker = db.start(f"""BEGIN;
SET LOCAL application_name = {literal(tag + '_coordinator')};
SELECT pg_backend_pid() AS coordinator_pid FROM public.game_sessions
WHERE id={literal(session)}::uuid FOR UPDATE
\\gset
\\echo {marker} :coordinator_pid
""", keep_stdin=True)
    workers: list[subprocess.Popen[str]] = []
    evidence: Json = {"label": label, "tag": tag, "session": session}
    report["races"].append(evidence)
    released = False
    try:
        assert blocker.stdout is not None
        with selectors.DefaultSelector() as selector:
            selector.register(blocker.stdout, selectors.EVENT_READ)
            check(bool(selector.select(timeout=10)), "Le coordinateur n'a pas confirmé son verrou.")
            line = blocker.stdout.readline().strip()
        check(line.startswith(marker), f"Marqueur de verrou absent : {line!r}")
        coordinator_pid = int(line[len(marker):])
        evidence["coordinator_pid"] = coordinator_pid
        for index, move in enumerate(moves):
            # \gset conserve la réponse RPC sans perdre le verrou jusqu'aux deux projections.
            sql = ("BEGIN;\nSET LOCAL ROLE authenticated;\n"
                   f"SET LOCAL application_name = {literal(names[index])};\n" + identity(move.user)
                   + f"SELECT /* {tag} */ {move_expression(session, move)} AS action_result\n\\gset\n"
                   + "SELECT jsonb_build_object('result', :'action_result'::jsonb, "
                   f"'view', public.get_session_state({literal(session)}::uuid));\n"
                   + identity(move.peer)
                   + f"SELECT jsonb_build_object('peer_view', public.get_session_state({literal(session)}::uuid));\nCOMMIT;\n")
            workers.append(db.start(sql))
        limit = time.monotonic() + 8
        waiting: list[Json] = []
        while time.monotonic() < limit:
            waiting = db.one(f"""SELECT COALESCE(jsonb_agg(jsonb_build_object(
 'pid', pid, 'application_name', application_name, 'state', state,
 'wait_event_type', wait_event_type, 'wait_event', wait_event,
 'blocked_by', pg_blocking_pids(pid), 'tag_seen', position({literal(tag)} in query)>0
) ORDER BY application_name),'[]') FROM pg_stat_activity
WHERE datname=current_database() AND application_name IN ({literal(names[0])},{literal(names[1])});""")
            if len(waiting) == 2 and all(w["wait_event_type"] == "Lock" and w["tag_seen"] for w in waiting):
                break
            check(all(p.poll() is None for p in workers), "Un worker s'est terminé avant la preuve de contention.")
            time.sleep(0.05)
        evidence["waiting"] = waiting
        check(len(waiting) == 2 and len({w["pid"] for w in waiting}) == 2
              and all(w["wait_event_type"] == "Lock" and w["tag_seen"] for w in waiting),
              "Deux PID distincts en wait_event_type=Lock doivent être observés ensemble.")
        blockers = {w["pid"]: w["blocked_by"] for w in waiting}

        def reaches_coordinator(pid: int, visited: set[int] | None = None) -> bool:
            if pid == coordinator_pid:
                return True
            seen = set() if visited is None else visited
            if pid in seen:
                return False
            return any(reaches_coordinator(p, seen | {pid}) for p in blockers.get(pid, []))

        check(all(reaches_coordinator(w["pid"]) for w in waiting), "Les deux attentes doivent remonter au coordinateur.")
        # Deux secondes supplémentaires APRÈS preuve de contention, sans fenêtre de lancement fragile.
        assert blocker.stdin is not None
        blocker.stdin.write("SELECT pg_sleep(2);\nCOMMIT;\n")
        blocker.stdin.close()
        blocker.stdin = None
        released = True
        outputs = []
        for index, worker in enumerate(workers):
            rows = json_rows(collect(worker))
            check(len(rows) == 2, "Chaque worker doit rendre sa réponse et les deux vues avant COMMIT.")
            output = rows[0] | rows[1]
            for view_key, expected_user in (("view", moves[index].user), ("peer_view", moves[index].peer)):
                view = output[view_key]
                check(view.get("ok") is True, "Un membre doit pouvoir lire sa projection fixture.")
                mine = [p for p in view["players"] if p.get("is_me")]
                check(len(mine) == 1 and mine[0]["user_id"] == expected_user
                      and view["my_seat"] == mine[0]["seat"], "Le GUC doit effectivement changer l'identité et le siège projetés.")
                check({p["user_id"] for p in view["players"]} == {moves[index].user, moves[index].peer},
                      "La projection doit rester dans le duo du worker.")
            outputs.append(output)
        collect(blocker)
        evidence["responses"] = [x["result"] for x in outputs]
        evidence["hold_after_observation_seconds"] = 2
        print(json.dumps({"contention": evidence}, ensure_ascii=False), flush=True)
        return outputs
    finally:
        if not released and blocker.stdin is not None:
            # Annule uniquement la transaction du coordinateur ; jamais les fixtures committées.
            try:
                blocker.stdin.write("ROLLBACK;\n")
                blocker.stdin.close()
                blocker.stdin = None
            except BrokenPipeError:
                blocker.stdin = None
        for process in [*workers, blocker]:
            if process.poll() is None:
                collect(process)


def assert_delta(before: Json, after: Json, count: int, ids: set[str]) -> None:
    check(card(after).get("rev", 0) == card(before).get("rev", 0) + count, "Révision : une incrémentation par coup accepté.")
    check(after["session"]["state_version"] == before["session"]["state_version"] + count, "state_version : aucune mutation perdue ou doublée.")
    previous = {m["action_id"] for m in before["moves"]}
    current = {m["action_id"] for m in after["moves"]}
    check(len(after["moves"]) == len(before["moves"]) + count and current - previous == ids,
          "Journal board_moves : exactement les actions acceptées, une seule fois.")


def three(prefix: str, lie: str) -> Json:
    return {"confirmed_truths": True, "lie_statement_id": lie,
            "statements": [{"id": f"s{i}", "text": f"{prefix} affirmation fictive {i}"} for i in range(1, 4)]}


def verify_g08(db: LocalPostgres, session: str, sentinel: str, report: Json) -> Json:
    baseline = session_snapshot(db, session)
    untouched = session_snapshot(db, sentinel)
    users = {p["seat"]: p["user_id"] for p in baseline["players"]}
    check(card(baseline).get("mode") == "simultaneous" and card(baseline).get("phase") == "write", "G08 simultané requis.")
    payloads = {1: three("Alpha " + report["run_id"][:8], "s2"), 2: three("Bravo " + report["run_id"][:8], "s3")}
    private_parts = {str(seat): {"statements": p["statements"], "lie": p["lie_statement_id"]} for seat, p in payloads.items()}
    publications = [Move(users[s], users[3-s], str(uuid.uuid4()), "publish_three", payloads[s]) for s in (1, 2)]
    outputs = concurrent(db, session, publications, "G08 : deux publications", report)
    for output in outputs:
        accepted(output["result"], "Publication concurrente")
        for key in ("view", "peer_view"):
            view = output[key]
            rd = round_view(view)
            own = str(view["my_seat"])
            other = str(3 - int(own))
            check(not {"lie", "lies", "guess", "guesses"} & rd["card"].keys(), "Aucun mensonge ni choix dans la carte publique avant révélation.")
            own_ready = rd["card"].get("ready", {}).get(own, False)
            check(rd.get("private") == (private_parts[own] if own_ready else None), "Chaque vue ne reçoit que sa propre part privée.")
            if rd["card"]["phase"] == "write":
                for statement in payloads[int(other)]["statements"]:
                    check(statement["text"] not in json.dumps(view, ensure_ascii=False), "Publication adverse masquée avant les deux verrous.")
    first_views = [round_view(x["view"])["card"]["phase"] for x in outputs]
    check(sorted(first_views) == ["guess", "write"], "Les workers doivent capturer le premier et le second état sérialisés.")
    published = session_snapshot(db, session)
    assert_delta(baseline, published, 2, {m.action for m in publications})
    expected = copy.deepcopy(card(baseline)) | {
        "phase": "guess", "ready": {"1": True, "2": True}, "statements": {str(s): payloads[s]["statements"] for s in (1, 2)},
        "rev": card(baseline).get("rev", 0) + 2, "last": card(published)["last"],
    }
    check(card(published) == expected, "Carte G08 après publications : deux parts conservées, aucun autre changement.")
    check(secret(published) == {"seats": private_parts}, "Les deux parts secrètes doivent survivre à la course de publications.")
    check(session_snapshot(db, sentinel) == untouched, "Le duo/session témoin a changé pendant les publications.")

    guesses = {1: "s3", 2: "s1"}
    moves = [Move(users[s], users[3-s], str(uuid.uuid4()), "lock_guess", {"statement_id": guesses[s]}) for s in (1, 2)]
    outputs = concurrent(db, session, moves, "G08 : deux devinettes", report)
    phases = []
    for output in outputs:
        accepted(output["result"], "Devinette concurrente")
        phases.append(round_view(output["view"])["card"]["phase"])
        for key in ("view", "peer_view"):
            view = output[key]
            rd = round_view(view)
            seat = str(view["my_seat"])
            private = copy.deepcopy(private_parts[seat])
            if rd["card"].get("guessed", {}).get(seat):
                private["guess"] = guesses[int(seat)]
            check(rd.get("private") == private, "Une devinette ne doit écraser ni les affirmations ni le mensonge privé.")
            if not rd["card"].get("done"):
                check(not {"guess", "guesses", "lie", "lies"} & rd["card"].keys(), "Le premier choix reste scellé dans les deux vues.")
    check(sorted(phases) == ["guess", "reveal"], "Une seule devinette puis révélation commune doivent être observées.")
    final = session_snapshot(db, session)
    assert_delta(published, final, 2, {m.action for m in moves})
    expected = copy.deepcopy(card(published)) | {
        "done": True, "phase": "reveal", "guessed": {"1": True, "2": True},
        "lies": {"1": "s2", "2": "s3"}, "guesses": {"1": "s3", "2": "s1"},
        "found": {"1": True, "2": False}, "scores": {"1": 1, "2": 0},
        "rev": card(published)["rev"] + 2, "last": card(final)["last"],
    }
    check(card(final) == expected, "La révélation doit conserver toutes les affirmations et les deux choix, avec scores 1/0.")
    check(secret(final) == {"seats": {s: p | {"guess": guesses[int(s)]} for s, p in private_parts.items()}}, "Secrets finaux G08 incomplets.")
    for move in [*publications, *moves]:
        repeated = db.rpc(move.user, move_expression(session, move))
        check(repeated == {"ok": True, "repeated": True}, "Action ID exact répété : retour idempotent requis.")
    check(session_snapshot(db, session) == final, "Rejeu d'action : carte, secrets, révision ou journal modifiés.")
    check(session_snapshot(db, sentinel) == untouched, "Le duo/session témoin a changé pendant G08.")
    report["checks"].append("G08 : publications et devinettes concurrentes, confidentialité intermédiaire, deux secrets préservés, 4 rejeux idempotents")
    return final


def verify_dots(db: LocalPostgres, session: str, sentinel: str, archived: str, report: Json) -> None:
    before = session_snapshot(db, session)
    untouched = session_snapshot(db, sentinel)
    archive = session_snapshot(db, archived)
    users = {p["seat"]: p["user_id"] for p in before["players"]}
    check(card(before).get("dot_rows") == 12 and card(before).get("dot_columns") == 12
          and len(card(before)["owner"]) == 121 and card(before)["total_edges"] == 264, "M04 draft 12x12 non initialisé.")
    for same_action, edge in [(True, "h:0:0"), (False, "v:0:0")]:
        seat = card(before)["turn"]
        action = str(uuid.uuid4())
        moves = [Move(users[seat], users[3-seat], action if i == 0 or same_action else str(uuid.uuid4()),
                      "draw_edge", {"edge_id": edge}) for i in range(2)]
        outputs = concurrent(db, session, moves, "M04 : " + ("même action ID" if same_action else "deux actions, même segment"), report)
        results = [o["result"] for o in outputs]
        normal = [i for i, r in enumerate(results) if r.get("ok") is True and not r.get("repeated")]
        check(len(normal) == 1, "Un seul draw_edge doit être accepté comme nouvelle mutation.")
        loser = results[1-normal[0]]
        if same_action:
            check(loser == {"ok": True, "repeated": True}, "Le doublon concurrent doit être repeated:true.")
        else:
            check(loser.get("ok") is False and loser.get("error") in {"not_your_turn", "edge_taken"}, "La seconde action distincte doit être refusée.")
        after = session_snapshot(db, session)
        assert_delta(before, after, 1, {moves[normal[0]].action})
        expected = copy.deepcopy(card(before))
        expected["edges"][edge] = seat
        expected.update(turn=3-seat, rev=card(before).get("rev", 0)+1, last={"seat": seat, "type": "draw_edge"})
        check(card(after) == expected, "Un seul segment ajouté ; tour, propriétaires et scores doivent rester cohérents.")
        check(after["secrets"] == before["secrets"], "Draw_edge ne doit modifier aucun secret.")
        check(session_snapshot(db, sentinel) == untouched, "Le duo/session historique témoin a changé.")
        check(session_snapshot(db, archived) == archive, "La session G08 archivée a changé pendant M04.")
        before = after
    report["checks"].append("M04 draft 12x12 : même action idempotente et deux actions concurrentes sur un segment ; une mutation par course")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("database", type=database_arg)
    args = parser.parse_args()
    report: Json = {"run_id": str(uuid.uuid4()), "database": args.database, "container": CONTAINER,
                    "users": {}, "duos": {}, "sessions": {}, "races": [], "checks": []}
    try:
        db = LocalPostgres(args.database)
        report["attestation"] = db.attest()
        catalogue = db.one("""SELECT jsonb_build_object('game', to_jsonb(g), 'versions',
          (SELECT jsonb_agg(to_jsonb(v) ORDER BY v.version) FROM public.game_versions v WHERE v.game_id=g.id))
          FROM public.games g WHERE g.id='N2-079';""")
        drafts = [v for v in catalogue["versions"] if v["config"].get("version") == DRAFT_VERSION]
        check(len(drafts) == 1 and drafts[0]["published_at"] is None, "Une version M04 12x12 non publiée est requise (migration010).")
        draft = drafts[0]
        historical = catalogue["game"]["current_version"]
        check(draft["version"] != historical, "Le draft M04 ne doit pas être current_version.")
        check(draft["config"]["parameters"]["dot_rows"] == 12 and draft["config"]["parameters"]["dot_columns"] == 12,
              "Le draft doit porter exactement douze points par axe.")
        report["users"] = {name: str(uuid.uuid4()) for name in "ABCD"}
        print(json.dumps({"fixtures_planned": report}, ensure_ascii=False), flush=True)
        values = ",\n".join(f"({literal(user)}::uuid,{literal(user+'@noodeu.invalid')},"
                              f"{json_sql({'display_name': 'Concurrence '+name, 'test_run': report['run_id']})})"
                              for name, user in report["users"].items())
        db.run("INSERT INTO auth.users(id,email,raw_user_meta_data) VALUES " + values + ";")
        a, b, c, d = (report["users"][name] for name in "ABCD")
        report["duos"] = {"AB": create_pair(db, a, b), "CD": create_pair(db, c, d)}
        sentinel = create_session(db, c, "N2-079")
        report["sessions"]["sentinel_historical_CD"] = sentinel
        historical_state = ready(db, sentinel, [c, d])
        check(historical_state["session"]["game_version"] == historical and len(card(historical_state)["owner"]) == 16,
              "Le témoin C-D doit conserver le moteur historique 5x5.")
        g08 = create_session(db, a, "nd-deux-verites-mensonge")
        report["sessions"]["g08_AB"] = g08
        ready(db, g08, [a, b])
        print(json.dumps({"fixtures_committed": report["sessions"], "run_id": report["run_id"]}), flush=True)
        verify_g08(db, g08, sentinel, report)
        archived = db.one(f"""WITH changed AS (UPDATE public.game_sessions SET status='abandoned', closed_at=now()
          WHERE id={literal(g08)}::uuid AND created_by={literal(a)}::uuid AND status='playing' RETURNING id)
          SELECT COALESCE(jsonb_agg(id),'[]') FROM changed;""")
        check(archived == [g08], "Seule la session G08 fictive peut être archivée administrativement, sans effacement.")
        dots = create_session(db, a, "N2-079")
        report["sessions"]["dots12_AB"] = dots
        lobby = session_snapshot(db, dots)
        check(lobby["session"]["game_version"] == historical and not lobby["rounds"]
              and all(p["ready_at"] is None for p in lobby["players"]), "Le chemin public doit créer un salon historique non prêt.")
        switched = db.one(f"""WITH changed AS (UPDATE public.game_sessions SET game_version={int(draft['version'])}
          WHERE id={literal(dots)}::uuid AND created_by={literal(a)}::uuid AND status='lobby'
            AND game_version={int(historical)} AND NOT EXISTS (SELECT 1 FROM public.session_players p
              WHERE p.session_id={literal(dots)}::uuid AND p.ready_at IS NOT NULL)
          RETURNING id) SELECT COALESCE(jsonb_agg(id),'[]') FROM changed;""")
        check(switched == [dots], "La substitution du draft doit cibler uniquement le salon fixture avant ready.")
        ready(db, dots, [a, b])
        verify_dots(db, dots, sentinel, g08, report)
        catalogue_after = db.one("""SELECT jsonb_build_object('game', to_jsonb(g), 'versions',
          (SELECT jsonb_agg(to_jsonb(v) ORDER BY v.version) FROM public.game_versions v WHERE v.game_id=g.id))
          FROM public.games g WHERE g.id='N2-079';""")
        check(catalogue_after == catalogue, "Catalogue/version publiée/current_version modifiés par le harness.")
        check(session_snapshot(db, sentinel) == historical_state, "Le duo C-D et sa session doivent rester strictement identiques du début à la fin.")
        report["checks"].append("Catalogue inchangé, draft toujours non publié, session historique et duo C-D inchangés")
        report["ok"] = True
        print(json.dumps(report, ensure_ascii=False, indent=2), flush=True)
        return 0
    except (CheckFailure, subprocess.SubprocessError, OSError, ValueError, KeyError, StopIteration) as exc:
        report.update(ok=False, error=str(exc), fixture_policy="Données fictives conservées ; aucun nettoyage automatique.")
        print(json.dumps(report, ensure_ascii=False, indent=2), file=sys.stderr, flush=True)
        return 1


if __name__ == "__main__":
    sys.exit(main())
