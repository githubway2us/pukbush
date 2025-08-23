from flask import Flask, request, jsonify, render_template_string
import sqlite3
from sqlite3 import Error

app = Flask(__name__)

# ชื่อไฟล์ฐานข้อมูล
DATABASE = 'rpg_game.db'

# ฟังก์ชันเชื่อมต่อฐานข้อมูล
def create_connection():
    conn = None
    try:
        conn = sqlite3.connect(DATABASE)
        return conn
    except Error as e:
        print(f"Error connecting to database: {e}")
    return conn

# ฟังก์ชันสร้างตาราง players ถ้ายังไม่มี
def create_table():
    conn = create_connection()
    if conn is not None:
        try:
            cursor = conn.cursor()
            cursor.execute('''
                CREATE TABLE IF NOT EXISTS players (
                    name TEXT PRIMARY KEY,
                    character TEXT,
                    level INTEGER,
                    exp INTEGER,
                    hp INTEGER,
                    attack INTEGER,
                    puk INTEGER
                )
            ''')
            conn.commit()
        except Error as e:
            print(f"Error creating table: {e}")
        finally:
            conn.close()

# สร้างตารางเมื่อเริ่มเซิร์ฟเวอร์
create_table()

# 🏠 หน้าแรก (Index)
@app.route('/')
def index():
    html = """
    <html>
    <head>
        <title>🌟 Bash RPG Game</title>
        <style>
            body {
                font-family: Arial, sans-serif;
                background: linear-gradient(to bottom, #1a1a2e, #16213e);
                color: #e0e0e0;
                text-align: center;
                margin: 0;
                padding: 20px;
            }
            h1 {
                font-size: 2.5em;
                color: #ffd700;
                text-shadow: 2px 2px 4px #000;
            }
            p {
                font-size: 1.2em;
                max-width: 600px;
                margin: 20px auto;
                line-height: 1.6;
            }
            a {
                display: inline-block;
                padding: 10px 20px;
                background: #4caf50;
                color: white;
                text-decoration: none;
                border-radius: 5px;
                font-weight: bold;
                margin-top: 20px;
                transition: background 0.3s;
            }
            a:hover {
                background: #45a049;
            }
            .container {
                background: #2a2a3c;
                padding: 20px;
                border-radius: 10px;
                box-shadow: 0 0 10px rgba(0,0,0,0.5);
                max-width: 800px;
                margin: 20px auto;
            }
            .features {
                text-align: left;
                margin: 20px auto;
                max-width: 600px;
            }
            .features li {
                margin: 10px 0;
                font-size: 1.1em;
            }
        </style>
    </head>
    <body>
        <div class="container">
            <h1>🌟 Welcome to Bash RPG Game @PUK pukumpee</h1>
            <p>
                Embark on an epic adventure in a fantasy world! Fight monsters, complete quests, upgrade your skills and items, and rise to the top of the leaderboard. Play in auto or manual mode, collect PUK, and save your progress!
            </p>
            <div class="features">
                <h2>🎮 Game Features</h2>
                <ul>
                    <li>🦸‍♂️ Create and customize your character (Warrior, Mage, Healer, Assassin)</li>
                    <li>⚔️ Battle monsters and bosses with skills and items</li>
                    <li>🛒 Buy, sell, and upgrade items in the shop</li>
                    <li>🧬 Level up by earning EXP and completing quests</li>
                    <li>🏆 Check your rank on the <a href="/scoreboard">Scoreboard</a></li>
                </ul>
            </div>
            <a href="/scoreboard">🏆 View Scoreboard</a>
        </div>
    </body>
    </html>
    """
    return render_template_string(html)

# 🎮 รับผลการเล่นจากเกมและบันทึกลงฐานข้อมูล
@app.route('/api/game/update', methods=['POST'])
def update_game():
    data = request.get_json()
    name = data.get("player_name", "Unknown")
    character = data.get("character", "none")
    level = data.get("level", 1)
    exp = data.get("exp", 0)
    hp = data.get("hp", 0)
    attack = data.get("attack", 0)
    puk = data.get("puk", 0)

    # อัพเดตหรือเพิ่มข้อมูลผู้เล่นในฐานข้อมูล
    conn = create_connection()
    if conn is not None:
        try:
            cursor = conn.cursor()
            cursor.execute('''
                INSERT OR REPLACE INTO players (name, character, level, exp, hp, attack, puk)
                VALUES (?, ?, ?, ?, ?, ?, ?)
            ''', (name, character, level, exp, hp, attack, puk))
            conn.commit()

            # ดึงข้อมูลผู้เล่นทั้งหมดและจัดอันดับ
            cursor.execute('SELECT * FROM players ORDER BY exp DESC')
            all_players = cursor.fetchall()
            players_dict = {
                row[0]: {
                    "character": row[1],
                    "level": row[2],
                    "exp": row[3],
                    "hp": row[4],
                    "attack": row[5],
                    "puk": row[6]
                } for row in all_players
            }

            # หาอันดับของผู้เล่น
            rank = next((i + 1 for i, row in enumerate(all_players) if row[0] == name), None)
            player_data = players_dict.get(name, {
                "character": character,
                "level": level,
                "exp": exp,
                "hp": hp,
                "attack": attack,
                "puk": puk
            })

            return jsonify({
                "status": "ok",
                "message": "Detail on board!!!",
                "player": player_data,
                "rank": rank,
                "total_players": len(players_dict),
                "all_players": players_dict
            }), 200
        except Error as e:
            print(f"Error updating player data: {e}")
            return jsonify({"status": "error", "message": "Failed to update player data"}), 500
        finally:
            conn.close()
    else:
        return jsonify({"status": "error", "message": "Database connection failed"}), 500

# 🏆 แสดงหน้า Scoreboard (HTML)
@app.route('/scoreboard')
def scoreboard():
    conn = create_connection()
    sorted_players = []
    if conn is not None:
        try:
            cursor = conn.cursor()
            cursor.execute('SELECT name, character, level, exp, hp, attack, puk FROM players ORDER BY exp DESC')
            sorted_players = [(row[0], {
                "character": row[1],
                "level": row[2],
                "exp": row[3],
                "hp": row[4],
                "attack": row[5],
                "puk": row[6]
            }) for row in cursor.fetchall()]
        except Error as e:
            print(f"Error fetching scoreboard: {e}")
        finally:
            conn.close()

    html = """
    <html>
    <head>
        <title>🏆 Scoreboard</title>
        <style>
            body {
                font-family: Arial, sans-serif;
                background: linear-gradient(to bottom, #1a1a2e, #16213e);
                color: #e0e0e0;
                text-align: center;
                margin: 0;
                padding: 20px;
            }
            table {
                border-collapse: collapse;
                width: 80%;
                margin: 20px auto;
                background: #2a2a3c;
                border-radius: 10px;
                box-shadow: 0 0 10px rgba(0,0,0,0.5);
            }
            th, td {
                border: 1px solid #555;
                padding: 10px;
                text-align: center;
            }
            th {
                background: #444;
            }
            tr:nth-child(even) {
                background: #2a2a3c;
            }
            h1 {
                font-size: 2.5em;
                color: #ffd700;
                text-shadow: 2px 2px 4px #000;
            }
            a {
                display: inline-block;
                padding: 10px 20px;
                background: #4caf50;
                color: white;
                text-decoration: none;
                border-radius: 5px;
                font-weight: bold;
                margin-top: 20px;
            }
            a:hover {
                background: #45a049;
            }
        </style>
    </head>
    <body>
        <h1>🏆 Scoreboard</h1>
        <table>
            <tr>
                <th>Rank</th>
                <th>Player</th>
                <th>Character</th>
                <th>Level</th>
                <th>EXP</th>
                <th>HP</th>
                <th>Attack</th>
                <th>PUK</th>
            </tr>
            {% for name, stats in sorted_players %}
            <tr>
                <td>{{ loop.index }}</td>
                <td>{{ name }}</td>
                <td>{{ stats.character }}</td>
                <td>{{ stats.level }}</td>
                <td>{{ stats.exp }}</td>
                <td>{{ stats.hp }}</td>
                <td>{{ stats.attack }}</td>
                <td>{{ stats.puk }}</td>
            </tr>
            {% endfor %}
        </table>
        <a href="/">🏠 Back to Home</a>
    </body>
    </html>
    """
    return render_template_string(html, sorted_players=sorted_players)

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=7700, debug=True)