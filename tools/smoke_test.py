"""Headless smoke test for game.html.

Opens the game in a headless Chromium, checks rendering, input handling and
JavaScript errors. Never opens a visible window. Kept ASCII-only because the
Windows console still uses a legacy codepage in some setups.

Usage:
    pip install playwright
    python -m playwright install chromium
    python tools/smoke_test.py
"""

import hashlib
import sys
from pathlib import Path

from playwright.sync_api import sync_playwright

ROOT = Path(__file__).resolve().parent.parent
GAME = ROOT / "game.html"
ASSET = ROOT / "apk_project" / "assets" / "game.html"

SAMPLE_JS = """
() => {
  const c = document.getElementById('gameCanvas');
  const g = c.getContext('2d');
  const d = g.getImageData(0, 0, c.width, c.height).data;
  const colors = new Set();
  let sum = 0;
  for (let i = 0; i < d.length; i += 4 * 499) {
    colors.add((d[i] << 16) | (d[i + 1] << 8) | d[i + 2]);
  }
  for (let i = 0; i < d.length; i += 4 * 4999) {
    sum += (d[i] + d[i + 1] * 3 + d[i + 2] * 7) * ((i % 97) + 1);
  }
  return { colors: colors.size, sum: sum, w: c.width, h: c.height };
}
"""

passed = 0
failed = 0


def check(name, condition, detail=""):
    global passed, failed
    if condition:
        passed += 1
        print("PASS  " + name)
    else:
        failed += 1
        print("FAIL  " + name + ("  (" + detail + ")" if detail else ""))


def main():
    check("game.html exists", GAME.is_file())

    if ASSET.is_file():
        same = hashlib.sha256(GAME.read_bytes()).hexdigest() == hashlib.sha256(
            ASSET.read_bytes()
        ).hexdigest()
        check("apk_project/assets/game.html matches game.html", same,
              "run the copy step after editing game.html")

    errors = []
    with sync_playwright() as pw:
        browser = pw.chromium.launch(headless=True)
        page = browser.new_page(viewport={"width": 420, "height": 700})
        page.on("pageerror", lambda exc: errors.append("pageerror: " + str(exc)))
        page.on(
            "console",
            lambda msg: errors.append("console: " + msg.text)
            if msg.type == "error"
            else None,
        )

        page.goto(GAME.as_uri())
        page.wait_for_timeout(700)

        first = page.evaluate(SAMPLE_JS)
        check("canvas has non-zero size", first["w"] > 0 and first["h"] > 0,
              "%dx%d" % (first["w"], first["h"]))
        check("menu is actually drawn", first["colors"] >= 20,
              "unique sampled colors = %d" % first["colors"])

        page.keyboard.press("Enter")
        page.wait_for_timeout(1200)
        second = page.evaluate(SAMPLE_JS)
        check("game advances after Enter", second["sum"] != first["sum"])

        for key in ("ArrowLeft", "ArrowUp", "ArrowRight", "ArrowDown"):
            page.keyboard.press(key)
            page.wait_for_timeout(120)
        page.wait_for_timeout(300)
        third = page.evaluate(SAMPLE_JS)
        check("input does not freeze rendering", third["sum"] != second["sum"])

        storage = page.evaluate(
            """
            () => {
              try {
                localStorage.setItem('ss_smoke', '1');
                const v = localStorage.getItem('ss_smoke');
                localStorage.removeItem('ss_smoke');
                return v;
              } catch (e) { return 'error: ' + e.message; }
            }
            """
        )
        check("localStorage works", storage == "1", str(storage))

        page.screenshot(path=str(ROOT / "_shot_headless.png"))
        check("screenshot captured", (ROOT / "_shot_headless.png").stat().st_size > 10000)

        browser.close()

    check("no page/console errors", not errors, "; ".join(errors[:3]))

    print("")
    print("%d passed, %d failed" % (passed, failed))
    return 0 if failed == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
