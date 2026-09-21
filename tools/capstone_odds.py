"""Monte Carlo of how often each character's Birthstone tiers fire.

Run: python3 tools/capstone_odds.py
Each character rolls its starting bowl, spends its rerolls with a greedy policy that chases its
own capstone, and the final hand is scored. Numbers back docs/CHARACTERS.md.
"""
import random
from collections import Counter

random.seed(2026)
N = 200_000
REROLLS = 2


def D(n):
    return list(range(1, n + 1))


def roll_die(faces):
    return random.choice(faces)


def roll(dice):
    return [roll_die(f) for f in dice]


def mean(dice):
    return sum(sum(f) / len(f) for f in dice)


def pct(x):
    return f"{100 * x:5.1f}%"


def reroll(hand, dice, keep):
    return [x if keep[i] else roll_die(dice[i]) for i, x in enumerate(hand)]


# --- Ardor: sets ---------------------------------------------------------------------------
def ardor(dice, rerolls):
    h = roll(dice)
    for _ in range(rerolls):
        v, n = Counter(h).most_common(1)[0]
        if n == 5:
            break
        h = reroll(h, dice, [x == v for x in h])
    return Counter(h).most_common(1)[0][1]


# --- Vesper: distinct, variants --------------------------------------------------------------
def vesper(dice, rerolls, mode):
    """mode: distinct | ascending | distinct_high10 | ladder"""
    h = roll(dice)
    for _ in range(rerolls):
        if vesper_ok(h, dice, mode):
            break
        keep = [False] * 5
        if mode == "ascending":
            for i in range(4):
                keep[i] = h[i] == i + 1
            keep[4] = h[4] >= 5
        else:
            seen = set()
            for i in sorted(range(5), key=lambda i: -max(dice[i])):
                low_big = max(dice[i]) >= 12 and h[i] <= (9 if mode == "distinct_high10" else 4)
                if h[i] not in seen and not low_big:
                    seen.add(h[i])
                    keep[i] = True
        h = reroll(h, dice, keep)
    return vesper_ok(h, dice, mode), max(h)


def vesper_ok(h, dice, mode):
    if mode == "distinct":
        return len(set(h)) == 5
    if mode == "distinct_high10":
        return len(set(h)) == 5 and max(h) >= 10
    if mode == "ascending":
        return all(h[i] == i + 1 for i in range(4)) and h[4] >= 5
    if mode == "ladder":
        return {1, 2, 3, 4} <= set(h) and max(h) > 4 and len(set(h)) == 5
    raise ValueError(mode)


# --- Cadence: straights ----------------------------------------------------------------------
def longest_run(vals):
    s = sorted(set(vals))
    best, cur = [], []
    for v in s:
        cur = cur + [v] if cur and v == cur[-1] + 1 else [v]
        if len(cur) > len(best):
            best = cur[:]
    return best


def cadence(dice, rerolls):
    h = roll(dice)
    for _ in range(rerolls):
        run = longest_run(h)
        if len(run) == 5:
            break
        used, keep = set(), [False] * 5
        for i, x in enumerate(h):
            if x in run and x not in used:
                used.add(x)
                keep[i] = True
        h = reroll(h, dice, keep)
    return len(longest_run(h))


# --- Rue: low dice and ones ------------------------------------------------------------------
def rue(dice, shape_max, rerolls, chase_ones):
    h = roll(dice)
    for _ in range(rerolls):
        if chase_ones:
            if all(x == 1 for x in h):
                break
            h = reroll(h, dice, [x == 1 for x in h])
        else:
            if all(x * 2 <= shape_max[i] for i, x in enumerate(h)):
                break
            h = reroll(h, dice, [x * 2 <= shape_max[i] for i, x in enumerate(h)])
    nlow = sum(x * 2 <= shape_max[i] for i, x in enumerate(h))
    return nlow, all(x == 1 for x in h)


# --- Florin: crowns with free reroll of ones --------------------------------------------------
def florin(dice, rerolls, free_ones):
    h = roll(dice)
    if free_ones:
        h = [roll_die(dice[i]) if x == 1 else x for i, x in enumerate(h)]
    for _ in range(rerolls):
        crown = [x == max(dice[i]) for i, x in enumerate(h)]
        if all(crown):
            break
        h = reroll(h, dice, crown)
        if free_ones:
            h = [roll_die(dice[i]) if x == 1 and not crown[i] else x for i, x in enumerate(h)]
    return sum(x == max(dice[i]) for i, x in enumerate(h))


# --- Harrow: high total ----------------------------------------------------------------------
def harrow(dice, rerolls):
    h = roll(dice)
    top = sum(max(f) for f in dice)
    for _ in range(rerolls):
        if all(x * 2 > max(dice[i]) for i, x in enumerate(h)):
            break
        h = reroll(h, dice, [x * 2 > max(dice[i]) for i, x in enumerate(h)])
    return sum(h) / top


# --- Blaise: exploding dice ------------------------------------------------------------------
def explode_roll():
    """An exploding d6: a 6 rolls again and adds. Returns (value, explosions)."""
    total, n = 0, 0
    while True:
        r = random.randint(1, 6)
        total += r
        if r != 6:
            return total, n
        n += 1


def blaise(n_exploding, rerolls):
    vals, booms = [], []
    for i in range(5):
        if i < n_exploding:
            v, b = explode_roll()
        else:
            v, b = random.randint(1, 6), 0
        vals.append(v)
        booms.append(b)
    for _ in range(rerolls):
        if all(b > 0 for b in booms[:n_exploding]):
            break
        for i in range(5):
            if i < n_exploding and booms[i] == 0:
                vals[i], booms[i] = explode_roll()
            elif i >= n_exploding and vals[i] * 2 <= 6:
                vals[i] = random.randint(1, 6)
    return sum(1 for b in booms if b > 0), max(booms), sum(vals)


# --- Puck: parity with one free flip ---------------------------------------------------------
def puck(dice, rerolls, flip, chase_motley):
    h = roll(dice)
    for _ in range(rerolls):
        odd = sum(x % 2 for x in h)
        tgt = 1 if odd >= 3 else 0
        if odd in (0, 5) and (not chase_motley or len(set(h)) == 5):
            break
        keep, seen = [False] * 5, set()
        for i, x in enumerate(h):
            if x % 2 == tgt and (not chase_motley or x not in seen):
                seen.add(x)
                keep[i] = True
        h = reroll(h, dice, keep)
    if flip:
        odd = sum(x % 2 for x in h)
        if odd in (1, 4):
            tgt = 1 if odd == 4 else 0
            i = next(i for i, x in enumerate(h) if x % 2 != tgt)
            h[i] = max(dice[i]) + 1 - h[i]
        elif odd in (0, 5) and chase_motley and len(set(h)) < 5:
            pass  # a flip would break parity; keep the safe tier
    odd = sum(x % 2 for x in h)
    same = max(odd, 5 - odd)
    return same, same == 5 and len(set(h)) == 5


def main():
    print(f"{N:,} hands per line, {REROLLS} rerolls unless stated\n")

    K = [D(6), D(6), D(6), D(8), D(8)]
    print(f"ARDOR  d6 d6 d6 d8 d8  mean {mean(K):.1f}")
    for rr in (0, REROLLS):
        c = Counter(ardor(K, rr) for _ in range(N))
        print(f"  rerolls {rr}: pair {pct(sum(v for k, v in c.items() if k >= 2) / N)} triple {pct(sum(v for k, v in c.items() if k >= 3) / N)} quad {pct(sum(v for k, v in c.items() if k >= 4) / N)} quint {pct(c[5] / N)}")

    print()
    for label, dice in [("d4 d4 d4 d4 d20", [D(4)] * 4 + [D(20)]), ("d4 d4 d6 d8 d20 (a mid-run bowl)", [D(4), D(4), D(6), D(8), D(20)])]:
        print(f"VESPER  {label}  mean {mean(dice):.1f}")
        for mode in ("distinct", "ascending", "distinct_high10", "ladder"):
            for rr in (0, REROLLS):
                res = [vesper(dice, rr, mode) for _ in range(N)]
                hits = [m for ok, m in res if ok]
                rate = len(hits) / N
                avg = sum(hits) / len(hits) if hits else 0
                print(f"  {mode:15s} rerolls {rr}: fires {pct(rate)}  avg hits {avg:4.1f}  expected hits/turn {rate * avg:4.1f}")

    print()
    W = [D(4), D(6), D(8), D(10), D(12)]
    print(f"CADENCE  d4 d6 d8 d10 d12  mean {mean(W):.1f}")
    for rr in (0, 2, 3):
        c = Counter(cadence(W, rr) for _ in range(N))
        print(f"  rerolls {rr}: small straight {pct((c[4] + c[5]) / N)} large {pct(c[5] / N)}")

    print()
    PHIAL = [1, 1, 1, 2, 2, 3]
    R = [D(4), D(4), D(6), D(6), PHIAL]
    RM = [4, 4, 6, 6, 6]
    print(f"RUE  d4 d4 d6 d6 Phial(1 1 1 2 2 3)  mean {mean(R):.1f}")
    for chase in (False, True):
        res = [rue(R, RM, REROLLS, chase) for _ in range(N)]
        print(f"  chasing {'ones' if chase else 'low '}: 4+ low {pct(sum(n >= 4 for n, _ in res) / N)}  all low {pct(sum(n == 5 for n, _ in res) / N)}  all ones {pct(sum(o for _, o in res) / N)}")

    print()
    G = [[1, 2, 3, 4, 5, 7]] * 5
    print(f"FLORIN  five d6 with the 6 replaced by 7  mean {mean(G):.1f}")
    for free in (False, True):
        c = Counter(florin(G, REROLLS, free) for _ in range(N))
        print(f"  {'free reroll of ones' if free else 'no passive         '}: no crown {pct(c[0] / N)}  1+ {pct(1 - c[0] / N)}  3+ {pct((c[3] + c[4] + c[5]) / N)}  five {pct(c[5] / N)}  avg {sum(k * v for k, v in c.items()) / N:.2f}")

    print()
    H = [D(8), D(8), D(10), D(10), D(12)]
    print(f"HARROW  d8 d8 d10 d10 d12  mean {mean(H):.1f}")
    for rr in (0, REROLLS):
        res = [harrow(H, rr) for _ in range(N)]
        print(f"  rerolls {rr}: total>=60% {pct(sum(t >= .6 for t in res) / N)}  >=75% {pct(sum(t >= .75 for t in res) / N)}  >=90% {pct(sum(t >= .9 for t in res) / N)}")

    print()
    for n_ex in (3, 5):
        print(f"BLAISE  {n_ex} exploding d6 + {5 - n_ex} plain d6")
        res = [blaise(n_ex, REROLLS) for _ in range(N)]
        print(f"  mean total {sum(t for _, _, t in res) / N:.1f}  1+ explosion {pct(sum(c >= 1 for c, _, _ in res) / N)}  3+ dice exploded {pct(sum(c >= 3 for c, _, _ in res) / N)}  a double {pct(sum(m >= 2 for _, m, _ in res) / N)}  a triple {pct(sum(m >= 3 for _, m, _ in res) / N)}")

    print()
    P = [D(6), D(6), D(8), D(8), D(10)]
    print(f"PUCK  d6 d6 d8 d8 d10  mean {mean(P):.1f}")
    for flip in (False, True):
        for motley in (False, True):
            res = [puck(P, REROLLS, flip, motley) for _ in range(N)]
            print(f"  flip {'on ' if flip else 'off'} chasing {'motley' if motley else 'parity'}: all one parity {pct(sum(s == 5 for s, _ in res) / N)}  full motley {pct(sum(m for _, m in res) / N)}")


if __name__ == "__main__":
    main()
