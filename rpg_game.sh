#!/bin/bash

# -----------------------------------
# ตัวแปรเริ่มต้น
# -----------------------------------
save_file="savegame.txt"
max_inventory=5
player_name="Adventurer"
current_character="none"
player_hp=10000
player_attack=15
player_exp=0
player_level=1
puk=0
inventory=()
player_status="none"
player_status_turns=0
quest_monster_progress=0
quest_boss_progress=0
rpg_mode="manual"

# -----------------------------------
# รายการไอเทม (name:value:cost:effect:count)
# -----------------------------------
items=(
    "Minor Heal:10:5:heal:0"
    "Major Heal:50:20:heal:0"
    "Attack Boost:5:5:attack:0"
    "Health Boost:20:5:hp:0"
    "Antidote:0:5:status:0"
)

# -----------------------------------
# รายการสกิล (name:damage:cost:effect:description:level)
# -----------------------------------
skills=(
    "Fireball:30:20:damage:ปล่อยลูกไฟทำดาเมจ :0"
    "Thunderstrike:40:25:stun:โจมตีด้วยสายฟ้าทำดาเมจ และสตันศัตรู 1 เทิร์น:0"
    "Heal:50:30:heal:ฟื้นฟู HP :0"
    "Shadow Strike:35:15:damage:โจมตีเงารวดเร็วทำดาเมจ :0"
    "Holy Shield:0:25:heal:สร้างโล่ป้องกัน ลดดาเมจ 50% เป็นเวลา 2 เทิร์น:0"
)

# -----------------------------------
# รายการตัวละคร (name:hp:attack:cost:skill1:skill2)
# -----------------------------------
characters=(
    "Warrior:12000:20:100:Fireball:Holy Shield"
    "Mage:8000:30:150:Thunderstrike:Fireball"
    "Healer:10000:10:120:Heal:Holy Shield"
    "Assassin:9000:25:130:Shadow Strike:none"
)

# -----------------------------------
# ฟังก์ชัน: สร้างศัตรู
# -----------------------------------
generate_enemy() {
    enemies=("Goblin:20:5" "Slime:10:3" "Wolf:30:7" "Troll:50:10")
    boss_enemies=("Dragon:100:20" "Demon Lord:150:25")
    boss_flag=$((RANDOM % 10 < 2 ? 1 : 0))
    if [ $boss_flag -eq 1 ]; then
        enemy=$((RANDOM % ${#boss_enemies[@]}))
        IFS=':' read -r enemy_name enemy_hp enemy_attack <<< "${boss_enemies[$enemy]}"
        enemy_level=$((player_level + 2))
        enemy_hp=$((enemy_hp + enemy_level * 10))
        enemy_attack=$((enemy_attack + enemy_level * 2))
    else
        enemy=$((RANDOM % ${#enemies[@]}))
        IFS=':' read -r enemy_name enemy_hp enemy_attack <<< "${enemies[$enemy]}"
        enemy_level=$((player_level))
        enemy_hp=$((enemy_hp + enemy_level * 5))
        enemy_attack=$((enemy_attack + enemy_level))
    fi
}

# -----------------------------------
# ฟังก์ชัน: อัพเกรดไอเทม
# -----------------------------------
upgrade_item() {
    if [ ${#inventory[@]} -eq 0 ]; then
        echo "🎒 กระเป๋าไม่มีไอเทม! "
        return
    fi
    echo "===== 🛠️ อัพเกรดไอเทม ====="
    for i in "${!inventory[@]}"; do
        IFS=':' read -r name value cost effect count <<< "${inventory[$i]}"
        if [ $count -lt 3 ]; then
            up_cost=$((cost * (count + 1)))
            echo "$i) $name (ใช้แล้ว $count/3) - อัพเกรด: $up_cost PUK "
        fi
    done
    echo "q) กลับ"
    echo "เลือกไอเทมเพื่ออัพเกรด: "
    read item_choice
    if [ "$item_choice" == "q" ]; then
        return
    fi
    if [[ ! "$item_choice" =~ ^[0-9]+$ ]] || [ $item_choice -ge ${#inventory[@]} ]; then
        echo "❌ ตัวเลือกไม่ถูกต้อง "
        return
    fi
    IFS=':' read -r name value cost effect count <<< "${inventory[$item_choice]}"
    if [ $count -ge 3 ]; then
        echo "❌ ไอเทม $name อัพเกรดถึงขีดจำกัดแล้ว! "
        return
    fi
    up_cost=$((cost * (count + 1)))
    if [ $puk -ge $up_cost ]; then
        puk=$((puk - up_cost))
        count=$((count + 1))
        value=$((value + 5))
        inventory[$item_choice]="$name:$value:$cost:$effect:$count"
        echo "🔧 อัพเกรด $name เรียบร้อย! ค่า $effect +5 | PUK เหลือ $puk "
    else
        echo "❌ PUK ไม่พอ "
    fi
}

# -----------------------------------
# ฟังก์ชัน: ขายไอเทม
# -----------------------------------
sell_item() {
    if [ ${#inventory[@]} -eq 0 ]; then
        echo "🎒 กระเป๋าไม่มีไอเทม! "
        return
    fi
    echo "===== 💰 ขายไอเทม ====="
    for i in "${!inventory[@]}"; do
        IFS=':' read -r name value cost effect count <<< "${inventory[$i]}"
        sell_price=$((cost / 2))
        echo "$i) $name (ขายได้ $sell_price PUK) "
    done
    echo "q) กลับ"
    echo "เลือกไอเทมเพื่อขาย: "
    read sell_choice
    if [ "$sell_choice" == "q" ]; then
        return
    fi
    if [[ ! "$sell_choice" =~ ^[0-9]+$ ]] || [ $sell_choice -ge ${#inventory[@]} ]; then
        echo "❌ ตัวเลือกไม่ถูกต้อง "
        return
    fi
    IFS=':' read -r name value cost effect count <<< "${inventory[$sell_choice]}"
    sell_price=$((cost / 2))
    puk=$((puk + sell_price))
    unset 'inventory[$sell_choice]'
    inventory=("${inventory[@]}")
    echo "💰 ขาย $name ได้ $sell_price PUK | PUK รวม: $puk "
}

# -----------------------------------
# ฟังก์ชัน: ใช้ไอเทม
# -----------------------------------
use_item() {
    if [ ${#inventory[@]} -eq 0 ]; then
        echo "🎒 กระเป๋าไม่มีไอเทม! "
        return
    fi
    echo "🎒 ไอเทมในกระเป๋า: "
    for i in "${!inventory[@]}"; do
        IFS=':' read -r name value cost effect count <<< "${inventory[$i]}"
        echo "$i) $name (ค่า $effect: $value) "
    done
    echo "เลือกไอเทม (หรือ q เพื่อยกเลิก): "
    read item_choice
    if [ "$item_choice" == "q" ]; then
        echo "ยกเลิกการใช้ไอเทม "
        return
    fi
    if [[ ! "$item_choice" =~ ^[0-9]+$ ]] || [ $item_choice -ge ${#inventory[@]} ]; then
        echo "❌ ตัวเลือกไม่ถูกต้อง "
        return
    fi
    IFS=':' read -r name value cost effect count <<< "${inventory[$item_choice]}"
    if [ "$effect" == "heal" ]; then
        player_hp=$((player_hp + value))
        echo "✨ ใช้ $name ฮีล +$value HP | HP คุณ: $player_hp "
    elif [ "$effect" == "attack" ]; then
        player_attack=$((player_attack + value))
        echo "⚔️ ใช้ $name ATK +$value | ATK คุณ: $player_attack "
    elif [ "$effect" == "hp" ]; then
        player_hp=$((player_hp + value))
        echo "🛡️ ใช้ $name HP +$value | HP คุณ: $player_hp "
    elif [ "$effect" == "status" ]; then
        player_status="none"
        player_status_turns=0
        echo "🧪 ใช้ $name ลบสถานะผิดปกติ! "
    fi
    unset 'inventory[$item_choice]'
    inventory=("${inventory[@]}")
}

# -----------------------------------
# ฟังก์ชัน: รีเซ็ตข้อมูลผู้เล่น
# -----------------------------------
reset_player() {
    if [ "$current_character" == "none" ]; then
        player_hp=10000
        player_attack=15
        skills=("Fireball:30:20:damage:ปล่อยลูกไฟทำดาเมจ :0")
    else
        for char in "${characters[@]}"; do
            IFS=':' read -r name hp attack cost skill1 skill2 <<< "$char"
            if [ "$name" == "$current_character" ]; then
                player_hp=$hp
                player_attack=$attack
                skills=()
                if [ "$skill1" != "none" ]; then
                    for skill in "${skills[@]}"; do
                        IFS=':' read -r s_name s_damage s_cost s_effect s_desc s_level <<< "$skill"
                        if [ "$s_name" == "$skill1" ]; then
                            skills+=("$s_name:$s_damage:$s_cost:$s_effect:$s_desc:0")
                        fi
                    done
                fi
                if [ "$skill2" != "none" ]; then
                    for skill in "${skills[@]}"; do
                        IFS=':' read -r s_name s_damage s_cost s_effect s_desc s_level <<< "$skill"
                        if [ "$s_name" == "$skill2" ]; then
                            skills+=("$s_name:$s_damage:$s_cost:$s_effect:$s_desc:0")
                        fi
                    done
                fi
                break
            fi
        done
    fi
    player_exp=0
    player_level=1
    puk=0
    inventory=()
    player_status="none"
    player_status_turns=0
    quest_monster_progress=0
    quest_boss_progress=0
    if [ -f "$save_file" ]; then
        rm "$save_file"
        echo "🗑️ ลบไฟล์บันทึกเก่าเรียบร้อย "
    fi
    echo "✅ รีเซ็ตข้อมูลผู้เล่นเรียบร้อย! "
}

# -----------------------------------
# ฟังก์ชัน: สร้างไอดีใหม่
# -----------------------------------
create_new_id() {
    echo "📝 กรุณาตั้งชื่อผู้เล่น: "
    read player_name
    if [ -z "$player_name" ]; then
        player_name="Adventurer"
        echo "⚠️ ไม่ได้ตั้งชื่อ ใช้ชื่อเริ่มต้น: $player_name"
    fi
    echo "🦸‍♂️ เลือกประเภทตัวละคร: "
    for i in "${!characters[@]}"; do
        IFS=':' read -r name hp attack cost skill1 skill2 <<< "${characters[$i]}"
        echo -n "$i) $name (HP: $hp, ATK: $attack) - สกิล: "
        if [ "$skill1" != "none" ]; then
            for skill in "${skills[@]}"; do
                IFS=':' read -r s_name s_damage s_cost s_effect s_desc s_level <<< "$skill"
                if [ "$s_name" == "$skill1" ]; then
                    case "$s_effect" in
                        "damage"|"stun") echo -n "$s_name (Lv.0, $s_desc$s_damage), "; ;;
                        "heal")
                            if [ "$s_name" == "Heal" ]; then
                                echo -n "$s_name (Lv.0, $s_desc$s_damage HP), "
                            else
                                echo -n "$s_name (Lv.0, $s_desc), "
                            fi
                            ;;
                    esac
                fi
            done
        fi
        if [ "$skill2" != "none" ]; then
            for skill in "${skills[@]}"; do
                IFS=':' read -r s_name s_damage s_cost s_effect s_desc s_level <<< "$skill"
                if [ "$s_name" == "$skill2" ]; then
                    case "$s_effect" in
                        "damage"|"stun") echo -n "$s_name (Lv.0, $s_desc$s_damage)"; ;;
                        "heal")
                            if [ "$s_name" == "Heal" ]; then
                                echo -n "$s_name (Lv.0, $s_desc$s_damage HP)"
                            else
                                echo -n "$s_name (Lv.0, $s_desc)"
                            fi
                            ;;
                    esac
                fi
            done
        fi
        if [ "$skill1" == "none" ] && [ "$skill2" == "none" ]; then
            echo "ไม่มี"
        else
            echo ""
        fi
    done
    echo "เลือก: "
    read char_choice
    if [[ ! "$char_choice" =~ ^[0-9]+$ ]] || [ $char_choice -ge ${#characters[@]} ]; then
        echo "❌ ตัวเลือกไม่ถูกต้อง ใช้ตัวละครเริ่มต้น"
        current_character="none"
    else
        IFS=':' read -r name hp attack cost skill1 skill2 <<< "${characters[$char_choice]}"
        current_character="$name"
    fi
    reset_player
    echo "🎉 สร้างตัวละคร '$player_name' ($current_character) สำเร็จ! เริ่มต้นด้วย HP: $player_hp, ATK: $player_attack"
    echo "สกิล: ${skill1:-none}${skill2:+, $skill2}"
    save_game
    echo "🎮 เลือกโหมดการเล่น: "
    echo "1) Auto"
    echo "2) Manual"
    read mode_choice
    if [ "$mode_choice" == "1" ]; then
        rpg_mode="auto"
        echo "🎮 โหมด RPG: auto "
    else
        rpg_mode="manual"
        echo "🎮 โหมด RPG: manual "
    fi
}

# -----------------------------------
# ฟังก์ชัน: บันทึกเกม
# -----------------------------------
save_game() {
    echo "player_name=$player_name" > "$save_file"
    echo "current_character=$current_character" >> "$save_file"
    echo "player_hp=$player_hp" >> "$save_file"
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
    echo -n "skills=" >> "$save_file"
    if [ ${#skills[@]} -eq 0 ]; then
        echo "" >> "$save_file"
    else
        for i in "${!skills[@]}"; do
            IFS=':' read -r name damage cost effect desc level <<< "${skills[$i]}"
            if [ $i -eq 0 ]; then
                echo -n "${skills[$i]}" >> "$save_file"
            else
                echo -n "|${skills[$i]}" >> "$save_file"
            fi
        done
        echo "" >> "$save_file"
    fi
    echo "🎉 บันทึกเกมเรียบร้อย! "
    echo "💾 รายละเอียดสกิลที่บันทึก:"
    for skill in "${skills[@]}"; do
        IFS=':' read -r s_name s_damage s_cost s_effect s_desc s_level <<< "$skill"
        case "$s_effect" in
            "damage"|"stun") echo "   $s_name (Lv.$s_level, $s_desc$s_damage, ใช้ $s_cost PUK)"; ;;
            "heal")
                if [ "$s_name" == "Heal" ]; then
                    echo "   $s_name (Lv.$s_level, $s_desc$s_damage HP, ใช้ $s_cost PUK)"
                else
                    echo "   $s_name (Lv.$s_level, $s_desc, ใช้ $s_cost PUK)"
                fi
                ;;
        esac
    done
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
    IFS='|' read -ra skills_array <<< "$skills"
    skills=("${skills_array[@]}")
    echo "✅ โหลดเกมเรียบร้อย! "
    echo "✨ ผู้เล่น: $player_name | ตัวละคร: $current_character"
    echo "✨ PUK: $puk | ❤️ HP: $player_hp | ⚔️ ATK: $player_attack | 🧬 EXP: $player_exp/$((player_level * 50)) (Lv.$player_level)"
    echo "🪄 สกิลที่โหลด:"
    if [ ${#skills[@]} -eq 0 ]; then
        echo "   ไม่มีสกิล"
    else
        for skill in "${skills[@]}"; do
            IFS=':' read -r s_name s_damage s_cost s_effect s_desc s_level <<< "$skill"
            case "$s_effect" in
                "damage"|"stun") echo "   $s_name (Lv.$s_level, $s_desc$s_damage, ใช้ $s_cost PUK)"; ;;
                "heal")
                    if [ "$s_name" == "Heal" ]; then
                        echo "   $s_name (Lv.$s_level, $s_desc$s_damage HP, ใช้ $s_cost PUK)"
                    else
                        echo "   $s_name (Lv.$s_level, $s_desc, ใช้ $s_cost PUK)"
                    fi
                    ;;
            esac
        done
    fi
    return 0
}

# -----------------------------------
# ฟังก์ชัน: ซื้อตัวละคร
# -----------------------------------
buy_character() {
    echo "===== 🦸‍♂️ ร้านค้าตัวละคร ====="
    echo "PUK ที่มี: $puk "
    for i in "${!characters[@]}"; do
        IFS=':' read -r name hp attack cost skill1 skill2 <<< "${characters[$i]}"
        echo -n "$i) $name (HP: $hp, ATK: $attack, ราคา: $cost PUK) - สกิล: "
        if [ "$skill1" != "none" ]; then
            for skill in "${skills[@]}"; do
                IFS=':' read -r s_name s_damage s_cost s_effect s_desc s_level <<< "$skill"
                if [ "$s_name" == "$skill1" ]; then
                    case "$s_effect" in
                        "damage"|"stun") echo -n "$s_name (Lv.0, $s_desc$s_damage), "; ;;
                        "heal")
                            if [ "$s_name" == "Heal" ]; then
                                echo -n "$s_name (Lv.0, $s_desc$s_damage HP), "
                            else
                                echo -n "$s_name (Lv.0, $s_desc), "
                            fi
                            ;;
                    esac
                fi
            done
        fi
        if [ "$skill2" != "none" ]; then
            for skill in "${skills[@]}"; do
                IFS=':' read -r s_name s_damage s_cost s_effect s_desc s_level <<< "$skill"
                if [ "$s_name" == "$skill2" ]; then
                    case "$s_effect" in
                        "damage"|"stun") echo -n "$s_name (Lv.0, $s_desc$s_damage)"; ;;
                        "heal")
                            if [ "$s_name" == "Heal" ]; then
                                echo -n "$s_name (Lv.0, $s_desc$s_damage HP)"
                            else
                                echo -n "$s_name (Lv.0, $s_desc)"
                            fi
                            ;;
                    esac
                fi
            done
        fi
        if [ "$skill1" == "none" ] && [ "$skill2" == "none" ]; then
            echo "ไม่มี"
        else
            echo ""
        fi
    done
    echo "q) กลับ"
    echo "เลือกซื้อ: "
    read char_choice
    if [ "$char_choice" == "q" ]; then
        return
    fi
    if [[ ! "$char_choice" =~ ^[0-9]+$ ]] || [ $char_choice -ge ${#characters[@]} ]; then
        echo "❌ ตัวเลือกไม่ถูกต้อง "
        return
    fi
    IFS=':' read -r name hp attack cost skill1 skill2 <<< "${characters[$char_choice]}"
    if [ $puk -ge $cost ]; then
        puk=$((puk - cost))
        current_character="$name"
        player_hp=$hp
        player_attack=$attack
        skills=()
        if [ "$skill1" != "none" ]; then
            for skill in "${skills[@]}"; do
                IFS=':' read -r s_name s_damage s_cost s_effect s_desc s_level <<< "$skill"
                if [ "$s_name" == "$skill1" ]; then
                    skills+=("$s_name:$s_damage:$s_cost:$s_effect:$s_desc:0")
                fi
            done
        fi
        if [ "$skill2" != "none" ]; then
            for skill in "${skills[@]}"; do
                IFS=':' read -r s_name s_damage s_cost s_effect s_desc s_level <<< "$skill"
                if [ "$s_name" == "$skill2" ]; then
                    skills+=("$s_name:$s_damage:$s_cost:$s_effect:$s_desc:0")
                fi
            done
        fi
        echo "🦸‍♂️ ซื้อตัวละคร $name เรียบร้อย! HP: $player_hp, ATK: $player_attack"
        echo "สกิล: ${skill1:-none}${skill2:+, $skill2}"
        save_game
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
    echo "=== ไอเทม ==="
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
    echo "=== ตัวเลือกเพิ่มเติม ==="
    echo "c) ซื้อตัวละคร"
    echo "s) ขายไอเทม"
    echo "q) กลับ"
    echo "เลือก: "
    read shop_choice
    if [ "$shop_choice" == "q" ]; then
        return
    elif [ "$shop_choice" == "c" ]; then
        buy_character
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
# ฟังก์ชัน: อัพเกรดสกิล
# -----------------------------------
upgrade_skill() {
    if [ ${#skills[@]} -eq 0 ]; then
        echo "❌ คุณยังไม่มีสกิล! "
        return
    fi
    echo "===== 🪄 อัพเกรดสกิล ====="
    echo "PUK ที่มี: $puk "
    for i in "${!skills[@]}"; do
        IFS=':' read -r name damage cost effect desc level <<< "${skills[$i]}"
        up_cost=$((10 + level * 10))
        up_damage=$((damage + 10))
        up_cost_reduced=$((cost - 5 > 5 ? cost - 5 : 5))
        case "$effect" in
            "damage"|"stun")
                echo "$i) $name (Lv.$level -> Lv.$((level + 1))) - $desc$damage -> $up_damage, ใช้ $up_cost PUK"
                ;;
            "heal")
                if [ "$name" == "Heal" ]; then
                    echo "$i) $name (Lv.$level -> Lv.$((level + 1))) - $desc$damage HP -> $up_damage HP, ใช้ $up_cost PUK"
                elif [ "$name" == "Holy Shield" ]; then
                    echo "$i) $name (Lv.$level -> Lv.$((level + 1))) - $desc, ลด PUK: $cost -> $up_cost_reduced, ใช้ $up_cost PUK"
                fi
                ;;
        esac
    done
    echo "q) กลับ"
    echo "เลือกสกิลเพื่ออัพเกรด: "
    read skill_choice
    if [ "$skill_choice" == "q" ]; then
        echo "ยกเลิกการอัพเกรดสกิล "
        return
    fi
    if [[ ! "$skill_choice" =~ ^[0-9]+$ ]] || [ $skill_choice -ge ${#skills[@]} ]; then
        echo "❌ ตัวเลือกไม่ถูกต้อง "
        return
    fi
    IFS=':' read -r name damage cost effect desc level <<< "${skills[$skill_choice]}"
    up_cost=$((10 + level * 10))
    if [ $puk -lt $up_cost ]; then
        echo "❌ PUK ไม่พอ "
        return
    fi
    if [ $level -ge 5 ]; then
        echo "❌ สกิล $name ถึงระดับสูงสุดแล้ว! "
        return
    fi
    puk=$((puk - up_cost))
    level=$((level + 1))
    case "$effect" in
        "damage"|"stun")
            damage=$((damage + 10))
            ;;
        "heal")
            if [ "$name" == "Heal" ]; then
                damage=$((damage + 10))
            elif [ "$name" == "Holy Shield" ]; then
                cost=$((cost - 5 > 5 ? cost - 5 : 5))
            fi
            ;;
    esac
    skills[$skill_choice]="$name:$damage:$cost:$effect:$desc:$level"
    echo "🔧 อัพเกรด $name เป็น Lv.$level เรียบร้อย! PUK เหลือ $puk "
    save_game
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
        IFS=':' read -r name damage cost effect desc level <<< "${skills[$i]}"
        case "$effect" in
            "damage"|"stun")
                echo "$i) $name (Lv.$level, $desc$damage, ใช้ $cost PUK) "
                ;;
            "heal")
                if [ "$name" == "Heal" ]; then
                    echo "$i) $name (Lv.$level, $desc$damage HP, ใช้ $cost PUK) "
                elif [ "$name" == "Holy Shield" ]; then
                    echo "$i) $name (Lv.$level, $desc, ใช้ $cost PUK) "
                fi
                ;;
        esac
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
    IFS=':' read -r name damage cost effect desc level <<< "${skills[$skill_choice]}"
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
        if [ "$name" == "Heal" ]; then
            player_hp=$((player_hp + damage))
            echo "✨ ใช้ $name ฮีล +$damage HP | HP คุณ: $player_hp "
        elif [ "$name" == "Holy Shield" ]; then
            player_status="shield"
            player_status_turns=2
            echo "🛡️ ใช้ $name สร้างโล่ป้องกัน ลดดาเมจ 50% เป็นเวลา 2 เทิร์น! "
        fi
    elif [ "$effect" == "stun" ]; then
        enemy_hp=$((enemy_hp - damage))
        echo "⚡ ใช้ $name ทำดาเมจ $damage และสตัน $enemy_name 1 เทิร์น! "
        stun=1
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
    elif [ "$player_status" == "shield" ] && [ $player_status_turns -gt 0 ]; then
        player_status_turns=$((player_status_turns - 1))
        echo "🛡️ โล่ป้องกันทำงาน! ลดดาเมจ 50% | เหลือ $player_status_turns เทิร์น "
        if [ $player_status_turns -eq 0 ]; then
            player_status="none"
            echo "✅ โล่ป้องกันหายไป! "
        fi
    fi
}

# -----------------------------------
# ฟังก์ชัน: ใช้สถานะ
# -----------------------------------
apply_status() {
    if [ $((RANDOM % 100)) -lt 10 ]; then
        player_status="poison"
        player_status_turns=3
        echo "☠️ คุณถูกพิษ! ลด HP 5 ต่อเทิร์น เป็นเวลา 3 เทิร์น "
    fi
}

# -----------------------------------
# ฟังก์ชัน: อัพเลเวล
# -----------------------------------
level_up() {
    exp_needed=$((player_level * 50))
    while [ $player_exp -ge $exp_needed ]; do
        player_level=$((player_level + 1))
        player_hp=$((player_hp + 20))
        player_attack=$((player_attack + 5))
        player_exp=$((player_exp - exp_needed))
        exp_needed=$((player_level * 50))
        echo "🎉 อัพเลเวลเป็น Lv.$player_level! HP +20, ATK +5 "
    done
}

# -----------------------------------
# ฟังก์ชัน: อีเวนต์สุ่ม
# -----------------------------------
random_event() {
    event=$((RANDOM % 100))
    if [ $event -lt 10 ]; then
        puk=$((puk + 10))
        echo "💰 พบสมบัติ! ได้ PUK +10 | PUK รวม: $puk "
    elif [ $event -lt 20 ]; then
        player_hp=$((player_hp - 10))
        echo "🪤 ติดกับดัก! HP -10 | HP คุณ: $player_hp "
    elif [ $event -lt 30 ]; then
        item=$((RANDOM % ${#items[@]}))
        if [ ${#inventory[@]} -lt $max_inventory ]; then
            inventory+=("${items[$item]}")
            IFS=':' read -r name _ _ _ _ <<< "${items[$item]}"
            echo "🎁 พบ $name! เก็บใส่กระเป๋า "
        else
            echo "🎒 กระเป๋าเต็ม! ไม่สามารถเก็บไอเทมได้ "
        fi
    fi
}

# -----------------------------------
# ฟังก์ชัน: ตรวจสอบเควสต์
# -----------------------------------
quest_menu() {
    echo "===== 📜 เควสต์ ====="
    echo "1) ฆ่ามอนสเตอร์ 10 ตัว ($quest_monster_progress/10)"
    echo "2) ฆ่าบอส 3 ตัว ($quest_boss_progress/3)"
    echo "q) กลับ"
    echo "เลือก: "
    read quest_choice
    if [ "$quest_choice" == "q" ]; then
        return
    fi
    case $quest_choice in
        1)
            if [ $quest_monster_progress -ge 10 ]; then
                puk=$((puk + 50))
                quest_monster_progress=0
                echo "🎉 เควสต์สำเร็จ! ได้รางวัล 50 PUK | PUK รวม: $puk "
            else
                echo "⚔️ ยังฆ่ามอนสเตอร์ไม่ครบ 10 ตัว! "
            fi
            ;;
        2)
            if [ $quest_boss_progress -ge 3 ]; then
                puk=$((puk + 100))
                quest_boss_progress=0
                echo "🎉 เควสต์สำเร็จ! ได้รางวัล 100 PUK | PUK รวม: $puk "
            else
                echo "⚔️ ยังฆ่าบอสไม่ครบ 3 ตัว! "
            fi
            ;;
        *)
            echo "❌ ตัวเลือกไม่ถูกต้อง "
            ;;
    esac
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
                damage=$enemy_attack
                if [ "$player_status" == "shield" ]; then
                    damage=$((damage / 2))
                    echo "🛡️ โล่ป้องกันลดดาเมจจาก $enemy_name เหลือ $damage "
                fi
                player_hp=$((player_hp - damage))
                echo "😈 $enemy_name โจมตี -$damage "
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
            echo "💀 คุณตาย! เริ่มใหม่... "
            reset_player
        else
            reward=$((enemy_level * 5))
            if [ $boss_flag -eq 1 ]; then
                reward=$((reward * 2))
                quest_boss_progress=$((quest_boss_progress + 1))
            else
                quest_monster_progress=$((quest_monster_progress + 1))
            fi
            puk=$((puk + reward))
            exp_gain=$((enemy_level * 10))
            player_exp=$((player_exp + exp_gain))
            echo "🎉 ชนะ $enemy_name! ได้ $reward PUK และ $exp_gain EXP "
            echo "💰 PUK รวม: $puk | 🧬 EXP: $player_exp/$((player_level * 50)) "
            level_up
            save_game
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
                    damage=$enemy_attack
                    if [ "$player_status" == "shield" ]; then
                        damage=$((damage / 2))
                        echo "🛡️ โล่ป้องกันลดดาเมจจาก $enemy_name เหลือ $damage "
                    fi
                    player_hp=$((player_hp - damage))
                    echo "😈 $enemy_name โจมตี -$damage "
                    apply_status
                else
                    echo "😴 $enemy_name สตัน! "
                    stun=0
                fi
            fi
            check_status
        done
        if [ $player_hp -le 0 ]; then
            echo "💀 คุณตาย! เริ่มใหม่... "
            reset_player
        else
            reward=$((enemy_level * 5))
            if [ $boss_flag -eq 1 ]; then
                reward=$((reward * 2))
                quest_boss_progress=$((quest_boss_progress + 1))
            else
                quest_monster_progress=$((quest_monster_progress + 1))
            fi
            puk=$((puk + reward))
            exp_gain=$((enemy_level * 10))
            player_exp=$((player_exp + exp_gain))
            echo "🎉 ชนะ $enemy_name! ได้ $reward PUK และ $exp_gain EXP "
            echo "💰 PUK รวม: $puk | 🧬 EXP: $player_exp/$((player_level * 50)) "
            level_up
            save_game
        fi
    fi
}

# -----------------------------------
# ฟังก์ชัน: เมนูอัพเกรด
# -----------------------------------
upgrade_menu() {
    while true; do
        echo "===== 🛠️ เมนูอัพเกรด ====="
        echo "✨ ผู้เล่น: $player_name | ตัวละคร: $current_character"
        echo "✨ PUK: $puk | ❤️ HP: $player_hp | ⚔️ ATK: $player_attack | 🧬 EXP: $player_exp/$((player_level * 50)) (Lv.$player_level)"
        echo "🪄 สกิล: "
        if [ ${#skills[@]} -eq 0 ]; then
            echo "   ไม่มีสกิล"
        else
            for skill in "${skills[@]}"; do
                IFS=':' read -r s_name s_damage s_cost s_effect s_desc s_level <<< "$skill"
                case "$s_effect" in
                    "damage"|"stun") echo "   $s_name (Lv.$s_level, $s_desc$s_damage, ใช้ $s_cost PUK)"; ;;
                    "heal")
                        if [ "$s_name" == "Heal" ]; then
                            echo "   $s_name (Lv.$s_level, $s_desc$s_damage HP, ใช้ $s_cost PUK)"
                        else
                            echo "   $s_name (Lv.$s_level, $s_desc, ใช้ $s_cost PUK)"
                        fi
                        ;;
                esac
            done
        fi
        echo "1) อัพเกรดสกิล (HP +20) | ใช้ PUK 5"
        echo "2) อัพเกรดอาวุธ (ATK +5) | ใช้ PUK 5"
        echo "3) ร้านค้า"
        echo "4) อัพเกรดไอเทม"
        echo "5) ตรวจสอบเควสต์"
        echo "6) อัพเกรดสกิลตัวละคร"
        echo "7) กลับไปต่อสู้"
        echo "8) บันทึกเกม"
        echo "9) ส่งผลคะแนนขึ้นท้าชิง 🚀"
        echo "10) ออกจากเกม"
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
                upgrade_skill
                ;;
            7)
                return
                ;;
            8)
                save_game
                ;;
            9)
                send_challenge
                ;;
            10)
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
    api_url="https://pukserv.wuaze.com/api/game/update"

    http_response=$(curl -s -o response.json -w "%{http_code}" \
        -X POST "$api_url" \
        -H "Content-Type: application/json" \
        -d "{
            \"player_name\": \"$player_name\",
            \"character\": \"$current_character\",
            \"level\": $player_level,
            \"exp\": $player_exp,
            \"hp\": $player_hp,
            \"attack\": $player_attack,
            \"puk\": $puk
        }")

    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;36m'
    NC='\033[0m'

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
        character=$(echo "$player" | jq -r '.character')

        echo -e "   🦸‍♂️ ตัวละคร: ${BLUE}$character${NC}"
        echo -e "   💎 LVL: ${BLUE}$level${NC}"
        echo -e "   🟢 HP: ${GREEN}$hp${NC}"
        echo -e "   🟡 ATK: ${YELLOW}$attack${NC}"
        echo -e "   🟢 EXP: ${GREEN}$exp${NC}"
        echo -e "   🟢 PUK: ${GREEN}$puk${NC}"

        echo -e "\n🌐 ผู้เล่นทั้งหมด ($total):"
        jq -r '.all_players | to_entries | .[] | 
            "   \(.key): ตัวละคร:\(.value.character) HP:\(.value.hp) ATK:\(.value.attack) EXP:\(.value.exp) LVL:\(.value.level) PUK:\(.value.puk)"' response.json
    else
        echo -e "❌ การส่งผลคะแนนล้มเหลว (รหัส: $http_response)"
        echo -e "📡 คำตอบจากเซิร์ฟเวอร์:"
        cat response.json
    fi

    rm -f response.json
}

# -----------------------------------
# เริ่มเกม
# -----------------------------------
echo "🌟 เลือกโหมด RPG:"
echo "1) เริ่มเกมใหม่ (auto)"
echo "2) เริ่มเกมใหม่ (manual)"
echo "3) โหลดเกม"
echo "4) สร้างไอดีใหม่"
echo "เลือก: "
read start_choice
case $start_choice in
    1)
        rpg_mode="auto"
        reset_player
        echo "🎮 โหมด RPG: auto "
        ;;
    2)
        rpg_mode="manual"
        reset_player
        echo "🎮 โหมด RPG: manual "
        ;;
    3)
        load_game
        if [ $? -ne 0 ]; then
            echo "🎮 เริ่มเกมใหม่ในโหมด manual "
            rpg_mode="manual"
            reset_player
        fi
        ;;
    4)
        create_new_id
        ;;
    *)
        echo "❌ ตัวเลือกไม่ถูกต้อง! เริ่มเกมในโหมด manual "
        rpg_mode="manual"
        reset_player
        ;;
esac
sleep 1

# -----------------------------------
# ลูปหลักของเกม
# -----------------------------------
while true; do
    upgrade_menu
    fight_monster
done