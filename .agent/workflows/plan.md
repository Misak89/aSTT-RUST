---
description: Plánování implementace dle frameworku Superpowers (Spec-Driven).
---

1. Na základě schváleného designu vytvoř podrobný plán.
2. Použij metodiku ze souboru [tools/superpowers/skills/writing-plans/SKILL.md](../../tools/superpowers/skills/writing-plans/SKILL.md).
3. Každý krok plánu musí být atomický (2-5 min) a obsahovat:
   - Přesné cesty k souborům.
   - **Důkaz o selhání** (Evidence of Failure/RED): Spusť test a ukaž chybu.
   - Kód minimální implementace.
   - **Důkaz o opravě** (Evidence of Fix/GREEN): Spusť test a ukaž, že prošel.
   - Verifikační příkaz.
4. Plán ulož do `docs/plans/YYYY-MM-DD-<feature-name>.md`.
