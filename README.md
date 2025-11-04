# Bodily Fluids Mod

Adds basic bladder/stomach mechanics and related items to Cataclysm: Bright Nights. Provides pee/defecate actions via the mutations menu. The ultimate shitpost mod.

<img width="1918" height="1075" alt="image" src="https://github.com/user-attachments/assets/d2683376-dd93-4244-8331-5956b90f3653" />

---

# Features
 - Urine can be distilled (distillation device) into clean water and salt.
 - Using a toilet grants a morale bonus, unless incontinent which uses a diaper instead.
 - `incontinent` trait: prevents controlled use and may not interrupt actions; starts with a box of diapers.
 - Diapers: `diaper`, `dirty_diaper`, `diaper_box` — can be sewn from rags/towel and dirty ones washed.
 - Soiling (urinating/defecating) applies a morale penalty and can wet items.
 - Male characters may choose a direction to pee; urine can extinguish small fires.
 - Thirst and metabolism affect how quickly bladder/stomach fill.
 - The character will expel their bodily fluid contents when on the very brink of death.

# Behavior
 - Every turn the mod updates bladder (from thirst) and stomach (from kcal/metabolism).
 - Warnings show at ~50/75/90%; at 100% the player soils themself unless wearing a diaper (which converts to `dirty_diaper`).
 - `expel()` places `human_urine` or `human_feces` on the map, handles diaper conversion, morale changes, wetting clothing, and small-fire reduction.
