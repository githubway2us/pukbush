#!/bin/bash
CONF="/mnt/newhdd/bitcoin/bitcoin.conf"

# เปิด RPG script แยกหน้าต่าง
gnome-terminal -- bash -c "/mnt/newhdd/Dev/tools/rpg_game.sh; exec bash"

while true; do
  clear
  info=$(bitcoin-cli -conf=$CONF getblockchaininfo)
  blocks=$(echo $info | jq ".blocks")
  headers=$(echo $info | jq ".headers")
  progress=$(echo $info | jq ".verificationprogress")
  progress_pct=$(echo "$progress*100" | bc -l | xargs printf "%.2f")
  connections=$(echo $info | jq ".connections")
  initial=$(echo $info | jq ".initialblockdownload")
  mempool=$(bitcoin-cli -conf=$CONF getmempoolinfo | jq ".size")

  # ดึงราคาคริปโตจาก CoinGecko API
  prices=$(curl -s "https://api.coingecko.com/api/v3/simple/price?ids=bitcoin,ethereum,ripple,cardano,worldcoin,solana,binancecoin&vs_currencies=usd" | jq -r '.')
  btc_price=$(echo $prices | jq -r ".bitcoin.usd // \"N/A\"")
  eth_price=$(echo $prices | jq -r ".ethereum.usd // \"N/A\"")
  xrp_price=$(echo $prices | jq -r ".ripple.usd // \"N/A\"")
  ada_price=$(echo $prices | jq -r ".cardano.usd // \"N/A\"")
  sol_price=$(echo $prices | jq -r ".solana.usd // \"N/A\"")
  bnb_price=$(echo $prices | jq -r ".binancecoin.usd // \"N/A\"")

  bar_len=30
  filled=$(printf "%.0f" $(echo "$progress_pct/100*$bar_len" | bc -l))
  empty=$((bar_len-filled))
  bar=$(printf "%0.s█" $(seq 1 $filled))
  bar="$bar$(printf "%0.s░" $(seq 1 $empty))"

  echo -e "\033[1;36m┌──────────────────────────────────────────────┐\033[0m"
  echo -e "\033[1;36m│        🚀 Bitcoin Node & Price Monitor       │\033[0m"
  echo -e "\033[1;36m└──────────────────────────────────────────────┘\033[0m"
  echo -e " ⛓️ Height: $blocks / $headers"
  echo -e " 🔄 Sync: [$bar] $progress_pct %"
  echo -e " 🌐 Peers: $connections | IBD: $initial"
  echo -e " 📦 Mempool: $mempool txs"
  echo -e " 💰 BTC Price: \033[1;32m\$${btc_price} USD\033[0m"
  echo -e " 💸 ETH Price: \033[1;32m\$${eth_price} USD\033[0m"
  echo -e " 💸 XRP Price: \033[1;32m\$${xrp_price} USD\033[0m"
  echo -e " 💸 ADA Price: \033[1;32m\$${ada_price} USD\033[0m"
  echo -e " 💸 SOL Price: \033[1;32m\$${sol_price} USD\033[0m"
  echo -e " 💸 BNB Price: \033[1;32m\$${bnb_price} USD\033[0m"
  echo ""
  sleep 10
done
