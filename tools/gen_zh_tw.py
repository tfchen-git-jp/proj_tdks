#!/usr/bin/env python3
"""Writes locale/zh_TW.po, the Traditional Chinese (Taiwan) catalogue.

    python3 tools/gen_zh_tw.py && python3 tools/make_font.py && tools/loc_check.py

G is the glossary: the user's picks from the picking page
(https://claude.ai/artifact/PRIVATE-LINK, store `picks`; see
CLAUDE.md "Localization"). Every sentence below is written with G, so a
changed pick changes every text that uses it. Wording rules: Taiwan usage
(tools/loc_check.py MAINLAND), full-width punctuation after Chinese, a
space between Chinese and a number or Latin word ("第 3 波", "Lv 5").
"""
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "locale", "zh_TW.po")

# --- the glossary: the user's picks of 2026-10-10 (all 65 rows) ------------
G = dict(
    title="俠盜塔防遊戲", title_short="俠盜塔防",
    title_big="俠盜塔防", title_sub="RogueShot Tower Defense",
    build_phase="建造階段", combat_phase="戰鬥階段",
    wave="波",                       # 第 3 波（共 10 波）
    keep="主堡", hero="英雄", gold="黃金",
    level_up="等級提升！", xp="經驗值", xp_pop="經驗",
    choose="三選一", relic="聖物", reroll="重骰", new="新",
    tower_spot="塔點", tower_pad="塔", gate_spot="城門點", gate_pad="門",
    eco_plot="資源點", eco_pad="資源", start="開戰",
    west="左路", centre="中路", east="右路",
    b_strong="克制：", b_weak="被克制：", e_weak="弱點：", e_strong="強項：",
    armor="護甲", splash="濺射", interest="利息", berserk="狂暴",
    guide="指南", scores="排行榜", top10="前十名",
    # buildings
    archer="弓箭塔", ballista="弩砲塔", mortar="臼砲塔", frost_t="冰晶塔", banner="戰旗塔",
    farm="農場", bank="銀行", gate="城門",
    # enemies
    grunt="雜兵", armored="裝甲兵", brute="巨人", runner="疾行兵", bat="魔蝠",
    crossbowman="骷髏弩手", boss="骷髏戰閥",
    # cards
    c_dmg="磨尖箭矢", c_aspd="快速上弦", c_range="長程射擊", c_multi="多重射擊", c_pierce="穿透弩箭",
    c_ricochet="彈跳彈", c_blast="爆裂箭簇", c_fire="烈焰箭", c_frost="寒冰箭", c_crit="銳眼",
    c_slayer="巨人殺手", c_boots="迅捷之靴", c_scholar="學者", c_rally="鼓舞", c_spotter="觀測手",
    c_engineer="工程師", c_bounty="賞金",
    # relics
    r_twin="雙聯弩", r_volley="箭雨", r_thunder="天雷擊", r_wisp="追射妖精", r_midas="點金術",
    r_laststand="背水一戰",
)
# Everyday words used in the texts (not picks): the element words the UI
# colours must appear verbatim in the sentences (UiText matches them).
W = dict(fire="火焰", burn="燃燒", ablaze="點燃", chill="冰凍", slow="緩速", lightning="閃電",
         critical="爆擊", ingot="金條", the_boss="頭目", giants="巨人",
         gates="城門", the_hero="英雄", archers="弓箭塔", ballistas="弩砲", mortars="臼砲", frost="冰霜水晶")


def build():
    g, w = G, W
    T = {}  # (ctx, english) -> chinese

    def t(en, zh, ctx=""):
        T[(ctx, en)] = zh

    # --- title, menu, confirmations ---------------------------------------
    t("RogueShot", g["title_big"])
    t("TOWER DEFENSE", g["title_sub"])
    t("New game", "新遊戲")
    t("Continue", "繼續")
    t("Continue  (wave %d)", "繼續（第 %%d %s）" % g["wave"])
    t("Scores", g["scores"])
    t("Guide", g["guide"])
    t("Credits", "製作群")
    t("Exit", "離開")
    t("Back", "返回")
    t("Language: %s", "語言：%s")
    t("Top 10", g["top10"])
    t("Most waves cleared, then score:\nkeep HP % x 10 + gold left",
      "通過波數多者優先，其次比分數：\n%s生命 %% x 10 + 剩餘%s" % (g["keep"], g["gold"]))
    t("No games finished yet.", "還沒有完成的遊戲。")
    t("WIN", "勝利")
    t("wave %d", "第 %%d %s" % g["wave"])
    t("%d pts", "%d 分")
    t("BUILDINGS", "建築")
    t("ENEMIES", "敵人")
    t("Yes", "是")
    t("No", "否")
    t("Quit RogueShot TD?", "要離開%s嗎？" % g["title"])
    t("Quit", "離開")
    t("Cancel", "取消")
    t("Leave", "離開")
    t("Keep playing", "繼續玩")
    t("Back to the main menu?\n\nContinue will resume from %s. Anything after that is lost.",
      "要回到主選單嗎？\n\n「繼續」將從%s重新開始，之後的進度會遺失。")
    t("the start of wave %d", "第 %%d %s開始時" % g["wave"])
    t("this build phase (wave %d)", "目前的%s（第 %%d %s）" % (g["build_phase"], g["wave"]))
    t("Main menu", "主選單")
    t("Play again", "再玩一次")
    t("VICTORY!", "勝利！")
    t("DEFEAT", "失敗")
    t("Waves cleared: %d / %d\nKeep %d%%  +  gold %d\nScore %d",
      "通過波數：%%d／%%d\n%s %%d%%%%  +  %s %%d\n分數 %%d" % (g["keep"], g["gold"]))
    t("\nNew top-10 entry: #%d", "\n新紀錄：第 %d 名")
    t("RogueShot Tower Defense\nMade with Godot Engine 4.7 (godotengine.org), by directing Claude.\n\n3D MODELS (CC0)\n"
      "Kay Lousberg (kaylousberg.com): KayKit Adventurers (hero, barbarian), Skeletons (crossbowmen, Bone Warlord), "
      "Medieval Hexagon (archer tower, windmill, market, keep, flag, gate), Dungeon Remastered (coins), Forest Nature (rocks)\n"
      "Kenney (kenney.nl): Tower Defense Kit, Mini Dungeon, Mini Arena, Nature Kit\n"
      "Quaternius (quaternius.com): Animated Monsters (bat)\n\nSOUND (CC0 unless noted)\n"
      "Kenney: RPG Audio, Impact Sounds, Interface Sounds, Casino Audio, Sci-fi Sounds, Music Jingles\n"
      "OpenGameArt: artisticdude (bow, freeze spell), Vehicle / Jan Schupke (Tinysized SFX), bart (ice spells), "
      "rubberduck (creature SFX), Joth (chunky explosion), qubodup (dull explosion), fvcalderan (fanfare), "
      "0new4y (game-over trumpet)\nWave horn: \"Scary Echoey Horn Esque Sound\" by Kat, CC-BY 4.0 (opengameart.org)\n\n"
      "MUSIC\n\"RPG City\" by phantasticbeats (Pixabay)\n\nThanks for playing!",
      "%s\n以 Godot Engine 4.7（godotengine.org）製作，由 Claude 協力開發。\n\n3D 模型（CC0）\n"
      "Kay Lousberg（kaylousberg.com）：KayKit Adventurers（%s、%s）、Skeletons（%s、%s）、"
      "Medieval Hexagon（%s、風車、市集、%s、旗幟、%s）、Dungeon Remastered（金幣）、Forest Nature（岩石）\n"
      "Kenney（kenney.nl）：Tower Defense Kit、Mini Dungeon、Mini Arena、Nature Kit\n"
      "Quaternius（quaternius.com）：Animated Monsters（%s）\n\n音效（除另註明外皆為 CC0）\n"
      "Kenney：RPG Audio、Impact Sounds、Interface Sounds、Casino Audio、Sci-fi Sounds、Music Jingles\n"
      "OpenGameArt：artisticdude（弓、冰凍法術）、Vehicle / Jan Schupke（Tinysized SFX）、bart（冰系法術）、"
      "rubberduck（生物音效）、Joth（爆炸）、qubodup（悶響爆炸）、fvcalderan（號角曲）、"
      "0new4y（失敗號角）\n波次號角：Kat〈Scary Echoey Horn Esque Sound〉，CC-BY 4.0（opengameart.org）\n\n"
      "音樂\nphantasticbeats〈RPG City〉（Pixabay）\n\n感謝遊玩！"
      % (g["title"], g["hero"], g["brute"], g["crossbowman"], g["boss"], g["archer"], g["keep"], g["gate"], g["bat"]))

    # --- HUD, phases, messages ----------------------------------------------
    t("KEEP", g["keep"])
    t("WAVE %d/%d  -  %s", "第 %%d/%%d %s  -  %%s" % g["wave"])
    t("BUILD PHASE", g["build_phase"])
    t("COMBAT PHASE  (%d)", "%s（%%d）" % g["combat_phase"])
    t("Build your defences,\nthen stand on START to begin", "建立防線，\n然後站上「%s」開始" % g["start"])
    t("Wave %d!", "第 %%d %s！" % g["wave"])
    t("Wave %d cleared!", "第 %%d %s結束！" % g["wave"])
    t("+%d gold from farms", "%s +%%d %s" % (g["farm"], g["gold"]))
    t("+%d gold interest", "%s +%%d %s" % (g["interest"], g["gold"]))
    t("Last Stand: the keep recovers", "%s：%s恢復生命" % (g["r_laststand"], g["keep"]))
    t("The %s gate fell!", "%%s%s被攻破了！" % g["gate"])
    t("Berserk!", g["berserk"] + "！")
    t("BERSERK", g["berserk"])
    t("Grunts summoned!", "召喚了%s！" % g["grunt"])
    t("Lv %d: %s", "Lv %d：%s")
    t("new gates and spots!", "新的%s與建造點！" % g["gate"])
    t("1 new spot!", "1 個新的建造點！")
    t("%d new spots!", "%d 個新的建造點！")
    t("NEW: %s", "新敵人：%s")
    t("Wave %d of %d starts in %d", "第 %%d %s（共 %%d %s）將在 %%d 秒後開始" % (g["wave"], g["wave"]))
    t("Walk off the pad to wait.", "離開平台即可暫緩。")
    t("%s: %s", "%s：%s")
    t(", ", "、")
    t("%d %s", "{1} ×{0}")
    t("West", g["west"])
    t("Centre", g["centre"])
    t("East", g["east"])
    t("LEVEL UP!", g["level_up"])
    t("RELIC", g["relic"])
    t("NEW", g["new"])
    t("Choose one", g["choose"])
    t("Choose one  -  %d more to come", "%s  -  還有 %%d 次" % g["choose"])
    t("+%d XP", "+%%d %s" % g["xp_pop"])
    t("Reroll  (%d gold)", "%s（%%d %s）" % (g["reroll"], g["gold"]))
    t("TOWER", g["tower_pad"])
    t("GATE", g["gate_pad"])
    t("GOLD", g["eco_pad"])
    t("START", g["start"])

    # --- build popup ----------------------------------------------------------
    t("Tower spot", g["tower_spot"])
    t("Gate spot", g["gate_spot"])
    t("Economy plot", g["eco_plot"])
    t("Tap a tower: see its range and role. Tap again: build.", "點一下：查看射程與定位。再點一下：建造。")
    t("Farm: fixed gold per wave.\nBank: interest on gold you hold.",
      "%s：每%s固定%s。\n%s：依持有%s計算%s。" % (g["farm"], g["wave"], g["gold"], g["bank"], g["gold"], g["interest"]))
    t("Upgrade to Lv %d", "升級至 Lv %d")
    t("> Build %s (tap again)", "> 建造%s（再點一下）")
    t("%s (need more gold)", "%%s（%s不足）" % g["gold"])
    t(" %s   -   %d gold", " %%s   -   %%d %s" % g["gold"])
    t("Max level.", "已達最高等級。")
    t("Gold ring: Lv %d range", "金色圓圈：Lv %d 射程")
    t("Damage %s  |  every %.2fs  |  range %s m", "傷害 %s  |  每 %.2f 秒  |  射程 %s 公尺")
    t("Damage %s  |  pierces %d  |  every %.1fs  |  range %s m", "傷害 %s  |  貫穿 %d  |  每 %.1f 秒  |  射程 %s 公尺")
    t("Damage %s, %.1f m splash  |  every %.1fs  |  range %s-%s m",
      "傷害 %%s，%%.1f 公尺%s  |  每 %%.1f 秒  |  射程 %%s-%%s 公尺" % g["splash"])
    t("Slow %d%% for %.1fs  |  every %.1fs  |  range %s m",
      "%s %%d%%%% 持續 %%.1f 秒  |  每 %%.1f 秒  |  射程 %%s 公尺" % w["slow"])
    t("+%d%% attack speed  |  range %s m", "攻擊速度 +%d%%  |  射程 %s 公尺")
    t("+%d gold per wave", "每%s +%%d %s" % (g["wave"], g["gold"]))
    t("%d%% interest per wave  |  cap +%d", "每%s %%d%%%% %s  |  上限 +%%d" % (g["wave"], g["interest"]))
    t("%d HP  |  rebuilt after each wave", "%%d 生命  |  每%s結束後重建" % g["wave"])
    t("Strong vs:", g["b_strong"], "building")
    t("Weak vs:", g["b_weak"], "building")
    t("Weak vs:", g["e_weak"], "enemy")
    t("Strong vs:", g["e_strong"], "enemy")

    # --- buildings --------------------------------------------------------------
    t("Archer Tower", g["archer"])
    t("Ballista", g["ballista"])
    t("Mortar", g["mortar"])
    t("Frost Crystal", g["frost_t"])
    t("War Banner", g["banner"])
    t("Farm", g["farm"])
    t("Bank", g["bank"])
    t("Gate", g["gate"])
    t("Fast single shots at one target.", "快速單發，射擊單一目標。")
    t("Heavy bolt that pierces every enemy in a line.", "重型弩箭，貫穿一整排敵人。")
    t("Lobbed boulders that splash a whole group.", "拋射巨石，%s整群敵人。" % ("濺射" if g["splash"] == "濺射" else "波及"))
    t("Pulses slow walking and attacks of all nearby.", "脈衝%s周圍所有敵人的移動與攻擊。" % w["slow"])
    t("No attack: towers and hero nearby attack faster.", "不會攻擊：使附近的防禦塔與%s攻擊更快。" % g["hero"])
    t("Fixed gold after every wave.", "每%s結束後獲得固定%s。" % (g["wave"], g["gold"]))
    t("Interest on the gold you hold after each wave.", "每%s結束後，依持有的%s獲得%s。" % (g["wave"], g["gold"], g["interest"]))
    t("Blocks its lane until broken; rebuilt each wave.", "擋住所在道路直到被攻破；每%s重建。" % g["wave"])
    t("armored, giants, the boss", "%s、%s、%s" % (g["armored"], w["giants"], w["the_boss"]))
    t("grunts, runners, bats", "%s、%s、%s" % (g["grunt"], g["runner"], g["bat"]))
    t("scattered enemies (long reload)", "分散的敵人（裝填較久）")
    t("armored, giants, the boss, crossbowmen", "%s、%s、%s、%s" % (g["armored"], w["giants"], w["the_boss"], g["crossbowman"]))
    t("bats, anything within 2.5 m", "%s、2.5 公尺內的敵人" % g["bat"])
    t("crowds, gate queues", "密集敵群、%s前的隊伍" % g["gate"])
    t("bats; it deals little damage", "%s；本身傷害很低" % g["bat"])
    t("gate queues, giants, runners", "%s前的隊伍、%s、%s" % (g["gate"], w["giants"], g["runner"]))
    t("standing alone", "孤立放置")
    t("tower clusters", "防禦塔群")
    t("nothing to defend with now", "當下無法協助防守")
    t("early builds; upgrades pay best", "提早建造；升級最划算")
    t("spending: no gold, no interest", "花光%s：沒有%s就沒有%s" % (g["gold"], g["gold"], g["interest"]))
    t("saving up for big upgrades", "存錢準備大升級")
    t("bats (fly over), crossbowmen (shoot from range)", "%s（飛越）、%s（遠距射擊）" % (g["bat"], g["crossbowman"]))
    t("holding crowds inside tower range", "把敵群擋在塔的射程內")

    # --- enemies ------------------------------------------------------------------
    for en, zh in [("grunt", g["grunt"]), ("grunts", g["grunt"]), ("armored", g["armored"]), ("brute", g["brute"]),
                   ("brutes", g["brute"]), ("runner", g["runner"]), ("runners", g["runner"]), ("bat", g["bat"]),
                   ("bats", g["bat"]), ("crossbowman", g["crossbowman"]), ("crossbowmen", g["crossbowman"]),
                   ("Bone Warlord", g["boss"]), ("Bone Warlords", g["boss"])]:
        t(en, zh)
    t("Basic foot soldier, comes in big crowds.", "基本步兵，成群出現。")
    t("mortars, archers", "%s、%s" % (g["mortar"], g["archer"]))
    t("nothing, but there are many", "沒有，但數量很多")
    t("Armor shrugs off small hits.", "%s能抵擋小傷害。" % g["armor"])
    t("ballistas, mortars, fire", "%s、%s、%s" % (g["ballista"], g["mortar"], w["fire"]))
    t("archers, Multishot", "%s、%s" % (g["archer"], g["c_multi"]))
    t("Giant: shoves past others and smashes gates.", "巨人：推開其他敵人，猛砸%s。" % g["gate"])
    t("ballistas, frost, Giant Slayer", "%s、%s、%s" % (g["ballista"], g["frost_t"], g["c_slayer"]))
    t("gates", g["gate"])
    t("Fast and fragile.", "速度快但脆弱。")
    t("archers, frost", "%s、%s" % (g["archer"], g["frost_t"]))
    t("mortars (outruns the shells)", "%s（跑得比砲彈快）" % g["mortar"])
    t("Flies over gates, straight to the keep.", "飛越%s，直撲%s。" % (g["gate"], g["keep"]))
    t("archers, ballistas, the hero", "%s、%s、%s" % (g["archer"], g["ballista"], g["hero"]))
    t("gates, mortars, frost (can't reach it)", "%s、%s、%s（無法觸及）" % (g["gate"], g["mortar"], g["frost_t"]))
    t("Shoots gates from 6 m away, outside the queue.", "在 6 公尺外射擊%s，不必排隊。" % g["gate"])
    t("ballistas, the hero", "%s、%s" % (g["ballista"], g["hero"]))
    t("Armored boss: calls grunts, goes berserk when hurt.", "重甲%s：召喚%s，受傷後會%s。" % (w["the_boss"], g["grunt"], g["berserk"]))
    t("ballistas, Giant Slayer, fire", "%s、%s、%s" % (g["ballista"], g["c_slayer"], w["fire"]))
    t("light hits, gates", "小傷害、%s" % g["gate"])

    # --- UI keywords (icons and colours; must match the sentences above) ----
    for en, zh in [("archers", g["archer"]), ("ballistas", g["ballista"]), ("mortars", g["mortar"]),
                   ("frost", g["frost_t"]), ("the boss", w["the_boss"]), ("giants", w["giants"]),
                   ("the hero", g["hero"]), ("fire", w["fire"]), ("Burn", w["burn"]), ("burn", w["burn"]),
                   ("ablaze", w["ablaze"]), ("Chill", w["chill"]), ("chill", w["chill"]), ("Slow", w["slow"]),
                   ("slow", w["slow"]), ("Lightning", w["lightning"]), ("lightning", w["lightning"]),
                   ("critical", w["critical"]), ("interest", g["interest"]), ("gold", g["gold"]), ("Gold", g["gold"]),
                   ("ingot", w["ingot"]), ("Armor", g["armor"]), ("armor", g["armor"]), ("armour", g["armor"])]:
        t(en, zh)

    # --- cards ----------------------------------------------------------------------
    for en, key in [("Sharpened Bolts", "c_dmg"), ("Quick Draw", "c_aspd"), ("Long Shot", "c_range"),
                    ("Multishot", "c_multi"), ("Piercing Bolts", "c_pierce"), ("Ricochet", "c_ricochet"),
                    ("Explosive Tips", "c_blast"), ("Fire Bolts", "c_fire"), ("Frost Bolts", "c_frost"),
                    ("Keen Eye", "c_crit"), ("Giant Slayer", "c_slayer"), ("Swift Boots", "c_boots"),
                    ("Scholar", "c_scholar"), ("Rally", "c_rally"), ("Spotter", "c_spotter"),
                    ("Engineer", "c_engineer"), ("Bounty", "c_bounty")]:
        t(en, g[key])
    t("+20% bolt damage", "弩箭傷害 +20%")
    t("+40% bolt damage", "弩箭傷害 +40%")
    t("+60% bolt damage", "弩箭傷害 +60%")
    t("+10% attack speed", "攻擊速度 +10%")
    t("+20% attack speed", "攻擊速度 +20%")
    t("+35% attack speed", "攻擊速度 +35%")
    t("+1 m range", "射程 +1 公尺")
    t("+2 m range", "射程 +2 公尺")
    t("+3 m range", "射程 +3 公尺")
    t("+1 bolt (40% damage) at another enemy", "多 1 支弩箭（40% 傷害）射向另一個敵人")
    t("+2 bolts (40% damage) at other enemies", "多 2 支弩箭（40% 傷害）射向其他敵人")
    t("+3 bolts (40% damage) at other enemies", "多 3 支弩箭（40% 傷害）射向其他敵人")
    t("Bolts fly straight through 1 more enemy", "弩箭直線穿透多 1 個敵人")
    t("...through 2 more enemies", "……穿透多 2 個敵人")
    t("...through 3 more enemies", "……穿透多 3 個敵人")
    t("Bolts bounce to 1 nearby enemy (-40% each bounce)", "弩箭彈向附近 1 個敵人（每次彈射 -40%）")
    t("Bounce to 2 nearby enemies", "彈向附近 2 個敵人")
    t("Bounce to 3 nearby enemies", "彈向附近 3 個敵人")
    t("Hits explode: half damage within 0.9 m", "命中時爆炸：0.9 公尺內造成一半傷害")
    t("Blast radius 1.2 m", "爆炸半徑 1.2 公尺")
    t("Blast radius 1.5 m", "爆炸半徑 1.5 公尺")
    t("Set enemies ablaze: 40% of bolt damage per second for 3 s",
      "%s敵人：每秒造成弩箭傷害 40%%，持續 3 秒" % w["ablaze"])
    t("Burn 60% per second", "每秒%s 60%%" % w["burn"])
    t("Burn 90% per second", "每秒%s 90%%" % w["burn"])
    t("Hits chill: -20% walking and attack speed for 2 s",
      "命中時%s：移動與攻擊速度 -20%%，持續 2 秒" % w["chill"])
    t("Chill -30%", "%s -30%%" % w["chill"])
    t("Chill -40%", "%s -40%%" % w["chill"])
    t("10% chance of a 2.5x critical hit", "10%% 機率造成 2.5 倍%s" % w["critical"])
    t("20% critical chance", "%s機率 20%%" % w["critical"])
    t("30% critical chance", "%s機率 30%%" % w["critical"])
    t("+40% damage to giants", "對%s傷害 +40%%" % w["giants"])
    t("+80% damage to giants", "對%s傷害 +80%%" % w["giants"])
    t("+120% damage to giants", "對%s傷害 +120%%" % w["giants"])
    t("+10% move speed", "移動速度 +10%")
    t("+20% move speed", "移動速度 +20%")
    t("+30% move speed", "移動速度 +30%")
    t("+20% XP", "%s +20%%" % g["xp"])
    t("+40% XP", "%s +40%%" % g["xp"])
    t("+60% XP", "%s +60%%" % g["xp"])
    t("Towers within 5 m of you attack 10% faster", "你周圍 5 公尺內的防禦塔攻擊速度 +10%")
    t("...20% faster", "……+20%")
    t("...30% faster", "……+30%")
    t("Towers within 5 m of you: +1 m range", "你周圍 5 公尺內的防禦塔：射程 +1 公尺")
    t("...+2 m range", "……射程 +2 公尺")
    t("...+3 m range", "……射程 +3 公尺")
    t("Gates within 6 m of you take 20% less damage", "你周圍 6 公尺內的%s受到的傷害 -20%%" % g["gate"])
    t("...35% less", "……-35%")
    t("...50% less", "……-50%")
    t("Kills near you drop +1 gold (up to 10 a wave)", "在你附近擊殺額外掉落 1 %s（每%s最多 10）" % (g["gold"], g["wave"]))
    t("...up to 20 a wave", "……每%s最多 20" % g["wave"])
    t("...up to 30 a wave", "……每%s最多 30" % g["wave"])

    # --- relics -------------------------------------------------------------------------
    for en, key in [("Twin Crossbow", "r_twin"), ("Volley", "r_volley"), ("Thunderstrike", "r_thunder"),
                    ("Spirit Wisp", "r_wisp"), ("Midas Touch", "r_midas"), ("Last Stand", "r_laststand")]:
        t(en, g[key])
    t("Every shot fires a second, half-damage volley right after the first.", "每次射擊後，緊接著再射出一輪一半傷害的弩箭。")
    t("Every 6th shot also looses a bolt at each of the 4 nearest enemies.", "每第 6 次射擊，額外向最近的 4 個敵人各射一箭。")
    t("Every 8 s lightning strikes the toughest enemy near you and chains through 4 more.",
      "每 8 秒，%s擊中你附近最強的敵人，並連鎖到另外 4 個。" % w["lightning"])
    t("A wisp circles you and shoots magic bolts at enemies.", "%s繞著你飛行，向敵人發射魔法彈。" % g["r_wisp"])
    t("Every 40th kill near you drops a gold ingot (20).", "在你附近每擊殺 40 個敵人，掉落一塊%s（20）。" % w["ingot"])
    t("The keep regains 10% of its HP after every wave.", "每%s結束後，%s恢復 10%% 生命。" % (g["wave"], g["keep"]))
    return T


def esc(s):
    return s.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n")


def main():
    T = build()
    lines = ['# RogueShot TD -- Traditional Chinese (Taiwan). Written by tools/gen_zh_tw.py: edit that, not this.',
             'msgid ""', 'msgstr ""', '"Language: zh_TW\\n"', '"Content-Type: text/plain; charset=UTF-8\\n"', '']
    for (ctx, en), zh in T.items():
        if ctx:
            lines.append('msgctxt "%s"' % esc(ctx))
        lines.append('msgid "%s"' % esc(en))
        lines.append('msgstr "%s"' % esc(zh))
        lines.append('')
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "w", encoding="utf-8") as f:
        f.write("\n".join(lines))
    print("wrote %s: %d entries" % (OUT, len(T)))


if __name__ == "__main__":
    main()
