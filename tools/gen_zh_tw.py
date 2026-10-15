#!/usr/bin/env python3
"""Writes locale/zh_TW.po, the Traditional Chinese (Taiwan) catalogue.

    python3 tools/gen_zh_tw.py && python3 tools/make_font.py && tools/loc_check.py

G is the glossary: the user's picks from the picking page (an artifact,
store `picks`; see CLAUDE.md "Localization"). Every sentence below is written with G, so a
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
    s_good="適合：", s_bad="不適合：",      # support buildings (v0.2.2, provisional)
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
    # v0.1.28 (picking page section "New in v0.1.28"; the user's picks).
    spec="特化", sell="出售", freeze="凍結",
    s_sniper="狙擊塔", s_repeater="連弩塔", s_great="重型弩砲塔", s_harpoon="魚叉弩砲塔",
    s_cluster="散彈臼砲塔", s_fire="燃燒臼砲塔", s_glacier="冰封晶塔", s_frostbite="霜傷晶塔",
    s_drums="戰鼓塔", s_standard="英雄戰旗",
    slime="史萊姆", slimeling="分身史萊姆", mage="骷髏法師", captain="隊長",
    # v0.2.1 (picking page section "New in v0.2.1"): option A until the
    # user picks.
    warded="符文兵", shade="暗影", sapper="爆破兵", drake="飛龍", necro="死靈法師",
)
# Everyday words used in the texts (not picks): the element words the UI
# colours must appear verbatim in the sentences (UiText matches them).
W = dict(heal="治療", haste="加速", fire="火焰", burn="燃燒", ablaze="點燃", chill="冰凍", slow="緩速", lightning="閃電",
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
    t("Most waves cleared, then score:\nkeep HP % x 10 + gold left + 50 per hero level",
      "通過波數多者優先，其次比分數：\n%s生命 %% x 10 + 剩餘%s + %s每級 50" % (g["keep"], g["gold"], g["hero"]))
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
    t("Waves cleared: %d / %d\nKeep %d%%  +  gold %d  +  hero Lv %d\nScore %d",
      "通過波數：%%d／%%d\n%s %%d%%%%  +  %s %%d  +  %s Lv %%d\n分數 %%d" % (g["keep"], g["gold"], g["hero"]))
    t("Damage dealt", "造成的傷害")
    t("Damage taken (gates and keep)", "受到的傷害（%s與%s）" % (g["gate"], g["keep"]))
    t("Hero", g["hero"])
    t("None", "無")
    t("Your build", "本局配置")
    t("Results", "戰績")
    t("Relics", g["relic"])
    t("Cards", "升級卡")
    t("Buildings", "建築")
    t("\nNew top-10 entry: #%d", "\n新紀錄：第 %d 名")
    t("RogueShot Tower Defense\nGame design and direction: David Chen JP\nProgrammed with Claude (Anthropic) as the coding assistant\n"
      "Made with Godot Engine 4.7 (godotengine.org)\n\n3D MODELS (CC0)\n"
      "Kay Lousberg (kaylousberg.com): KayKit Adventurers (hero, barbarian, captain, shade, necromancer), "
      "Skeletons (crossbowmen, bone mages, sappers, warded, Bone Warlord), "
      "Medieval Hexagon (archer and sniper towers, fire mortar, windmill, market, keep, flags, gate), "
      "Dungeon Remastered (coins), Forest Nature (rocks)\n"
      "Kenney (kenney.nl): Tower Defense Kit, Mini Dungeon, Mini Arena, Nature Kit\n"
      "Quaternius (quaternius.com): Animated Monsters (bat, slime, drake)\n\nSOUND (CC0 unless noted)\n"
      "Kenney: RPG Audio, Impact Sounds, Interface Sounds, Casino Audio, Sci-fi Sounds, Music Jingles\n"
      "OpenGameArt: artisticdude (bow, freeze spell), Vehicle / Jan Schupke (Tinysized SFX), bart (ice spells), "
      "rubberduck (creature SFX), Joth (chunky explosion), qubodup (dull explosion), fvcalderan (fanfare), "
      "0new4y (game-over trumpet)\nWave horn: \"Scary Echoey Horn Esque Sound\" by Kat, CC-BY 4.0 (opengameart.org)\n\n"
      "MUSIC\n\"RPG City\" by phantasticbeats (Pixabay)\n\nThanks for playing!",
      "%s\n遊戲設計與製作：David Chen JP\n程式協力：Claude（Anthropic）\n以 Godot Engine 4.7（godotengine.org）製作\n\n3D 模型（CC0）\n"
      "Kay Lousberg（kaylousberg.com）：KayKit Adventurers（%s、%s、%s、%s、%s）、Skeletons（%s、%s、%s、%s、%s）、"
      "Medieval Hexagon（%s、%s、%s、風車、市集、%s、旗幟、%s）、Dungeon Remastered（金幣）、Forest Nature（岩石）\n"
      "Kenney（kenney.nl）：Tower Defense Kit、Mini Dungeon、Mini Arena、Nature Kit\n"
      "Quaternius（quaternius.com）：Animated Monsters（%s、%s、%s）\n\n音效（除另註明外皆為 CC0）\n"
      "Kenney：RPG Audio、Impact Sounds、Interface Sounds、Casino Audio、Sci-fi Sounds、Music Jingles\n"
      "OpenGameArt：artisticdude（弓、冰凍法術）、Vehicle / Jan Schupke（Tinysized SFX）、bart（冰系法術）、"
      "rubberduck（生物音效）、Joth（爆炸）、qubodup（悶響爆炸）、fvcalderan（號角曲）、"
      "0new4y（失敗號角）\n波次號角：Kat〈Scary Echoey Horn Esque Sound〉，CC-BY 4.0（opengameart.org）\n\n"
      "音樂\nphantasticbeats〈RPG City〉（Pixabay）\n\n感謝遊玩！"
      % (g["title"], g["hero"], g["brute"], g["captain"], g["shade"], g["necro"],
         g["crossbowman"], g["mage"], g["sapper"], g["warded"], g["boss"],
         g["archer"], g["s_sniper"], g["s_fire"], g["keep"], g["gate"], g["bat"], g["slime"], g["drake"]))

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
    t("+%d gold from kills", "擊殺 +%%d %s" % g["gold"])
    t("+%d gold from Midas Touch", "%s +%%d %s" % (g["r_midas"], g["gold"]))
    t("+%d gold from Bounty", "%s +%%d %s" % (g["c_bounty"], g["gold"]))
    t("Last Stand! Invulnerable for %d s", "%s！無敵 %%d 秒" % g["r_laststand"])
    t("The inner %s gate fell!", "%%s內%s被攻破了！" % g["gate"])
    t("The outer %s gate fell!", "%%s外%s被攻破了！" % g["gate"])
    t("Berserk!", g["berserk"] + "！")
    t("BERSERK", g["berserk"])
    t("The Warlord calls for help!", "%s召喚援軍！" % g["boss"])
    t("Berserk! Slows no longer work.", "%s！%s不再有效。" % (g["berserk"], w["slow"]))
    t("Lv %d: %s", "Lv %d：%s")
    t("new gates and spots!", "新的%s與建造點！" % g["gate"])
    t("1 new spot!", "1 個新的建造點！")
    t("%d new spots!", "%d 個新的建造點！")
    t("NEW: %s", "新敵人：%s")
    t("Wave %d of %d starts in %d", "第 %%d %s（共 %%d %s）將在 %%d 秒後開始" % (g["wave"], g["wave"]))
    t("Walk off the pad to stop the countdown.", "離開平台可暫停倒數計時")  # the user's wording
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
    t("Lv 4: pick one of two specializations (tap to compare).", "Lv 4：二選一%s（點一下比較）。" % g["spec"])
    t("Lv 4: %s", "Lv 4：%s")
    t(" Sell   +%d gold", " %s   +%%d %s" % (g["sell"], g["gold"]))
    t("Sell", g["sell"])
    t("Sell %s for %d gold?\n\nYou get back %d%% of what it cost.",
      "要以 {1} %s%s{0}嗎？\n\n可拿回花費的 {2}%%。" % (g["gold"], g["sell"]))
    t("Sold: +%d gold", "已%s：+%%d %s" % (g["sell"], g["gold"]))
    t("Damage %s, ignores armor  |  every %.1fs  |  range %s m", "傷害 %%s，無視%s  |  每 %%.1f 秒  |  射程 %%s 公尺" % g["armor"])
    t("Damage %s x %d arrows  |  every %.2fs  |  range %s m", "傷害 %s x %d 支箭  |  每 %.2f 秒  |  射程 %s 公尺")
    t("Damage %s  |  pierces %d, slows %d%% for %.1fs  |  every %.1fs  |  range %s m",
      "傷害 %%s  |  貫穿 %%d，%s %%d%%%% %%.1f 秒  |  每 %%.1f 秒  |  射程 %%s 公尺" % w["slow"])
    t("%d bomblets x damage %s, %.1f m splash  |  every %.1fs  |  range %s-%s m",
      "%%d 顆子彈 x 傷害 %%s，%%.1f 公尺%s  |  每 %%.1f 秒  |  射程 %%s-%%s 公尺" % g["splash"])
    t("Damage %s, %.1f m splash, burns %s/s for %ds  |  every %.1fs  |  range %s-%s m",
      "傷害 %%s，%%.1f 公尺%s，%s每秒 %%s 持續 %%d 秒  |  每 %%.1f 秒  |  射程 %%s-%%s 公尺" % (g["splash"], w["burn"]))
    t("Freezes %.1fs, then slow %d%% for %.1fs  |  every %.1fs  |  range %s m",
      "%s %%.1f 秒，再%s %%d%%%% %%.1f 秒  |  每 %%.1f 秒  |  射程 %%s 公尺" % (g["freeze"], w["slow"]))
    t("Damage %s, +%d%% damage taken for %ds, slow %d%%  |  every %.1fs  |  range %s m",
      "傷害 %%s，受到傷害 +%%d%%%% %%d 秒，%s %%d%%%%  |  每 %%.1f 秒  |  射程 %%s 公尺" % w["slow"])
    t("Towers +%d%% attack speed  |  hero +%d%% damage and speed  |  range %s m",
      "防禦塔攻擊速度 +%%d%%%%  |  %s傷害與速度 +%%d%%%%  |  射程 %%s 公尺" % g["hero"])
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
    t("Good with:", g["s_good"], "building")
    t("Bad with:", g["s_bad"], "building")

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
    t("grunts, runners, slimes (held in tower range)", "%s、%s、%s（擋在塔的射程內）" % (g["grunt"], g["runner"], g["slime"]))

    # --- tower specs (level IV, v0.1.28) ------------------------------------------
    for en, key in [("Sniper Tower", "s_sniper"), ("Repeater Tower", "s_repeater"), ("Great Ballista", "s_great"),
                    ("Harpoon Ballista", "s_harpoon"), ("Cluster Mortar", "s_cluster"), ("Fire Mortar", "s_fire"),
                    ("Glacier Crystal", "s_glacier"), ("Frostbite Crystal", "s_frostbite"), ("War Drums", "s_drums"),
                    ("Hero's Standard", "s_standard")]:
        t(en, g[key])
    t("Sniper", g["s_sniper"])
    t("Repeater", g["s_repeater"])
    t("Harpoon", g["s_harpoon"])
    t("Long shots at the toughest enemy in reach; ignore armor.", "遠距狙擊射程內最強的敵人，無視%s。" % g["armor"])
    t("Rapid arrows at two enemies at once.", "快速連射，同時射擊兩個敵人。")
    t("Huge bolts that pierce only a few enemies.", "巨型弩箭，只貫穿少數敵人。")
    t("Barbed bolts: every enemy hit is slowed 50% for 2.5 s.", "倒鉤弩箭：被命中的敵人%s 50%% 2.5 秒。" % w["slow"])
    t("Shells burst into 5 bomblets over a wide area.", "砲彈在空中分裂成 5 顆子彈，炸開一大片。")
    t("Firepots: everything hit burns for 4 s, armor or not.", "火罐：命中的敵人%s 4 秒，%s無效。" % (w["burn"], g["armor"]))
    t("Freezes everything nearby solid for 0.8 s (bosses half), then chills.",
      "把周圍所有敵人%s 0.8 秒（%s減半），之後%s。" % (g["freeze"], w["the_boss"], w["chill"]))
    t("Weaker chill, but chilled enemies take 50% more damage.", "%s較弱，但被%s的敵人受到的傷害 +50%%。" % (w["chill"], w["chill"]))
    t("Towers nearby attack twice as fast; the hero gets nothing.", "附近的防禦塔攻擊速度加倍；%s沒有加成。" % g["hero"])
    t("The hero nearby: +60% damage and attack speed; towers +35%.", "附近的%s：傷害與攻擊速度 +60%%；防禦塔 +35%%。" % g["hero"])
    t("armored, giants, the boss", "%s、%s、%s" % (g["armored"], w["giants"], w["the_boss"])) if False else None
    t("crowds, runners", "密集敵群、%s" % g["runner"])
    t("grunts, runners, bats, slimelings", "%s、%s、%s、%s" % (g["grunt"], g["runner"], g["bat"], g["slimeling"]))
    t("armored, the boss", "%s、%s" % (g["armored"], w["the_boss"]))
    t("giants, the boss, captains", "%s、%s、%s" % (w["giants"], w["the_boss"], g["captain"]))
    t("crowds", "密集敵群")
    t("long lines, runners, slimes", "長列敵人、%s、%s" % (g["runner"], g["slime"]))
    t("the berserk boss, bats", "%s的%s、%s" % (g["berserk"], w["the_boss"], g["bat"]))
    t("crowds, slimes, slimelings", "密集敵群、%s、%s" % (g["slime"], g["slimeling"]))
    t("armored, bats", "%s、%s" % (g["armored"], g["bat"]))
    t("armored, gate queues, captains", "%s、%s前的隊伍、%s" % (g["armored"], g["gate"], g["captain"]))
    t("runners, bats", "%s、%s" % (g["runner"], g["bat"]))
    t("giants, gate queues, crossbowmen", "%s、%s前的隊伍、%s" % (w["giants"], g["gate"], g["crossbowman"]))
    t("the berserk boss", "%s的%s" % (g["berserk"], w["the_boss"]))
    t("the boss, armored, bats", "%s、%s、%s" % (w["the_boss"], g["armored"], g["bat"]))
    t("the boss, giants, armored", "%s、%s、%s" % (w["the_boss"], w["giants"], g["armored"]))
    t("a strong hero", "強大的%s" % g["hero"])
    t("a lone hero", "獨自作戰的%s" % g["hero"])
    t("towers far from the hero", "離%s太遠的防禦塔" % g["hero"])
    t("gate queues", "%s前的隊伍" % g["gate"])

    # --- enemies ------------------------------------------------------------------
    for en, zh in [("grunt", g["grunt"]), ("grunts", g["grunt"]), ("armored", g["armored"]), ("brute", g["brute"]),
                   ("brutes", g["brute"]), ("runner", g["runner"]), ("runners", g["runner"]), ("bat", g["bat"]),
                   ("bats", g["bat"]), ("crossbowman", g["crossbowman"]), ("crossbowmen", g["crossbowman"]),
                   ("Bone Warlord", g["boss"]), ("Bone Warlords", g["boss"]), ("slime", g["slime"]),
                   ("slimes", g["slime"]), ("slimeling", g["slimeling"]), ("slimelings", g["slimeling"]),
                   ("bone mage", g["mage"]), ("bone mages", g["mage"]), ("captain", g["captain"]),
                   ("captains", g["captain"])]:
        t(en, zh)
    t("Bursts into 4 slimelings when it dies.", "死亡時分裂成 4 隻%s。" % g["slimeling"])
    t("mortars, Harpoon", "%s、%s" % (g["mortar"], g["s_harpoon"]))
    t("archers (more to kill)", "%s（要打的更多了）" % g["archer"])
    t("Small and quick, born from a slime.", "又小又快，由%s分裂而來。" % g["slime"])
    t("mortars, frost, Repeater", "%s、%s、%s" % (g["mortar"], g["frost_t"], g["s_repeater"]))
    t("single big shots", "單發重擊")
    t("Heals all within 4.5 m, 18% HP a second. Kill it first.", "%s 4.5 公尺內所有敵人，每秒 18%% 生命。優先擊殺！" % w["heal"])
    t("the hero, Sniper", "%s、%s" % (g["hero"], g["s_sniper"]))
    t("All within 4 m walk and attack 40% faster.", "4 公尺內所有敵人移動與攻擊%s 40%%。" % w["haste"])
    t("ballistas, mortars", "%s、%s" % (g["ballista"], g["mortar"]))
    t("archers (armor)", "%s（%s）" % (g["archer"], g["armor"]))
    for en, key in [("warded", "warded"), ("shade", "shade"), ("shades", "shade"), ("sapper", "sapper"),
                    ("sappers", "sapper"), ("drake", "drake"), ("drakes", "drake"), ("necromancer", "necro"),
                    ("necromancers", "necro")]:
        t(en, g[key])
    t("Runes turn aside 80% of the hero's damage.", "符文擋下%s 80%% 的傷害。" % g["hero"])
    t("archers, mortars, ballistas", "%s、%s、%s" % (g["archer"], g["mortar"], g["ballista"]))
    t("Can't be hit unless near a frost crystal or war banner.", "除非靠近%s或%s，否則無法被攻擊。" % (g["frost_t"], g["banner"]))
    t("frost, banners (reveal it)", "%s、%s（使其現形）" % (g["frost_t"], g["banner"]))
    t("gates out of frost and banner reach", "%s與%s範圍外的%s" % (g["frost_t"], g["banner"], g["gate"]))
    t("Runs at the walls and explodes: a big hit on a gate or the keep.", "衝向城牆自爆：對%s或%s造成重創。" % (g["gate"], g["keep"]))
    t("archers, the hero", "%s、%s" % (g["archer"], g["hero"]))
    t("Armored flyer, straight to the keep.", "重甲飛行敵人，直撲%s。" % g["keep"])
    t("ballistas, archers, the hero", "%s、%s、%s" % (g["ballista"], g["archer"], g["hero"]))
    t("Raises allies that fall near it at full HP, each only once.", "讓附近倒下的同伴滿血復活，每個只能復活一次。")
    t("giants (a second life)", "%s（第二條命）" % w["giants"])
    t("banners", g["banner"])
    t("war banner", g["banner"])
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
    t("Armored boss: calls armored men, berserk at 25%: no slow or freeze.",
      "重甲%s：召喚%s；生命 25%% 時%s，%s與%s無效。" % (w["the_boss"], g["armored"], g["berserk"], w["slow"], g["freeze"]))
    t("ballistas, Giant Slayer, fire", "%s、%s、%s" % (g["ballista"], g["c_slayer"], w["fire"]))
    t("light hits, gates, slow (berserk)", "小傷害、%s、%s（%s時）" % (g["gate"], w["slow"], g["berserk"]))

    # --- UI keywords (icons and colours; must match the sentences above) ----
    for en, zh in [("Giant", w["giants"]), ("archers", g["archer"]), ("ballistas", g["ballista"]), ("mortars", g["mortar"]),
                   ("frost", g["frost_t"]), ("the boss", w["the_boss"]), ("giants", w["giants"]),
                   ("the hero", g["hero"]), ("fire", w["fire"]), ("Burn", w["burn"]), ("burn", w["burn"]),
                   ("ablaze", w["ablaze"]), ("Chill", w["chill"]), ("chill", w["chill"]), ("Slow", w["slow"]),
                   ("slow", w["slow"]), ("Lightning", w["lightning"]), ("lightning", w["lightning"]),
                   ("critical", w["critical"]), ("interest", g["interest"]), ("gold", g["gold"]), ("Gold", g["gold"]),
                   ("ingot", w["ingot"]), ("Armor", g["armor"]), ("armor", g["armor"]), ("armour", g["armor"]),
                   ("slows", w["slow"]), ("slowed", w["slow"]), ("chilled", w["chill"]), ("Freezes", g["freeze"]),
                   ("freeze", g["freeze"]), ("burns", w["burn"]), ("Firepots", "火罐"), ("Heals", w["heal"]),
                   ("heals", w["heal"]), ("faster", w["haste"])]:
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
    t("+1 m range; +15% damage to enemies over 5 m away", "射程 +1 公尺；對 5 公尺外的敵人傷害 +15%")
    t("+2 m range; +30% damage over 5 m", "射程 +2 公尺；5 公尺外傷害 +30%")
    t("+3 m range; +45% damage over 5 m", "射程 +3 公尺；5 公尺外傷害 +45%")
    t("+1 bolt (40% damage) at another enemy", "多 1 支弩箭（40% 傷害）射向另一個敵人")
    t("+2 bolts (40% damage) at other enemies", "多 2 支弩箭（40% 傷害）射向其他敵人")
    t("+3 bolts (40% damage) at other enemies", "多 3 支弩箭（40% 傷害）射向其他敵人")
    t("Bolts fly straight through 1 more enemy", "弩箭直線穿透多 1 個敵人")
    t("Bolts fly straight through 2 more enemies", "弩箭直線穿透多 2 個敵人")
    t("Bolts fly straight through 3 more enemies", "弩箭直線穿透多 3 個敵人")
    t("Bolts bounce to 1 nearby enemy (-25% each bounce)", "弩箭彈向附近 1 個敵人（每次彈射 -25%）")
    t("Bounce to 2 nearby enemies", "彈向附近 2 個敵人")
    t("Bounce to 3 nearby enemies", "彈向附近 3 個敵人")
    t("Hits explode: 35% damage within 0.8 m", "命中時爆炸：0.8 公尺內造成 35% 傷害")
    t("Blast radius 1.0 m", "爆炸半徑 1.0 公尺")
    t("Blast radius 1.2 m", "爆炸半徑 1.2 公尺")
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
    t("+40% damage to giants and the boss", "對%s與%s傷害 +40%%" % (w["giants"], w["the_boss"]))
    t("+80% damage to giants and the boss", "對%s與%s傷害 +80%%" % (w["giants"], w["the_boss"]))
    t("+120% damage to giants and the boss", "對%s與%s傷害 +120%%" % (w["giants"], w["the_boss"]))
    t("+10% move speed, and +10% attack speed while moving", "移動速度 +10%，移動中攻擊速度 +10%")
    t("+20% move speed and attack speed while moving", "移動速度與移動中攻擊速度 +20%")
    t("+30% move speed and attack speed while moving", "移動速度與移動中攻擊速度 +30%")
    t("+20% XP; +2% bolt damage per hero level", "%s +20%%；%s每級弩箭傷害 +2%%" % (g["xp"], g["hero"]))
    t("+40% XP; +2% bolt damage per level", "%s +40%%；每級弩箭傷害 +2%%" % g["xp"])
    t("+60% XP; +2% bolt damage per level", "%s +60%%；每級弩箭傷害 +2%%" % g["xp"])
    t("All towers attack 4% faster; twice that within 6 m of you", "所有防禦塔攻擊速度 +4%；你周圍 6 公尺內加倍")
    t("All towers attack 8% faster; 16% within 6 m of you", "所有防禦塔攻擊速度 +8%；你周圍 6 公尺內 +16%")
    t("All towers attack 12% faster; 24% within 6 m of you", "所有防禦塔攻擊速度 +12%；你周圍 6 公尺內 +24%")
    t("Enemies your bolts hit are marked for 4 s: towers deal them +12% damage",
      "被你的弩箭命中的敵人會被標記 4 秒：防禦塔對其傷害 +12%")
    t("Enemies your bolts hit are marked for 4 s: towers deal them +20% damage",
      "被你的弩箭命中的敵人會被標記 4 秒：防禦塔對其傷害 +20%")
    t("Enemies your bolts hit are marked for 4 s: towers deal them +30% damage",
      "被你的弩箭命中的敵人會被標記 4 秒：防禦塔對其傷害 +30%")
    t("All gates +20% HP", "所有%s生命 +20%%" % g["gate"])
    t("All gates +35% HP", "所有%s生命 +35%%" % g["gate"])
    t("All gates +50% HP", "所有%s生命 +50%%" % g["gate"])
    t("Kills near you drop +1 gold (up to 20 a wave)", "在你附近擊殺額外掉落 1 %s（每%s最多 20）" % (g["gold"], g["wave"]))
    t("Kills near you drop +1 gold (up to 40 a wave)", "在你附近擊殺額外掉落 1 %s（每%s最多 40）" % (g["gold"], g["wave"]))
    t("Kills near you drop +1 gold (up to 60 a wave)", "在你附近擊殺額外掉落 1 %s（每%s最多 60）" % (g["gold"], g["wave"]))

    # --- relics -------------------------------------------------------------------------
    for en, key in [("Twin Crossbow", "r_twin"), ("Volley", "r_volley"), ("Thunderstrike", "r_thunder"),
                    ("Spirit Wisp", "r_wisp"), ("Midas Touch", "r_midas"), ("Last Stand", "r_laststand")]:
        t(en, g[key])
    for pct in [50, 70, 90]:
        t("Every shot fires a second volley at %d%% damage right after the first." % pct,
          "每次射擊後，緊接著再射出第二輪弩箭（%d%% 傷害）。" % pct)
    for nth, n in [(6, 4), (5, 5), (4, 6)]:
        t("Every %dth shot also looses a bolt at each of the %d nearest enemies." % (nth, n),
          "每第 %d 次射擊，額外向最近的 %d 個敵人各射一箭。" % (nth, n))
    for sec, n in [("8", 4), ("6", 5), ("4.5", 7)]:
        t("Every %s s lightning strikes the toughest enemy near you and chains through %d more." % (sec, n),
          "每 %s 秒，%s擊中你附近最強的敵人，並連鎖到另外 %d 個。" % (sec, w["lightning"], n))
    t("A wisp circles you and shoots bolts with all your bolt cards (80% damage).",
      "%s繞著你飛行，射出帶有你所有弩箭卡效果的弩箭（80%% 傷害）。" % g["r_wisp"])
    t("A wisp circles you and shoots bolts with all your bolt cards (80% damage), 40% faster.",
      "%s繞著你飛行，射出帶有你所有弩箭卡效果的弩箭（80%% 傷害），射速 +40%%。" % g["r_wisp"])
    t("A wisp circles you and shoots bolts with all your bolt cards (80% damage), twice as fast.",
      "%s繞著你飛行，射出帶有你所有弩箭卡效果的弩箭（80%% 傷害），射速加倍。" % g["r_wisp"])
    for n in [60, 45, 30]:
        t("Every %dth kill near you drops a gold ingot (20)." % n,
          "在你附近每擊殺 %d 個敵人，掉落一塊%s（20）。" % (n, w["ingot"]))
    for sec in [3, 5, 7]:
        t("Once per wave, a gate or the keep about to fall becomes invulnerable for %d s." % sec,
          "每%s一次：即將被攻破的%s或%s無敵 %d 秒。" % (g["wave"], g["gate"], g["keep"], sec))
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
