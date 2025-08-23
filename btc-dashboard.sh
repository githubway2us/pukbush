#!/bin/bash

CONF="/mnt/newhdd/bitcoin/bitcoin.conf"
TMPBAR="/tmp/btc_progress.dat"
OUTLINE="/tmp/btc_graph.dat"

> $OUTLINE   # เคลียร์ไฟล์เก็บข้อมูลเก่า

while true; do
  clear
  # --- ข้อมูลจาก bitcoin-cli ---
  info=$(bitcoin-cli -conf=$CONF getblockchaininfo)
  blocks=$(echo $info | jq ".blocks")
  headers=$(echo $info | jq ".headers")
  progress=$(echo $info | jq ".verificationprogress")
  progress_pct=$(echo "$progress*100" | bc -l | xargs printf "%.2f")

  connections=$(echo $info | jq ".connections")
  mempool=$(bitcoin-cli -conf=$CONF getmempoolinfo | jq ".size")

  # --- ดึงราคา BTC ---
  btc_price=$(curl -s "https://api.coingecko.com/api/v3/simple/price?ids=bitcoin&vs_currencies=usd" | jq -r ".bitcoin.usd")

  # --- แสดงข้อมูล ---
  echo -e "=== 🟠 Bitcoin Node Dashboard ==="
  echo "Height:      $blocks / $headers"
  echo "Progress:    $progress_pct %"
  echo "Peers:       $connections"
  echo "Mempool:     $mempool txs"
  echo "BTC Price:   \$${btc_price} USD"
  echo

  # --- กราฟแท่ง ---
  echo "Sync $progress_pct" > $TMPBAR
  echo "Peers $connections" >> $TMPBAR
  echo "Mempool $mempool" >> $TMPBAR
  termgraph $TMPBAR --color {green,blue,yellow} --width 50
  echo

  # --- เก็บข้อมูลสำหรับกราฟเส้น ---
  echo "$(date +%s) $blocks $btc_price" >> $OUTLINE

  # --- กราฟเส้น ---
  gnuplot -persist <<-EOF
    set term dumb 100 20
    set title "📈 Bitcoin Sync Progress & Price"
    set xlabel "Time"
    set ylabel "Blocks / Price"
    plot "$OUTLINE" using 1:2 with lines title "Blocks", \
         "$OUTLINE" using 1:3 with lines title "BTC Price (USD)"
EOF

  sleep 30
done
