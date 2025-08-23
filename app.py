from flask import Flask, request, jsonify, render_template_string

app = Flask(__name__)

# เก็บข้อมูลผู้เล่นทั้งหมด (ชั่วคราวใน memory)
players_dict = {}

# 🎮 รับผลการเล่นจากเกม
@app.route('/api/game/update', methods=['POST'])
def update_game():
    data = request.get_json()
    name = data.get("player_name", "Unknown")

    # เก็บ/อัปเดตข้อมูลผู้เล่น
    players_dict[name] = {
        "level": data.get("level", 1),
        "exp": data.get("exp", 0),
        "hp": data.get("hp", 0),
        "attack": data.get("attack", 0),
        "puk": data.get("puk", 0)
    }

    # ✅ จัดอันดับตาม EXP (มากไปน้อย)
    sorted_players = sorted(players_dict.items(), key=lambda x: x[1]["exp"], reverse=True)
    rank = next((i+1 for i, (n, _) in enumerate(sorted_players) if n == name), None)

    return jsonify({
        "status": "ok",
        "message": "Detail on board!!!",
        "player": players_dict[name],
        "rank": rank,
        "total_players": len(players_dict),
        "all_players": players_dict
    }), 200


# 🏆 แสดงหน้า Scoreboard (HTML)
@app.route('/scoreboard')
def scoreboard():
    html = """
    <html>
    <head>
        <title>🏆 Scoreboard</title>
        <style>
            body { font-family: Arial, sans-serif; background: #222; color: #eee; }
            table { border-collapse: collapse; width: 80%; margin: 20px auto; background: #333; }
            th, td { border: 1px solid #555; padding: 10px; text-align: center; }
            th { background: #444; }
            tr:nth-child(even) { background: #2a2a2a; }
        </style>
    </head>
    <body>
        <h1 style="text-align:center;">🏆 Scoreboard</h1>
        <table>
            <tr>
                <th>Rank</th>
                <th>Player</th>
                <th>Level</th>
                <th>EXP</th>
                <th>HP</th>
                <th>Attack</th>
                <th>PUK</th>
            </tr>
            {% for name, stats in players.items()|sort(attribute='exp', reverse=True) %}
            <tr>
                <td>{{ loop.index }}</td>
                <td>{{ name }}</td>
                <td>{{ stats.level }}</td>
                <td>{{ stats.exp }}</td>
                <td>{{ stats.hp }}</td>
                <td>{{ stats.attack }}</td>
                <td>{{ stats.puk }}</td>
            </tr>
            {% endfor %}
        </table>
    </body>
    </html>
    """
    return render_template_string(html, players=players_dict)


if __name__ == '__main__':
    app.run(port=7700, debug=True)
