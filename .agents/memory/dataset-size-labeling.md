---
name: Dataset size labeling
description: How unlabeled calamansi measurements are assigned to the model's size categories.
---

When importing weight/juice measurements that do not carry a trustworthy size label, assign the existing model categories by weight: up to 10 g is Small, 11–14 g is Medium, and 15 g or more is Large.

**Why:** The training schema requires a numeric size feature, while source measurement sheets may only provide weight and juice. These thresholds match the dominant size pattern already present in the project dataset without discarding otherwise usable observations.

**How to apply:** Preserve the original upload as a source asset, normalize only valid weight/juice pairs, and retrain the existing model files after appending the rows.