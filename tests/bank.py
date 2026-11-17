#!/usr/bin/env python3
"""Edits one prompt of the answer bank (src/ServerStorage/PromptBank/<id>.luau) safely.

  python tests/bank.py add     <id> <json file | ->   add answers and aliases
  python tests/bank.py retier  <id> <json file | ->   move answers between tiers
  python tests/bank.py remove  <id> <json file | ->   delete answers (and optionally their aliases)
  python tests/bank.py unalias <id> <json file | ->   delete aliases
  python tests/bank.py stats   [id]                   entries per tier and aliases (every prompt without an id)
  python tests/bank.py show    <id> [Tier ...]        the entries of those tiers (all of them without a tier), wrapped
  python tests/bank.py selftest                       parse every prompt file

Input is JSON:
  add:     {"Schooler": ["spork", "Crème brûlée"], "Rare": [...], "DeepCut": [...], "Mythic": [...],
            "aliases": {"typed form": "existing or added answer"}}
  retier:  {"answer": "NewTier", ...}   or a list of {"answer": "...", "from": "Tier", "to": "NewTier"} (from is ignored)
  remove:  ["answer", ...]        (an answer that aliases point at needs --drop-aliases)
  unalias: ["alias", ...]

Answers and aliases are normalized the way the game normalizes them (lower case, no punctuation, single
spaces), so raw text is fine. Plankton and TooClever are the curated top of each prompt: nothing is added to,
moved into or taken out of them without --allow-top.

Every edit takes a per-prompt lock (so agents may edit the same prompt at the same time), changes only what was
asked, re-reads the file to prove it, runs tests/check_prompt.luau on it and puts the old file back if any of
that fails. The last line printed is one JSON object saying what happened; "ok" is false on failure.
"""

import json
import os
import re
import subprocess
import sys
import tempfile
import time

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
BANK = os.path.join(ROOT, "src", "ServerStorage", "PromptBank")
TIERS = ["Plankton", "TooClever", "Schooler", "Rare", "DeepCut", "Mythic"]
CURATED = ("Plankton", "TooClever")
WRAP = 110  # columns, a tab counting as 4
MAX_LENGTH = 40  # GameConfig.Answer.MaxLength

# The same folding as Shared/AnswerMatcher.luau (ACCENT_GROUPS, normalize).
ACCENT_GROUPS = [
    ("a", "àáâãäåāăąÀÁÂÃÄÅĀĂĄ"),
    ("c", "çćčÇĆČ"),
    ("d", "ďđðĎĐÐ"),
    ("e", "èéêëēėęěÈÉÊËĒĖĘĚ"),
    ("g", "ğĞ"),
    ("i", "ìíîïīįıÌÍÎÏĪĮİ"),
    ("l", "łľŁĽ"),
    ("n", "ñńňÑŃŇ"),
    ("o", "òóôõöøōőÒÓÔÕÖØŌŐ"),
    ("r", "řŘ"),
    ("s", "śšşșŚŠŞȘ"),
    ("t", "ťţțŤŢȚ"),
    ("u", "ùúûüūůűųÙÚÛÜŪŮŰŲ"),
    ("y", "ýÿÝŸ"),
    ("z", "źżžŹŻŽ"),
    ("ae", "æÆ"),
    ("oe", "œŒ"),
    ("ss", "ß"),
    ("th", "þÞ"),
    ("", "’‘´"),
]
ACCENTS = {ch: plain for plain, chars in ACCENT_GROUPS for ch in chars}


def normalize(text):
    out = []
    for ch in text:
        if ch in ACCENTS:
            out.append(ACCENTS[ch])
        elif ord(ch) < 128:
            out.append(ch)
        else:
            out.append(" ")
    result = "".join(out).lower()
    result = result.replace("&", " and ").replace("+", " plus ").replace("#", " sharp ")
    result = re.sub(r"[!-/:-@\[-`{-~]", "", result)
    return re.sub(r"\s+", " ", result).strip()


def width(text):
    return len(text.replace("\t", " " * 4))


class Bank:
    """One prompt file, as a list of lines with the places of its tier blocks and alias table."""

    def __init__(self, text):
        self.nl = "\r\n" if "\r\n" in text else "\n"
        self.lines = text.replace("\r\n", "\n").split("\n")
        self.parse()

    def text(self):
        return self.nl.join(self.lines)

    def parse(self):
        lines = self.lines
        try:
            start = lines.index("\tanswers = {")
        except ValueError:
            raise ValueError("no '\\tanswers = {' line")
        # An empty tier written on one line (`Mythic = {},`) becomes a header and a closing line, the form
        # every edit below works on.
        i = start + 1
        while i < len(lines) and lines[i] != "\t},":
            empty = re.match(r"^\t\t(\w+) = \{\},$", lines[i])
            if empty is not None:
                lines[i : i + 1] = ["\t\t%s = {" % empty.group(1), "\t\t},"]
            i += 1
        end = next((i for i in range(start + 1, len(lines)) if lines[i] == "\t},"), None)
        if end is None:
            raise ValueError("answers block is not closed")
        self.answers_end = end
        self.blocks = {}  # tier -> (header index, closing index)
        i = start + 1
        while i < end:
            match = re.match(r"^\t\t(\w+) = \{$", lines[i])
            if match is None:
                raise ValueError("line %d is not a tier header: %r" % (i + 1, lines[i]))
            close = next((j for j in range(i + 1, end + 1) if lines[j] == "\t\t},"), None)
            if close is None or close >= end:
                raise ValueError("tier %s is not closed" % match.group(1))
            self.blocks[match.group(1)] = (i, close)
            i = close + 1
        try:
            alias_start = lines.index("\taliases = {")
        except ValueError:
            alias_start = None
        if alias_start is None:
            self.alias_block = None
        else:
            alias_end = next((j for j in range(alias_start + 1, len(lines)) if lines[j] == "\t},"), None)
            if alias_end is None:
                raise ValueError("aliases block is not closed")
            self.alias_block = (alias_start, alias_end)

    def tier_entries(self, tier):
        if tier not in self.blocks:
            return []
        h, c = self.blocks[tier]
        return re.findall(r'"([^"\\]*)"', "\n".join(self.lines[h + 1 : c]))

    def all_answers(self):
        """answer -> tier, in file order."""
        result = {}
        for tier in sorted(self.blocks, key=lambda t: self.blocks[t][0]):
            for answer in self.tier_entries(tier):
                result.setdefault(answer, tier)
        return result

    def aliases(self):
        if self.alias_block is None:
            return {}
        h, c = self.alias_block
        pairs = re.findall(r'\["([^"\\]*)"\]\s*=\s*"([^"\\]*)"', "\n".join(self.lines[h + 1 : c]))
        return dict(pairs)

    def alias_pairs(self):
        if self.alias_block is None:
            return []
        h, c = self.alias_block
        return re.findall(r'\["([^"\\]*)"\]\s*=\s*"([^"\\]*)"', "\n".join(self.lines[h + 1 : c]))


def wrap(tokens, indent, first=None):
    """Greedy lines of tokens up to WRAP columns. `first` is a partly filled last line to carry on from."""
    out = []
    cur = first
    for token in tokens:
        if cur is None:
            cur = indent + token
        elif width(cur + " " + token) > WRAP:
            out.append(cur)
            cur = indent + token
        else:
            cur += " " + token
    if cur is not None:
        out.append(cur)
    return out


def append_tokens(lines, h, c, tokens, indent):
    """Adds tokens at the end of the block whose header is lines[h] and closing line lines[c]; returns the
    change in line count. Blank lines inside the block are dropped."""
    body = [l for l in lines[h + 1 : c] if l.strip()]
    first = body.pop() if body else None
    new = body + wrap(tokens, indent, first)
    lines[h + 1 : c] = new
    return len(new) - (c - h - 1)


def entry_tokens(entries):
    return ['"%s",' % e for e in entries]


def rebuild_tier(lines, h, c, entries):
    new = wrap(entry_tokens(entries), "\t\t\t")
    lines[h + 1 : c] = new
    return len(new) - (c - h - 1)


class Failure(Exception):
    pass


def check_with_lune(prompt_id):
    result = subprocess.run(
        ["lune", "run", "tests/check_prompt.luau", prompt_id],
        cwd=ROOT,
        capture_output=True,
        text=True,
    )
    return result.returncode == 0, (result.stdout + result.stderr).strip()


def ensure_tier(bank, tier):
    """Makes sure the file has a block for `tier`, in tier order; returns its (header, closing)."""
    if tier in bank.blocks:
        return bank.blocks[tier]
    index = TIERS.index(tier)
    after = None  # the closing line of the nearest lower tier that exists
    before = None  # the header of the nearest higher tier that exists
    for lower in reversed(TIERS[:index]):
        if lower in bank.blocks:
            after = bank.blocks[lower][1]
            break
    for higher in TIERS[index + 1 :]:
        if higher in bank.blocks:
            before = bank.blocks[higher][0]
            break
    if after is not None:
        at = after + 1
    elif before is not None:
        at = before
    else:
        at = bank.answers_end
    bank.lines[at:at] = ["\t\t%s = {" % tier, "\t\t},"]
    bank.parse()
    return bank.blocks[tier]


def op_add(bank, data, allow_top):
    report = {"added": {}, "aliasesAdded": 0, "skipped": [], "errors": []}
    existing = bank.all_answers()
    aliases = bank.aliases()
    additions = {}
    for tier, items in data.items():
        if tier == "aliases":
            continue
        if tier not in TIERS:
            report["errors"].append("unknown tier %r" % tier)
            continue
        if tier in CURATED and not allow_top:
            report["errors"].append("%s is curated: not added to (use --allow-top)" % tier)
            continue
        if not isinstance(items, list):
            report["errors"].append("%s must be a list" % tier)
            continue
        for raw in items:
            answer = normalize(str(raw))
            if not answer:
                report["skipped"].append("%r: empty after normalizing" % raw)
            elif len(answer) > MAX_LENGTH:
                report["errors"].append("%r is longer than %d characters" % (answer, MAX_LENGTH))
            elif answer in existing:
                report["skipped"].append("%s: already in %s" % (answer, existing[answer]))
            elif answer in aliases:
                report["skipped"].append("%s: already an alias of %s" % (answer, aliases[answer]))
            else:
                existing[answer] = tier
                additions.setdefault(tier, []).append(answer)
    new_aliases = []
    for raw_alias, raw_target in (data.get("aliases") or {}).items():
        alias = normalize(str(raw_alias))
        target = normalize(str(raw_target))
        if not alias or not target or alias == target:
            report["skipped"].append("alias %r -> %r: nothing to add" % (raw_alias, raw_target))
        elif len(alias) > MAX_LENGTH:
            report["errors"].append("alias %r is longer than %d characters" % (alias, MAX_LENGTH))
        elif alias in existing:
            report["skipped"].append("alias %s: is an answer (in %s)" % (alias, existing[alias]))
        elif alias in aliases:
            same = aliases[alias] == target
            report["skipped"].append("alias %s: already %s%s" % (alias, "this" if same else "an alias of ", "" if same else aliases[alias]))
        elif target not in existing:
            report["errors"].append("alias %s points at %s, which is not an answer" % (alias, target))
        else:
            aliases[alias] = target
            new_aliases.append((alias, target))
    for tier in TIERS:
        items = additions.get(tier)
        if not items:
            continue
        h, c = ensure_tier(bank, tier)
        append_tokens(bank.lines, h, c, entry_tokens(items), "\t\t\t")
        bank.parse()
        report["added"][tier] = len(items)
    if new_aliases:
        if bank.alias_block is None:
            raise Failure("this file has no aliases table")
        h, c = bank.alias_block
        append_tokens(bank.lines, h, c, ['["%s"] = "%s",' % pair for pair in new_aliases], "\t\t")
        bank.parse()
        report["aliasesAdded"] = len(new_aliases)
    return report, additions, new_aliases


def op_retier(bank, data, allow_top):
    report = {"moved": 0, "skipped": [], "errors": []}
    if isinstance(data, list):
        if not all(isinstance(item, dict) and "answer" in item and "to" in item for item in data):
            raise Failure("retier takes an object of answer -> tier, or a list of {answer, to}")
        data = {item["answer"]: item["to"] for item in data}
    if not isinstance(data, dict):
        raise Failure("retier takes an object of answer -> tier, or a list of {answer, to}")
    existing = bank.all_answers()
    moves = {}
    for raw, tier in data.items():
        answer = normalize(str(raw))
        if tier not in TIERS:
            report["errors"].append("%s: unknown tier %r" % (answer, tier))
        elif answer not in existing:
            report["errors"].append("%s: not an answer of this prompt" % answer)
        elif existing[answer] == tier:
            report["skipped"].append("%s: already %s" % (answer, tier))
        elif (tier in CURATED or existing[answer] in CURATED) and not allow_top:
            report["errors"].append("%s: %s -> %s touches a curated tier (use --allow-top)" % (answer, existing[answer], tier))
        else:
            moves[answer] = tier
    if not moves:
        return report, moves
    leaving = {}
    for answer in moves:
        leaving.setdefault(existing[answer], set()).add(answer)
    arriving = {}
    for answer, tier in moves.items():
        arriving.setdefault(tier, []).append(answer)
    for tier, gone in leaving.items():
        h, c = bank.blocks[tier]
        rebuild_tier(bank.lines, h, c, [e for e in bank.tier_entries(tier) if e not in gone])
        bank.parse()
    for tier in TIERS:
        if tier in arriving:
            h, c = ensure_tier(bank, tier)
            append_tokens(bank.lines, h, c, entry_tokens(arriving[tier]), "\t\t\t")
            bank.parse()
    report["moved"] = len(moves)
    return report, moves


def op_remove(bank, data, drop_aliases, allow_top):
    report = {"removed": 0, "aliasesDropped": 0, "skipped": [], "errors": []}
    if not isinstance(data, list):
        raise Failure("remove takes a list of answers")
    existing = bank.all_answers()
    aliases = bank.aliases()
    gone = {}
    for raw in data:
        answer = normalize(str(raw))
        if answer not in existing:
            report["skipped"].append("%s: not an answer of this prompt" % answer)
        elif existing[answer] in CURATED and not allow_top:
            report["errors"].append("%s: in curated %s (use --allow-top)" % (answer, existing[answer]))
        else:
            gone[answer] = existing[answer]
    pointing = {}
    for alias, target in aliases.items():
        if target in gone:
            pointing.setdefault(target, []).append(alias)
    if pointing and not drop_aliases:
        for target, names in pointing.items():
            report["errors"].append("%s: aliases point at it: %s (use --drop-aliases)" % (target, ", ".join(names[:6])))
            del gone[target]
    drop = set()
    if drop_aliases:
        for target in gone:
            drop.update(pointing.get(target, []))
    by_tier = {}
    for answer, tier in gone.items():
        by_tier.setdefault(tier, set()).add(answer)
    for tier, names in by_tier.items():
        h, c = bank.blocks[tier]
        rebuild_tier(bank.lines, h, c, [e for e in bank.tier_entries(tier) if e not in names])
        bank.parse()
    if drop:
        drop_alias_entries(bank, drop)
    report["removed"] = len(gone)
    report["aliasesDropped"] = len(drop)
    return report, gone, drop


def drop_alias_entries(bank, names):
    pairs = [(a, t) for a, t in bank.alias_pairs() if a not in names]
    h, c = bank.alias_block
    bank.lines[h + 1 : c] = wrap(['["%s"] = "%s",' % pair for pair in pairs], "\t\t")
    bank.parse()


def op_unalias(bank, data):
    report = {"aliasesDropped": 0, "skipped": [], "errors": []}
    if not isinstance(data, list):
        raise Failure("unalias takes a list of aliases")
    aliases = bank.aliases()
    names = set()
    for raw in data:
        alias = normalize(str(raw))
        if alias in aliases:
            names.add(alias)
        else:
            report["skipped"].append("%s: not an alias" % alias)
    if names:
        drop_alias_entries(bank, names)
    report["aliasesDropped"] = len(names)
    return report, names


class Lock:
    def __init__(self, prompt_id):
        base = os.path.join(tempfile.gettempdir(), "rws-bank-locks")
        os.makedirs(base, exist_ok=True)
        self.path = os.path.join(base, prompt_id)

    def __enter__(self):
        for _ in range(1800):  # three minutes
            try:
                os.mkdir(self.path)
                return self
            except FileExistsError:
                try:
                    if time.time() - os.path.getmtime(self.path) > 120:
                        os.rmdir(self.path)  # a crashed run left it behind
                        continue
                except OSError:
                    pass
                time.sleep(0.1)
        raise Failure("could not get the lock on this prompt")

    def __exit__(self, *_):
        try:
            os.rmdir(self.path)
        except OSError:
            pass


def read_json(source):
    text = sys.stdin.read() if source == "-" else open(source, encoding="utf-8").read()
    return json.loads(text)


def prompt_path(prompt_id):
    if not re.fullmatch(r"[a-z0-9_]+", prompt_id) or prompt_id == "init":
        raise Failure("not a prompt id: %r" % prompt_id)
    path = os.path.join(BANK, prompt_id + ".luau")
    if not os.path.isfile(path):
        raise Failure("no prompt file " + path)
    return path


def summary(bank):
    return {
        "answers": len(bank.all_answers()),
        "aliases": len(bank.aliases()),
        "tiers": {t: len(bank.tier_entries(t)) for t in TIERS if t in bank.blocks},
    }


def edit(command, prompt_id, source, flags):
    path = prompt_path(prompt_id)
    data = read_json(source)
    allow_top = "--allow-top" in flags
    with Lock(prompt_id):
        original = open(path, encoding="utf-8", newline="").read()
        bank = Bank(original)
        before_answers = bank.all_answers()
        before_aliases = bank.aliases()
        if command == "add":
            report, additions, new_aliases = op_add(bank, data, allow_top)
            expect_answers = dict(before_answers)
            for tier, items in additions.items():
                for answer in items:
                    expect_answers[answer] = tier
            expect_aliases = dict(before_aliases)
            expect_aliases.update(dict(new_aliases))
        elif command == "retier":
            report, moves = op_retier(bank, data, allow_top)
            expect_answers = dict(before_answers)
            expect_answers.update(moves)
            expect_aliases = dict(before_aliases)
        elif command == "remove":
            report, gone, drop = op_remove(bank, data, "--drop-aliases" in flags, allow_top)
            expect_answers = {a: t for a, t in before_answers.items() if a not in gone}
            expect_aliases = {a: t for a, t in before_aliases.items() if a not in drop}
        else:
            report, names = op_unalias(bank, data)
            expect_answers = dict(before_answers)
            expect_aliases = {a: t for a, t in before_aliases.items() if a not in names}
        changed = bank.text() != original
        if changed:
            # Prove the new text says exactly what was meant before anything is written.
            proof = Bank(bank.text())
            if proof.all_answers() != expect_answers or proof.aliases() != expect_aliases:
                raise Failure("the edited file does not hold exactly what was asked; nothing was written")
            history = os.path.join(tempfile.gettempdir(), "rws-bank-history", prompt_id)
            os.makedirs(history, exist_ok=True)
            with open(os.path.join(history, "%d.luau" % int(time.time() * 1000)), "w", encoding="utf-8", newline="") as f:
                f.write(original)
            with open(path, "w", encoding="utf-8", newline="") as f:
                f.write(bank.text())
            good, output = check_with_lune(prompt_id)
            if not good:
                with open(path, "w", encoding="utf-8", newline="") as f:
                    f.write(original)
                raise Failure("check_prompt failed, the file was put back:\n" + output)
        report.update(summary(bank))
        report["id"] = prompt_id
        report["changed"] = changed
        report["ok"] = True
        return report


def stats(prompt_id):
    ids = [prompt_id] if prompt_id else sorted(
        f[:-5] for f in os.listdir(BANK) if f.endswith(".luau") and f != "init.luau"
    )
    rows = []
    for one in ids:
        bank = Bank(open(prompt_path(one), encoding="utf-8", newline="").read())
        rows.append((one, summary(bank)))
    total_answers = 0
    for one, info in rows:
        total_answers += info["answers"]
        tiers = " ".join("%s %d" % (t[:3] if t != "TooClever" else "Too", n) for t, n in info["tiers"].items())
        print("%-22s %5d answers %5d aliases   %s" % (one, info["answers"], info["aliases"], tiers))
    if len(rows) > 1:
        print("%d prompts, %d answers, %d aliases" % (len(rows), total_answers, sum(i["aliases"] for _, i in rows)))


def show(prompt_id, tiers):
    bank = Bank(open(prompt_path(prompt_id), encoding="utf-8", newline="").read())
    wanted = tiers or TIERS
    for tier in wanted:
        if tier not in TIERS:
            raise Failure("unknown tier %r" % tier)
        entries = bank.tier_entries(tier)
        print("== %s (%d)" % (tier, len(entries)))
        line = ""
        for entry in entries:
            piece = entry + "; "
            if len(line) + len(piece) > 150:
                print(line.rstrip())
                line = ""
            line += piece
        if line:
            print(line.rstrip())


def selftest():
    bad = 0
    for name in sorted(os.listdir(BANK)):
        if not name.endswith(".luau") or name == "init.luau":
            continue
        try:
            bank = Bank(open(os.path.join(BANK, name), encoding="utf-8", newline="").read())
            if not bank.all_answers():
                raise ValueError("no answers found")
        except Exception as error:  # noqa: BLE001
            bad += 1
            print("FAIL", name, error)
    print("selftest: %s" % ("every file parses" if bad == 0 else "%d files do not parse" % bad))
    return bad == 0


def main(argv):
    flags = [a for a in argv if a.startswith("--")]
    args = [a for a in argv if not a.startswith("--")]
    if not args:
        print(__doc__)
        return 2
    command = args[0]
    try:
        if command == "selftest":
            return 0 if selftest() else 1
        if command == "show" and len(args) >= 2:
            show(args[1], args[2:])
            return 0
        if command == "stats":
            stats(args[1] if len(args) > 1 else None)
            return 0
        if command in ("add", "retier", "remove", "unalias") and len(args) == 3:
            report = edit(command, args[1], args[2], flags)
            print(json.dumps(report, ensure_ascii=False))
            return 0
        print(__doc__)
        return 2
    except (Failure, ValueError, json.JSONDecodeError) as error:
        print(json.dumps({"ok": False, "error": str(error)}, ensure_ascii=False))
        return 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
