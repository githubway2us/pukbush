#!/bin/bash

# -----------------------------------
# ตัวแปรเริ่มต้นของเกม
# -----------------------------------
player_hp=10000                   # HP ของผู้เล่น
player_attack=15                # ค่าโจมตีของผู้เล่น
player_exp=0                    # ค่า EXP ของผู้เล่น
player_level=1                  # ระดับของผู้เล่น
puk=0                           # สกุลเงินในเกม (PUK)
inventory=()                    # อาร์เรย์เก็บไอเทม
player_status="none"            # สถานะพิษของผู้เล่น
player_status_turns=0           # จำนวนเทิร์นของสถานะ
quest_monster_progress=0        # ความคืบหน้าเควสต์มอนสเตอร์
quest_boss_progress=0           # ความคืบหน้าเควสต์บอส
quest_monster_goal=10           # เป้าหมายเควสต์มอนสเตอร์
quest_boss_goal=3               # เป้าหมายเควสต์บอส
max_inventory=10                # ขนาดสูงสุดของ inventory
save_file="savegame.txt"        # ไฟล์สำหรับบันทึกเกม

# -----------------------------------
# รายการมอนสเตอร์
# -----------------------------------
monster_names=(
    "Goblin" "Orc" "Skeleton" "Zombie" "Dragon" "Troll" "Slime" "Vampire" "Werewolf" "Giant Spider"
    "Mimic" "Harpy" "Imp" "Elemental" "Ghost" "Dark Knight" "Bandit" "Cultist" "Wolf" "Rat"
    "Snake" "Lizardman" "Bat" "Zombie Knight" "Ghoul" "Wraith" "Ogre" "Demon" "Spider Queen"
    "Fire Elemental" "Ice Golem" "Shadow Assassin" "Dark Mage" "Lich" "Necromancer" "Sorcerer"
    "Banshee" "Cyclops" "Minotaur" "Valkyrie" "Skeleton Archer" "Zombie Archer" "Troll Berserker"
    "Orc Warlord" "Dragon Hatchling" "Hydra" "Chimera" "Golem" "Phoenix" "Kraken"
)

# -----------------------------------
# รายการบอส
# -----------------------------------
boss_names=(
    "Dragon King" "Lich Lord" "Demon Overlord" "Behemoth" "Titan" "Ancient Dragon" "Dark Emperor"
    "Shadow Overlord" "Kraken Lord" "Phoenix King" "Leviathan" "Necromancer Supreme" "Vampire King"
    "Warlock Lord" "Titan of Destruction" "Giant Golem Lord" "Hydra Queen" "Celestial Dragon"
    "Demon Prince" "Hellfire Lord" "Ice Titan" "Storm King" "Chaos Overlord" "Bone Dragon Lord"
)

# -----------------------------------
# รายการไอเทม (name:value:cost:effect:level)
# -----------------------------------
items=(
    "Minor Heal:10:5:heal:0" "Light Heal:20:10:heal:0" "Medium Heal:50:25:heal:0" "Greater Heal:100:50:heal:0"
    "Antidote:0:20:clear_status:0" "Iron Sword:5:30:attack:0" "Steel Armor:50:40:hp:0" "Magic Ring:10:50:attack:0"
)

# -----------------------------------
# รายการสกิล (name:damage:cost:effect)
# -----------------------------------
skills=(
    "Fireball:30:20:damage" "Heal:50:30:heal" "Thunderstrike:40:25:stun"
)

# -----------------------------------
# ฟังก์ชัน: บันทึกเกม
# -----------------------------------
save_game() {
    echo "player_hp=$player_hp" > "$save_file"
    echo "player_attack=$player_attack" >> "$save_file"
    echo "player_exp=$player_exp" >> "$save_file"
    echo "player_level=$player_level" >> "$save_file"
    echo "puk=$puk" >> "$save_file"
    echo -n "inventory=" >> "$save_file"
    if [ ${#inventory[@]} -eq 0 ]; then
        echo "" >> "$save_file"
    else
        for i in "${!inventory[@]}"; do
            if [ $i -eq 0 ]; then
                echo -n "${inventory[$i]}" >> "$save_file"
            else
                echo -n "|${inventory[$i]}" >> "$save_file"
            fi
        done
        echo "" >> "$save_file"
    fi
    echo "player_status=$player_status" >> "$save_file"
    echo "player_status_turns=$player_status_turns" >> "$save_file"
    echo "quest_monster_progress=$quest_monster_progress" >> "$save_file"
    echo "quest_boss_progress=$quest_boss_progress" >> "$save_file"
    echo "🎉 บันทึกเกมเรียบร้อย! "
}

# -----------------------------------
# ฟังก์ชัน: โหลดเกม
# -----------------------------------
load_game() {
    if [ ! -f "$save_file" ]; then
        echo "❌ ไม่พบไฟล์บันทึกเกม! "
        return 1
    fi
    source "$save_file"
    IFS='|' read -ra inventory_array <<< "$inventory"
    inventory=("${inventory_array[@]}")
    echo "✅ โหลดเกมเรียบร้อย! "
    echo "✨ PUK: $puk | ❤️ HP: $player_hp | ⚔️ ATK: $player_attack | 🧬 EXP: $player_exp/$((player_level * 50)) (Lv.$player_level)"
    return 0
}

# -----------------------------------
# เริ่มเกม: เลือกโหมด
# -----------------------------------
echo "🌟 เลือกโหมด RPG:"
echo "1) เริ่มเกมใหม่ (auto)"
echo "2) เริ่มเกมใหม่ (manual)"
echo "3) โหลดเกม"
echo "เลือก: "
read start_choice
case $start_choice in
    1)
        rpg_mode="auto"
        echo "🎮 โหมด RPG: auto "
        ;;
    2)
        rpg_mode="manual"
        echo "🎮 โหมด RPG: manual "
        ;;
    3)
        load_game
        if [ $? -ne 0 ]; then
            echo "🎮 เริ่มเกมใหม่ในโหมด manual "
            rpg_mode="manual"
        fi
        ;;
    *)
        echo "❌ ตัวเลือกไม่ถูกต้อง! เริ่มเกมในโหมด manual "
        rpg_mode="manual"
        ;;
esac
sleep 1

# -----------------------------------
# ฟังก์ชัน: สร้างศัตรู
# -----------------------------------
generate_enemy() {
    is_boss=$((RANDOM % 20))
    if [ $is_boss -eq 0 ]; then
        # -------------------
        # บอส
        # -------------------
        enemy_name=${boss_names[$RANDOM % ${#boss_names[@]}]}
        enemy_level=$((player_level + 5 + RANDOM % 5))  # บอสเลเวลจะสูงกว่าผู้เล่น 5+
        enemy_hp=$((100 + enemy_level * 20 + RANDOM % 50))  # HP บวกเพิ่มตามเลเวล
        enemy_attack=$((15 + enemy_level * 5 + RANDOM % 1500)) # ATK แรงขึ้น
        boss_flag=1
    else
        # -------------------
        # มอนสเตอร์ทั่วไป
        # -------------------
        enemy_name=${monster_names[$RANDOM % ${#monster_names[@]}]}
        enemy_level=$((player_level + RANDOM % 3)) # เลเวลมอนใกล้เคียงผู้เล่น
        if [ $enemy_level -lt 1 ]; then enemy_level=1; fi
        enemy_hp=$((30 + enemy_level * 10 + RANDOM % 20))   # HP สเกลตามเลเวล
        enemy_attack=$((5 + enemy_level * 3 + RANDOM % 500)) # ATK สเกลตามเลเวล
        boss_flag=0
    fi
}


# -----------------------------------
# ฟังก์ชัน: ใช้สถานะพิษ
# -----------------------------------
apply_status() {
    if [ $boss_flag -eq 1 ] && [ $((RANDOM % 10)) -eq 0 ]; then
        player_status="poison"
        player_status_turns=3
        echo "😵 คุณถูก $enemy_name พิษ! ลด 5 HP ต่อเทิร์น 3 เทิร์น "
    fi
}

# -----------------------------------
# ฟังก์ชัน: ตรวจสอบสถานะพิษ
# -----------------------------------
check_status() {
    if [ "$player_status" == "poison" ] && [ $player_status_turns -gt 0 ]; then
        player_hp=$((player_hp - 5))
        player_status_turns=$((player_status_turns - 1))
        echo "☠️ พิษทำงาน! ลด HP -5 | เหลือ $player_status_turns เทิร์น "
        if [ $player_status_turns -eq 0 ]; then
            player_status="none"
            echo "✅ พิษหายแล้ว! "
        fi
    fi
}

# -----------------------------------
# ฟังก์ชัน: ดรอปไอเทม
# -----------------------------------
drop_item() {
    if [ $((RANDOM % 100)) -lt 30 ]; then
        drop_item=${items[$((RANDOM % 5))]}
        if [ ${#inventory[@]} -ge $max_inventory ]; then
            echo "🎒 กระเป๋าเต็ม! ไม่สามารถรับ $drop_item ได้ "
            return
        fi
        inventory+=("$drop_item")
        IFS=':' read -r name _ _ _ _ <<< "$drop_item"
        echo "🎁 ได้รับ $name จาก $enemy_name! "
    fi
}

# -----------------------------------
# ฟังก์ชัน: ตรวจสอบเควสต์
# -----------------------------------
check_quest() {
    if [ $boss_flag -eq 1 ]; then
        quest_boss_progress=$((quest_boss_progress + 1))
        echo "📜 ความคืบหน้าเควสต์: ฆ่าบอส $quest_boss_progress/$quest_boss_goal "
        if [ $quest_boss_progress -ge $quest_boss_goal ]; then
            puk=$((puk + 200))
            echo "🎉 ทำเควสต์ 'ฆ่าบอส 3 ตัว' สำเร็จ! ได้ 200 PUK "
            quest_boss_progress=0
        fi
    else
        quest_monster_progress=$((quest_monster_progress + 1))
        echo "📜 ความคืบหน้าเควสต์: ฆ่ามอนสเตอร์ $quest_monster_progress/$quest_monster_goal "
        if [ $quest_monster_progress -ge $quest_monster_goal ]; then
            puk=$((puk + 50))
            echo "🎉 ทำเควสต์ 'ฆ่ามอนสเตอร์ 10 ตัว' สำเร็จ! ได้ 50 PUK "
            quest_monster_progress=0
        fi
    fi
}

# -----------------------------------
# ฟังก์ชัน: ตรวจสอบเลเวลอัพ
# -----------------------------------
check_level_up() {
    exp_needed=$((player_level * 50))
    if [ $player_exp -ge $exp_needed ]; then
        player_level=$((player_level + 1))
        player_hp=$((player_hp + 20))
        player_attack=$((player_attack + 5))
        player_exp=$((player_exp - exp_needed))
        echo "🌟 เลเวลอัพ! คุณเป็น Lv.$player_level | HP +20 | ATK +5 "
    fi
}

# -----------------------------------
# ฟังก์ชัน: ใช้สกิล
# -----------------------------------
use_skill() {
    if [ ${#skills[@]} -eq 0 ]; then
        echo "❌ คุณยังไม่มีสกิล! "
        return
    fi
    echo "🪄 สกิลที่มี: "
    for i in "${!skills[@]}"; do
        IFS=':' read -r name damage cost effect <<< "${skills[$i]}"
        echo "$i) $name ($effect, ใช้ $cost PUK) "
    done
    echo "เลือกสกิล (หรือ q เพื่อยกเลิก): "
    read skill_choice
    if [ "$skill_choice" == "q" ]; then
        echo "ยกเลิกการใช้สกิล "
        return
    fi
    if [[ ! "$skill_choice" =~ ^[0-9]+$ ]] || [ $skill_choice -ge ${#skills[@]} ]; then
        echo "❌ ตัวเลือกไม่ถูกต้อง "
        return
    fi
    IFS=':' read -r name damage cost effect <<< "${skills[$skill_choice]}"
    if [ $puk -lt $cost ]; then
        echo "❌ PUK ไม่พอ "
        return
    fi
    puk=$((puk - cost))
    if [ "$effect" == "damage" ]; then
        crit=$((RANDOM % 100 < 20 ? 2 : 1))
        damage=$((damage * crit))
        enemy_hp=$((enemy_hp - damage))
        echo "🔥 ใช้ $name ทำดาเมจ $damage! "
        if [ $crit -eq 2 ]; then echo "💥 คริติคอล! "; fi
    elif [ "$effect" == "heal" ]; then
        player_hp=$((player_hp + damage))
        echo "✨ ใช้ $name ฮีล +$damage HP | HP คุณ: $player_hp "
    elif [ "$effect" == "stun" ]; then
        enemy_hp=$((enemy_hp - damage))
        echo "⚡ ใช้ $name ทำดาเมจ $damage และสตัน $enemy_name 1 เทิร์น! "
        stun=1
    fi
}

# -----------------------------------
# ฟังก์ชัน: เมนูเควสต์
# -----------------------------------
quest_menu() {
    echo "===== 📜 เมนูเควสต์ ====="
    echo "1) เควสต์: ฆ่ามอนสเตอร์ $quest_monster_progress/$quest_monster_goal (รางวัล: 50 PUK)"
    echo "2) เควสต์: ฆ่าบอส $quest_boss_progress/$quest_boss_goal (รางวัล: 200 PUK)"
    echo "q) กลับ"
    echo "เลือก: "
    read quest_choice
    if [ "$quest_choice" == "q" ]; then
        return
    else
        echo "❌ ตัวเลือกไม่ถูกต้อง "
    fi
}

# -----------------------------------
# ฟังก์ชัน: ใช้ไอเทม
# -----------------------------------
use_item() {
    if [ ${#inventory[@]} -eq 0 ]; then
        echo "❌ ไม่มีไอเทมในกระเป๋า! "
        return
    fi
    echo "🎒 ไอเทมในกระเป๋า: "
    for i in "${!inventory[@]}"; do
        IFS=':' read -r name value _ effect level <<< "${inventory[$i]}"
        up_value=$((value + level * 5))
        if [ "$effect" == "heal" ]; then
            echo "$i) $name (ฮีล $up_value HP, Lv.$level) "
        elif [ "$effect" == "attack" ]; then
            echo "$i) $name (+$up_value ATK, Lv.$level) "
        elif [ "$effect" == "hp" ]; then
            echo "$i) $name (+$up_value HP, Lv.$level) "
        else
            echo "$i) $name (ลบสถานะ, Lv.$level) "
        fi
    done
    echo "เลือกใช้ (หรือ q เพื่อยกเลิก): "
    read item_choice
    if [ "$item_choice" == "q" ]; then
        echo "ยกเลิกการใช้ไอเทม "
        return
    fi
    if [[ ! "$item_choice" =~ ^[0-9]+$ ]] || [ $item_choice -ge ${#inventory[@]} ]; then
        echo "❌ ตัวเลือกไม่ถูกต้อง "
        return
    fi
    IFS=':' read -r name value _ effect level <<< "${inventory[$item_choice]}"
    up_value=$((value + level * 5))
    if [ "$effect" == "heal" ]; then
        player_hp=$((player_hp + up_value))
        echo "✨ ใช้ $name ฮีล +$up_value HP | HP คุณ: $player_hp "
    elif [ "$effect" == "attack" ]; then
        player_attack=$((player_attack + up_value))
        echo "⚔️ ใช้ $name ATK +$up_value | ATK คุณ: $player_attack "
    elif [ "$effect" == "hp" ]; then
        player_hp=$((player_hp + up_value))
        echo "🛡️ ใช้ $name HP +$up_value | HP คุณ: $player_hp "
    elif [ "$effect" == "clear_status" ]; then
        player_status="none"
        player_status_turns=0
        echo "✅ ใช้ $name ลบสถานะพิษ! "
    fi
    unset inventory[$item_choice]
    inventory=("${inventory[@]}")
}

# -----------------------------------
# ฟังก์ชัน: ขายไอเทม
# -----------------------------------
sell_item() {
    if [ ${#inventory[@]} -eq 0 ]; then
        echo "❌ ไม่มีไอเทมในกระเป๋า! "
        return
    fi
    echo "🎒 ไอเทมในกระเป๋า: "
    for i in "${!inventory[@]}"; do
        IFS=':' read -r name _ cost _ level <<< "${inventory[$i]}"
        sell_price=$((cost / 2 + level * 5))
        echo "$i) $name (ขายได้ $sell_price PUK, Lv.$level) "
    done
    echo "เลือกขาย (หรือ q เพื่อยกเลิก): "
    read sell_choice
    if [ "$sell_choice" == "q" ]; then
        echo "ยกเลิกการขาย "
        return
    fi
    if [[ ! "$sell_choice" =~ ^[0-9]+$ ]] || [ $sell_choice -ge ${#inventory[@]} ]; then
        echo "❌ ตัวเลือกไม่ถูกต้อง "
        return
    fi
    IFS=':' read -r name _ cost _ level <<< "${inventory[$sell_choice]}"
    sell_price=$((cost / 2 + level * 5))
    puk=$((puk + sell_price))
    echo "💰 ขาย $name ได้ $sell_price PUK | PUK คุณ: $puk "
    unset inventory[$sell_choice]
    inventory=("${inventory[@]}")
}

# -----------------------------------
# ฟังก์ชัน: อัพเกรดไอเทม
# -----------------------------------
upgrade_item() {
    if [ ${#inventory[@]} -eq 0 ]; then
        echo "❌ ไม่มีไอเทมในกระเป๋า! "
        return
    fi
    echo "🔧 ไอเทมที่อัพเกรดได้: "
    has_upgradable=0
    for i in "${!inventory[@]}"; do
        IFS=':' read -r name value cost effect level <<< "${inventory[$i]}"
        if [ "$effect" == "attack" ] || [ "$effect" == "hp" ]; then
            if [ $level -lt 5 ]; then
                has_upgradable=1
                up_cost=$((10 + level * 10))
                echo "$i) $name (Lv.$level -> Lv.$((level + 1)), ใช้ $up_cost PUK) "
            fi
        fi
    done
    if [ $has_upgradable -eq 0 ]; then
        echo "❌ ไม่มีไอเทมที่อัพเกรดได้! "
        return
    fi
    echo "เลือกอัพเกรด (หรือ q เพื่อยกเลิก): "
    read up_choice
    if [ "$up_choice" == "q" ]; then
        echo "ยกเลิกการอัพเกรด "
        return
    fi
    if [[ ! "$up_choice" =~ ^[0-9]+$ ]] || [ $up_choice -ge ${#inventory[@]} ]; then
        echo "❌ ตัวเลือกไม่ถูกต้อง "
        return
    fi
    IFS=':' read -r name value cost effect level <<< "${inventory[$up_choice]}"
    if [ "$effect" != "attack" ] && [ "$effect" != "hp" ] || [ $level -ge 5 ]; then
        echo "❌ ไอเทมนี้ไม่อัพเกรดได้! "
        return
    fi
    up_cost=$((10 + level * 10))
    if [ $puk -ge $up_cost ]; then
        puk=$((puk - up_cost))
        level=$((level + 1))
        inventory[$up_choice]="$name:$value:$cost:$effect:$level"
        echo "🔧 อัพเกรด $name เป็น Lv.$level! PUK เหลือ $puk "
    else
        echo "❌ PUK ไม่พอ "
    fi
}

# -----------------------------------
# ฟังก์ชัน: ร้านค้า
# -----------------------------------
shop_menu() {
    discount=$((RANDOM % 10 < 3 ? 10 : 0))
    echo "===== 🏪 ร้านค้า ====="
    echo "PUK ที่มี: $puk "
    if [ $discount -eq 10 ]; then
        echo "🎉 ส่วนลด 10% วันนี้! "
    fi
    for i in "${!items[@]}"; do
        IFS=':' read -r name value cost effect _ <<< "${items[$i]}"
        d_cost=$((discount > 0 ? cost * 9 / 10 : cost))
        if [ "$effect" == "heal" ]; then
            echo "$i) $name (ฮีล $value HP) - $d_cost PUK "
        elif [ "$effect" == "attack" ]; then
            echo "$i) $name (+$value ATK) - $d_cost PUK "
        elif [ "$effect" == "hp" ]; then
            echo "$i) $name (+$value HP) - $d_cost PUK "
        else
            echo "$i) $name (ลบสถานะ) - $d_cost PUK "
        fi
    done
    echo "s) ขายไอเทม"
    echo "q) กลับ"
    echo "เลือกซื้อ: "
    read shop_choice
    if [ "$shop_choice" == "q" ]; then
        return
    elif [ "$shop_choice" == "s" ]; then
        sell_item
        return
    fi
    if [[ ! "$shop_choice" =~ ^[0-9]+$ ]] || [ $shop_choice -ge ${#items[@]} ]; then
        echo "❌ ตัวเลือกไม่ถูกต้อง "
        return
    fi
    IFS=':' read -r name value cost effect _ <<< "${items[$shop_choice]}"
    d_cost=$((discount > 0 ? cost * 9 / 10 : cost))
    if [ ${#inventory[@]} -ge $max_inventory ]; then
        echo "🎒 กระเป๋าเต็ม! ไม่สามารถซื้อ $name ได้ "
        return
    fi
    if [ $puk -ge $d_cost ]; then
        puk=$((puk - d_cost))
        inventory+=("$name:$value:$cost:$effect:0")
        echo "🛒 ซื้อ $name เรียบร้อย! PUK เหลือ $puk "
    else
        echo "❌ PUK ไม่พอ "
    fi
}

# -----------------------------------
# ฟังก์ชัน: อีเวนต์สุ่ม
# -----------------------------------
random_event() {
    event=$((RANDOM % 100))
    if [ $event -lt 10 ]; then
        treasure=$((10 + RANDOM % 50))
        puk=$((puk + treasure))
        echo "💰 พบสมบัติ! ได้ $treasure PUK | PUK คุณ: $puk "
    elif [ $event -lt 20 ]; then
        damage=$((10 + RANDOM % 20))
        player_hp=$((player_hp - damage))
        echo "🪤 ติดกับดัก! ลด HP -$damage | HP คุณ: $player_hp "
    fi
}

# -----------------------------------
# ฟังก์ชัน: ต่อสู้กับมอนสเตอร์
# -----------------------------------
fight_monster() {
    generate_enemy
    if [ $boss_flag -eq 1 ]; then
        echo "💥🎉 BOSS ปรากฏ! $enemy_name Lv.$enemy_level 💥🎉 "
    else
        echo "⚔️ เจอ $enemy_name Lv.$enemy_level "
    fi
    random_event
    stun=0
    if [ "$rpg_mode" == "auto" ]; then
        while [ $player_hp -gt 0 ] && [ $enemy_hp -gt 0 ]; do
            enemy_hp=$((enemy_hp - player_attack))
            if [ $stun -eq 0 ]; then
                player_hp=$((player_hp - enemy_attack))
                echo "😈 $enemy_name โจมตี -$enemy_attack "
            else
                echo "😴 $enemy_name สตัน! "
                stun=0
            fi
            check_status
            if [ $enemy_hp -gt 0 ]; then
                apply_status
            fi
        done
        if [ $player_hp -le 0 ]; then
            echo "----------------------ผลการต่อสู้---------------------- "
            echo "💀 คุณตายจาก $enemy_name! HP รีเซ็ต "
            echo "💀💀💀💀💀💀💀💀💀💀💀💀💀💀💀"
            echo "---------------------------------------------------- "
            player_hp=100
            player_status="none"
            player_status_turns=0
        else
            if [ $boss_flag -eq 1 ]; then
                reward=100
                exp_gain=$((50 + enemy_level * 10))
                puk=$((puk + reward))
                player_exp=$((player_exp + exp_gain))
                echo "----------------------ผลการต่อสู้---------------------- "
                echo "🎉 ชนะ BOSS $enemy_name! ได้ PUK +$reward | EXP +$exp_gain | HP=$player_hp | PUK=$puk "
                echo "---------------------------------------------------- "
                drop_item
                check_quest
                check_level_up
            else
                reward=$((1 + RANDOM % 5))
                exp_gain=$((10 + enemy_level * 5))
                puk=$((puk + reward))
                player_exp=$((player_exp + exp_gain))
                echo "----------------------ผลการต่อสู้---------------------- "
                echo "🎉 ชนะ $enemy_name! ได้ PUK +$reward | EXP +$exp_gain | HP=$player_hp | PUK=$puk "
                echo "---------------------------------------------------- "
                drop_item
                check_quest
                check_level_up
            fi
        fi
    else
        while [ $player_hp -gt 0 ] && [ $enemy_hp -gt 0 ]; do
            echo "❤️ HP คุณ: $player_hp (Lv.$player_level) 💀 HP $enemy_name: $enemy_hp "
            if [ "$player_status" != "none" ]; then
                echo "สถานะ: $player_status ($player_status_turns เทิร์น) "
            fi
            echo "เลือก [a=โจมตี / s=ใช้สกิล / h=ใช้ไอเทม / q=หนี]: "
            read action
            if [ "$action" == "a" ]; then
                enemy_hp=$((enemy_hp - player_attack))
                echo "💥 โจมตี $enemy_name -$player_attack "
            elif [ "$action" == "s" ]; then
                use_skill
            elif [ "$action" == "h" ]; then
                use_item
            elif [ "$action" == "q" ]; then
                echo "🏃‍♂️ หนีออกมา! HP ฟื้นฟูเป็น 100 "
                player_hp=100
                player_status="none"
                player_status_turns=0
                return
            fi
            if [ $enemy_hp -gt 0 ]; then
                if [ $stun -eq 0 ]; then
                    player_hp=$((player_hp - enemy_attack))
                    echo "😈 $enemy_name โจมตี -$enemy_attack "
                    apply_status
                else
                    echo "😴 $enemy_name สตัน! "
                    stun=0
                fi
            fi
            check_status
        done
        if [ $player_hp -le 0 ]; then
            echo "----------------------ผลการต่อสู้---------------------- "
            echo "💀 คุณตายแล้ว! HP รีเซ็ต "
            echo "💀💀💀💀💀💀💀💀💀💀💀💀💀💀💀"
            echo "---------------------------------------------------- "
            player_hp=100
            player_status="none"
            player_status_turns=0
        else
            if [ $boss_flag -eq 1 ]; then
                reward=100
                exp_gain=$((50 + enemy_level * 10))
                puk=$((puk + reward))
                player_exp=$((player_exp + exp_gain))
                echo "----------------------ผลการต่อสู้---------------------- "
                echo "🎉 ชนะ BOSS $enemy_name! ได้ PUK +$reward | EXP +$exp_gain | HP=$player_hp | PUK=$puk "
                echo "---------------------------------------------------- "
                drop_item
                check_quest
                check_level_up
            else
                reward=$((1 + RANDOM % 5))
                exp_gain=$((10 + enemy_level * 5))
                puk=$((puk + reward))
                player_exp=$((player_exp + exp_gain))
                echo "----------------------ผลการต่อสู้---------------------- "
                echo "🎉 ชนะ $enemy_name! ได้ PUK +$reward | EXP +$exp_gain | HP=$player_hp | PUK=$puk "
                echo "---------------------------------------------------- "
                drop_item
                check_quest
                check_level_up
            fi
        fi
    fi
}

# -----------------------------------
# ฟังก์ชัน: เมนูอัพเกรด
# -----------------------------------
upgrade_menu() {
    while true; do
        echo "===== 🛠️ เมนูอัพเกรด ====="
        echo "✨ PUK: $puk | ❤️ HP: $player_hp | ⚔️ ATK: $player_attack | 🧬 EXP: $player_exp/$((player_level * 50)) (Lv.$player_level)"
        echo "1) อัพเกรดสกิล (HP +20) | ใช้ PUK 5"
        echo "2) อัพเกรดอาวุธ (ATK +5) | ใช้ PUK 5"
        echo "3) ร้านค้า"
        echo "4) อัพเกรดไอเทม"
        echo "5) ตรวจสอบเควสต์"
        echo "6) กลับไปต่อสู้"
        echo "7) บันทึกเกม"
        echo "8) ส่งผลคะแนนขึ้นท้าชิง 🚀"
        echo "9) ออกจากเกม"

        echo "เลือกเมนู: "
        read choice
        case $choice in
            1)
                if [ $puk -ge 5 ]; then
                    player_hp=$((player_hp + 20))
                    puk=$((puk - 5))
                    echo "🛡️ อัพเกรดสกิล! HP +20 | PUK เหลือ $puk "
                else
                    echo "❌ PUK ไม่พอ "
                fi
                ;;
            2)
                if [ $puk -ge 5 ]; then
                    player_attack=$((player_attack + 5))
                    puk=$((puk - 5))
                    echo "⚔️ อัพเกรดอาวุธ! ATK +5 | PUK เหลือ $puk "
                else
                    echo "❌ PUK ไม่พอ "
                fi
                ;;
            3)
                shop_menu
                ;;
            4)
                upgrade_item
                ;;
            5)
                quest_menu
                ;;
            6)
                return
                ;;
            7)
                save_game
                ;;
            8) 
                send_challenge    # ✅ เรียกฟังก์ชันส่งผลคะแนน
                ;;
            9)
                echo "👋 ออกจากเกม "
                exit 0
                ;;

            *)
                echo "❌ ตัวเลือกไม่ถูกต้อง "
                ;;
        esac
    done
}
# -----------------------------------
# ฟังก์ชัน: ส่งผลคะแนนขึ้นท้าชิง (API)
# -----------------------------------
send_challenge() {
    api_url="http://localhost:7700/api/game/update"

    http_response=$(curl -s -o response.json -w "%{http_code}" \
        -X POST "$api_url" \
        -H "Content-Type: application/json" \
        -d "{
            \"player_name\": \"${USER:-player}\",
            \"level\": $player_level,
            \"exp\": $player_exp,
            \"hp\": $player_hp,
            \"attack\": $player_attack,
            \"puk\": $puk
        }")

    # สี ANSI
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;36m'
    NC='\033[0m' # ไม่มีสี

    if [ "$http_response" -eq 200 ]; then
        status=$(jq -r '.status' response.json)
        message=$(jq -r '.message' response.json)
        player=$(jq -r '.player' response.json)
        total=$(jq -r '.all_players | length' response.json)

        echo -e "✅ ส่งผลคะแนนขึ้นท้าชิงสำเร็จแล้ว!"
        echo -e "💬 ข้อความจากเซิร์ฟเวอร์: $message"
        echo -e "📊 สถานะผู้เล่นของคุณ:"

        hp=$(echo "$player" | jq -r '.hp')
        attack=$(echo "$player" | jq -r '.attack')
        exp=$(echo "$player" | jq -r '.exp')
        level=$(echo "$player" | jq -r '.level')
        puk=$(echo "$player" | jq -r '.puk')

        echo -e "   💎 LVL: ${BLUE}$level${NC}"
        echo -e "   🟢 HP: ${GREEN}$hp${NC}"
        echo -e "   🟡 ATK: ${YELLOW}$attack${NC}"
        echo -e "   🟢 EXP: ${GREEN}$exp${NC}"
        echo -e "   🟢 PUK: ${GREEN}$puk${NC}"

        echo -e "\n🌐 ผู้เล่นทั้งหมด ($total):"
        jq -r '.all_players | to_entries | .[] | 
            "   \(.key): HP:\(.value.hp) ATK:\(.value.attack) EXP:\(.value.exp) LVL:\(.value.level) PUK:\(.value.puk)"' response.json

    else
        echo -e "❌ การส่งผลคะแนนล้มเหลว (รหัส: $http_response)"
        echo -e "📡 คำตอบจากเซิร์ฟเวอร์:"
        cat response.json
    fi

    rm -f response.json
}




# -----------------------------------
# ลูปหลักของเกม
# -----------------------------------
while true; do
    fight_monster
    upgrade_menu
done
