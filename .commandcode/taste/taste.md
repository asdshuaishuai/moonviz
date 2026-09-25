# Taste

- Requires core fixes to be synchronously propagated to all product surfaces (SDK capability tiers, CLI, MCP, SKILL, site/docs, playground) instead of fixing core alone. Confidence: 0.85
- Requires a review pass over the current diff before starting follow-up sync work. Confidence: 0.8
- Requires syncing/bumping the baseline version with `-fix` suffix in GitHub Actions version gates when landing fixes. Confidence: 0.8
- Requires closing releases end-to-end via GitHub Actions (tag → binaries Release as Latest → Pages deploy) with live verification of docs site and playground wasm, not just bumping version constants. Confidence: 0.8
