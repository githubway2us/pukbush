#!/usr/bin/env python3
import subprocess
import requests
import json
import time
import matplotlib.pyplot as plt
from datetime import datetime

# === Config ===
BITCOIN_CLI = "/usr/local/bin/bitcoin-cli"   # path ของ bitcoin-cli (ปรับตามเครื่องคุณ)
CONF = "/mnt/newhdd/bitcoin/bitcoin.conf"    # config file ของโหนด

def run_cli(cmd):
    """เรียก bitcoin-cli และคืนค่า JSON"""
    full_cmd = [BITCOIN_CLI, f"-conf={CONF}"] + cmd
    result = subprocess.run(full_cmd, capture_output=True, text=True)
    if result.returncode != 0:
        return None
    try:
        return json.loads(result.stdout)
    except:
        return result.stdout.strip()

def get_node_status():
    info = run_cli(["getblockchaininfo"])
    mempool = run_cli(["getmempoolinfo"])
    peers = run_cli(["getconnectioncount"])

    return {
        "height": info.get("blocks"),
        "best": info.get("bestblockhash"),
        "headers": info.get("headers"),
        "progress": float(info.get("verificationprogress", 0)) * 100,
        "mempool": mempool.get("size"),
        "peers": peers
    }

def get_btc_price():
    try:
        r = requests.get("https://api.coindesk.com/v1/bpi/currentprice/USD.json")
        return float(r.json()["bpi"]["USD"]["rate_float"])
    except:
        return None

def draw_graph(heights, progresses, prices):
    plt.figure(figsize=(10,6))

    # กราฟซิงค์
    plt.subplot(2,1,1)
    plt.plot(heights, label="Block Height", marker="o")
    plt.title("Bitcoin Node Sync Progress")
    plt.xlabel("Checkpoints")
    plt.ylabel("Block Height")
    plt.legend()

    # กราฟราคา
    plt.subplot(2,1,2)
    plt.plot(prices, label="BTC Price (USD)", color="orange", marker="x")
    plt.title("Bitcoin Price")
    plt.xlabel("Checkpoints")
    plt.ylabel("Price (USD)")
    plt.legend()

    plt.tight_layout()
    plt.show()

if __name__ == "__main__":
    heights, progresses, prices = [], [], []

    for i in range(5):   # ดึงข้อมูล 5 รอบ (ตัวอย่าง)
        status = get_node_status()
        price = get_btc_price()

        print("\n=== 🟠 Bitcoin Node Dashboard ===")
        print(f"Height:    {status['height']} / {status['headers']}")
        print(f"Progress:  {status['progress']:.2f} %")
        print(f"Peers:     {status['peers']}")
        print(f"Mempool:   {status['mempool']} txs")
        print(f"BTC Price: ${price:,.2f} USD" if price else "BTC Price: N/A")

        # เก็บค่าไว้ plot
        heights.append(status["height"])
        progresses.append(status["progress"])
        prices.append(price if price else 0)

        time.sleep(5)  # 5 วินาทีต่อรอบ

    draw_graph(heights, progresses, prices)
